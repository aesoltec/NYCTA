import '../../models/charge.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';

/// Calculs caisse PURS (Phase 0) : solde par boutique.
/// Identique à `Store.soldeCaisse` (l.1644-1651) :
/// fonds de roulement + CA encaissé (payé) − dépenses.
class CaisseService {
  const CaisseService._();

  static double solde({
    required Iterable<Tx> transactions,
    required Iterable<Charge> depenses,
    required String boutiqueId,
    required double fondsRoulement,
  }) {
    final ca = transactions
        .where((t) =>
            t.boutiqueId == boutiqueId &&
            t.statut == StatutPaiement.paye)
        .fold(0.0, (s, t) => s + t.montant);
    final dep = depenses
        .where((c) => c.boutiqueId == boutiqueId)
        .fold(0.0, (s, c) => s + c.montant);
    return fondsRoulement + ca - dep;
  }
}
