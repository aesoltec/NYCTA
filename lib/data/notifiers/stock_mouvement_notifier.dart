import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/mouvement_stock.dart';
import '../../models/produit.dart';
import '../../services/cloud_repository.dart';
import 'session_notifier.dart';

/// Mouvements de stock (Phase 2 — découpage Store) : journal traçable +
/// ajustement manuel.
/// Rôle : liste `mouvements`, journalisation, ajustement avec motif.
/// Dépendances : `SessionNotifier` (permission + user.id) ;
/// `genererId` injecté ; liste `produits` partagée (mutée par
/// l'ajustement) ; `fileUpsert` injecté (câblé Phase 5, no-op en test).
/// Extrait à l'identique de `Store` (l.2221-2281 + `_journaliser`).
class StockMouvementNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;
  final List<Produit> produits;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;

  final List<MouvementStock> mouvements;

  StockMouvementNotifier({
    required this.session,
    required this.genererId,
    required this.produits,
    this.fileUpsert,
    List<MouvementStock>? mouvements,
  }) : mouvements = mouvements ?? [];

  List<MouvementStock> mouvementsProduit(String produitId) => mouvements
      .where((m) => m.produitId == produitId)
      .toList();

  List<MouvementStock> mouvementsBoutique(String boutiqueId) =>
      mouvements
          .where((m) => m.boutiqueId == boutiqueId)
          .toList();

  Future<void> journaliser({
    required String produitId,
    required String produitNom,
    required String type,
    required int quantite,
    required int stockApres,
    required String boutiqueId,
    String motif = '',
    String refId = '',
    DateTime? date,
  }) async {
    final m = MouvementStock(
      id: genererId(),
      boutiqueId: boutiqueId,
      produitId: produitId,
      produitNom: produitNom,
      type: type,
      quantite: quantite,
      stockApres: stockApres,
      motif: motif,
      refId: refId,
      date: date ?? DateTime.now(),
      createdBy: session.user.id,
    );
    mouvements.insert(0, m);
    notifyListeners();
    await CloudRepository.upsertMouvement(m);
    await fileUpsert?.call('mouvements_stock', {
      'id': m.id,
      'boutique_id': m.boutiqueId,
      'produit_id': m.produitId,
      'produit_nom': m.produitNom,
      'type': m.type,
      'quantite': m.quantite,
      'stock_apres': m.stockApres,
      'motif': m.motif,
      'ref_id': m.refId,
      'date_mouvement': m.date.toIso8601String(),
      'created_by': m.createdBy,
    });
  }

  /// Ajustement manuel (correction, perte, casse, don) avec motif
  /// obligatoire. Retourne null si OK, sinon un message d'erreur.
  Future<String?> ajusterStock(String produitId, int nouveauStock,
      String motif, String boutiqueId) async {
    if (!session.peut(Permission.gererStock)) {
      return 'Réservé à la gestion du stock';
    }
    if (motif.trim().length < 3) return 'Motif requis (3 car. min.)';
    if (nouveauStock < 0) return 'Le stock ne peut pas être négatif';
    final i = produits.indexWhere((x) => x.id == produitId);
    if (i < 0) return 'Produit introuvable';
    final avant = produits[i].stock;
    if (avant == nouveauStock) return 'Aucun changement';
    final maj = produits[i].copyWith(stock: nouveauStock);
    produits[i] = maj;
    notifyListeners();
    await CloudRepository.upsertProduit(maj);
    await fileUpsert?.call('produits', {'id': maj.id});
    await journaliser(
      produitId: maj.id,
      produitNom: maj.libelle,
      type: MouvementStock.ajustement,
      quantite: nouveauStock - avant,
      stockApres: nouveauStock,
      motif: motif.trim(),
      boutiqueId: boutiqueId,
    );
    return null;
  }
}
