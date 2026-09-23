class Boutique {
  final String id;
  final String nom;
  final String adresse;
  final bool siege;
  final bool actif;

  const Boutique({
    required this.id,
    required this.nom,
    this.adresse = '',
    this.siege = false,
    this.actif = true,
  });

  Boutique copyWith({bool? actif, bool? siege}) => Boutique(
        id: id, nom: nom, adresse: adresse,
        siege: siege ?? this.siege, actif: actif ?? this.actif,
      );
}
