import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_card.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_grid.dart';

/// Goldens Phase 1 (refonte UX) : carte produit (3 badges) + grille.
/// Génération : `flutter test test/golden/product_ux_test.dart --update-goldens`.
Produit _p(String id, String libelle,
        {int stock = 10, int seuil = 3, DateTime? dateAjout}) =>
    Produit(
        id: id,
        boutiqueId: 'b1',
        libelle: libelle,
        categorie: 'Test',
        prixAchat: 3000,
        prixVente: 5000,
        stock: stock,
        seuil: seuil,
        dateAjout: dateAjout);

Future<void> _cadre(
    WidgetTester tester, Widget enfant, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value:
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin)),
      child: MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: taille.width,
                  height: taille.height,
                  child: enfant)))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('Goldens UX Stock', () {
    testWidgets('carte rupture', (tester) async {
      await _cadre(
          tester,
          Center(
              child: SizedBox(
                  width: 180,
                  child: ProductCard(
                      produit: _p('a', 'Câble RJ45', stock: 0)))),
          const Size(360, 640));
      await expectLater(
          find.byType(ProductCard),
          matchesGoldenFile('goldens/product_card_rupture.png'));
    });

    testWidgets('carte stock faible + nouveau', (tester) async {
      await _cadre(
          tester,
          Center(
              child: SizedBox(
                  width: 180,
                  child: ProductCard(
                      produit: _p('a', 'Disjoncteur 32A',
                          stock: 2,
                          seuil: 3,
                          dateAjout: DateTime.now().subtract(
                              const Duration(days: 1)))))),
          const Size(360, 640));
      await expectLater(
          find.byType(ProductCard),
          matchesGoldenFile('goldens/product_card_faible_nouveau.png'));
    });

    testWidgets('grille 2 colonnes 360px', (tester) async {
      await _cadre(
          tester,
          ProductGrid(produits: [
            _p('a', 'Article A'),
            _p('b', 'Article B', stock: 0),
          ]),
          const Size(360, 800));
      await expectLater(
          find.byType(ProductGrid),
          matchesGoldenFile('goldens/product_grid_360.png'));
    });
  });
}
