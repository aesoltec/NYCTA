import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Photos produits, logo, cachet : import galerie ou appareil photo,
/// puis copie dans le stockage privé de l'app (chemin stable).
///
/// Stratégie anti-disparition (plan A2 renforcé) :
/// 1. Nom UNIQUE et traçable : `<entite>_<id>_<tsSec>_<6hex>.<ext>`
///    (plus de `millisecondes.jpg` plat sujet aux collisions).
/// 2. Compression systématique : 1280px max, JPEG q75, cible < 300 Ko.
/// 3. Stockage `<docs>/media/<entite>/` (+ URLs cloud en parallèle).
/// 4. Rechargement résilient : local d'abord, re-téléchargement cloud
///    sinon, placeholder jamais bloquant (voir `AppImage`).
class MediaService {
  static final _picker = ImagePicker();
  static final _rand = Random.secure();

  /// Taille max d'une image persistée (plan A2 : < 300 Ko).
  static const tailleMaxOctets = 300 * 1024;

  /// Dimension max (plus grand côté) après redimensionnement.
  static const dimensionMax = 1280;

  /// Schéma de nom : entite_id_timestampSec_6hex.ext
  static final schemaNom = RegExp(
      r'^[A-Za-z0-9]+_[A-Za-z0-9_-]+_\d{10}_[0-9a-f]{6}\.(jpg|jpeg|png)$');

  /// Dossier racine injectable pour les tests (sinon
  /// `getApplicationDocumentsDirectory()`, indisponible en test).
  @visibleForTesting
  static Directory? dossierRacineTest;

  static Future<Directory> _racine() async {
    final test = dossierRacineTest;
    if (test != null) return test;
    return getApplicationDocumentsDirectory();
  }

  // ---------- Nommage unique ----------

  /// Génère `<entite>_<id>_<timestampSec>_<6hex>.<ext>`.
  /// Le hash est tiré de `Random.secure()` : unicité pratique équivalente
  /// à un SHA-1/UUID tronqué, sans dépendance crypto.
  static String genererNomFichier(String entite, String id,
      [String ext = 'jpg']) {
    final e = _sanitiser(entite, 'divers');
    final i = _sanitiser(id, 'x');
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hash = _rand
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    var extension = ext.toLowerCase().replaceAll('.', '');
    if (extension != 'png' && extension != 'jpeg') extension = 'jpg';
    return '${e}_${i}_${ts}_$hash.$extension';
  }

  static String _sanitiser(String s, String defaut) {
    final propre =
        s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return propre.isEmpty ? defaut : propre;
  }

  // ---------- Compression ----------

  /// Compresse [source] : redimensionne (max [maxDimension] px, ratio
  /// conservé) puis encode JPEG [qualite], en baissant par paliers
  /// (qualité puis dimensions) jusqu'à passer sous [tailleMaxOctets].
  /// Si [conserverPng] et image avec transparence : PNG redimensionné
  /// (800px max). Retourne un NOUVEAU fichier (le source est intact).
  /// Retourne [source] tel quel si le contenu n'est pas décodable.
  static Future<File> compresser(File source,
      {int maxDimension = dimensionMax,
      int qualite = 75,
      bool conserverPng = false,
      int tailleMax = tailleMaxOctets}) async {
    late final Uint8List octets;
    try {
      octets = await source.readAsBytes();
    } catch (_) {
      return source;
    }
    final decodee = img.decodeImage(octets);
    if (decodee == null) return source;
    final estPng =
        source.path.toLowerCase().endsWith('.png') && decodee.hasAlpha;
    if (conserverPng && estPng) {
      var im = decodee;
      final plusGrand = im.width > im.height ? im.width : im.height;
      if (plusGrand > 800) {
        im = im.width >= im.height
            ? img.copyResize(im, width: 800)
            : img.copyResize(im, height: 800);
      }
      return _ecrireTemp(() => img.encodePng(im));
    }
    // Étapes (dimension, qualité) : la première sous le seuil gagne ;
    // sinon on garde la plus petite obtenue (jamais d'exception).
    var dims = maxDimension;
    var im = _reduire(decodee, dims);
    var q = qualite.clamp(10, 95);
    var encoded = img.encodeJpg(im, quality: q);
    var meilleure = encoded;
    while (encoded.length > tailleMax) {
      if (q > 35) {
        q -= 15;
      } else if (dims > 800) {
        dims = (dims * 0.75).round();
        im = _reduire(decodee, dims);
        q = 60;
      } else {
        break;
      }
      encoded = img.encodeJpg(im, quality: q);
      if (encoded.length < meilleure.length) meilleure = encoded;
      if (meilleure.length <= tailleMax) {
        encoded = meilleure;
        break;
      }
    }
    if (encoded.length > tailleMax) encoded = meilleure;
    final sortie = encoded;
    return _ecrireTemp(() => sortie);
  }

