import 'package:flutter/foundation.dart';
import '../../models/analytique.dart';
import '../../models/charge.dart';
import '../../models/transaction.dart';

/// Analytique CA & dépenses (Phase 4 — découpage Store) : séries
/// 7 jours / mois / années + années présentes.
/// Rôle : agrégation pure en lecture (aucune mutation, aucun notify
/// nécessaire au-delà du standard).
/// Dépendances : listes `txBoutique` et `depensesBoutique` (déjà filtrées
/// boutique, fournies par la façade en Phase 5).
/// Extrait à l'identique de `Store` (l.2285-2390).
class AnalytiqueNotifier extends ChangeNotifier {
  final List<Tx> txBoutique;
  final List<Charge> depensesBoutique;

  AnalytiqueNotifier({
    required this.txBoutique,
    required this.depensesBoutique,
  });

  /// Jours calendaires couvrant [fin] et les [jours]-1 jours précédents.
  List<AgregatPeriode> serieJours(DateTime fin, int jours,
      List<(DateTime, double, double)> lignes) {
    final parJour = <String, AgregatPeriode>{};
    final refs = <String, DateTime>{};
    for (var i = jours - 1; i >= 0; i--) {
      final j = DateTime(fin.year, fin.month, fin.day)
          .subtract(Duration(days: i));
      final cle = '${j.year}-${j.month}-${j.day}';
      refs[cle] = j;
      parJour[cle] = AgregatPeriode(
        label:
            '${j.day.toString().padLeft(2, '0')}/${j.month.toString().padLeft(2, '0')}',
        debut: j,
        montant: 0,
        nb: 0,
      );
    }
    final compteurs = <String, (double, int, double)>{};
    for (final (date, montant, marge) in lignes) {
      final cle = '${date.year}-${date.month}-${date.day}';
      if (!parJour.containsKey(cle)) continue;
      final (m, n, mg) = compteurs[cle] ?? (0.0, 0, 0.0);
      compteurs[cle] = (m + montant, n + 1, mg + marge);
    }
    return [
      for (final e in parJour.entries)
        AgregatPeriode(
          label: e.value.label,
          debut: refs[e.key]!,
          montant: compteurs[e.key]?.$1 ?? 0,
          nb: compteurs[e.key]?.$2 ?? 0,
          marge: compteurs[e.key]?.$3 ?? 0,
        ),
    ];
  }

  /// CA jour par jour sur les 7 derniers jours.
  List<AgregatPeriode> ca7Jours({DateTime? fin}) => serieJours(
      fin ?? DateTime.now(),
      7,
      [for (final t in txBoutique) (t.date, t.montant, t.marge)]);

  /// Dépenses jour par jour sur les 7 derniers jours.
  List<AgregatPeriode> depenses7Jours({DateTime? fin}) => serieJours(
      fin ?? DateTime.now(),
      7,
      [for (final c in depensesBoutique) (c.date, c.montant, 0.0)]);

  List<AgregatPeriode> serieMois(
          int annee, List<(DateTime, double, double)> lignes) =>
      [
        for (var mois = 1; mois <= 12; mois++)
          AgregatPeriode(
            label: mois.toString().padLeft(2, '0'),
            debut: DateTime(annee, mois),
            montant: lignes
                .where((l) => l.$1.year == annee && l.$1.month == mois)
                .fold(0.0, (s, l) => s + l.$2),
            nb: lignes
                .where((l) => l.$1.year == annee && l.$1.month == mois)
                .length,
            marge: lignes
                .where((l) => l.$1.year == annee && l.$1.month == mois)
                .fold(0.0, (s, l) => s + l.$3),
          ),
      ];

  /// CA mensuel sur l'année (12 mois, même vides).
  List<AgregatPeriode> caParMois(int annee) => serieMois(annee,
      [for (final t in txBoutique) (t.date, t.montant, t.marge)]);

  /// Dépenses mensuelles sur l'année.
  List<AgregatPeriode> depensesParMois(int annee) => serieMois(annee, [
        for (final c in depensesBoutique) (c.date, c.montant, 0.0)
      ]);

  List<AgregatPeriode> serieAnnees(
      List<(DateTime, double, double)> lignes) {
    final annees = anneesDonnees();
    return [
      for (final a in annees)
        AgregatPeriode(
          label: '$a',
          debut: DateTime(a),
          montant: lignes
              .where((l) => l.$1.year == a)
              .fold(0.0, (s, l) => s + l.$2),
          nb: lignes.where((l) => l.$1.year == a).length,
          marge: lignes
              .where((l) => l.$1.year == a)
              .fold(0.0, (s, l) => s + l.$3),
        ),
    ];
  }

  /// CA annuel, toutes années présentes dans les données.
  List<AgregatPeriode> caParAnnee() => serieAnnees(
      [for (final t in txBoutique) (t.date, t.montant, t.marge)]);

  /// Dépenses annuelles.
  List<AgregatPeriode> depensesParAnnee() => serieAnnees(
      [for (final c in depensesBoutique) (c.date, c.montant, 0.0)]);

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
