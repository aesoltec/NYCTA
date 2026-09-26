import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';

Produit _produit() => const Produit(
      id: 'pr_test',
      boutiqueId: 'bt_siege',
      libelle: 'Produit galerie',
      categorie: 'Autre',
      prixAchat: 1000,
      prixVente: 1500,
      stock: 10,
      images: ['a.jpg', 'b.jpg', 'c.jpg'],
      imagePath: 'a.jpg',
    );

void main() {
  group('Galerie produits (max 05)', () {
    test('maxImages vaut 5', () {
      expect(Produit.maxImages, 5);
    });

    test('copyWith synchronise la photo principale', () {
      final p = _produit().copyWith(
          images: ['x.jpg', 'y.jpg']);
      expect(p.imagePath, 'x.jpg');
      expect(p.images, ['x.jpg', 'y.jpg']);
    });

    test('sansImage vide la galerie', () {
      final p = _produit().sansImage();
      expect(p.imagePath, isNull);
      expect(p.images, isEmpty);
    });

    test('roundtrip persistance locale', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      final err = await s.ajouterProduit(Produit(
        id: 'nouveau',
        boutiqueId: s.boutiqueId,
        libelle: 'Produit photo test',
        categorie: 'Autre',
        prixAchat: 500,
        prixVente: 800,
        stock: 3,
        images: const ['u1.jpg', 'u2.jpg'],
        imagePath: 'u1.jpg',
      ));
      expect(err, isNull);
      final json = s.toJson();
      final imgs = (json['produits'] as List)
          .where((e) =>
              (e as Map)['libelle'] == 'Produit photo test')
          .toList();
      expect(imgs.length, 1);
      expect((imgs.first as Map)['images'], ['u1.jpg', 'u2.jpg']);
    });
  });
}
