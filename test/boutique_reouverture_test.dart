import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/admin/boutiques_screen.dart';

/// Point 22bis — réouverture boutique (garde locale testable sans RPC).
void main() {
  group('Réouverture boutique (22bis)', () {
    test('vendeur : refusé (garde locale)', () async {
      final s = Store(
          const AppUser(id: 'u', nom: 'V', role: Role.vendeur));
      final err = await s.rouvrirBoutique('bt_marche');
      expect(err, contains('Réouverture réservée'));
    });

    test('admin : boutique déjà active → refus', () async {
      final s = Store(
          const AppUser(id: 'u', nom: 'A', role: Role.admin));
      final err = await s.rouvrirBoutique('bt_siege');
      expect(err, 'Boutique déjà active');
    });

    test('admin : boutique introuvable → refus', () async {
      final s = Store(
          const AppUser(id: 'u', nom: 'A', role: Role.admin));
      final err = await s.rouvrirBoutique('bt_inconnue');
      expect(err, 'Boutique introuvable');
    });

    testWidgets('bouton Réouvrir visible admin, caché vendeur',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // Admin : ferme d'abord une boutique, puis vérifie le bouton.
      final s = Store(
          const AppUser(id: 'u', nom: 'A', role: Role.admin));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: s,
          child: const MaterialApp(home: BoutiquesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(await s.fermerBoutique('bt_marche'), isNull);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermées'));
      await tester.pumpAndSettle();
      // La carte fermée porte le badge FERMÉE ; le bouton Réouvrir est
      // dans son trailing (visible sans scroll : 1 seule boutique fermée).
      expect(find.text('FERMÉE'), findsOneWidget);
      expect(find.byTooltip('Réouvrir cette boutique'),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
