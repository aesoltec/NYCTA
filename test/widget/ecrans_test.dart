import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/achat/achat_list_screen.dart';
import 'package:pme_gestion_pro/screens/charges/charges_screen.dart';
import 'package:pme_gestion_pro/screens/collab/messagerie_screen.dart';
import 'package:pme_gestion_pro/screens/dashboard/dashboard_screen.dart';
import 'package:pme_gestion_pro/screens/admin/boutiques_screen.dart';
import 'package:pme_gestion_pro/screens/admin/categories_screen.dart';
import 'package:pme_gestion_pro/screens/documents/documents_history_screen.dart';
import 'package:pme_gestion_pro/screens/documents/documents_screen.dart';
import 'package:pme_gestion_pro/screens/journal/journal_screen.dart';
import 'package:pme_gestion_pro/screens/rapports/analytique_screen.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';

/// Tests widget par écran critique (mission §A1) : rendu sans exception
/// + interaction principale. Les onglets (corps sans Scaffold) sont
/// montés dans un Scaffold comme AppShell.
Widget _hote(Widget enfant) {
  final store = Store(
      const AppUser(id: 'u', nom: 'Test', role: Role.admin));
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: Scaffold(body: enfant)),
  );
}

Future<void> _pomper(WidgetTester tester, Widget enfant) async {
  // Grande surface : les ListView construisent tout (pas de lazy-build).
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_hote(enfant));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  // Laisse le timer de persistance (600 ms) s'écouler avant dispose.
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('Écrans critiques (rendu + interaction)', () {
    testWidgets('Dashboard : tuiles Achats et Dépenses', (tester) async {
      await _pomper(tester, const DashboardScreen());
      expect(find.text('Nouvelle opération'), findsOneWidget);
      expect(find.text('Achats fournisseurs'), findsOneWidget);
      expect(find.text('Dépenses du mois'), findsOneWidget);
    });

    testWidgets('Journal : recherche filtre', (tester) async {
      await _pomper(tester, const JournalScreen());
      await tester.enterText(
          find.widgetWithText(TextField, 'Rechercher un client…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucune transaction'), findsOneWidget);
    });

    testWidgets('Journal : filtres date + menu export', (tester) async {
      await _pomper(tester, const JournalScreen());
      expect(find.text('Début (optionnel)'), findsOneWidget);
      expect(find.text('Fin (optionnel)'), findsOneWidget);
      expect(
          find.byTooltip('Exporter la vue filtrée'), findsOneWidget);
    });

    testWidgets('Stock : liste + valorisation', (tester) async {
      await _pomper(tester, const StockScreen());
      expect(find.text('Valorisation du stock'), findsOneWidget);
      expect(find.text('Mouvements'), findsOneWidget);
    });

    testWidgets('Stock : recherche + catégorie + export', (tester) async {
      await _pomper(tester, const StockScreen());
      await tester.enterText(
          find.widgetWithText(TextField, 'Rechercher un produit…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun produit dans cette boutique'),
          findsOneWidget);
      expect(
          find.byTooltip('Exporter la liste filtrée'), findsOneWidget);
    });

    testWidgets('Charges : résumé du mois', (tester) async {
      await _pomper(tester, const ChargesScreen());
      expect(find.textContaining('Dépenses du mois'), findsOneWidget);
      expect(find.text('Toutes catégories'), findsOneWidget);
    });

    testWidgets('Messagerie : écran complet', (tester) async {
      await _pomper(tester, const MessagerieScreen());
      expect(find.text('Messagerie interne'), findsOneWidget);
      expect(
          find.text('Aucun message').evaluate().isNotEmpty ||
              find.byType(ListView).evaluate().isNotEmpty,
          isTrue);
    });

    testWidgets('Documents : 5 types proposés', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
          value: Store(const AppUser(
              id: 'u', nom: 'Test', role: Role.admin)),
          child: const DocumentsScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('FACTURE'), findsOneWidget);
      expect(find.text('BORDEREAU DE LIVRAISON'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Achats : liste vide + filtres', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
          value: Store(const AppUser(
              id: 'u', nom: 'Test', role: Role.admin)),
          child: const AchatListScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Achats fournisseurs'), findsOneWidget);
      expect(find.byTooltip('Exporter (vue filtrée ou tout)'),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Documents émis : filtres + état vide sans overflow', (tester) async {
      await _pomper(tester, const DocumentsHistoryScreen());
      expect(find.text('Documents émis'), findsOneWidget);
      expect(
          find.widgetWithText(TextField, 'Rechercher (client, numéro)…'),
          findsOneWidget);
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Début'), findsOneWidget);
      expect(find.text('Aucun document émis'), findsOneWidget);
    });

    testWidgets('Documents émis : rendu étroit 360px sans overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_hote(const DocumentsHistoryScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Boutiques : recherche + filtres statut/siège',
        (tester) async {
      await _pomper(tester, const BoutiquesScreen());
      expect(find.text('Boutiques'), findsOneWidget);
      expect(
          find.widgetWithText(
              TextField, 'Rechercher (nom, adresse)…'),
          findsOneWidget);
      expect(find.text('Actives'), findsOneWidget);
      expect(find.text('Siège + annexes'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Rechercher (nom, adresse)…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucune boutique (filtre sans résultat)'),
          findsOneWidget);
    });

    testWidgets('Catégories : recherche par nom (onglet type)',
        (tester) async {
      await _pomper(tester, const CategoriesScreen());
      expect(find.text('Catégories'), findsOneWidget);
      // Onglets = filtre par type (Produits / Charges).
      expect(find.text('Produits'), findsOneWidget);
      expect(
          find.widgetWithText(
              TextField, 'Rechercher une catégorie…'),
          findsOneWidget);
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Rechercher une catégorie…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucune catégorie (filtre sans résultat)'),
          findsOneWidget);
    });

    testWidgets('Analytique : onglets CA et Dépenses', (tester) async {      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
          value: Store(const AppUser(
              id: 'u', nom: 'Test', role: Role.admin)),
          child: const AnalytiqueScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Dépenses'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
