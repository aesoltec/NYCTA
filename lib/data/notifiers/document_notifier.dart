import 'package:flutter/foundation.dart';
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

  final List<DocumentBati> documentsEmis = [];

  DocumentNotifier({
    required this.session,
    required this.numeroDocument,
    this.deduireStock,
    this.boutiqueId = '',
  });

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
