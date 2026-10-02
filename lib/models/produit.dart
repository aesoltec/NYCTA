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

  /// `imagePath` est une valeur DÉRIVÉE de [images] (`images.first`),
  /// jamais une donnée indépendante : c'est ce qui garantit qu'une image
  /// retirée de la galerie ne réapparaisse pas.
  ///
  /// Avant, le repli `imagePath ?? (imgs.isNotEmpty ? imgs.first :
  /// this.imagePath)` rendait la valeur COLLANTE : vider la galerie
  /// laissait l'ancien chemin principal survivre et l'ancienne image
  /// revenait à la sauvegarde (symptôme observé sur l'écran Stock).
  ///
  /// Règle de résolution, sans ambiguïté :
  /// 1. [effacerImagePath] → principal nul ;
  /// 2. [imagePath] fourni → il gagne (appelant explicite) ;
  /// 3. [images] fourni → `images.first`, ou null si la liste est vide ;
  /// 4. sinon → dérivé de la galerie existante.
  Produit copyWith({
    int? stock,
    String? imagePath,
    List<String>? images,
    bool effacerImagePath = false,
    String? libelle,
    String? categorie,
    double? prixAchat,
    double? prixVente,
    int? seuil,
    String? boutiqueId,
    DateTime? dateAjout,
  }) {
    final imgs = images ?? this.images;
    final String? principal = effacerImagePath
        ? null
        : (imagePath ?? (imgs.isNotEmpty ? imgs.first : null));
    return Produit(
      id: id,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      libelle: libelle ?? this.libelle,
      categorie: categorie ?? this.categorie,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      stock: stock ?? this.stock,
      seuil: seuil ?? this.seuil,
      imagePath: principal,
      images: imgs,
      dateAjout: dateAjout ?? this.dateAjout,
    );
  }

  /// Retire explicitement la photo (équivalent
  /// à `copyWith(effacerImagePath: true)`).
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
