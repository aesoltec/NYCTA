import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/tarifs/tarifs_screen.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/categorie_tree.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_card.dart';

/// Phase 2 — refonte UX e-commerce Tarifs : carte, arbre, écran.
Tarif _t(String id, String libelle,
        {String categorie = 'Info',
        double prix = 10000,
        DateTime? dateAjout}) =>
    Tarif(
        id: id,
        libelle: libelle,
        categorie: categorie,
        prix: prix,
        dateAjout: dateAjout);

Widget _hote(Widget enfant) {
  final store =
      Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: Scaffold(body: enfant)),
  );
}

Future<void> _pomper(WidgetTester tester, Widget enfant) async {
  tester.view.physicalSize = const Size(900, 1400);
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
  group('Tarif.nouveau', () {
    test('badge < 7 jours uniquement', () {
      expect(
          _t('a', 'A',
                  dateAjout:
                      DateTime.now().subtract(const Duration(days: 3)))
              .nouveau,
          isTrue);
      expect(_t('a', 'A').nouveau, isFalse);
    });
  });

  group('TarifCard', () {
    testWidgets('badge Nouveau + prix + bouton', (tester) async {
      await _pomper(
          tester,
          TarifCard(
              tarif: _t('a', 'Installation',
                  dateAjout: DateTime.now()
                      .subtract(const Duration(days: 1)))));
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.text('Installation'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Utiliser dans vente'),
          findsOneWidget);
    });

    testWidgets('sans date : pas de badge', (tester) async {
      await _pomper(tester, TarifCard(tarif: _t('a', 'Vieux')));
      expect(find.text('Nouveau'), findsNothing);
    });

    testWidgets('menu désactiver', (tester) async {
      String? action;
      await _pomper(
          tester,
          TarifCard(
              tarif: _t('a', 'A'), onMenu: (a) => action = a));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Désactiver'));
      await tester.pumpAndSettle();
      expect(action, 'desactiver');
    });
  });

  group('CategorieTree', () {
    testWidgets('compteurs + sélection', (tester) async {
      String? sel;
      await _pomper(
          tester,
          CategorieTree(
              compteurs: const {'Info': 2, 'Elec': 1},
              selection: '',
              onSelection: (c) => sel = c));
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Elec'));
      await tester.pumpAndSettle();
      expect(sel, 'Elec');
    });
  });

  group('TarifsScreen refondu', () {
    Future<void> pomperAvecTarifs(WidgetTester tester) async {
      final store = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      await store.ajouterTarif(Tarif(
          id: 'x',
          libelle: 'Installation caméra',
          categorie: 'Info',
          prix: 25000,
          dateAjout:
              DateTime.now().subtract(const Duration(days: 1))));
      await store.ajouterTarif(const Tarif(
          id: 'y',
          libelle: 'Dépannage',
          categorie: 'Elec',
          prix: 5000));
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store,
        child:
            const MaterialApp(home: Scaffold(body: TarifsScreen())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('grille + recherche filtre', (tester) async {
      await pomperAvecTarifs(tester);
      expect(find.byType(TarifCard), findsNWidgets(2));
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Rechercher un article…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun article (filtre sans résultat)'),
          findsOneWidget);
    });

    testWidgets('arbre catégories présent en large', (tester) async {
      await pomperAvecTarifs(tester);
      expect(find.byType(CategorieTree), findsOneWidget);
      expect(find.text('Info'), findsWidgets);
    });
  });
}
