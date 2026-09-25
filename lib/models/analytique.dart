import 'dart:math' as math;

/// Agrégat sur une période (mission 3, §3.1/3.2) : un jour, un mois ou
/// une année. `montant` = CA (transactions) ou dépenses (charges) ;
/// `marge` = marge CA, 0 pour les dépenses.
class AgregatPeriode {
  final String label;
  final DateTime debut;
  final double montant;
  final int nb;
  final double marge;

  const AgregatPeriode({
    required this.label,
    required this.debut,
    required this.montant,
    required this.nb,
    this.marge = 0,
  });

  double get panierMoyen => nb == 0 ? 0 : montant / nb;
}

/// Variation en % : 0 si les deux sont nuls, +100 si départ de zéro.
double variationPct(double actuel, double precedent) {
  if (precedent == 0) return actuel == 0 ? 0 : 100;
  return (actuel - precedent) / precedent * 100;
}

/// CAGR annualisé d'une série mensuelle (mission §25) : compare le premier
/// mois non nul au dernier et annualise sur le nombre de mois écoulés.
/// Null si incalculable (moins de 2 mois non nuls).
double? cagrMensuelAnnualise(List<AgregatPeriode> serie) {
  final utils = serie.where((e) => e.montant > 0).toList();
  if (utils.length < 2) return null;
  final premier = utils.first.montant;
  final dernier = utils.last.montant;
  final mois = (utils.last.debut.year - utils.first.debut.year) * 12 +
      (utils.last.debut.month - utils.first.debut.month);
  if (premier <= 0 || mois <= 0 || dernier <= 0) return null;
  return (math.pow(dernier / premier, 12 / mois) - 1) * 100;
}

