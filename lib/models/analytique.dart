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
