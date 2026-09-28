/// Article du catalogue tarifaire : produits/services vendus AVEC prix,
/// y compris ceux qui ne sont PAS en stock (prestations forfaitaires,
/// licences, forfaits…). Alimente la création de factures et devis.
class Tarif {
  static const maxImages = 5;

  final String id;
  final String libelle;
  final String categorie;
  final double prix;
  final String description;
  final bool actif;

  /// Galerie (max 05, optionnelle — point 36) : mêmes règles que Produit.
  final List<String> images;

  /// Date de création de la fiche (badge « Nouveau », tri par date).
  /// Nullable pour rétrocompatibilité.
  final DateTime? dateAjout;

  const Tarif({
    required this.id,
    required this.libelle,
    required this.prix,
    this.categorie = 'Général',
    this.description = '',
    this.actif = true,
    this.images = const [],
    this.dateAjout,
  });

  /// Badge « Nouveau » (< 7 jours) — seul badge du catalogue.
  bool get nouveau =>
      dateAjout != null &&
      DateTime.now().difference(dateAjout!).inDays < 7;

  Tarif copyWith(
          {bool? actif,
          double? prix,
          String? categorie,
          String? libelle,
          String? description,
          List<String>? images,
          DateTime? dateAjout}) =>
      Tarif(
        id: id,
        libelle: libelle ?? this.libelle,
        prix: prix ?? this.prix,
        categorie: categorie ?? this.categorie,
        description: description ?? this.description,
        actif: actif ?? this.actif,
        images: images ?? this.images,
        dateAjout: dateAjout ?? this.dateAjout,
      );
}
