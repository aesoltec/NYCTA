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

  /// Rattache [cle] au produit [id]. null si : clé vide, produit
  /// introuvable, image déjà présente, ou liste pleine (5 max).
  ///
  /// L'image est mise en TÊTE : elle devient la photo principale
  /// (`imagePath` = `images.first`), convention du modèle.
  static Produit? affecterProduit(
    Produit produit,
    String cle, {
    required List<Produit> produits,
  }) {
    if (cle.isEmpty) return null;
    if (produits.indexWhere((p) => p.id == produit.id) < 0) return null;
    if (produit.images.contains(cle)) return null;
    if (produit.images.length >= Produit.maxImages) return null;
    return produit.copyWith(images: [cle, ...produit.images]);
  }

  /// Retire [cle] du produit [id]. Si c'était la photo principale, la
  /// suivante de la galerie le devient (et `sansImage()` si la liste se
  /// vide — `copyWith` seul ne peut pas mettre `imagePath` à null).
  static Produit? retirerProduit(
    Produit produit,
    String cle, {
    required List<Produit> produits,
  }) {
    if (produits.indexWhere((p) => p.id == produit.id) < 0) return null;
    final dansGalerie = produit.images.contains(cle);
    if (!dansGalerie && produit.imagePath != cle) return null;
    final reste = produit.images.where((c) => c != cle).toList();
    if (produit.imagePath != cle) return produit.copyWith(images: reste);
    return reste.isEmpty ? produit.sansImage() : produit.copyWith(images: reste);
  }

  /// Rattache [cle] à l'article [id] du catalogue. null si déjà présente,
  /// liste pleine, ou article introuvable.
  static Tarif? affecterTarif(
    Tarif tarif,
    String cle, {
    required List<Tarif> tarifs,
  }) {
    if (cle.isEmpty) return null;
    if (tarifs.indexWhere((t) => t.id == tarif.id) < 0) return null;
    if (tarif.images.contains(cle)) return null;
    if (tarif.images.length >= Produit.maxImages) return null;
    return tarif.copyWith(images: [cle, ...tarif.images]);
  }

  /// Retire [cle] de l'article [id]. null si absente.
  static Tarif? retirerTarif(
    Tarif tarif,
    String cle, {
    required List<Tarif> tarifs,
  }) {
    if (tarifs.indexWhere((t) => t.id == tarif.id) < 0) return null;
    if (!tarif.images.contains(cle)) return null;
    return tarif.copyWith(images: tarif.images.where((c) => c != cle).toList());
  }

  /// Retire [cle] de TOUTES les entités, sur place (les listes du Store
  /// sont partagées avec les Notifiers). Retourne les identifiants des
  /// entités détachées — utilisé avant une suppression DÉFINITIVE pour ne
  /// jamais laisser de référence morte, et ne persister QUE celles-ci.
  static ({List<String> produits, List<String> tarifs}) detacher(
    String cle, {
    required List<Produit> produits,
    required List<Tarif> tarifs,
  }) {
    final pIds = <String>[];
    final tIds = <String>[];
    for (var i = 0; i < produits.length; i++) {
      final p = produits[i];
      if (!p.images.contains(cle) && p.imagePath != cle) continue;
      final reste = p.images.where((c) => c != cle).toList();
      // `copyWith` ne peut pas mettre `imagePath` à null : d'où
      // `sansImage()` quand la galerie se vide.
      produits[i] = p.imagePath == cle && reste.isEmpty
          ? p.sansImage()
          : p.copyWith(images: reste);
      pIds.add(p.id);
    }
    for (var i = 0; i < tarifs.length; i++) {
      final t = tarifs[i];
      if (!t.images.contains(cle)) continue;
      tarifs[i] = t.copyWith(images: t.images.where((c) => c != cle).toList());
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
