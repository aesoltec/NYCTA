import '../../models/analytique.dart';
import '../../models/charge.dart';
import '../../models/ecriture.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../../core/constants.dart';

/// Agrégats analytiques PURS (Phase 0) : CA/marges jour/mois, par type,
/// par jour (30 j), frais MoMo, balance âgée, TVA mensuelle.
/// Extraits à l'identique de `Store` (l.1442-1535, tvaParMois, balance).
class AnalytiqueService {
  const AnalytiqueService._();

  static bool memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<Tx> duJour(
          Iterable<Tx> txs, String boutiqueId, DateTime jour) =>
      txs
          .where((t) =>
              t.boutiqueId == boutiqueId && memeJour(t.date, jour))
          .toList();

  static double caJour(
          Iterable<Tx> txs, String boutiqueId, DateTime jour) =>
      duJour(txs, boutiqueId, jour)
          .fold(0.0, (s, t) => s + t.montant);

  static double margeJour(
          Iterable<Tx> txs, String boutiqueId, DateTime jour) =>
      duJour(txs, boutiqueId, jour)
          .fold(0.0, (s, t) => s + t.marge);

  static List<Tx> duMois(
          Iterable<Tx> txs, String boutiqueId, String moisKey) =>
      txs
          .where((t) =>
              t.boutiqueId == boutiqueId &&
              C.moisKey(t.date) == moisKey)
          .toList();

  static double caMois(
          Iterable<Tx> txs, String boutiqueId, String moisKey) =>
      duMois(txs, boutiqueId, moisKey)
          .fold(0.0, (s, t) => s + t.montant);

  static double margeMois(
          Iterable<Tx> txs, String boutiqueId, String moisKey) =>
      duMois(txs, boutiqueId, moisKey)
          .fold(0.0, (s, t) => s + t.marge);

  static Map<TypeTransaction, double> caParType(
      Iterable<Tx> txsMois) {
    final map = <TypeTransaction, double>{};
    for (final t in txsMois) {
      map[t.type] = (map[t.type] ?? 0) + t.montant;
    }
    return map;
  }

  /// CA par jour sur les 30 derniers jours (clés 'jj/mm', zéros inclus).
  static Map<String, double> caParJour(
      Iterable<Tx> txsBoutique, DateTime maintenant) {
    final map = <String, double>{};
    for (var i = 29; i >= 0; i--) {
      final jour = maintenant.subtract(Duration(days: i));
      map['${jour.day.toString().padLeft(2, '0')}/'
          '${jour.month.toString().padLeft(2, '0')}'] = 0;
    }
    for (final t in txsBoutique) {
      final cle =
          '${t.date.day.toString().padLeft(2, '0')}/'
          '${t.date.month.toString().padLeft(2, '0')}';
      if (map.containsKey(cle)) map[cle] = map[cle]! + t.montant;
    }
    return map;
  }

  static double totalDepensesMois(Iterable<Charge> depensesMois) =>
      depensesMois.fold(0.0, (s, c) => s + c.montant);

  /// Créances : ventes non soldées (boutique, anciennes d'abord).
  static List<Tx> creances(Iterable<Tx> txsBoutique) {
    final l = txsBoutique
        .where((t) => t.statut != StatutPaiement.paye)
        .toList();
    l.sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  static double totalCreances(Iterable<Tx> creancesList) =>
      creancesList.fold(0.0, (s, t) => s + t.montant);

  /// Balance âgée : encours impayé par tranche d'ancienneté.
  static Map<String, double> balanceAgee(
      Iterable<Tx> creancesList, DateTime maintenant) {
    final map = {
      '0-30 j': 0.0,
      '31-60 j': 0.0,
      '61-90 j': 0.0,
      '+90 j': 0.0
    };
    for (final t in creancesList) {
      final jours = maintenant.difference(t.date).inDays;
      final cle = jours <= 30
          ? '0-30 j'
          : jours <= 60
              ? '31-60 j'
              : jours <= 90
                  ? '61-90 j'
                  : '+90 j';
      map[cle] = map[cle]! + t.montant;
    }
    return map;
  }

  /// TVA par mois : collectée (443) − déductible (445), depuis le journal.
  /// Rôle LECTURE seule : agrège des écritures existantes (ne génère rien).
  /// La génération des lignes 443/445 relève de `ComptaService`
  /// (rôle ÉCRITURE). Les deux ne sont pas redondants.
  static Map<int, (double, double)> tvaParMois(
      Iterable<Ecriture> ecritures, int annee) {
    final map = <int, (double, double)>{};
    for (var m = 1; m <= 12; m++) {
      var collectee = 0.0, deductible = 0.0;
      for (final e in ecritures) {
        if (e.date.year != annee || e.date.month != m) continue;
        if (e.compte == '443') collectee += e.credit - e.debit;
        if (e.compte == '445') deductible += e.debit - e.credit;
      }
      map[m] = (collectee, deductible);
    }
    return map;
  }

  /// Frais Mobile Money par opérateur sur une liste de ventes du mois.
  static Map<String, double> fraisMoMo(
      Iterable<Tx> txsMois) {
    final map = <String, double>{};
    for (final t in txsMois
        .where((t) => t.type == TypeTransaction.mobileMoney)) {
      final op = (t.details['operateur'] ?? 'Autre').toString();
      final frais = (t.details['frais'] as num?)?.toDouble() ?? 0;
      map[op] = (map[op] ?? 0) + frais;
    }
    return map;
  }

  /// Jours calendaires couvrant [fin] et les [jours]-1 jours précédents.
  /// Chaque ligne = (date, montant, marge). Identique à `Store._serieJours`.
  static List<AgregatPeriode> serieJours(DateTime fin, int jours,
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

  /// 12 mois d'une année (même vides). Identique à `Store._serieMois`.
  static List<AgregatPeriode> serieMois(
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

  /// Une entrée par année présente. Identique à `Store._serieAnnees`.
  static List<AgregatPeriode> serieAnnees(
      List<int> annees, List<(DateTime, double, double)> lignes) =>
      [
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
