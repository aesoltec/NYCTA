import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/produit.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import 'session_notifier.dart';

/// Transactions / ventes (Phase 3 — découpage Store) : CRUD + crédit +
/// encaissement + restauration stock.
/// Rôle : journal des ventes de la boutique, créances.
/// Dépendances : `SessionNotifier` (user.id, permission vendre) ;
/// `genererId` injecté ; listes `transactions` et `produits` partagées ;
/// `boutiqueId` mutable (façade Phase 5) ; callbacks compta
/// `comptabiliserVente`/`contrePasser`/`posterEncaissement` + `fileUpsert`
/// injectés (câblés Phase 5, no-op en test).
/// Extrait à l'identique de `Store` (l.1304-1443).
class TransactionNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;
  final List<Tx> transactions;
  final List<Produit> produits;
  final Future<void> Function(Tx tx)? comptabiliserVente;
  final Future<void> Function(String refId, String motif)? contrePasser;
  final Future<void> Function(Tx tx)? posterEncaissement;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;
  String boutiqueId;

  TransactionNotifier({
    required this.session,
    required this.genererId,
    required this.transactions,
    required this.produits,
    this.comptabiliserVente,
    this.contrePasser,
    this.posterEncaissement,
    this.fileUpsert,
    this.boutiqueId = '',
  });

  List<Tx> get txBoutique =>
      transactions.where((t) => t.boutiqueId == boutiqueId).toList();

  Future<String> ajouterTransaction({
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    String? partenaireId,
    Map<String, dynamic> details = const {},
    DateTime? date,
    StatutPaiement statut = StatutPaiement.paye,
  }) async {
    final tx = Tx(
      id: genererId(),
      boutiqueId: boutiqueId,
      employeId: session.user.id,
      type: type,
      montant: montant,
      cout: cout,
      statut: statut,
      clientNom: clientNom,
      partenaireId: partenaireId,
      details: details,
      date: date ?? DateTime.now(),
    );
    transactions.insert(0, tx);
    notifyListeners();
    await CloudRepository.upsertTransaction(tx);
    if (SupabaseService.client != null) {
      await SyncService().mettreEnFile(_payload(tx));
    }
    await comptabiliserVente?.call(tx);
    return tx.id;
  }

  Map<String, dynamic> _payload(Tx tx) => {
        'id': tx.id,
        'boutique_id': tx.boutiqueId,
        'employe_id': tx.employeId,
        'type': CloudTx.dbValue(tx.type),
        'montant': tx.montant,
        'cout': tx.cout,
        'statut': tx.statut.name,
        'client_nom': tx.clientNom,
        'partenaire_id': tx.partenaireId,
        'details': tx.details,
        'date_transaction': tx.date.toIso8601String(),
      };

  /// Modification d'une vente existante (journal → Modifier).
  Future<String?> majTransaction(Tx maj) async {
    final i = transactions.indexWhere((t) => t.id == maj.id);
    if (i < 0) return 'Vente introuvable';
    if (maj.montant <= 0) return 'Le montant doit être > 0';
    if (maj.cout < 0) return 'Le coût ne peut pas être négatif';
    transactions[i] = maj;
    notifyListeners();
    await CloudRepository.upsertTransaction(maj);
    await fileUpsert?.call('transactions', _payload(maj));
    // Journal tenu à jour : annule l'historique puis re-comptabilise.
    await contrePasser?.call(maj.id, 'correction vente');
    await comptabiliserVente?.call(maj);
    return null;
  }

  /// Suppression définitive : restaure le stock matériel puis
  /// contre-passe (jamais de suppression comptable).
  Future<void> supprimerTransaction(String id) async {
    final i = transactions.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final tx = transactions[i];
    if (tx.type == TypeTransaction.venteMateriel) {
      final lignes = (tx.details['lignes'] as List?) ?? const [];
      for (final l in lignes) {
        if (l is! Map) continue;
        final pid = l['produitId']?.toString();
        final qte = (l['quantite'] as num?)?.toInt() ?? 0;
        if (pid == null || qte <= 0) continue;
        final pi = produits.indexWhere((p) => p.id == pid);
        if (pi >= 0) {
          final restaure = produits[pi]
              .copyWith(stock: produits[pi].stock + qte);
          produits[pi] = restaure;
          await CloudRepository.upsertProduit(restaure);
        }
      }
    }
    transactions.removeAt(i);
    notifyListeners();
    await CloudRepository.supprimerTransaction(id);
    if (CloudRepository.actif) {
      await SyncService()
          .mettreEnFile({'id': id}, table: 'transactions__delete');
    }
    await contrePasser?.call(id, 'vente supprimée');
  }

  /// Encaissement d'une vente à crédit : impayé/partiel → payé.
  Future<String?> encaisserVente(String id) async {
    if (!session.peut(Permission.vendre)) {
      return 'Encaissement réservé à la vente';
    }
    final i = transactions.indexWhere((t) => t.id == id);
    if (i < 0) return 'Vente introuvable';
    if (transactions[i].statut == StatutPaiement.paye) {
      return 'Déjà encaissée';
    }
    final tx =
        transactions[i].copyWith(statut: StatutPaiement.paye);
    transactions[i] = tx;
    notifyListeners();
    await CloudRepository.upsertTransaction(tx);
    await fileUpsert?.call('transactions', _payload(tx));
    await posterEncaissement?.call(tx);
    return null;
  }

  /// Créances : ventes non soldées (boutique courante, anciennes d'abord).
  List<Tx> get creances {
    final l = txBoutique
        .where((t) => t.statut != StatutPaiement.paye)
        .toList();
    l.sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  double get totalCreances =>
      creances.fold(0.0, (s, t) => s + t.montant);
}
