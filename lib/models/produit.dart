class Produit {
  final String id;
  final String boutiqueId;
  final String libelle;
  final String categorie;
  final double prixAchat;
  final double prixVente;
  final int stock;
  final int seuil;
  final String? imagePath; // photo du produit (galerie/appareil)

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
  });

  bool get alerte => stock <= seuil;
  double get margeUnitaire => prixVente - prixAchat;

  Produit copyWith({
    int? stock,
    String? imagePath,
    String? libelle,
    String? categorie,
    double? prixAchat,
    double? prixVente,
    int? seuil,
    String? boutiqueId,
  }) =>
      Produit(
        id: id,
        boutiqueId: boutiqueId ?? this.boutiqueId,
        libelle: libelle ?? this.libelle,
        categorie: categorie ?? this.categorie,
        prixAchat: prixAchat ?? this.prixAchat,
        prixVente: prixVente ?? this.prixVente,
        stock: stock ?? this.stock,
        seuil: seuil ?? this.seuil,
        imagePath: imagePath ?? this.imagePath,
      );

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
      );
}
