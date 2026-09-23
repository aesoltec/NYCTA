import 'enums.dart';

class Partage {
  final String id;
  final String partenaireId;
  final String mois; // "2026-09"
  final double totalVentes;
  final double taux;
  final double partPartenaire;
  final double partEntreprise;
  final StatutPartage statut;

  const Partage({
    required this.id,
    required this.partenaireId,
    required this.mois,
    required this.totalVentes,
    required this.taux,
    required this.partPartenaire,
    required this.partEntreprise,
    this.statut = StatutPartage.valide,
  });

  factory Partage.calculer({
    required String id,
    required String partenaireId,
    required String mois,
    required double totalVentes,
    required double taux,
  }) =>
      Partage(
        id: id,
        partenaireId: partenaireId,
        mois: mois,
        totalVentes: totalVentes,
        taux: taux,
        partPartenaire: totalVentes * taux,
        partEntreprise: totalVentes * (1 - taux),
      );
}
