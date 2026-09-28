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
  /// Date de création de la fiche (badge « Nouveau » < 7 jours).
  /// Nullable pour rétrocompatibilité (anciennes fiches sans date).
  final DateTime? dateAjout;

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
    this.dateAjout,
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
    DateTime? dateAjout,
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
      dateAjout: dateAjout ?? this.dateAjout,
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
        dateAjout: dateAjout,
      );
}

/// Badges INFORMATIFS e-commerce (refonte UX) : seuls 3 badges existent —
/// « Nouveau » (< 7 jours), « Stock faible » (stock ≤ seuil), « Rupture »
/// (stock = 0). Tout badge marketing (rotation, marge, promo,
/// best-seller…) est définitivement supprimé.
extension ProduitExtension on Produit {
  /// Rupture : aucun article disponible.
  bool get enRupture => stock <= 0;

  /// Stock faible : il reste des articles mais sous le seuil d'alerte.
  bool get stockFaible => stock > 0 && stock <= seuil;

  /// Nouveau : fiche créée il y a moins de 7 jours.
  bool get nouveau =>
      dateAjout != null &&
      DateTime.now().difference(dateAjout!).inDays < 7;
}
