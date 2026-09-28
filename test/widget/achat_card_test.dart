import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/achat/achat_detail_screen.dart';
import 'package:pme_gestion_pro/screens/achat/achat_list_screen.dart';
import 'package:pme_gestion_pro/screens/achat/widgets/achat_card.dart';
import 'package:pme_gestion_pro/screens/achat/widgets/ligne_achat_card.dart';

/// Phase 3 — refonte UX e-commerce Achats : cartes, liste, détail.
Achat _a(String id, String numero,
        {String statut = Achat.statutEnAttente,
        double paye = 0}) =>
    Achat(
        id: id,
        numero: numero,
        boutiqueId: 'bt_siege',
        fournisseurNom: 'ETS Test',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble', quantite: 2, prixUnitaire: 1000),
          LigneAchat(
              produitNom: 'Prise', quantite: 1, prixUnitaire: 500),
        ],
        date: DateTime(2026, 9, 5),
        statut: statut,
        montantPaye: paye,
        createdBy: 'u',
        createdAt: DateTime(2026, 9, 5));

Future<Store> _storeAvecAchats() async {
  final s =
      Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
  s.achats.add(_a('a1', 'ACH-2026-00001'));
  s.achats.add(_a('a2', 'ACH-2026-00002',
      statut: Achat.statutAnnule));
  return s;
}

Future<void> _pomper(
    WidgetTester tester, Widget enfant, Store store,
    {Size taille = const Size(800, 1400)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: Scaffold(body: enfant)),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('AchatCard.libelleStatut', () {
    test('5 statuts libellés', () {
      expect(AchatCard.libelleStatut(Achat.statutDemande), 'DEMANDE');
      expect(
          AchatCard.libelleStatut(Achat.statutEnAttente), 'EN ATTENTE');
      expect(AchatCard.libelleStatut(Achat.statutValide), 'VALIDÉ');
      expect(AchatCard.libelleStatut(Achat.statutRecu), 'REÇU');
      expect(AchatCard.libelleStatut(Achat.statutAnnule), 'ANNULÉ');
    });
  });

  group('LigneAchatCard', () {
    testWidgets('libellé + qté + sous-total', (tester) async {
      final s = await _storeAvecAchats();
      await _pomper(
          tester,
          const LigneAchatCard(
              ligne: LigneAchat(
                  produitNom: 'Câble',
                  quantite: 2,
                  prixUnitaire: 1000)),
          s);
      expect(find.text('Câble'), findsOneWidget);
      expect(find.textContaining('000'), findsWidgets);
    });
  });

  group('AchatCard', () {
    testWidgets('en-tête + lignes + totaux + actions', (tester) async {
      final s = await _storeAvecAchats();
      var vu = false;
      await _pomper(
          tester, AchatCard(achat: _a('a1', 'ACH-2026-00001'), onVoir: () => vu = true), s);
      expect(find.text('ACH-2026-00001'), findsOneWidget);
      expect(find.text('EN ATTENTE'), findsOneWidget);
      expect(find.text('Câble'), findsOneWidget);
      await tester.tap(find.text('Détails'));
      await tester.pumpAndSettle();
      expect(vu, isTrue);
    });

    testWidgets('annulé : pas de bouton Payer', (tester) async {
      final s = await _storeAvecAchats();
      await _pomper(
          tester,
          AchatCard(
              achat: _a('a2', 'ACH-2',
                  statut: Achat.statutAnnule),
              onVoir: () {},
              onPayer: () {},
              onAnnuler: () {}),
          s);
      expect(find.text('Payer'), findsNothing);
      expect(find.text('ANNULÉ'), findsOneWidget);
    });
  });

  group('AchatListScreen refondu', () {
    testWidgets('cartes + recherche filtre', (tester) async {
      final s = await _storeAvecAchats();
      await _pomper(tester, const AchatListScreen(), s);
      expect(find.byType(AchatCard), findsNWidgets(2));
      await tester.enterText(
          find.widgetWithText(
              TextField, 'Rechercher (n°, fournisseur)…'),
          'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.byType(AchatCard), findsNothing);
    });

    testWidgets('bascule grille', (tester) async {
      final s = await _storeAvecAchats();
      await _pomper(tester, const AchatListScreen(), s);
      await tester.tap(find.byTooltip('Vue grille'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('AchatDetailScreen enrichi', () {
    testWidgets('en-tête + lignes + historique', (tester) async {
      final s = await _storeAvecAchats();
      await _pomper(tester, const AchatDetailScreen(achatId: 'a1'), s);
      expect(find.text('ACH-2026-00001'), findsWidgets);
      expect(find.text('Câble'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.textContaining('Demande créée'), findsOneWidget);
    });
  });
}
