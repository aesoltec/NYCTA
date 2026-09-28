import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/services/media_service.dart';

/// Plan A2 renforcé — persistance des images : noms uniques, compression
/// < 300 Ko, migration anciens noms, re-téléchargement cloud, reload Store.
void main() {
  late Directory racine;

  setUpAll(() async {
    racine = await Directory.systemTemp.createTemp('nycta_img_test');
    MediaService.dossierRacineTest = racine;
  });

  tearDownAll(() async {
    MediaService.dossierRacineTest = null;
    try {
      await racine.delete(recursive: true);
    } catch (_) {}
  });

  /// Image synthétique lourde et peu compressible (bruit).
  Future<File> imageBruitee(String nom, int cote) async {
    final im = img.Image(width: cote, height: cote);
    var graine = 123456789;
    for (var y = 0; y < cote; y++) {
      for (var x = 0; x < cote; x++) {
        graine = (graine * 1103515245 + 12345) & 0x7fffffff;
        im.setPixelRgb(x, y, graine % 256, (graine >> 8) % 256,
            (graine >> 16) % 256);
      }
    }
    final f = File('${racine.path}/$nom');
    await f.writeAsBytes(img.encodeJpg(im, quality: 100), flush: true);
    return f;
  }

  group('Nommage unique (Action 1)', () {
    test('schéma entite_id_ts_hash.ext', () {
      final n = MediaService.genererNomFichier(
          'produit', 'PRD123', 'jpg');
      expect(MediaService.schemaNom.hasMatch(n), isTrue);
      expect(n.startsWith('produit_PRD123_'), isTrue);
      expect(n.endsWith('.jpg'), isTrue);
    });

    test('500 noms tous distincts', () {
      final noms = {
        for (var i = 0; i < 500; i++)
          MediaService.genererNomFichier('produit', 'PRD123', 'jpg'),
      };
      expect(noms.length, 500);
    });

    test('ids spéciaux sanitisés', () {
      final n =
          MediaService.genererNomFichier('client', 'a/b c@d!', 'png');
      expect(MediaService.schemaNom.hasMatch(n), isTrue);
    });
  });

  group('Compression (Action 2)', () {
    test('2000px bruités → ≤ 1280px et < 300 Ko', () async {
      final src = await imageBruitee('grosse.jpg', 2000);
      expect(await src.length() > 300 * 1024, isTrue);
      final comp = await MediaService.compresser(src);
      final taille = await comp.length();
      expect(taille < 300 * 1024, isTrue,
          reason: 'taille=${taille ~/ 1024} Ko');
      final dec = img.decodeImage(await comp.readAsBytes())!;
      expect(dec.width <= 1280, isTrue);
      expect(dec.height <= 1280, isTrue);
    });

    test('copierDansApp : dossier media/<entite> + nom unique', () async {
      final src = await imageBruitee('src.jpg', 400);
      final chemin = await MediaService.copierDansApp(src,
          entite: 'produit', id: 'PRD1');
      expect(chemin.contains('media'), isTrue);
      expect(chemin.contains('produit'), isTrue);
      final base = chemin.split(RegExp(r'[/\\]')).last;
      expect(MediaService.schemaNom.hasMatch(base), isTrue);
      expect(File(chemin).existsSync(), isTrue);
    });
  });

  group('Migration anciens noms (Action 6)', () {
    test('vieux nom → nouveau schéma, ancien supprimé', () async {
      final vieux =
          File('${racine.path}/1790603849688.jpg');
      await imageBruitee('1790603849688.jpg', 100);
      final nouveau = MediaService.normaliserChemin(vieux.path,
          entite: 'produit', id: 'PRD9');
      expect(nouveau, isNotNull);
      expect(nouveau, isNot(endsWith('1790603849688.jpg')));
      final base = nouveau!.split(RegExp(r'[/\\]')).last;
      expect(MediaService.schemaNom.hasMatch(base), isTrue);
      expect(File(nouveau).existsSync(), isTrue);
      expect(vieux.existsSync(), isFalse);
    });

    test('nom déjà conforme : inchangé', () {
      const bon =
          'produit_PRD1_1738012345_a1b2c3.jpg';
      expect(
          MediaService.normaliserChemin(
              '/x/media/produit/$bon',
              entite: 'produit',
              id: 'PRD1'),
          endsWith(bon));
    });

    test('URL cloud : inchangée (gérée par assurerLocal)', () {
      const url = 'https://x.supabase.co/media/produit/a.jpg';
      expect(
          MediaService.normaliserChemin(url,
              entite: 'produit', id: 'P'),
          url);
    });
  });

  group('Reload Store = redémarrage simulé (Action 5)', () {
    test('produit + image → toJson → fromJson → accessible', () async {
      final src = await imageBruitee('reload.jpg', 500);
      final chemin = await MediaService.copierDansApp(src,
          entite: 'produit', id: 'PRD_R');
      final s = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final err = await s.ajouterProduit(Produit(
        id: 'nouveau',
        boutiqueId: s.boutiqueId,
        libelle: 'Produit photo reload',
        categorie: 'Autre',
        prixAchat: 500,
        prixVente: 800,
        stock: 3,
        images: [chemin],
        imagePath: chemin,
      ));
      expect(err, isNull);
      // Redémarrage simulé : sérialisation → rechargement.
      final json = s.toJson();
      final s2 = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      // Même chemin que le boot démo (_chargerEtat).
      s2.restaurerEtatPourTest(json);
      final retrouve = s2.produits
          .where((p) => p.libelle == 'Produit photo reload')
          .toList();
      expect(retrouve.length, 1);
      expect(retrouve.first.images.length, 1);
      expect(MediaService.existe(retrouve.first.images.first),
          isTrue);
    });
  });

  group('Re-téléchargement cloud (Action 4)', () {
    // Note : le loopback HTTP est bloqué dans cet environnement de test
    // (400 systématique, sans proxy configuré) → on utilise MockClient
    // (package:http/testing, déterministe, sans réseau). Le téléchargement
    // réel sera validé en manuel/cloud (parcours checklist).
    test('URL http → fichier local compressé + nommé', () async {
      final im = img.Image(width: 600, height: 600);
      img.fill(im, color: img.ColorRgb8(10, 120, 200));
      final octets = img.encodeJpg(im, quality: 90);
      final mock = MockClient((req) async => http.Response.bytes(
          octets, 200,
          headers: {'content-type': 'image/jpeg'}));
      final local = await MediaService.telechargerDepuisCloud(
          'https://cloud.test/media/produit/photo.jpg',
          entite: 'produit',
          id: 'PRD_DL',
          clientTest: mock);
      expect(local, isNotNull);
      expect(File(local!).existsSync(), isTrue);
      final base = local.split(RegExp(r'[/\\]')).last;
      expect(MediaService.schemaNom.hasMatch(base), isTrue);
      expect(await File(local).length() < 300 * 1024, isTrue);
      // assurerLocal : local existant → retourné tel quel.
      expect(
          await MediaService.assurerLocal(local,
              entite: 'produit', id: 'PRD_DL', clientTest: mock),
          local);
      // assurerLocal : chemin absent + URL → re-télécharge.
      final re = await MediaService.assurerLocal(
          '/chemin/absent.jpg',
          entite: 'produit',
          id: 'PRD_DL2',
          urlSecours: 'https://cloud.test/media/produit/autre.jpg',
          clientTest: mock);
      expect(re, isNotNull);
      expect(File(re!).existsSync(), isTrue);
      // Échec HTTP (404) → null, jamais d'exception.
      final echec = MockClient(
          (req) async => http.Response('absent', 404));
      expect(
          await MediaService.telechargerDepuisCloud(
              'https://cloud.test/absent.jpg',
              entite: 'produit',
              id: 'P',
              clientTest: echec),
          isNull);
    });
  });
}
