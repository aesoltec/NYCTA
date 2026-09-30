/// Élément de la banque d'images interne (galerie).
///
/// Une entrée est une image **physiquement stockée** (fichier local dans
/// `<docs>/media/<dossier>/` et/ou objet du bucket Supabase `media`) que
/// l'on peut rattacher à un produit du stock ou à un article du
/// catalogue. Elle n'est pas un modèle persisté en base : la banque est
/// l'index des médias réellement présents, déduit du stockage et des
/// affectations courantes.
class MediaItem {
  /// Clé d'identification = nom de fichier (`produit_xxx_1700000000_ab12cd.jpg`)
  /// ou chemin de stockage cloud. C'est cette clé qui relie l'image aux
  /// produits/articles qui l'utilisent.
  final String cle;

  /// Chemin local si disponible (sinon null : image encore cloud-only).
  final String? cheminLocal;

  /// URL publique cloud si disponible (sinon null : image encore locale).
  final String? urlCloud;

  /// Dossier de stockage : `produit`, `tarif`, `galerie`…
  final String dossier;

  /// Date de détection (fichier local) — sert au tri antéchronologique.
  final DateTime? modifieLe;

  /// `imagePath` du produit quand le nom du fichier ne permet pas de le
  /// retrouver seul (chemins historiques non renommés).
  final bool cleLocale;

  /// Empreinte du contenu (`taille:4 premiers octets`) pour les fichiers
  /// locaux. Sert à reconnaître deux images de même contenu malgré des
  /// noms différents (anciens uploads nommés `millisecondes.jpg`).
  final String? empreinte;

  const MediaItem({
    required this.cle,
    this.cheminLocal,
    this.urlCloud,
    this.dossier = 'galerie',
    this.modifieLe,
    this.cleLocale = false,
    this.empreinte,
  });

  /// Aperçu affichable : local d'abord (instantané), cloud en secours.
  String get apercu => cheminLocal ?? urlCloud ?? cle;

  bool get estDistante => urlCloud != null && cheminLocal == null;

  /// Dossier + nom de fichier reconstruit pour le stockage cloud
  /// (le bucket `media` range les uploads sous `produits/`, `tarifs/`,
  /// `galerie/`).
  String? get cheminCloud {
    final u = urlCloud;
    if (u == null || cleLocale) return null;
    final base = u.split('/').last.split('?').first;
    return base.isEmpty ? null : base;
  }

  /// Vrai si l'image n'est stockée qu'en local (jamais montée au cloud).
  bool get seulementLocale => urlCloud == null;

  MediaItem copyWith({String? cheminLocal, String? urlCloud}) => MediaItem(
        cle: cle,
        cheminLocal: cheminLocal ?? this.cheminLocal,
        urlCloud: urlCloud ?? this.urlCloud,
        dossier: dossier,
        modifieLe: modifieLe,
        cleLocale: cleLocale,
        empreinte: empreinte,
      );

  @override
  bool operator ==(Object other) => other is MediaItem && other.cle == cle;

  @override
  int get hashCode => cle.hashCode;

  @override
  String toString() => 'MediaItem($cle)';
}

/// Référence d'un média utilisé par une entité (produit ou article).
class MediaUsage {
  /// `produit` ou `tarif`.
  final String type;
  final String id;
  final String libelle;
  /// `images` (galerie) ou `imagePath` (photo principale historique).
  final bool principale;

  const MediaUsage({
    required this.type,
    required this.id,
    required this.libelle,
    this.principale = false,
  });

  String get libelleAffiche =>
      principale ? '$libelle (principale)' : libelle;
}
