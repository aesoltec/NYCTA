import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/gallery/gallery_service.dart';
import 'package:pme_gestion_pro/data/models/media_item.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';

Produit _p(String id, {List<String> images = const [], String? principale}) =>
    Produit(
      id: id,
      boutiqueId: 'b1',
      libelle: 'Produit $id',
      categorie: 'Test',
      prixAchat: 100,
      prixVente: 200,
      stock: 5,
      images: images,
      imagePath: principale ?? (images.isEmpty ? null : images.first),
    );

Tarif _t(String id, {List<String> images = const []}) => Tarif(
      id: id,
      libelle: 'Article $id',
      categorie: 'Test',
      prix: 500,
      images: images,
    );

void main() {
  group('GalleryService.usages', () {
    test('compte les produits et articles qui utilisent une image', () {
      final u = GalleryService.usages(
        produits: [_p('p1', images: ['a.jpg']), _p('p2', images: ['a.jpg'])],
        tarifs: [_t('t1', images: ['a.jpg'])],
      );
      expect(u['a.jpg']!.length, 3);
      expect(u['a.jpg']!.map((x) => x.type).toSet(), {'produit', 'tarif'});
    });

    test('image inutilisée : aucune entrée', () {
      final u = GalleryService.usages(
          produits: [_p('p1', images: ['a.jpg'])], tarifs: const []);
      expect(u['b.jpg'], isNull);
    });

    test('la photo principale hors galerie est comptée', () {
      final u = GalleryService.usages(
        produits: [_p('p1', principale: 'legacy.jpg')],
        tarifs: const [],
      );
      expect(u['legacy.jpg']!.length, 1);
    });

    test('nbUsages : 0 pour une image libre', () {
      expect(
        GalleryService.nbUsages('libre.jpg',
            produits: [_p('p1', images: ['a.jpg'])], tarifs: const []),
        0,
      );
    });
  });

  group('GalleryService.indexer', () {
    test('fusionne stockés + référencés sans doublon', () {
      final index = GalleryService.indexer(
        stockes: [
          const MediaItem(cle: 'a.jpg', cheminLocal: '/tmp/a.jpg'),
          const MediaItem(cle: 'libre.jpg', cheminLocal: '/tmp/libre.jpg'),
        ],
        produits: [_p('p1', images: ['a.jpg'])],
        tarifs: const [],
      );
      expect(index.length, 2);
      // rattachées d'abord
      expect(index.first.cle, 'a.jpg');
    });

    test('une image référencée mais absente du stockage reste visible', () {
      final index = GalleryService.indexer(
        stockes: const [],
        produits: [_p('p1', images: ['orpheline.jpg'])],
        tarifs: const [],
      );
      expect(index.length, 1);
      expect(index.first.cle, 'orpheline.jpg');
    });

    test('vide si rien nulle part', () {
      expect(
        GalleryService.indexer(
            stockes: const [], produits: const [], tarifs: const []),
        isEmpty,
      );
    });
  });

  group('GalleryService.affecterProduit', () {
    test('ajoute en tête (devient la photo principale)', () {
      final liste = [_p('p1', images: ['a.jpg'])];
      final r = GalleryService.affecterProduit(liste[0], 'b.jpg',
          produits: liste);
      expect(r!.images.first, 'b.jpg');
      expect(r.images.length, 2);
      expect(r.imagePath, 'b.jpg');
    });

    test('refuse un doublon', () {
      final liste = [_p('p1', images: ['a.jpg'])];
      expect(
        GalleryService.affecterProduit(liste[0], 'a.jpg', produits: liste),
        isNull,
      );
    });

    test('refuse au-delà de 5 images', () {
      final liste = [
        _p('p1', images: ['1.jpg', '2.jpg', '3.jpg', '4.jpg', '5.jpg'])
      ];
      expect(
        GalleryService.affecterProduit(liste[0], '6.jpg', produits: liste),
        isNull,
      );
    });

    test('refuse un produit inexistant', () {
      expect(
        GalleryService.affecterProduit(_p('fantome'), 'a.jpg', produits: []),
        isNull,
      );
    });

    test('refuse une clé vide', () {
      final liste = [_p('p1')];
      expect(GalleryService.affecterProduit(liste[0], '', produits: liste),
          isNull);
    });
  });

  group('GalleryService.retirerProduit', () {
    test('retire et promeut la suivante comme principale', () {
      final liste = [_p('p1', images: ['a.jpg', 'b.jpg'])];
      final r = GalleryService.retirerProduit(liste[0], 'a.jpg',
          produits: liste);
      expect(r!.images, ['b.jpg']);
      expect(r.imagePath, 'b.jpg');
    });

    test('retirer la dernière : imagePath null', () {
      final liste = [_p('p1', images: ['a.jpg'])];
      final r = GalleryService.retirerProduit(liste[0], 'a.jpg',
          produits: liste);
      expect(r!.images, isEmpty);
      expect(r.imagePath, isNull);
    });

    test('image absente : null (no-op)', () {
      final liste = [_p('p1', images: ['a.jpg'])];
      expect(
        GalleryService.retirerProduit(liste[0], 'z.jpg', produits: liste),
        isNull,
      );
    });
  });

  group('GalleryService — articles du catalogue', () {
    test('affecter un article', () {
      final liste = [_t('t1')];
      final r = GalleryService.affecterTarif(liste[0], 'a.jpg', tarifs: liste);
      expect(r!.images, ['a.jpg']);
    });

    test('refuser doublon et liste pleine', () {
      final liste = [_t('t1', images: ['a.jpg'])];
      expect(GalleryService.affecterTarif(liste[0], 'a.jpg', tarifs: liste),
          isNull);
    });

    test('retirer un article', () {
      final liste = [_t('t1', images: ['a.jpg', 'b.jpg'])];
      final r = GalleryService.retirerTarif(liste[0], 'a.jpg', tarifs: liste);
      expect(r!.images, ['b.jpg']);
    });
  });

  group('GalleryService.detacher (suppression définitive)', () {
    test('détache de tous les produits et articles', () {
      final produits = [
        _p('p1', images: ['a.jpg', 'b.jpg']),
        _p('p2', images: ['a.jpg']),
      ];
      final tarifs = [_t('t1', images: ['a.jpg'])];
      final r =
          GalleryService.detacher('a.jpg', produits: produits, tarifs: tarifs);
      expect(r.produits, ['p1', 'p2']);
      expect(r.tarifs, ['t1']);
      expect(produits[0].images, ['b.jpg']);
      expect(produits[1].images, isEmpty);
      expect(tarifs[0].images, isEmpty);
    });

    test('la principale d��truite devient la suivante', () {
      final produits = [_p('p1', images: ['a.jpg', 'b.jpg'])];
      GalleryService.detacher('a.jpg', produits: produits, tarifs: const []);
      expect(produits[0].imagePath, 'b.jpg');
    });

    test('image absente : aucune entité touchée', () {
      final produits = [_p('p1', images: ['a.jpg'])];
      final r =
          GalleryService.detacher('z.jpg', produits: produits, tarifs: const []);
      expect(r.produits, isEmpty);
      expect(produits[0].images, ['a.jpg']);
    });
  });

  group('GalleryService.estDistant', () {
    test('distingue URL et chemin local', () {
      expect(GalleryService.estDistant('https://x/y.jpg'), isTrue);
      expect(GalleryService.estDistant('C:/docs/media/a.jpg'), isFalse);
      expect(GalleryService.estDistant(null), isFalse);
    });
  });
}
