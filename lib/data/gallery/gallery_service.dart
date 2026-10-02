import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../models/media_item.dart';

/// Indexation et bascule d'affectation d'une image de la galerie interne.
///
/// Entièrement PUR : on lui passe les entités et les médias, elle rend
/// l'index et les nouvelles listes. Aucune persistance, aucun cloud, aucun
/// état propre — donc testable sans widget ni base (voir
/// `test/data/gallery/gallery_service_test.dart`).
class GalleryService {
  const GalleryService._();

  /// Vrai si [chemin] pointe vers le cloud (URL http).
  /// Isolé ici pour que le service reste testable sans `dart:io`.
  static bool estDistant(String? chemin) =>
      chemin != null && chemin.startsWith('http');

/// Nom de fichier d'un chemin (local complet, URL, ou nom seul) : c'est
  /// la clé d'identité commune à la galerie et aux entités.
  static String nomFichier(String chemin) => chemin
      .split('/')
      .last
      .split('\\')
      .last
      .toLowerCase();

  /// Vrai si [reference] pointe l'image [cle] — par son nom de fichier
  /// (forme galerie) ou par son chemin exact (forme historique).
  static bool meme(MediaItem item, String reference) =>
      nomFichier(reference) == nomFichier(item.cle);

  /// Valeur à stocker dans `Produit.images` / `Tarif.images` : le chemin
  /// local si l'image est sur l'appareil, sinon l'URL cloud.
  ///
  /// Stocker `item.cle` (nom seul) casserait deux choses : `AppImage`
  /// teste `File(path).existsSync()` (donc placeholder), et
  /// `CloudRepository._publier` teste aussi `existsSync()` (donc rien
  /// n'est téléversé et la référence cloud est perdue).
  static String valeurStockable(MediaItem item) => item.apercu;

