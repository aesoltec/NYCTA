import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/client.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/admin/clients_screen.dart';

/// Batch 2 (points 27-29) : recherche/filtre, champs étendus, persistance.
void main() {
  group('Clients (27-29)', () {
    test('fromJson rétrocompatible (anciennes sauvegardes)', () {
      final c = Client.fromJson({
        'id': 'cl1', 'boutique_id': 'bt_siege', 'nom': 'Ancien',
      });
      expect(c.telephone, '');
      expect(c.email, '');
      expect(c.rccm, '');
      expect(c.rib, '');
      expect(c.logoPath, isNull);
      expect(c.estPro, isFalse);
    });

    test('estPro = RCCM renseigné', () {
      const pro = Client(
          id: 'a', boutiqueId: 'b', nom: 'SARL', rccm: 'RCCM-1');
      const part = Client(id: 'c', boutiqueId: 'b', nom: 'Moussa');
      expect(pro.estPro, isTrue);
      expect(part.estPro, isFalse);
    });

    test('roundtrip toJson/fromJson champs étendus', () {
      const c = Client(
        id: 'cl9', boutiqueId: 'bt_siege', nom: 'SARL Test',
        telephone: '+22670000000', email: 'a@b.c', adresse: 'Ouaga',
        rccm: 'RCCM-9', rib: 'RIB-9', logoPath: '/tmp/logo.png',
      );
      final r = Client.fromJson(c.toJson());
      expect(r.email, 'a@b.c');
      expect(r.rccm, 'RCCM-9');
      expect(r.rib, 'RIB-9');
      expect(r.logoPath, '/tmp/logo.png');
    });

    test('ajouterClient persiste les champs étendus', () async {
      final s = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final err = await s.ajouterClient(const Client(
        id: 'nouveau', boutiqueId: 'bt_siege', nom: 'Client Etendu Test',
        email: 'e@f.g', rccm: 'RCCM-X', rib: 'RIB-X',
      ));
      expect(err, isNull);
      final trouve = s.clientsBoutique
          .where((c) => c.nom == 'Client Etendu Test')
          .toList();
      expect(trouve.length, 1);
      expect(trouve.first.email, 'e@f.g');
      expect(trouve.first.estPro, isTrue);
      final json = s.toJson();
      final lignes = (json['clients'] as List)
          .where((e) => (e as Map)['nom'] == 'Client Etendu Test')
          .toList();
      expect(lignes.length, 1);
      expect((lignes.first as Map)['rccm'], 'RCCM-X');
    });

    testWidgets('liste : recherche + filtre + export', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: Store(
              const AppUser(id: 'u', nom: 'T', role: Role.admin)),
          child: const MaterialApp(home: ClientsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Clients'), findsOneWidget);
      expect(
          find.widgetWithText(
              TextField, 'Rechercher (nom, téléphone, adresse)…'),
          findsOneWidget);
      expect(find.text('Professionnels'), findsOneWidget);
      expect(find.byTooltip('Exporter la vue filtrée'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Rechercher (nom, téléphone, adresse)…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun client (filtre sans résultat)'),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('formulaire : champs étendus présents', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: Store(
              const AppUser(id: 'u', nom: 'T', role: Role.admin)),
          child: const MaterialApp(home: ClientsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Client'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau client'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Email (optionnel)'),
          findsOneWidget);
      expect(
          find.widgetWithText(
              TextFormField, 'RCCM (optionnel — professionnel)'),
          findsOneWidget);
      expect(
          find.widgetWithText(TextFormField,
              'RIB / coordonnées bancaires (optionnel)'),
          findsOneWidget);
      expect(find.text('Logo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
