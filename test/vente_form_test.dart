import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';
import 'package:pme_gestion_pro/screens/journal/journal_screen.dart';
import 'package:pme_gestion_pro/screens/transaction/nouvelle_transaction_screen.dart';

/// Point 24 — audit formulaire de vente : remise, mode de paiement,
/// validations, calcul net = brut − remise.
Tx _tx(Map<String, dynamic> details, {double montant = 9000}) => Tx(
      id: 't1',
      boutiqueId: 'bt_siege',
      employeId: 'u',
      type: TypeTransaction.prestationService,
      montant: montant,
      date: DateTime(2026, 9, 26, 10, 0),
      details: details,
    );

Future<void> _pomperForm(WidgetTester tester, Store store) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: const MaterialApp(
        home: NouvelleTransactionScreen(
            type: TypeTransaction.prestationService),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _choisirDomaine(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Informatique').last);
  await tester.pumpAndSettle();
}

void main() {
  group('Formulaire de vente (point 24)', () {
    test('suffixesVente : vide pour ventes antérieures', () {
      expect(suffixesVente(_tx(const {})), '');
      expect(
          suffixesVente(_tx({
            'domaine': 'Informatique',
            'modePaiement': '',
          })),
          '');
    });

    test('suffixesVente : remise + brut + mode', () {
      expect(
          suffixesVente(_tx({
            'montantBrut': 10000.0,
            'remise': 1000.0,
            'modePaiement': 'especes',
          })),
          ' · remise 1000 (brut 10000) · Espèces');
    });

    test('libelleMode : 4 codes + repli brut', () {
      expect(
          NouvelleTransactionScreen.libelleMode('especes'),
          'Espèces');
      expect(
          NouvelleTransactionScreen.libelleMode('virement'),
          'Virement');
      expect(NouvelleTransactionScreen.libelleMode('xxx'), 'xxx');
    });

    testWidgets('champs remise + paiement présents', (tester) async {
      final store = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      await _pomperForm(tester, store);
      expect(find.text('Remise accordée (optionnel)'), findsOneWidget);
      expect(find.text('Mode de paiement'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('remise >= montant refusée, rien enregistré',
        (tester) async {
      final store = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      await _pomperForm(tester, store);
      await _choisirDomaine(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Montant (FCFA)'),
          '10000');
      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Remise accordée (optionnel)'),
          '15000');
      await tester.pumpAndSettle();
      final avant = store.transactions.length;
      await tester.tap(find.text('Valider la vente'));
      await tester.pumpAndSettle();
      expect(
          find.text('⚠️ La remise doit être inférieure au montant'),
          findsOneWidget);
      expect(store.transactions.length, avant);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('remise valide → net + détails persistés',
        (tester) async {
      final store = Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin));
      await _pomperForm(tester, store);
      await _choisirDomaine(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Montant (FCFA)'),
          '10000');
      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Remise accordée (optionnel)'),
          '1000');
      await tester.pumpAndSettle();
      final avant = store.transactions.length;
      await tester.tap(find.text('Valider la vente'));
      await tester.pumpAndSettle();
      expect(store.transactions.length, avant + 1);
      final tx = store.transactions.first;
      expect(tx.montant, 9000.0);
      expect(tx.details['remise'], 1000.0);
      expect(tx.details['montantBrut'], 10000.0);
      expect(tx.details['modePaiement'], 'especes');
      expect(
          suffixesVente(tx),
          ' · remise 1000 (brut 10000) · Espèces');
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
