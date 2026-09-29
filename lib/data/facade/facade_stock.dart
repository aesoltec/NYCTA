// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/document.dart';
import '../../models/mouvement_stock.dart';
import '../../models/produit.dart';
import '../services/stock_service.dart';

/// Façade StoreStockFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreStockFacade on Store {
  // ---------- Produits (délégué à `produit`, Phase 5) ----------
  List<Produit> get produitsBoutique => produit.produitsBoutique;

  List<Produit> get alertesStock => produit.alertesStock;

  Future<String?> ajouterProduit(Produit p) =>
      produit.ajouterProduit(p);

  Future<String?> majProduit(Produit p) => produit.majProduit(p);

  Future<void> archiverProduit(String id) =>
      produit.archiverProduit(id);

  Future<String?> supprimerProduit(String id,
          {bool forcerArchive = false}) =>
      produit.supprimerProduit(id, forcerArchive: forcerArchive);

  Future<List<String>> deduireStockPourLignes(List<LigneDoc> lignes,
          {String refId = '', DateTime? date}) =>
      produit.deduireStockPourLignes(
          [for (final l in lignes) {'libelle': l.libelle, 'quantite': l.quantite}],
          refId: refId,
          date: date);

  Future<void> vendreProduit(Produit p, int quantite,
          {String? clientNom, DateTime? date}) =>
      produit.vendreProduit(p, quantite,
          clientNom: clientNom, date: date);

  // ---------- Mouvements (délégué à `stockMouvements`, Phase 5) ----------
  List<MouvementStock> get mouvementsBoutique =>
      this.stockMouvements.mouvementsBoutique(boutiqueId);

  List<MouvementStock> mouvementsProduit(String produitId) =>
      this.stockMouvements.mouvementsProduit(produitId);

  /// Valorisation du stock (quantité × coût d'achat courant).
  double get valeurStock =>
      StockService.valorisation(produit.produitsBoutique);

  /// Ajustement manuel (délégué à `stockMouvements`, Phase 5).
  Future<String?> ajusterStock(String produitId, int nouveauStock,
          String motif) =>
      this.stockMouvements.ajusterStock(
          produitId, nouveauStock, motif, boutiqueId);

}
