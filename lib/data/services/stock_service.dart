import '../../models/produit.dart';

/// Calculs stock PURS (Phase 0 — découpage Store) : CUMP, valorisation,
/// quantités après mouvement, alertes. Aucun état, aucun I/O.
/// Extraits à l'identique de `Store` (recevoirAchat, valeurStock…).
class StockService {
  const StockService._();

  /// CUMP : (stock × ancien PA + qté × nouveau PA) / nouveau stock.
  /// Identique à `Store.recevoirAchat` (l.2629-2631).
  static double cump({
    required int stockActuel,
    required double prixAchatActuel,
    required double quantiteEntree,
    required double prixUnitaireEntree,
  }) {
    final nouveauStock = stockActuel + quantiteEntree.toInt();
    if (nouveauStock <= 0) return prixUnitaireEntree;
    return (stockActuel * prixAchatActuel +
            quantiteEntree * prixUnitaireEntree) /
        nouveauStock;
  }

  /// Valorisation : Σ(stock × prixAchat). Identique à `valeurStock`.
  static double valorisation(Iterable<Produit> produits) =>
      produits.fold(0.0, (s, p) => s + p.stock * p.prixAchat);

  /// Stock après réception (entrée).
  static int apresReception(int stock, int quantite) => stock + quantite;

  /// Stock après annulation de réception (plancher 0).
  /// Identique à `Store.annulerAchat` (l.2562).
  static int apresAnnulationReception(int stock, int quantite) =>
      (stock - quantite).clamp(0, 1 << 30);

  /// Stock après suppression de vente matériel (remise en rayon).
  static int apresRetourVente(int stock, int quantite) =>
      stock + quantite;

  /// Produits en alerte (stock ≤ seuil).
  static List<Produit> enAlerte(Iterable<Produit> produits) =>
      produits.where((p) => p.alerte).toList();

  /// Quantité signée d'un ajustement manuel (peut être négative).
  static int deltaAjustement(int avant, int apres) => apres - avant;
}
