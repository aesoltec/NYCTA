import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/widgets/filtre_panel.dart';

/// Point 25bis — FiltrePanel testé une fois, réutilisé partout.
Future<void> _pomper(
    WidgetTester tester, FiltrePanel panel, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: panel))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  group('FiltrePanel (25bis)', () {
    testWidgets('rendu 5 kinds + callbacks recherche/chips/dropdown',
        (tester) async {
      Map<String, dynamic>? recues;
      await _pomper(
          tester,
          FiltrePanel(
            filtres: const [
              FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher…'),
              FiltreConfig(
                  cle: 'statut',
                  kind: FiltreKind.chips,
                  label: 'Statut',
                  options: [
                    ('tous', 'Tous'),
                    ('recu', 'Reçus'),
                  ]),
              FiltreConfig(
                  cle: 'cat',
                  kind: FiltreKind.dropdown,
                  label: 'Catégorie',
                  options: [
                    ('a', 'A'),
                    ('b', 'B'),
                  ]),
              FiltreConfig(
                  cle: '', kind: FiltreKind.dates, label: ''),
              FiltreConfig(
                  cle: '', kind: FiltreKind.minMax, label: ''),
            ],
            onFiltreChange: (m) => recues = m,
          ),
          const Size(800, 2400));

      // Recherche.
      await tester.enterText(
          find.widgetWithText(TextField, 'Rechercher…'), 'café');
      await tester.pumpAndSettle();
      expect(recues?['q'], 'café');

      // Chips.
      await tester.tap(find.text('Reçus'));
      await tester.pumpAndSettle();
      expect(recues?['statut'], 'recu');

      // Dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      expect(recues?['cat'], 'b');

      // Dates + min/max rendus.
      expect(find.text('Début'), findsOneWidget);
      expect(find.text('Fin'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('étroit 360px sans overflow', (tester) async {
      await _pomper(
          tester,
          FiltrePanel(
            filtres: const [
              FiltreConfig(
                  cle: '', kind: FiltreKind.dates, label: ''),
              FiltreConfig(
                  cle: '', kind: FiltreKind.minMax, label: ''),
            ],
            onFiltreChange: (_) {},
          ),
          const Size(360, 800));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('clés dates/minMax préfixées', (tester) async {
      Map<String, dynamic>? recues;
      await _pomper(
          tester,
          FiltrePanel(
            filtres: const [
              FiltreConfig(
                  cle: 'p', kind: FiltreKind.minMax, label: ''),
            ],
            onFiltreChange: (m) => recues = m,
          ),
          const Size(800, 2400));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Min'), '10');
      await tester.pumpAndSettle();
      expect(recues?['p_min'], '10');
    });
  });
}
