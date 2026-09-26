class Produit {
  static const maxImages = 5;

  final String id;
  final String boutiqueId;
  final String libelle;
  final String categorie;
  final double prixAchat;
  final double prixVente;
  final int stock;
  final int seuil;
  final String? imagePath; // photo principale (galerie/appareil)
  /// Galerie (max 05, optionnelle) : imagePath vaut images.firstOrNull
  /// pour compatibilité avec l'existant.
  final List<String> images;

  const Produit({
    required this.id,
    required this.boutiqueId,
    required this.libelle,
    required this.categorie,
    required this.prixAchat,
    required this.prixVente,
    this.stock = 0,
    this.seuil = 3,
    this.imagePath,
    this.images = const [],
  });

  bool get alerte => stock <= seuil;
  double get margeUnitaire => prixVente - prixAchat;

  Produit copyWith({
    int? stock,
    String? imagePath,
    List<String>? images,
    String? libelle,
    String? categorie,
    double? prixAchat,
    double? prixVente,
    int? seuil,
    String? boutiqueId,
  }) {
    final imgs = images ?? this.images;
    return Produit(
      id: id,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      libelle: libelle ?? this.libelle,
      categorie: categorie ?? this.categorie,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      stock: stock ?? this.stock,
      seuil: seuil ?? this.seuil,
      imagePath: imagePath ?? (imgs.isNotEmpty ? imgs.first : this.imagePath),
      images: imgs,
    );
  }

  /// Retire explicitement la photo (copyWith ne peut pas mettre un null).
  Produit sansImage() => Produit(
        id: id,
        boutiqueId: boutiqueId,
        libelle: libelle,
        categorie: categorie,
        prixAchat: prixAchat,
        prixVente: prixVente,
        stock: stock,
        seuil: seuil,
        imagePath: null,
        images: const [],
      );
}