  static img.Image _reduire(img.Image im, int maxDim) {
    final plusGrand = im.width > im.height ? im.width : im.height;
    if (plusGrand <= maxDim) return im;
    return im.width >= im.height
        ? img.copyResize(im, width: maxDim)
        : img.copyResize(im, height: maxDim);
  }

  static Future<File> _ecrireTemp(List<int> Function() encoder) async {
    final dir = await _racine();
    final tmp = Directory('${dir.path}/tmp');
    if (!tmp.existsSync()) await tmp.create(recursive: true);
    final f = File(
        '${tmp.path}/cmp_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await f.writeAsBytes(encoder(), flush: true);
    return f;
  }

  // ---------- Copie stable + sélection ----------

  static Future<String?> pickImage(
      {bool camera = false,
      String entite = 'divers',
      String id = 'x'}) async {
    try {
      final x = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (x == null) return null;
      // CRITIQUE : le chemin retourné pointe vers le CACHE (effacé par le
      // système). On COMPRESSE puis on COPIE dans le stockage privé avec
      // un nom unique, pour survivre aux redémarrages.
      return await copierDansApp(File(x.path),
          entite: entite, id: id);
    } catch (_) {
      return null; // permission refusée ou indisponible : fallback icône
    }
  }

  /// Galerie multi-images (max 05, mission §3.2) : sélection galerie
  /// uniquement (caméra = une seule photo), compression + copie stable.
  static Future<List<String>> pickImages(
      {int max = 5, String entite = 'divers', String id = 'x'}) async {
    try {
      final xs = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      final chemins = <String>[];
      for (final x in xs.take(max)) {
        chemins.add(await copierDansApp(File(x.path),
            entite: entite, id: id));
      }
      return chemins;
    } catch (_) {
      return const []; // permission refusée : rien, pas d'erreur
    }
  }

  /// Copie un fichier image vers `<docs>/media/<entite>/` sous un nom
  /// unique, après compression. Chemin stable et persistant.
  /// L'ancien appel `copierDansApp(f)` reste valide (entité `divers`).
  static Future<String> copierDansApp(File source,
      {String entite = 'divers',
      String id = 'x',
      bool compresserImage = true}) async {
    final dir = await _racine();
    final dossier = Directory('${dir.path}/media/$entite');
    if (!dossier.existsSync()) await dossier.create(recursive: true);
    final ext = source.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final nom = genererNomFichier(entite, id, ext);
    final dest = File('${dossier.path}/$nom');
    if (compresserImage) {
      final comp = await compresser(source,
          conserverPng: ext == 'png');
      await comp.copy(dest.path);
      try {
        if (comp.path != source.path) await comp.delete();
      } catch (_) {}
    } else {
      await source.copy(dest.path);
    }
    return dest.path;
  }

  /// Persiste des octets PNG (ex : signature manuscrite) dans l'app.
  static Future<String> savePng(Uint8List bytes, String nom) async {
    final dir = await _racine();
    final f = File('${dir.path}/$nom.png');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  static bool existe(String? path) =>
      path != null &&
      path.isNotEmpty &&
      !path.startsWith('http') &&
      File(path).existsSync();

  /// Vrai si le chemin pointe vers le cloud (URL http).
  static bool estDistant(String? path) =>
      path != null && path.startsWith('http');

  // ---------- Galerie : listage + suppression physique ----------

  /// Extension image acceptée dans la banque interne.
  static const extensionsImages = ['.jpg', '.jpeg', '.png'];

  /// Jointure de chemin cross-platform (Windows `\`, POSIX `/`).
  static String _joindre(String base, String a, String b) =>
      '$base${Platform.pathSeparator}$a${Platform.pathSeparator}$b';

  /// Dossiers scannés par la galerie interne. `galerie` = banque brute
  /// (uploads non encore rattachés) ; `produit`/`tarif` = copies faites
  /// lors de l'affectation. `divers` est **exclu** : il accueille les
  /// images de marque (logo, cachet, signature), qui ne sont pas du stock.
  static const dossiersGalerie = ['galerie', 'produit', 'tarif'];

  /// Préfixes de nom de fichier réservés aux images de marque.
  /// Le logo, le cachet et la signature ne sont pas des visuels produits :
  /// ils ne doivent JAMAIS alimenter la galerie interne.
  static const prefixesImageMarque = ['logo', 'cachet', 'signature'];

  /// Vrai si [chemin] désigne une image de marque (logo/cachet/signature).
  ///
  /// Deux formes de nom coexistent : `genererNomFichier` produit
  /// `<entite>_<id>_<ts>_<hash>.ext` (ex. `logo_marque_…`), et
  /// `savePng` produit `<nom>.png` (ex. `signature.png`). On accepte donc
  /// le préfixe suivi d'un séparateur `_` **ou** d'un point, sans quoi un
  /// logo nommé exactement `logo.png` passerait dans la galerie.
  static bool estImageDeMarque(String chemin) {
    final nom = chemin.split('/').last.split('\\').last.toLowerCase();
    return prefixesImageMarque.any(
        (p) => nom.startsWith('${p}_') || nom.startsWith('$p.'));
  }

  /// Supprime le FICHIER d'une image de marque lorsqu'elle est
  /// remplacée — le remplacement écrase le précédent (condition
  /// non négociable : pas d'accumulation d'anciens logos/signatures).
  /// Chemin local uniquement ; le cloud est traité par l'appelant.
  static Future<bool> effacerAncienneImageMarque(String? ancien) async =>
      supprimerFichier(ancien);

  /// Répertoire d'un dossier média (`<docs>/media/<dossier>`), créé si
  /// besoin. [dossierRacineTest] est honoré (tests).
  static Future<Directory> dossierMedia(String dossier) async {
    final racine = await _racine();
    final d = Directory(_joindre(racine.path, 'media', dossier));
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  /// Liste les images d'un dossier média (récursif : `media/<dossier>/**`).
  /// Tri antéchronologique par date de modification. Jamais d'exception.
  static Future<List<File>> listerImages(String dossier) async {
    try {
      final dir =
          Directory(_joindre((await _racine()).path, 'media', dossier));
      if (!dir.existsSync()) return const [];
      final fichiers = <File>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        final ext = e.path.toLowerCase();
        if (!extensionsImages.any(ext.endsWith)) continue;
        fichiers.add(e);
      }
      fichiers.sort((a, b) => b.statSync().modified.compareTo(
          a.statSync().modified));
      return fichiers;
    } catch (_) {
      return const [];
    }
  }

  /// Suppression PHYSIQUE d'un média local (définitif).
  /// Un fichier encore utilisé par un produit/article n'est PAS supprimé :
  /// la protection est faite en amont par l'appelant (l'utilisateur
  /// confirme), ici on ne protège que le chemin distant (jamais d'écriture).
  /// Retourne true si le fichier a disparu du disque.
  static Future<bool> supprimerFichier(String? chemin) async {
    if (chemin == null || chemin.isEmpty) return false;
    if (chemin.startsWith('http')) return false; // distant : voir cloud
    try {
      final f = File(chemin);
      if (!f.existsSync()) return true; // déjà absent = objectif atteint
      await f.delete();
      return !f.existsSync();
    } catch (_) {
      return false;
    }
  }

  // ---------- Migration des anciens noms (Action 6) ----------

  /// Si [chemin] local ne respecte pas le schéma unique, le recopie
  /// sous un nouveau nom, met à jour le modèle (via la valeur retournée)
  /// et supprime l'ancien fichier. Synchrone + jamais d'exception :
  /// en cas de doute, retourne [chemin] inchangé.
  static String? normaliserChemin(String? chemin,
      {required String entite, required String id}) {
    if (chemin == null || chemin.isEmpty) return chemin;
    if (chemin.startsWith('http')) return chemin;
    final base =
        chemin.split(RegExp(r'[/\\]')).lastWhere((s) => s.isNotEmpty);
    if (schemaNom.hasMatch(base)) return chemin;
    try {
      final f = File(chemin);
      if (!f.existsSync()) return chemin;
      var ext = 'jpg';
      if (base.toLowerCase().endsWith('.png')) ext = 'png';
      final dir = f.parent;
      // Même dossier si déjà sous media/, sinon media/<entite>.
      final dossier = dir.path.endsWith('media${Platform.pathSeparator}$entite')
          ? dir
          : Directory(
              '${dir.path}${Platform.pathSeparator}media${Platform.pathSeparator}$entite');
      if (!dossier.existsSync()) dossier.createSync(recursive: true);
      final dest =
          File('${dossier.path}${Platform.pathSeparator}'
              '${genererNomFichier(entite, id, ext)}');
      f.copySync(dest.path);
      try {
        f.deleteSync();
      } catch (_) {}
      return dest.path;
    } catch (_) {
      return chemin;
    }
  }

  // ---------- Rechargement résilient (Action 4) ----------

  /// Re-télécharge [url] (compressée, nom unique) et retourne le chemin
  /// local, ou null en cas d'échec (jamais d'exception).
  /// [clientTest] : injecté uniquement par les tests (`MockClient`).
  static Future<String?> telechargerDepuisCloud(String url,
      {required String entite,
      required String id,
      @visibleForTesting http.Client? clientTest}) async {
    final client = clientTest ?? http.Client();
    final possedeClient = clientTest == null;
    try {
      final resp = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      final dir = await _racine();
      final tmp = Directory('${dir.path}/tmp');
      if (!tmp.existsSync()) await tmp.create(recursive: true);
      final estPng = (resp.headers['content-type'] ?? '')
              .contains('png') ||
          url.toLowerCase().split('?').first.endsWith('.png');
      final f = File('${tmp.path}/dl_'
          '${DateTime.now().microsecondsSinceEpoch}.${estPng ? 'png' : 'jpg'}');
      await f.writeAsBytes(resp.bodyBytes, flush: true);
      final local = await copierDansApp(f,
          entite: entite, id: id, compresserImage: true);
      try {
        await f.delete();
      } catch (_) {}
      return local;
    } catch (_) {
      return null;
    } finally {
      if (possedeClient) client.close();
    }
  }

  /// Garantit un chemin local utilisable : le local s'il existe, sinon
  /// re-téléchargement depuis [urlSecours] (ou depuis [chemin] si c'est
  /// déjà une URL), sinon null (placeholder à l'affichage).
  static Future<String?> assurerLocal(String? chemin,
      {required String entite,
      required String id,
      String? urlSecours,
      @visibleForTesting http.Client? clientTest}) async {
    if (existe(chemin)) return chemin;
    final url = urlSecours ??
        ((chemin != null && chemin.startsWith('http')) ? chemin : null);
    if (url == null) return null;
    return telechargerDepuisCloud(url,
        entite: entite, id: id, clientTest: clientTest);
  }
}
