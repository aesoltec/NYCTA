class Partenaire {
  final String id;
  final String nom;
  final String telephone;
  final String localisation;
  final double taux; // part du partenaire, ex 0.60
  final bool actif;

  const Partenaire({
    required this.id,
    required this.nom,
    required this.telephone,
    this.localisation = '',
    this.taux = 0.60,
    this.actif = true,
  });

  Partenaire copyWith({bool? actif}) => Partenaire(
        id: id, nom: nom, telephone: telephone,
        localisation: localisation, taux: taux, actif: actif ?? this.actif,
      );
}
