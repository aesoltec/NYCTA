import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../models/document.dart';
import '../../models/enums.dart';
import '../../services/cloud_repository.dart';
import '../../services/document_service.dart';
import 'session_notifier.dart';

/// Documents commerciaux (Phase 3 — découpage Store) : émission,
/// workflow brouillon → émis → payé/annulé, signature client,
/// transformation devis → facture.
/// Rôle : historique `documentsEmis`, gardes par rôle.
/// Dépendances : `SessionNotifier` (rôle, permissions) ;
/// `numeroDocument(prefixe)` injecté (compteur) ; `deduireStock`
/// injecté (sortie de stock facture, câblé Phase 5) ;
/// `boutiqueId` mutable (façade Phase 5).
/// Extrait à l'identique de `Store` (l.1824-1952).
class DocumentNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final Future<String> Function(String prefixe) numeroDocument;
  final Future<List<String>> Function(List<LigneDoc> lignes)? deduireStock;
  String boutiqueId;

  final List<DocumentBati> documentsEmis;

  /// Journal des modifications de documents ÉMIS (traçabilité).
  ///
  /// Une correction d'un document émis laisse une trace : qui, quand,
  /// pourquoi. C'est ce qui autorise une telle correction sans rompre
  /// l'exigence « un numéro = un contenu » — le contenu a bougé, mais il
  /// est resté traçable.
  final List<ModificationDocument> modifications;

  DocumentNotifier({
    required this.session,
    required this.numeroDocument,
    this.deduireStock,
    this.boutiqueId = '',
    List<DocumentBati>? documentsEmis,
    List<ModificationDocument>? modifications,
  })  : documentsEmis = documentsEmis ?? [],
        modifications = modifications ?? [];

  Future<String?> enregistrerDocument(DocumentBati d,
      {DateTime? date}) async {
    final doc = session.role == Role.vendeur
        ? d.copyWith(statut: 'brouillon')
        : d.copyWith(statut: 'emis');
    documentsEmis.insert(0, doc);
    notifyListeners();
    if (CloudRepository.actif) {
      return CloudRepository.enregistrerDocument(doc, boutiqueId,
          date: date);
    }
    return null;
  }

  /// Modifie un document (client, lignes, date, taux, note, échéance).
  ///
  /// QUOI EST MODIFIABLE — règle professionnelle, elle dépend de la
  /// NATURE du document et pas seulement de son statut :
  /// - `brouillon` : toujours. Personne ne l'a encore vu.
  /// - `emis` DEVIS / BON DE COMMANDE / BORDEREAU : oui, mais **motif
  ///   obligatoire** et écriture au journal. Un devis est une proposition,
  ///   un BC un engagement révisable, un BL se corrige en pratique
  ///   (reliquats, avaries).
  /// - `emis` FACTURE / TICKET : **jamais**. Un numéro de facture ne doit
  ///   correspondre qu'à un seul contenu ; la voie professionnelle est un
  ///   avoir (note de crédit), ou `annulerDocument` (motif tracé) puis
  ///   ré-émission.
  /// - `annule` / `paye` : figés.
  ///
  /// Le refus nomme la voie légitime : un message « modification
  /// impossible » sans issue oblige l'utilisateur à chercher.
  ///
  /// Les totaux sont toujours recalculés : un document dont le total ne
  /// correspond plus à ses lignes est une facture fausse.
  Future<String?> modifierDocument(
    DocumentBati d, {
    double? tvaPct,
    String? motif,
  }) async {
    final i = documentsEmis.indexWhere((e) =>
        e.numero == d.numero || (d.id != null && e.id == d.id));
    if (i < 0) return 'Document introuvable';
    final avant = documentsEmis[i];

    if (!avant.peutModifier) {
      return avant.statut == 'emis'
          ? '${avant.type.titre} émise : son contenu est figé — un numéro '
              'de facture ne doit correspondre qu\'à un seul contenu. '
              'Émettez un avoir (note de crédit), ou annulez le document '
              '(motif obligatoire) puis ré-émettez-le.'
          : 'Document ${avant.statut} : il n\'est plus modifiable.';
    }
    // Un émis modifiable reste traçable : pas de modification sans motif.
    if (avant.exigeMotifModification &&
        (motif == null || motif.trim().isEmpty)) {
      return 'Motif de modification obligatoire (document émis)';
    }

    final recalcule = tvaPct == null ? d : d.recalculeTaux(tvaPct);
    documentsEmis[i] = recalcule;
    // Journal : uniquement pour un émis (un brouillon n'a pas d'histoire
    // à protéger, et la trace doit rester lisible).
    if (avant.exigeMotifModification) {
      modifications.insert(
        0,
        ModificationDocument(
          numero: avant.numero,
          date: DateTime.now().toIso8601String(),
          auteur: '${session.user.nom} (${session.role.name})',
          motif: motif!.trim(),
          resume: resumeModification(avant, recalcule, recalcule.devise),
        ),
      );
    }
    notifyListeners();
    if (CloudRepository.actif) {
      await CloudRepository.majDocument(recalcule, boutiqueId,
          id: documentsEmis[i].id, numero: d.numero);
      // Le journal part AVEC le document : s'il est ecrit apres, un
      // document modifie mais non journalise resterait invisible et la
      // modification aurait été faite « sans trace » — l'inverse du but.
      final derniere = modifications.isEmpty ? null : modifications.first;
      if (derniere != null) {
        await CloudRepository.journaliserModification(derniere, boutiqueId);
      }
    }
    return null;
  }

  /// Recharge le journal des corrections depuis le cloud (au démarrage).
  ///
  /// Sans cet appel, le journal ne survivrait pas au rechargement : il
  /// ne serait visible que jusqu'a la fermeture de l'application.
  Future<void> chargerJournal() async {
    if (!CloudRepository.actif || documentsEmis.isEmpty) return;
    final numeros = documentsEmis.map((d) => d.numero).toList();
    final charge = await CloudRepository.chargerModifications(numeros);
    if (charge.isEmpty) return;
    // On remplace le journal en memoire plutot que d'ajouter : le cloud
    // fait foi, et un doublon n'apprendrait rien a personne.
    modifications
      ..clear()
      ..addAll(charge);
    notifyListeners();
  }

  /// Résumé lisible d'une modification, destiné au journal.
  ///
  /// On compare ce qui change vraiment : nombre de lignes, total, et
  /// champs de tête. Un journal qui recopie tout le document n'apprend
  /// rien à personne.
  static String resumeModification(
      DocumentBati avant, DocumentBati apres, String devise) {
    final parties = <String>[];
    if (avant.lignes.length != apres.lignes.length) {
      parties.add('${avant.lignes.length} → ${apres.lignes.length} lignes');
    }
    if ((avant.totalTTC - apres.totalTTC).abs() > 0.005) {
      parties.add('total ${C.money(avant.totalTTC, devise)} → '
          '${C.money(apres.totalTTC, devise)}');
    }
    if (avant.date != apres.date) {
      parties.add('date ${avant.date} → ${apres.date}');
    }
    if (avant.client != apres.client) {
      parties.add('client ${avant.client} → ${apres.client}');
    }
    if (avant.note != apres.note) {
      parties.add('note modifiée');
    }
    if (avant.echeance != apres.echeance) {
      parties.add('échéance ${avant.echeance} → ${apres.echeance}');
    }
    // Rien de detectable ci-dessus : le contenu des lignes a changé sans
    // que le total bouge (quantité et prix compensés, désignation).
    if (parties.isEmpty) parties.add('détail des lignes modifié');
    return parties.join(', ');
  }

  /// Validation manager d'un brouillon vendeur : `brouillon` → `emis`.
  Future<String?> validerDocument(String numero) async {
    if (!session.peut(Permission.gererDocuments) ||
        session.role == Role.vendeur) {
      return 'Validation réservée (admin, gérant, comptable)';
    }
    final i = documentsEmis.indexWhere((e) => e.numero == numero);
    if (i < 0) return 'Document introuvable';
    if (documentsEmis[i].statut == 'emis') return 'Déjà validé';
    documentsEmis[i] = documentsEmis[i].copyWith(statut: 'emis');
    notifyListeners();
    await CloudRepository.majStatutDocument(
      id: documentsEmis[i].id,
      numero: numero,
      statut: 'emis',
    );
    return null;
  }

  /// Encaissement : `emis` → `paye` (aucune écriture auto ici —
  /// l'encaissement passe par une vente).
  Future<String?> payerDocument(String numero) async {
    if (!session.peut(Permission.gererDocuments) ||
        session.role == Role.vendeur) {
      return 'Réservé (admin, gérant, comptable, caissier)';
    }
    final i = documentsEmis.indexWhere((e) => e.numero == numero);
    if (i < 0) return 'Document introuvable';
    if (documentsEmis[i].statut != 'emis') {
      return 'Seul un document émis peut être marqué payé';
    }
    documentsEmis[i] = documentsEmis[i].copyWith(statut: 'paye');
    notifyListeners();
    await CloudRepository.majStatutDocument(
      id: documentsEmis[i].id,
      numero: numero,
      statut: 'paye',
    );
    return null;
  }

  /// Annulation avec motif : `brouillon`/`emis` → `annule` (admin/gérant).
  Future<String?> annulerDocument(String numero, String motif) async {
    if (session.role != Role.admin &&
        session.role != Role.gerant) {
      return 'Annulation réservée (admin, gérant)';
    }
    if (motif.trim().length < 3) return 'Motif requis (3 car. min.)';
    final i = documentsEmis.indexWhere((e) => e.numero == numero);
    if (i < 0) return 'Document introuvable';
    if (documentsEmis[i].statut == 'annule') return 'Déjà annulé';
    documentsEmis[i] = documentsEmis[i].copyWith(
        statut: 'annule', motifAnnulation: motif.trim());
    notifyListeners();
    await CloudRepository.majStatutDocument(
      id: documentsEmis[i].id,
      numero: numero,
      statut: 'annule',
    );
    return null;
  }

  /// Joint la signature manuscrite du client à un document déjà émis.
  Future<void> joindreSignatureClient(
      String numero, String cheminLocal) async {
    final i = documentsEmis.indexWhere((e) => e.numero == numero);
    if (i < 0) return;
    documentsEmis[i] = documentsEmis[i]
        .copyWith(signatureClientPath: cheminLocal);
    notifyListeners();
    if (CloudRepository.actif) {
      await CloudRepository.majSignatureDocument(
        id: documentsEmis[i].id,
        numero: numero,
        cheminLocal: cheminLocal,
      );
    }
  }

  Future<DocumentBati> transformerDevisEnFacture(
      DocumentBati devis) async {
    final facture = DocumentBati(
      type: TypeDocument.facture,
      numero: await numeroDocument('FACT'),
      date: devis.date,
      client: devis.client,
      lignes: devis.lignes,
      totalHT: devis.totalHT,
      tva: devis.tva,
      totalTTC: devis.totalTTC,
      devise: devis.devise,
      // La signature du client accompagne la transformation.
      signatureClientPath: devis.signatureClientPath,
    );
    documentsEmis.insert(0, facture);
    notifyListeners();
    // La facture issue du devis est une vente ferme : sortie de stock.
    await deduireStock?.call(facture.lignes);
    if (CloudRepository.actif) {
      await CloudRepository.enregistrerDocument(facture, boutiqueId,
          date: DocumentService.parseAffichage(devis.date));
    }
    return facture;
  }
}
