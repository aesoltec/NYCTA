import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/media_service.dart';

/// Galerie interne — briques `MediaService` : listage et suppression
/// PHYSIQUE. Le dossier racine est injecté (`dossierRacineTest`) car
/// `getApplicationDocumentsDirectory()` n'existe pas en test unitaire.
void main() {
  late Directory racine;

  File _image(String dossier, String nom) {
    final d = Directory('${racine.path}/media/$dossier');
    if (!d.existsSync()) d.createSync(recursive: true);
    final f = File('${d.path}/$nom');
    f.writeAsBytesSync(List<int>.filled(64, 7));
    return f;
  }

  setUp(() {
    racine = Directory.systemTemp.createTempSync('galerie_test');
    MediaService.dossierRacineTest = racine;
  });

  tearDown(() {
    MediaService.dossierRacineTest = null;
    try {
      racine.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('MediaService.dossierMedia', () {
    test('crée le dossier et le renvoie', () async {
      final d = await MediaService.dossierMedia('galerie');
      expect(d.existsSync(), isTrue);
      expect(d.path, contains('media${Platform.pathSeparator}galerie'));
    });
  });

  group('MediaService.listerImages', () {
    test('liste uniquement les images, triées du plus récent', () async {
      final a = _image('galerie', 'a.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      _image('galerie', 'b.png');
      _image('galerie', 'notes.txt'); // non image : ignorée

      final fichiers = await MediaService.listerImages('galerie');
      expect(fichiers.length, 2);
      expect(fichiers.first.path, endsWith('b.png'));
      expect(fichiers.any((f) => f.path.endsWith('notes.txt')), isFalse);
      expect(a.existsSync(), isTrue);
    });

    test('dossier inexistant → liste vide, jamais d\'exception', () async {
      expect(await MediaService.listerImages('fantome'), isEmpty);
    });

    test('les 3 dossiers de la galerie sont déclarés', () {
      expect(MediaService.dossiersGalerie,
          containsAll(<String>['galerie', 'produit', 'tarif']));
    });
  });

  group('MediaService.supprimerFichier', () {
    test('supprime définitivement un fichier local', () async {
      final f = _image('galerie', 'a.jpg');
      expect(await MediaService.supprimerFichier(f.path), isTrue);
      expect(f.existsSync(), isFalse);
    });

    test('fichier déjà absent → true (objectif atteint)', () async {
      final f = _image('galerie', 'gone.jpg');
      await f.delete();
      expect(await MediaService.supprimerFichier(f.path), isTrue);
    });

    test('refuse un chemin vide ou distant (jamais d\'écriture réseau)',
        () async {
      expect(await MediaService.supprimerFichier(null), isFalse);
      expect(await MediaService.supprimerFichier(''), isFalse);
      expect(
          await MediaService.supprimerFichier('https://x.supabase.co/a.jpg'),
          isFalse);
    });
  });
}
