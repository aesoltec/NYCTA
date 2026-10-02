import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Régression : « même si on utilise de nouvelles images, les anciennes
/// reviennent remplacer les nouvelles ».
///
/// Cause initiale : `imagePath` est une valeur DÉRIVÉE de `images`
/// (`images.first`) mais [Produit.copyWith] gardait l'ancienne valeur
/// quand la nouvelle liste devenait vide. Une image retirée de la
/// galerie survivait donc en `imagePath` et revenait à la sauvegarde.
///
/// Cause secondaire trouvée sur appareil : le CONSTRUCTEUR ne derivait
/// rien, alors que la documentation du modèle annonce « imagePath vaut
/// images.firstOrNull » et que `copyWith` le fait. Deux façons de
/// construire le même produit, deux états différents. Les tests
/// unitaires ne le voyaient pas car leur helper passait `imagePath` en
/// dur — masquage classique d'une régression par le test lui-même.
void main() {
  /// Construit SANS passer `imagePath` : le constructeur doit dériver
  /// seul. C'est exactement le scénario que l'utilisateur exerce.
  Produit _p({
    String id = 'p1',
    List<String> images = const [],
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
      );

  /// Variante pour le seul cas « imagePath fournit explicitement ».
  Produit _pAvecImagePath({
    List<String> images = const [],
    String? imagePath,
  }) =>
      Produit(
        id: 'p1',
        boutiqueId: 'b1',
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
        images: images,
        imagePath: imagePath,
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

    test('effacerImagePath est explicite et sans effet de bord', () {
      final p = _p(images: const ['/a.jpg']);
      final r = p.copyWith(effacerImagePath: true, libelle: 'X');
      expect(r.imagePath, isNull);
      expect(r.images, const ['/a.jpg'],
          reason: 'effacerImagePath touche la photo, pas la galerie');
    });
  });

  group('constructeur — même règle que copyWith', () {
    test('dérive le principal depuis la galerie', () {
      expect(_p(images: const ['/a.jpg']).imagePath, '/a.jpg');
      expect(_p(images: const ['/a.jpg', '/b.jpg']).imagePath, '/a.jpg');
    });

    test('galerie vide → aucun principal', () {
      expect(_p().imagePath, isNull);
    });

    test('imagePath explicite gagne sur la galerie', () {
      final p = _pAvecImagePath(
          images: const ['/a.jpg'], imagePath: '/force.jpg');
      expect(p.imagePath, '/force.jpg');
    });

    test('imagePath explicitement nul : le constructeur NE redérive pas',
        () {
      // C'est le cas `copyWith(effacerImagePath: true)` : la photo est
      // retirée alors que la galerie est intacte. Si le constructeur
      // ré-derivait `images.first`, la photo repartirait.
      final p = _pAvecImagePath(images: const ['/a.jpg']);
      expect(p.images, const ['/a.jpg']);
      expect(p.imagePath, isNull);
    });

    test('constructeur et copyWith donnent le même état', () {
      // Le test qui avait échoué sur l'appareil : les deux façons de
      // construire le même produit divergeaient.
      for (final images in <List<String>>[
        const [],
        const ['/a.jpg'],
        const ['/a.jpg', '/b.jpg'],
      ]) {
        final direct = _p(images: images);
        final copie = _p().copyWith(images: images);
        expect(copie.imagePath, direct.imagePath,
            reason: 'divergence pour $images');
      }
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
