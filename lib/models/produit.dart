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
  /// Photo principale : DERIVEE de [images], sauf valeur fournie
  /// explicitement (voir le constructeur).
  final String? imagePath;
  /// Galerie (max 05, optionnelle) : imagePath vaut images.firstOrNull
  /// pour compatibilité avec l'existant.
  final List<String> images;
  /// Date de création de la fiche (badge « Nouveau » < 7 jours).
  /// Nullable pour rétrocompatibilité (anciennes fiches sans date).
  final DateTime? dateAjout;

  /// `imagePath` est une valeur DERIVEE de [images] (`images.first`), pas
  /// une donnee independante. Le constructeur applique donc la meme regle
  /// que [copyWith] :
  /// 1. [imagePath] fourni explicitement → il gagne (chemins historiques,
  ///    image cloud-only) ;
  /// 2. sinon → `images.first`, ou null si la galerie est vide.
  ///
  /// Avant, le constructeur ne derivait rien : `Produit(images: ['/a.jpg'])`
  /// avait `imagePath == null` alors que `copyWith()` de ce meme produit
  /// valait '/a.jpg'. Deux manieres de construire le meme produit, deux
  /// etats differents — exactement la famille de bugs « l image revient ».
  /// Regle UNIQUE de resolution de la photo principale, partagee par
  /// le constructeur et par les deserialiseurs (stockage local + cloud).
  ///
  /// - [imagePath] non nul : c'est la valeur ecrite par l'application,
  ///   elle prime (chemins historiques, image cloud-only) ;
  /// - [imagePath] nul et [images] non vide : la photo EST dans la
  ///   galerie, donc `images.first` — c'est le cas des fiches ecrites
  ///   par les versions anterieures a la 1.13.4, ou `image_path` etait
  ///   enregistre nul alors que la galerie contenait l'image ;
  /// - les deux vides : pas de photo.
  ///
  /// Coller cette regle ici evite que les deserialiseurs la
  /// reimplementent (et divergent) — c'etait precisement le defaut
  /// corrige en 1.13.3/1.13.4.
  static String? principal({String? imagePath, required List<String> images}) =>
      imagePath ?? (images.isNotEmpty ? images.first : null);

  /// Marqueur interne : distingue « [imagePath] non fourni » (on derive
  /// alors le principal de la galerie) de « [imagePath] explicitement
  /// nul » (la photo a ete retiree, le principal doit le rester).
  ///
  /// Dart ne permet pas un parametre nullable avec cette distinction :
  /// `String? imagePath = null` ne distingue pas les deux cas. Sans ce
  /// sentinelle, `copyWith(effacerImagePath: true)` etait silencieusement
  /// annule par le constructeur, qui re-derivait `images.first`.
  static const Object _deriveImagePath = Object();

  Produit({
    required this.id,
    required this.boutiqueId,
    required this.libelle,
    required this.categorie,
    required this.prixAchat,
    required this.prixVente,
    this.stock = 0,
    this.seuil = 3,
    Object? imagePath = _deriveImagePath,
    this.images = const [],
    this.dateAjout,
  }) : imagePath = identical(imagePath, _deriveImagePath)
            ? principal(images: images)
            : imagePath as String?;

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
    // `null` = a effacer ou explicitement demande ; sinon le constructeur
    // derive de la galerie (pas de duplication de regle).
    final Object? principal = effacerImagePath || imagePath != null
        ? imagePath
        : _deriveImagePath;
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
