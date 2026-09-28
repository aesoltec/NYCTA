import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/badge_produit.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_card.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_grid.dart';

/// Phase 1 — refonte UX e-commerce Stock : badges, cartes, grille.
Produit _p(String id, String libelle,
        {int stock = 10,
        int seuil = 3,
        DateTime? dateAjout,
        double prixVente = 5000,
        List<String> images = const []}) =>
    Produit(
        id: id,
        boutiqueId: 'bt_siege',
        libelle: libelle,
        categorie: 'Test',
        prixAchat: 3000,
        prixVente: prixVente,
        stock: stock,
        seuil: seuil,
        images: images,
        dateAjout: dateAjout);

Widget _hote(Widget enfant) {
  final store =
      Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: Scaffold(body: enfant)),
  );
}

Future<void> _pomper(WidgetTester tester, Widget enfant,
    {Size taille = const Size(800, 1200)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_hote(enfant));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('ProduitExtension badges', () {
    test('rupture / faible / ok', () {
      expect(_p('a', 'A', stock: 0).enRupture, isTrue);
      expect(_p('a', 'A', stock: 0).stockFaible, isFalse);
      expect(_p('a', 'A', stock: 2, seuil: 3).stockFaible, isTrue);
      expect(_p('a', 'A', stock: 4, seuil: 3).stockFaible, isFalse);
    });

    test('nouveau < 7 jours, ancien non', () {
      expect(
          _p('a', 'A',
                  dateAjout:
                      DateTime.now().subtract(const Duration(days: 2)))
              .nouveau,
          isTrue);
      expect(
          _p('a', 'A',
                  dateAjout:
                      DateTime.now().subtract(const Duration(days: 30)))
              .nouveau,
          isFalse);
      expect(_p('a', 'A').nouveau, isFalse);
    });
  });

  group('BadgeProduitWidget', () {
    testWidgets('3 libellés rendus', (tester) async {
      await _pomper(
          tester,
          const Column(children: [
            BadgeProduitWidget(BadgeProduit.nouveau),
            BadgeProduitWidget(BadgeProduit.stockFaible),
            BadgeProduitWidget(BadgeProduit.rupture),
          ]));
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.text('Stock faible'), findsOneWidget);
      expect(find.text('Rupture'), findsOneWidget);
    });
  });

  group('ProductCard', () {
    testWidgets('rupture : badge + Vendre désactivé', (tester) async {
      await _pomper(
          tester, ProductCard(produit: _p('a', 'Câble', stock: 0)));
      expect(find.text('Rupture'), findsOneWidget);
      final bouton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Vendre'));
      expect(bouton.onPressed, isNull);
    });

    testWidgets('stock faible + nouveau : 2 badges', (tester) async {
      await _pomper(
          tester,
          ProductCard(
              produit: _p('a', 'Câble',
                  stock: 2,
                  seuil: 3,
                  dateAjout: DateTime.now()
                      .subtract(const Duration(days: 1)))));
      expect(find.text('Stock faible'), findsOneWidget);
      expect(find.text('Nouveau'), findsOneWidget);
    });

    testWidgets('prix vente + stock affichés, menu ⋮ présent',
        (tester) async {
      String? action;
      await _pomper(
          tester,
          ProductCard(
              produit: _p('a', 'Câble'),
              onMenu: (a) => action = a));
      expect(find.textContaining('000'), findsWidgets);
      expect(find.textContaining('Stock : 10'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(action, 'modifier');
    });
  });

  group('ProductGrid colonnes', () {
    test('2 / 3 / 4 selon largeur', () {
      expect(ProductGrid.colonnesPour(360), 2);
      expect(ProductGrid.colonnesPour(700), 3);
      expect(ProductGrid.colonnesPour(1200), 4);
    });

    testWidgets('grille rend 2 cartes', (tester) async {
      await _pomper(
          tester,
          ProductGrid(
              produits: [_p('a', 'A'), _p('b', 'B')]));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('StockScreen refondu', () {
    testWidgets('grille + bascule liste', (tester) async {
      await _pomper(tester, const StockScreen());
      expect(find.byType(ProductGrid), findsOneWidget);
      await tester.tap(find.byTooltip('Vue liste'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductGrid), findsNothing);
    });

    testWidgets('recherche as-you-type filtre', (tester) async {
      await _pomper(tester, const StockScreen());
      await tester.enterText(
          find.widgetWithText(TextField, 'Rechercher un produit…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun produit pour ces filtres'),
          findsOneWidget);
    });

    testWidgets('bandeau valorisation présent', (tester) async {
      await _pomper(tester, const StockScreen());
      expect(find.text('Valorisation du stock'), findsOneWidget);
    });
  });
}