  /// Index des médias de la banque, **sans doublon**.
  ///
  /// Trois passes de fusion :
  /// 1. par **clé** (nom de fichier) — l'appariement local ↔ bucket ;
  /// 2. par **empreinte de contenu** — deux fichiers de même contenu mais
  ///    de noms différents (anciens uploads `millisecondes.jpg`) ne
  ///    comptent qu'une fois ;
  /// 3. les **références** des produits/articles non encore vues, avec
  ///    report des usages de la clé dédupliquée.
  ///
  /// Tri : les images rattachées d'abord, puis les plus récentes.
  static List<MediaItem> indexer({
    required List<MediaItem> stockes,
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) {
    final utilisees = usages(produits: produits, tarifs: tarifs);

    // --- passe 1 : par clé, en FUSIONNANT les champs ---
    // Deux entrées de même nom (le fichier local et son objet bucket)
    // doivent devenir une seule ligne qui a les DEUX : chemin local pour
    // l'affichage instantané, URL pour la persistance. `putIfAbsent`
    // seul garderait la première et perdrait l'URL.
    final parCle = <String, MediaItem>{};
    for (final m in stockes) {
      final deja = parCle[m.cle];
      if (deja == null) {
        parCle[m.cle] = m;
      } else {
        parCle[m.cle] = _fusionner(deja, m);
      }
    }

    // --- passe 2 : par empreinte (le premier arrivé garde la place) ---
    final parEmpreinte = <String, MediaItem>{};
    for (final m in parCle.values) {
      final e = m.empreinte;
      if (e == null) continue;
      parEmpreinte.putIfAbsent(e, () => m);
    }
    final doublons = parEmpreinte.length == 0
        ? const <MediaItem>[]
        : parCle.values
            .where((m) =>
                m.empreinte != null && !identical(parEmpreinte[m.empreinte], m))
            .toList();

    final liste = <MediaItem>[
      for (final m in parCle.values)
        if (!doublons.any((d) => d.cle == m.cle)) m,
    ];

    // --- passe 3 : références absentes du stockage ---
    // Une entité peut pointer une URL distante dont le fichier local a
    // disparu (cloud-only) : on l'affiche pour qu'elle ne soit jamais
    // orpheline. En revanche, si la banque contient déjà une image
    // rattachée, on n'ajoute PAS une seconde entrée pour la même entité.
    for (final ref in references(produits: produits, tarifs: tarifs)) {
      if (liste.any((m) => m.cle == ref.cle)) continue;
      final dejaRattachee = utilisees.containsKey(ref.cle) &&
          liste.any((m) => utilisees.containsKey(m.cle));
      if (dejaRattachee) continue;
      liste.add(ref);
    }

    liste.sort((a, b) {
      final ua = utilisees.containsKey(a.cle);
      final ub = utilisees.containsKey(b.cle);
      if (ua != ub) return ua ? -1 : 1; // rattachées d'abord
      final da = a.modifieLe ?? DateTime(2000);
      final db = b.modifieLe ?? DateTime(2000);
      return db.compareTo(da);
    });
    return liste;
  }

  /// Fusionne deux vues de la MÊME image (local + cloud) : on garde le
  /// chemin local si l'un des deux l'a, l'URL si l'un des deux l'a, et
  /// la date la plus récente. `dossier` : celui qui a le plus de contexte
  /// (produit/tarif) gagne sur le `galerie` générique.
  static MediaItem _fusionner(MediaItem a, MediaItem b) => MediaItem(
        cle: a.cle,
        cheminLocal: a.cheminLocal ?? b.cheminLocal,
        urlCloud: a.urlCloud ?? b.urlCloud,
        dossier: a.dossier == 'galerie' ? b.dossier : a.dossier,
        modifieLe: _plusRecent(a.modifieLe, b.modifieLe),
        cleLocale: a.cleLocale || b.cleLocale,
        empreinte: a.empreinte ?? b.empreinte,
      );

  static DateTime? _plusRecent(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Toutes les images référencées par les entités (galerie + principale).
  static List<MediaItem> references({
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) {
    final out = <MediaItem>[];
    for (final p in produits) {
      for (final c in _clesProduit(p)) {
        out.add(MediaItem(
          cle: c,
          cheminLocal: estDistant(c) ? null : c,
          urlCloud: estDistant(c) ? c : null,
          dossier: 'produit',
          cleLocale: !estDistant(c),
        ));
      }
    }
    for (final t in tarifs) {
      for (final c in t.images) {
        out.add(MediaItem(
          cle: c,
          cheminLocal: estDistant(c) ? null : c,
          urlCloud: estDistant(c) ? c : null,
          dossier: 'tarif',
          cleLocale: !estDistant(c),
        ));
      }
    }
    return out.where((m) => m.cle.isNotEmpty).toList();
  }

  /// Index des usages : clé d'image → entités qui l'utilisent.
  /// Permet d'interdire la suppression d'une image encore rattachée et
  /// d'afficher « utilisée par N produit(s) ».
  static Map<String, List<MediaUsage>> usages({
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) {
    final out = <String, List<MediaUsage>>{};
    void add(String cle, MediaUsage u) {
      if (cle.isEmpty) return;
      out.putIfAbsent(cle, () => <MediaUsage>[]).add(u);
    }

    for (final p in produits) {
      final u = MediaUsage(type: 'produit', id: p.id, libelle: p.libelle);
      for (final c in _clesProduit(p)) {
        add(c, u);
      }
    }
    for (final t in tarifs) {
      final u = MediaUsage(type: 'tarif', id: t.id, libelle: t.libelle);
      for (final c in t.images) {
        add(c, u);
      }
    }
    return out;
  }

  /// Nombre d'entités utilisant [cle] (0 = suppression libre).
  static int nbUsages(
    String cle, {
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) =>
      (usages(produits: produits, tarifs: tarifs)[cle] ?? const []).length;

  /// Rattache [item] au produit [id]. null si : produit introuvable,
  /// image déjà présente, ou liste pleine (5 max).
  ///
  /// L'image est mise en TÊTE : elle devient la photo principale
  /// (`imagePath` = `images.first`), convention du modèle.
  static Produit? affecterProduit(
    Produit produit,
    MediaItem item, {
    required List<Produit> produits,
  }) {
    if (item.cle.isEmpty) return null;
    if (produits.indexWhere((p) => p.id == produit.id) < 0) return null;
    if (produit.images.any((c) => meme(item, c))) return null;
    if (produit.imagePath != null && meme(item, produit.imagePath!)) {
      return null;
    }
    if (produit.images.length >= Produit.maxImages) return null;
    return produit.copyWith(
        images: [valeurStockable(item), ...produit.images]);
  }

  /// Retire [item] du produit [id]. Si c'était la photo principale, la
  /// suivante de la galerie le devient (et la photo est retirée si la
  /// liste se vide — `copyWith` dérive désormais le principal, donc une
  /// image retirée ne peut plus revenir).
  static Produit? retirerProduit(
    Produit produit,
    MediaItem item, {
    required List<Produit> produits,
  }) {
    if (produits.indexWhere((p) => p.id == produit.id) < 0) return null;
    final dansGalerie = produit.images.any((c) => meme(item, c));
    final principalMeme = produit.imagePath != null &&
        meme(item, produit.imagePath!);
    if (!dansGalerie && !principalMeme) return null;
    final reste = produit.images
        .where((c) => !meme(item, c))
        .toList();
    return produit.copyWith(images: reste);
  }

  /// Rattache [item] à l'article [id] du catalogue. null si déjà
  /// présente, liste pleine, ou article introuvable.
  static Tarif? affecterTarif(
    Tarif tarif,
    MediaItem item, {
    required List<Tarif> tarifs,
  }) {
    if (item.cle.isEmpty) return null;
    if (tarifs.indexWhere((t) => t.id == tarif.id) < 0) return null;
    if (tarif.images.any((c) => meme(item, c))) return null;
    if (tarif.images.length >= Produit.maxImages) return null;
    return tarif.copyWith(images: [valeurStockable(item), ...tarif.images]);
  }

  /// Retire [item] de l'article [id]. null si absente.
  static Tarif? retirerTarif(
    Tarif tarif,
    MediaItem item, {
    required List<Tarif> tarifs,
  }) {
    if (tarifs.indexWhere((t) => t.id == tarif.id) < 0) return null;
    if (!tarif.images.any((c) => meme(item, c))) return null;
    return tarif.copyWith(
        images: tarif.images.where((c) => !meme(item, c)).toList());
  }

  /// Retire [cle] de TOUTES les entités, sur place (les listes du Store
  /// sont partagées avec les Notifiers). Retourne les identifiants des
  /// entités détachées — utilisé avant une suppression DÉFINITIVE pour ne
  /// jamais laisser de référence morte, et ne persister QUE celles-ci.
  ///
  /// L'apparient se fait par NOM DE FICHIER : l'entité peut porter un
  /// chemin complet alors que la galerie connaît le nom seul.
  static ({List<String> produits, List<String> tarifs}) detacher(
    String cle, {
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) {
    bool cible(String reference) => nomFichier(reference) == nomFichier(cle);
    final pIds = <String>[];
    final tIds = <String>[];
    for (var i = 0; i < produits.length; i++) {
      final p = produits[i];
      final dansGalerie = p.images.any(cible);
      final principalMeme = p.imagePath != null && cible(p.imagePath!);
      if (!dansGalerie && !principalMeme) continue;
      final reste = p.images.where((c) => !cible(c)).toList();
      // `copyWith(images: reste)` dérive le principal : plus besoin du
      // `sansImage()` manuel qui masquait le cas « liste vidée ».
      produits[i] = p.copyWith(images: reste);
      pIds.add(p.id);
    }
    for (var i = 0; i < tarifs.length; i++) {
      final t = tarifs[i];
      if (!t.images.any(cible)) continue;
      tarifs[i] = t.copyWith(images: t.images.where((c) => !cible(c)).toList());
      tIds.add(t.id);
    }
    return (produits: pIds, tarifs: tIds);
  }

  /// Clés images d'un produit : photo principale (si absente de la
  /// galerie — chemins historiques) puis la galerie. Sans doublon.
  static List<String> _clesProduit(Produit p) {
    final out = <String>[];
    final principale = p.imagePath;
    if (principale != null &&
        principale.isNotEmpty &&
        !p.images.contains(principale)) {
      out.add(principale);
    }
    for (final c in p.images) {
      if (c.isNotEmpty && !out.contains(c)) out.add(c);
    }
    return out;
  }
}
