import '../../models/partage.dart';
import '../../models/transaction.dart';
import '../../../core/constants.dart';

/// Calculs partenaires PURS (Phase 0) : total des ventes forfait d'un
/// partenaire sur un mois + construction du partage.
/// Identique à `Store.ventesPartenaireMois` + `Partage.calculer`.
class PartageService {
  const PartageService._();

  /// Total forfait hotspot d'un partenaire sur `mois` ('AAAA-MM').
  static double totalVentes(
      Iterable<Tx> transactions, String partenaireId, String mois) =>
      transactions
          .where((t) =>
              t.partenaireId == partenaireId &&
              t.type == TypeTransaction.forfaitHotspot &&
              C.moisKey(t.date) == mois)
          .fold(0.0, (s, t) => s + t.montant);

  /// Construit le partage (délègue à `Partage.calculer`).
  static Partage cloturer({
    required String id,
    required String partenaireId,
    required String mois,
    required double totalVentes,
    required double taux,
  }) =>
      Partage.calculer(
        id: id,
        partenaireId: partenaireId,
        mois: mois,
        totalVentes: totalVentes,
        taux: taux,
      );

  /// Vérifie l'équilibre d'un partage (partenaire + entreprise = total).
  static bool estEquilibre(Partage p, [double epsilon = 0.01]) =>
      (p.partPartenaire + p.partEntreprise - p.totalVentes).abs() <
      epsilon;
}
