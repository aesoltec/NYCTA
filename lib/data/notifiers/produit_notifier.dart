import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/mouvement_stock.dart';
import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart';
import 'session_notifier.dart';

/// Produits du stock (Phase 3 — découpage Store) : CRUD + galerie +
/// archivage + vente atomique + déduction documentaire.
/// Rôle : fiches produits de la boutique, sync catalogue, traçabilité.
/// Dépendances : `SessionNotifier` (rôle, user.id) ; `genererId` injecté ;
/// listes `produits`, `catalogue`, `transactions`, `mouvements` partagées ;
/// callbacks `fileUpsert`, `ajouterVente` (retourne l'id Tx),
/// `journaliserMouvement` (câblés Phase 5, no-op en test).
/// Extrait à l'identique de `Store` (l.1972-2212 + `_syncCatalogue`).
class ProduitNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;
  final List<Produit> produits;
  final List<Tarif> catalogue;
  final List<Tx> transactions;
  final List<MouvementStock> mouvements;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;
  final Future<String> Function({
    required TypeTransaction type,
    required double montant,
    double cout,
    String? clientNom,
    DateTime? date,
    Map<String, dynamic> details,
  })? ajouterVente;
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
  })? journaliserMouvement;
  String boutiqueId;

  ProduitNotifier({
    required this.session,
    required this.genererId,
    required this.produits,
    required this.catalogue,
    required this.transactions,
    required this.mouvements,
    this.fileUpsert,
    this.ajouterVente,
    this.journaliserMouvement,
    this.boutiqueId = '',
  });

  List<Produit> get produitsBoutique =>
      produits.where((p) => p.boutiqueId == boutiqueId).toList();

  List<Produit> get alertesStock =>
      produitsBoutique.where((p) => p.alerte).toList();

  static bool memeLibelle(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Future<String?> ajouterProduit(Produit p) async {
    if (p.libelle.trim().length < 2) {
      return 'Libellé requis (2 car. min.)';
    }
    if (produits.any((x) =>
        x.boutiqueId == p.boutiqueId &&
        memeLibelle(x.libelle, p.libelle))) {
      return '« ${p.libelle.trim()} » existe déjà dans cette boutique — modifiez sa fiche au lieu de le recréer';
    }
    final produit = Produit(
      id: genererId(),
      boutiqueId: p.boutiqueId,
      libelle: p.libelle.trim(),
      categorie: p.categorie,
      prixAchat: p.prixAchat,
      prixVente: p.prixVente,
      stock: p.stock,
      seuil: p.seuil,
      imagePath: p.imagePath,
      images: p.images,
      // Remplie au premier ajout, jamais écrasée ensuite (badge Nouveau).
      dateAjout: p.dateAjout ?? DateTime.now(),
    );
    produits.add(produit);
    notifyListeners();
    await CloudRepository.upsertProduit(produit);
    await fileUpsert?.call('produits', _payload(produit));
    await syncCatalogueDepuisProduit(produit);
    return null;
  }

  /// Payload de la FILE hors-ligne (rejeu a la reconnexion).
  ///
  /// `image_path` et `images` en sont VOLONTAIREMENT absents : le modele
  /// stocke des CHEMINS LOCAUX (`<docs>/media/produit/...`) alors que la
  /// base doit contenir des URL publiques. Les rejouer tel quel
  /// ecraserait les URL deja publiees par un chemin local inexistant sur
  /// les autres appareils - les images « reviendraient » en placeholder.
  /// La publication est faite par `CloudRepository.upsertProduit`, appele
  /// systematiquement, qui applique `_publier`.
  ///
  /// Consequence assumee : un produit cree HORS LIGNE n'aura pas ses
  /// images en base tant qu'il n'est pas re-enregistre avec le cloud
  /// joignable. Ne surtout pas « corriger » en ajoutant les images ici.
  Map<String, dynamic> _payload(Produit p) => {
        'id': p.id,
        'boutique_id': p.boutiqueId,
        'libelle': p.libelle,
        'categorie': p.categorie,
        'prix_achat': p.prixAchat,
        'prix_vente': p.prixVente,
        'quantite_stock': p.stock,
        'seuil_alerte': p.seuil,
        'date_ajout': p.dateAjout?.toIso8601String(),
        'actif': true,
      };

  /// Modification complète d'un produit (tap sur la fiche stock).
  Future<String?> majProduit(Produit p) async {
    final i = produits.indexWhere((x) => x.id == p.id);
    if (i < 0) return 'Produit introuvable';
    if (produits.any((x) =>
        x.id != p.id &&
        x.boutiqueId == p.boutiqueId &&
        memeLibelle(x.libelle, p.libelle))) {
      return 'Un autre produit porte déjà ce nom dans cette boutique';
    }
    final avant = produits[i].stock;
    // La date d'ajout d'origine est conservée (jamais écrasée en modif).
    var maj = p;
    if (maj.dateAjout == null && produits[i].dateAjout != null) {
      maj = p.copyWith(dateAjout: produits[i].dateAjout);
    }
    produits[i] = maj;
    notifyListeners();
    await CloudRepository.upsertProduit(maj);
    await fileUpsert?.call('produits', _payload(maj));
    await syncCatalogueDepuisProduit(maj);
    // Correction manuelle du stock via la fiche : tracée.
    if (maj.stock != avant) {
      await journaliserMouvement?.call(
        produitId: maj.id,
        produitNom: maj.libelle,
        type: MouvementStock.ajustement,
        quantite: maj.stock - avant,
        stockApres: maj.stock,
        boutiqueId: maj.boutiqueId,
        motif: 'Correction fiche produit',
      );
    }
    return null;
  }

  Future<void> archiverProduit(String id) async {
    final i = produits.indexWhere((x) => x.id == id);
    if (i >= 0) {
      produits.removeAt(i);
      notifyListeners();
      await CloudRepository.archiverProduit(id);
      await fileUpsert?.call('produits', {'id': id, 'actif': false});
    }
  }

  /// Suppression définitive avec garde-fou : si des transactions
  /// référencent le produit, refus + archivage conseillé.
  /// Seuls admin/gérant retirent un article.
  Future<String?> supprimerProduit(String id,
      {bool forcerArchive = false}) async {
    if (session.role != Role.admin &&
        session.role != Role.gerant) {
      return 'Retrait d\'article réservé (admin, gérant)';
    }
    final i = produits.indexWhere((x) => x.id == id);
    if (i < 0) return 'Produit introuvable';
    final lie = transactions.any((t) {
      final lignes =
          (t.details['lignes'] as List?) ?? const [];
      return lignes.any((l) =>
          l is Map && l['produitId']?.toString() == id);
    });
    if (lie && !forcerArchive) {
      return 'Ce produit a déjà été vendu — archivez-le plutôt pour garder un historique cohérent';
    }
    await archiverProduit(id);
    return null;
  }

  /// Tout produit du stock est présent au catalogue (même libellé).
  Future<void> syncCatalogueDepuisProduit(Produit p) async {
    final i = catalogue.indexWhere(
        (t) => t.actif && memeLibelle(t.libelle, p.libelle));
    if (i >= 0) {
      if (catalogue[i].prix != p.prixVente ||
          catalogue[i].categorie != p.categorie) {
        catalogue[i] = catalogue[i]
            .copyWith(prix: p.prixVente, categorie: p.categorie);
        notifyListeners();
        await CloudRepository.upsertTarif(catalogue[i]);
      }
      return;
    }
    final t = Tarif(
      id: genererId(),
      libelle: p.libelle.trim(),
      categorie: p.categorie,
      prix: p.prixVente,
      description: 'Depuis le stock',
      actif: true,
      dateAjout: DateTime.now(),
    );
    catalogue.add(t);
    notifyListeners();
    await CloudRepository.upsertTarif(t);
  }

  /// Décrémente le stock pour chaque ligne documentaire correspondante.
  /// Retourne les libellés ignorés faute de stock suffisant.
  Future<List<String>> deduireStockPourLignes(
      List<Map<String, dynamic>> lignes,
      {String refId = '',
      DateTime? date}) async {
    final ignores = <String>[];
    for (final l in lignes) {
      final i = produits.indexWhere((p) =>
          p.boutiqueId == boutiqueId &&
          memeLibelle(p.libelle, l['libelle']?.toString() ?? ''));
      if (i < 0) continue;
      final p = produits[i];
      final qte = (l['quantite'] as num?)?.toInt() ?? 0;
      if (p.stock < qte) {
        ignores.add('${l['libelle']} (stock ${p.stock})');
        continue;
      }
      final maj = p.copyWith(stock: p.stock - qte);
      produits[i] = maj;
      await CloudRepository.upsertProduit(maj);
      await fileUpsert?.call('produits', _payload(maj));
      await journaliserMouvement?.call(
        produitId: maj.id,
        produitNom: maj.libelle,
        type: MouvementStock.sortie,
        quantite: -qte,
        stockApres: maj.stock,
        boutiqueId: maj.boutiqueId,
        motif: 'Document commercial',
        refId: refId,
        date: date,
      );
    }
    notifyListeners();
    return ignores;
  }

  /// Vente atomique : stock −, transaction, mouvement. Lève StateError
  /// si stock insuffisant ou produit introuvable.
  Future<void> vendreProduit(Produit p, int quantite,
      {String? clientNom, DateTime? date}) async {
    if (quantite > p.stock) throw StateError('Stock insuffisant');
    final idx = produits.indexWhere((x) => x.id == p.id);
    if (idx < 0) throw StateError('Produit introuvable');
    final produit = p.copyWith(stock: p.stock - quantite);
    produits[idx] = produit;
    notifyListeners();
    await CloudRepository.upsertProduit(produit);
    await fileUpsert?.call('produits', _payload(produit));
    final txId = await ajouterVente?.call(
      type: TypeTransaction.venteMateriel,
      montant: p.prixVente * quantite,
      cout: p.prixAchat * quantite,
      clientNom: clientNom,
      date: date,
      details: {
        'lignes': [
          {
            'produitId': p.id,
            'libelle': p.libelle,
            'quantite': quantite,
            'prixUnitaire': p.prixVente
          }
        ]
      },
    );
    await journaliserMouvement?.call(
      produitId: produit.id,
      produitNom: produit.libelle,
      type: MouvementStock.sortie,
      quantite: -quantite,
      stockApres: produit.stock,
      boutiqueId: produit.boutiqueId,
      motif: clientNom == null ? 'Vente directe' : 'Vente — $clientNom',
      refId: txId ?? '',
      date: date,
    );
  }
}
