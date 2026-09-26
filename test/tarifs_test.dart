import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/tarifs/tarifs_screen.dart';

/// Batch 4 (points 34-36) : filtres, catégorie connectée + anti-doublon,
/// galerie articles.
Store _store() =>
    Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

void main() {
  group('Tarifs (34-36)', () {
    test('sansAccents : É=E, ç=c, ü=u', () {
      expect(Store.sansAccents('Électricité'), 'Electricite');
      expect(Store.sansAccents('Ça coûte'), 'Ca coute');
      expect(Store.sansAccents('Réseaux & Télécom'),
          'Reseaux & Telecom');
    });

    test('memeCategorie : casse + accents', () {
      expect(
          Store.memeCategorie('Électricité', 'electricite'), isTrue);
      expect(Store.memeCategorie('Loyer', 'LOYER'), isTrue);
      expect(Store.memeCategorie('Loyer', 'Salaires'), isFalse);
    });

    test('ajouterCategorie refuse le doublon accentué', () async {
      final s = _store();
      expect(s.catsProduit.contains('Électricité'), isTrue);
      final err = await s.ajouterCategorie('electricite',
          produit: true);
      expect(err, contains('existe déjà'));
      expect(err, contains('Électricité'));
    });

    test('ajouterTarif refuse le doublon accentué', () async {
      final s = _store();
      expect(
          await s.ajouterTarif(const Tarif(
              id: 'x', libelle: 'Café Touba', prix: 500)),
          isNull);
      final err = await s.ajouterTarif(const Tarif(
          id: 'y', libelle: 'cafe touba', prix: 600));
      expect(err, contains('même nom'));
    });

    test('roundtrip images article', () async {
      final s = _store();
      final err = await s.ajouterTarif(const Tarif(
        id: 'nouveau', libelle: 'Article Photo Test', prix: 1500,
        images: ['u1.jpg', 'u2.jpg'],
      ));
      expect(err, isNull);
      final json = s.toJson();
      final lignes = (json['catalogue'] as List)
          .where(
              (e) => (e as Map)['libelle'] == 'Article Photo Test')
          .toList();
      expect(lignes.length, 1);
      expect((lignes.first as Map)['images'], ['u1.jpg', 'u2.jpg']);
    });

    testWidgets('liste : recherche + catégorie', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: _store(),
          child: const MaterialApp(home: TarifsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tarifs & catalogue'), findsOneWidget);
      expect(
          find.widgetWithText(
              TextField, 'Rechercher un article…'),
          findsOneWidget);
      expect(find.text('Catégorie'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('formulaire : catégorie connectée + images',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: _store(),
          child: const MaterialApp(home: TarifsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvel article au tarif'), findsOneWidget);
      expect(find.text('Catégorie'), findsWidgets);
      expect(find.textContaining('Images (0/5)'), findsOneWidget);
      // Suggestions : catégories du module + catalogue.
      await tester.enterText(
          find.widgetWithText(TextField, 'Catégorie'), 'Élec');
      await tester.pumpAndSettle();
      expect(find.text('Électricité'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
