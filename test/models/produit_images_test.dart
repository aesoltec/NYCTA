import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Régression : « même si on utilise de nouvelles images, les anciennes
/// reviennent remplacer les nouvelles ».
///
/// Cause : `imagePath` est une valeur DÉRIVÉE de `images` (`images.first`)
/// mais `copyWith` gardait l'ancienne valeur quand la nouvelle liste
/// devenait vide. Une image retirée de la galerie survivait donc en
/// `imagePath` et revenait à la sauvegarde.
void main() {
  Produit _p({
    String id = 'p1',
    List<String> images = const [],
    String? imagePath,
  }) =>
      Produit(
        id: id,
        boutiqueId: 'b1',
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
        images: images,
        imagePath: imagePath ?? (images.isEmpty ? null : images.first),
      );

  group('Produit.copyWith — dérivation de imagePath', () {
    test('vider la galerie SUPPRIME la photo (pas de retour de l\'ancienne)',
        () {
      final p = _p(images: const ['/a.jpg', '/b.jpg']);
      expect(p.imagePath, '/a.jpg');

      final r = p.copyWith(images: const <String>[]);

      expect(r.images, isEmpty);
      expect(r.imagePath, isNull,
          reason: 'l\'ancienne image ne doit PAS survivre au vidage');
    });

    test('retirer la première promeut la suivante', () {
      final p = _p(images: const ['/a.jpg', '/b.jpg']);
      final r = p.copyWith(images: const ['/b.jpg']);
      expect(r.imagePath, '/b.jpg');
    });

    test('remplacer toutes les images change bien le principal', () {
      final p = _p(images: const ['/ancienne.jpg']);
      final r = p.copyWith(images: const ['/nouvelle.jpg']);
      expect(r.imagePath, '/nouvelle.jpg');
      expect(r.imagePath, isNot('/ancienne.jpg'));
    });

    test('imagePath fourni explicitement reste prioritaire', () {
      final p = _p(images: const ['/a.jpg']);
      final r = p.copyWith(imagePath: '/force.jpg', images: const ['/b.jpg']);
      expect(r.imagePath, '/force.jpg');
    });

    test('sans argument images, le principal suit la galerie existante', () {
      final p = _p(images: const ['/a.jpg']);
      final r = p.copyWith(libelle: 'Autre');
      expect(r.imagePath, '/a.jpg');
      expect(r.libelle, 'Autre');
    });

    test('produit sans image reste sans image', () {
      final p = _p();
      expect(p.imagePath, isNull);
      expect(p.copyWith(stock: 9).imagePath, isNull);
    });

    test('effacerImagePath est explicite etsans effet de bord', () {
      final p = _p(images: const ['/a.jpg']);
      final r = p.copyWith(effacerImagePath: true, libelle: 'X');
      expect(r.imagePath, isNull);
      expect(r.images, const ['/a.jpg'],
          reason: 'effacerImagePath touche la photo, pas la galerie');
    });
  });

  group('invariant du modèle', () {
    test('imagePath == images.first, ou null si galerie vide', () {
      for (final images in <List<String>>[
        const [],
        const ['/a.jpg'],
        const ['/a.jpg', '/b.jpg'],
      ]) {
        final p = _p(images: images);
        if (images.isEmpty) {
          expect(p.imagePath, isNull);
        } else {
          expect(p.imagePath, images.first);
        }
      }
    });

    test('copyWith préserve toujours cet invariant', () {
      final p = _p(images: const ['/a.jpg', '/b.jpg']);
      final r = p.copyWith(images: const ['/x.jpg', '/y.jpg', '/z.jpg']);
      expect(r.imagePath, r.images.first);
    });
  });

  group('sansImage() reste cohérent', () {
    test('retire photo ET galerie', () {
      final p = _p(images: const ['/a.jpg']);
      final r = p.sansImage();
      expect(r.imagePath, isNull);
      expect(r.images, isEmpty);
    });
  });
}
