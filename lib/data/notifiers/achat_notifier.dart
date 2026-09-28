import 'package:flutter/foundation.dart';
import '../../models/achat.dart';
import '../../models/charge.dart';
import '../../models/enums.dart';
import '../../models/mouvement_stock.dart';
import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../../services/cloud_repository.dart';
import 'session_notifier.dart';

/// Achats fournisseurs (Phase 3 — découpage Store) : cycle complet
/// demande → valide → reçu → payé → annulé.
/// Rôle : achats, réception stock (CUMP), paiements, annulations.
/// Dépendances : `SessionNotifier` (permissions, user.id) ;
/// `genererId` et `numeroDocument(prefixe)` injectés ; listes `achats`,
/// `produits`, `catalogue`, `depenses`, `mouvements` partagées ;
/// callbacks `fileUpsert`, `upsertProduitLocal`, `syncCatalogue`,
/// `journaliser`, `ajouterChargeDepense`, `comptabiliserReception`,
/// `comptabiliserPaiement`, `contrePasser` (câblés Phase 5, no-op en test).
/// Contrat `ajouterChargeDepense` : insère la charge TELLE QUELLE
/// (id déjà attribué, SANS recomptabiliser — le paiement poste déjà
/// en BQ, sinon double caisse, cf. point 30).
/// Extrait à l'identique de `Store` (l.2545-2760).
class AchatNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;
  final Future<String> Function(String prefixe) numeroDocument;
  final List<Achat> achats;
  final List<Produit> produits;
  final List<Tarif> catalogue;
  final List<Charge> depenses;
  final List<MouvementStock> mouvements;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;
  final Future<void> Function(Produit p)? upsertProduitLocal;
  final Future<void> Function(Produit p)? syncCatalogue;
  final Future<void> Function({
    required String produitId,
    required String produitNom,
    required String type,
    required int quantite,
    required int stockApres,
    required String boutiqueId,
    String motif,
    String refId,
    DateTime? date,
  })? journaliser;
  final Future<void> Function(Charge c)? ajouterChargeDepense;
  final Future<void> Function(Achat a)? comptabiliserReception;
  final Future<void> Function(Achat a, double montant, String mode)?
      comptabiliserPaiement;
  final Future<void> Function(String refId, String motif)? contrePasser;

  AchatNotifier({
    required this.session,
    required this.genererId,
    required this.numeroDocument,
    required this.achats,
    required this.produits,
    required this.catalogue,
    required this.depenses,
    required this.mouvements,
    this.fileUpsert,
    this.upsertProduitLocal,
    this.syncCatalogue,
    this.journaliser,
    this.ajouterChargeDepense,
    this.comptabiliserReception,
    this.comptabiliserPaiement,
    this.contrePasser,
  });

  static bool _meme(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Future<String?> creerAchat(Achat brouillon) async {
    if (brouillon.fournisseurNom.trim().length < 2) {
      return 'Fournisseur requis (2 car. min.)';
    }
    if (brouillon.lignes.isEmpty) return 'Ajoutez au moins une ligne';
    for (final l in brouillon.lignes) {
      if (l.produitNom.trim().isEmpty) return 'Ligne sans libellé';
      if (l.quantite <= 0) {
        return 'Quantité > 0 requise (${l.produitNom})';
      }
      if (l.prixUnitaire < 0) return 'Prix invalide (${l.produitNom})';
    }
    final statut = session.peut(Permission.gererAchats)
        ? (brouillon.statut == Achat.statutDemande
            ? Achat.statutDemande
            : Achat.statutEnAttente)
        : Achat.statutDemande;
    final a = Achat(
      id: genererId(),
      numero: await numeroDocument('ACH'),
      boutiqueId: brouillon.boutiqueId,
      fournisseurId: brouillon.fournisseurId,
      fournisseurNom: brouillon.fournisseurNom.trim(),
      lignes: brouillon.lignes,
      date: brouillon.date,
      statut: statut,
      modePaiement: brouillon.modePaiement,
      referenceFacture: brouillon.referenceFacture?.trim(),
      notes: brouillon.notes?.trim(),
      createdBy: session.user.id,
      createdAt: DateTime.now(),
    );
    achats.insert(0, a);
    notifyListeners();
    await CloudRepository.upsertAchat(a);
    await fileUpsert?.call('achats', _payload(a));
    return null;
  }

  Map<String, dynamic> _payload(Achat a) => {
        'id': a.id,
        'numero': a.numero,
        'boutique_id': a.boutiqueId,
        'fournisseur_id': a.fournisseurId,
        'fournisseur_nom': a.fournisseurNom,
        'lignes': [for (final l in a.lignes) l.toJson()],
        'date_achat': a.date.toIso8601String(),
        'statut': a.statut,
        'mode_paiement': a.modePaiement,
        'reference_facture': a.referenceFacture,
        'notes': a.notes,
        'motif_annulation': a.motifAnnulation,
        'montant_paye': a.montantPaye,
        'created_by': a.createdBy,
        'created_at': a.createdAt.toIso8601String(),
      };

  /// Correction d'un brouillon (demande/en_attente uniquement).
  Future<String?> majAchat(Achat maj) async {
    final i = achats.indexWhere((x) => x.id == maj.id);
    if (i < 0) return 'Achat introuvable';
    final actuel = achats[i];
    if (actuel.statut != Achat.statutDemande &&
        actuel.statut != Achat.statutEnAttente) {
      return 'Seule une demande ou un achat en attente est modifiable';
    }
    if (maj.lignes.isEmpty) return 'Ajoutez au moins une ligne';
    achats[i] = maj;
    notifyListeners();
    await CloudRepository.upsertAchat(maj);
    await fileUpsert?.call('achats', _payload(maj));
    return null;
  }

  /// Validation : demande/en_attente → valide (dette fournisseur).
  Future<String?> validerAchat(String id) async {
    if (!session.peut(Permission.gererAchats)) {
      return 'Réservé (admin, gérant, comptable)';
    }
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    if (!achats[i].peutValider) {
      return 'Statut incompatible avec la validation';
    }
    achats[i] = achats[i].copyWith(statut: Achat.statutValide);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await fileUpsert?.call('achats', _payload(achats[i]));
    return null;
  }

  /// Réception : valide → recu + entrée stock (CUMP) par ligne.
  Future<String?> recevoirAchat(String id) async {
    if (!session.peut(Permission.gererAchats)) {
      return 'Réservé (admin, gérant, comptable)';
    }
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutRecevoir) return 'Validez d\'abord cet achat';
    for (final l in a.lignes) {
      final pi = produits.indexWhere((p) =>
          p.boutiqueId == a.boutiqueId &&
          (l.produitId.isNotEmpty
              ? p.id == l.produitId
              : _meme(p.libelle, l.produitNom)));
      if (pi >= 0) {
        final p = produits[pi];
        final qte = l.quantite.toInt();
        final nouveauStock = p.stock + qte;
        // CUMP : (stock × ancien PA + qté × nouveau PA) / nouveau stock.
        final cump = nouveauStock > 0
            ? (p.stock * p.prixAchat + l.quantite * l.prixUnitaire) /
                nouveauStock
            : l.prixUnitaire;
        final maj = p.copyWith(stock: nouveauStock, prixAchat: cump);
        produits[pi] = maj;
        await CloudRepository.upsertProduit(maj);
        await upsertProduitLocal?.call(maj);
        await journaliser?.call(
          produitId: maj.id,
          produitNom: maj.libelle,
          type: MouvementStock.entree,
          quantite: qte,
          stockApres: nouveauStock,
          boutiqueId: maj.boutiqueId,
          motif: 'Réception ${a.numero} — ${a.fournisseurNom}',
          refId: a.id,
          date: a.date,
        );
      } else {
        final nouveau = Produit(
          id: genererId(),
          boutiqueId: a.boutiqueId,
          libelle: l.produitNom.trim(),
          categorie: 'Autre',
          prixAchat: l.prixUnitaire,
          prixVente: l.prixUnitaire,
          stock: l.quantite.toInt(),
          seuil: 3,
        );
        produits.add(nouveau);
        await CloudRepository.upsertProduit(nouveau);
        await upsertProduitLocal?.call(nouveau);
        await syncCatalogue?.call(nouveau);
        await journaliser?.call(
          produitId: nouveau.id,
          produitNom: nouveau.libelle,
          type: MouvementStock.entree,
          quantite: l.quantite.toInt(),
          stockApres: nouveau.stock,
          boutiqueId: nouveau.boutiqueId,
          motif: 'Création à la réception ${a.numero}',
          refId: a.id,
          date: a.date,
        );
      }
    }
    achats[i] = a.copyWith(statut: Achat.statutRecu);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await fileUpsert?.call('achats', _payload(achats[i]));
    await comptabiliserReception?.call(a);
    return null;
  }

  /// Paiement total ou partiel : met à jour le payé/restant et enregistre
  /// une charge « Fournisseurs » (sortie de trésorerie traçable).
  Future<String?> payerAchat(String id, double montant,
      {String? mode}) async {
    if (!session.peut(Permission.gererAchats)) {
      return 'Réservé (admin, gérant, comptable)';
    }
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutPayer) return 'Aucun montant à payer sur cet achat';
    if (montant <= 0) return 'Montant > 0 requis';
    if (montant > a.montantRestant + 0.001) {
      return 'Montant supérieur au reste dû (${a.montantRestant.toStringAsFixed(0)})';
    }
    final paye = (a.montantPaye + montant).clamp(0.0, a.montantTTC);
    achats[i] = a.copyWith(
        montantPaye: paye, modePaiement: mode ?? a.modePaiement);
    final charge = Charge(
      id: genererId(),
      boutiqueId: a.boutiqueId,
      categorie: 'Fournisseurs',
      libelle: 'Paiement ${a.numero} — ${a.fournisseurNom}',
      montant: montant,
      date: DateTime.now(),
      recurrente: false,
    );
    depenses.insert(0, charge);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await fileUpsert?.call('achats', _payload(achats[i]));
    await CloudRepository.upsertCharge(charge);
    await ajouterChargeDepense?.call(charge);
    await comptabiliserPaiement?.call(
        achats[i], montant, mode ?? a.modePaiement);
    return null;
  }

  /// Annulation avec motif obligatoire. Si déjà reçu : contre-écriture
  /// stock (retrait des quantités, plancher 0) + contre-passation.
  Future<String?> annulerAchat(String id, String motif) async {
    if (!session.peut(Permission.gererAchats)) {
      return 'Réservé (admin, gérant, comptable)';
    }
    if (motif.trim().length < 3) return 'Motif requis (3 car. min.)';
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutAnnuler) return 'Achat déjà annulé';
    if (a.statut == Achat.statutRecu) {
      for (final l in a.lignes) {
        final pi = produits.indexWhere((p) =>
            p.boutiqueId == a.boutiqueId &&
            (l.produitId.isNotEmpty
                ? p.id == l.produitId
                : _meme(p.libelle, l.produitNom)));
        if (pi >= 0) {
          final p = produits[pi];
          final maj = p.copyWith(
              stock: (p.stock - l.quantite.toInt()).clamp(0, 1 << 30));
          produits[pi] = maj;
          await CloudRepository.upsertProduit(maj);
          await upsertProduitLocal?.call(maj);
          await journaliser?.call(
            produitId: maj.id,
            produitNom: maj.libelle,
            type: MouvementStock.ajustement,
            quantite: maj.stock - p.stock,
            stockApres: maj.stock,
            boutiqueId: maj.boutiqueId,
            motif: 'Annulation ${a.numero} : ${motif.trim()}',
            refId: a.id,
          );
        }
      }
    }
    achats[i] = a.copyWith(
        statut: Achat.statutAnnule, motifAnnulation: motif.trim());
    notifyListeners();
    if (a.statut == Achat.statutRecu) {
      await contrePasser?.call(a.id, 'annulation ${a.numero}');
    }
    await CloudRepository.upsertAchat(achats[i]);
    await fileUpsert?.call('achats', _payload(achats[i]));
    return null;
  }
}
