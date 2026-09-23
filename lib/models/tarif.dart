/// Article du catalogue tarifaire : produits/services vendus AVEC prix,
/// y compris ceux qui ne sont PAS en stock (prestations forfaitaires,
/// licences, forfaits…). Alimente la création de factures et devis.
class Tarif {
  final String id;
  final String libelle;
  final String categorie;
  final double prix;
  final String description;
  final bool actif;

  const Tarif({
    required this.id,
    required this.libelle,
    required this.prix,
    this.categorie = 'Général',
    this.description = '',
    this.actif = true,
  });

  Tarif copyWith({bool? actif, double? prix, String? categorie, String? libelle, String? description}) => Tarif(
        id: id,
        libelle: libelle ?? this.libelle,
        prix: prix ?? this.prix,
        categorie: categorie ?? this.categorie,
        description: description ?? this.description,
        actif: actif ?? this.actif,
      );
}
