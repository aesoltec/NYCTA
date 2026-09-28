import 'package:flutter/foundation.dart';
import '../../models/analytique.dart';
import '../../models/charge.dart';
import '../../models/transaction.dart';
import '../services/analytique_service.dart';

/// Analytique CA & dépenses (Phase 4 — découpage Store, révisé Phase 5) :
/// séries 7 jours / mois / années + années présentes.
/// Rôle : agrégation pure en lecture (aucune mutation).
/// Dépendances : listes BRUTES `transactions`/`depenses` + `boutiqueId`
/// mutable (filtrées en interne — la façade propage la boutique courante).
/// Séries déléguées à `AnalytiqueService` (source unique, pas de doublon).
class AnalytiqueNotifier extends ChangeNotifier {
  final List<Tx> transactions;
  final List<Charge> depenses;
  String boutiqueId;

  AnalytiqueNotifier({
    required this.transactions,
    required this.depenses,
    this.boutiqueId = '',
  });

  List<Tx> get txBoutique =>
      transactions.where((t) => t.boutiqueId == boutiqueId).toList();

  List<Charge> get depensesBoutique =>
      depenses.where((c) => c.boutiqueId == boutiqueId).toList();

  /// CA jour par jour sur les 7 derniers jours.
  List<AgregatPeriode> ca7Jours({DateTime? fin}) =>
      AnalytiqueService.serieJours(fin ?? DateTime.now(), 7, [
        for (final t in txBoutique) (t.date, t.montant, t.marge)
      ]);

  /// Dépenses jour par jour sur les 7 derniers jours.
  List<AgregatPeriode> depenses7Jours({DateTime? fin}) =>
      AnalytiqueService.serieJours(fin ?? DateTime.now(), 7, [
        for (final c in depensesBoutique) (c.date, c.montant, 0.0)
      ]);

  /// CA mensuel sur l'année (12 mois, même vides).
  List<AgregatPeriode> caParMois(int annee) =>
      AnalytiqueService.serieMois(annee, [
        for (final t in txBoutique) (t.date, t.montant, t.marge)
      ]);

  /// Dépenses mensuelles sur l'année.
  List<AgregatPeriode> depensesParMois(int annee) =>
      AnalytiqueService.serieMois(annee, [
        for (final c in depensesBoutique) (c.date, c.montant, 0.0)
      ]);

  /// CA annuel, toutes années présentes dans les données.
  List<AgregatPeriode> caParAnnee() =>
      AnalytiqueService.serieAnnees(anneesDonnees(), [
        for (final t in txBoutique) (t.date, t.montant, t.marge)
      ]);

  /// Dépenses annuelles.
  List<AgregatPeriode> depensesParAnnee() =>
      AnalytiqueService.serieAnnees(anneesDonnees(), [
        for (final c in depensesBoutique) (c.date, c.montant, 0.0)
      ]);

  /// Années présentes dans les données (transactions + dépenses).
  List<int> anneesDonnees() {
    final set = <int>{
      for (final t in txBoutique) t.date.year,
      for (final c in depensesBoutique) c.date.year,
    };
    final l = set.toList()..sort();
    return l;
  }
}
