import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/achat/achat_detail_screen.dart';
import 'package:pme_gestion_pro/screens/achat/achat_list_screen.dart';
import 'package:pme_gestion_pro/screens/achat/widgets/achat_card.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/produit_detail_screen.dart';
import 'package:pme_gestion_pro/screens/tarifs/tarifs_screen.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_detail_screen.dart';

/// Parcours UX e-commerce (Phases 1-3) : grille → tap → détail → action.
/// Exécutable sur émulateur (`flutter test integration_test`) et sur VM.
Future<void> _pomper(
    WidgetTester tester, Widget enfant, Store store) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: enfant),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stock : grille → détail → vendre', (tester) async {
    final s = Store(
        const AppUser(id: 'u', nom: 'T', role: Role.admin));
    await _pomper(tester, const StockScreen(), s);
    final avant =
        s.produits.firstWhere((p) => p.id == 'pr_1').stock;
    await tester.tap(find.text('Câble RJ45 (305m)').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProduitDetailScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Vendre'));
    await tester.pumpAndSettle();
    expect(
        s.produits.firstWhere((p) => p.id == 'pr_1').stock,
        avant - 1);
  });

  testWidgets('Tarifs : grille → détail', (tester) async {
    final s = Store(
        const AppUser(id: 'u', nom: 'T', role: Role.admin));
    await s.ajouterTarif(const Tarif(
        id: 'x', libelle: 'Article test', prix: 1000));
    await _pomper(tester, const TarifsScreen(), s);
    await tester.tap(find.text('Article test').first);
    await tester.pumpAndSettle();
    expect(find.byType(TarifDetailScreen), findsOneWidget);
  });

  testWidgets('Achats : liste → détail → historique', (tester) async {
    final s = Store(
        const AppUser(id: 'u', nom: 'T', role: Role.admin));
    s.achats.add(Achat(
        id: 'a1',
        numero: 'ACH-2026-00001',
        boutiqueId: s.boutiqueId,
        fournisseurNom: 'ETS Test',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble', quantite: 1, prixUnitaire: 1000),
        ],
        date: DateTime(2026, 9, 5),
        createdBy: 'u',
        createdAt: DateTime(2026, 9, 5)));
    await _pomper(tester, const AchatListScreen(), s);
    expect(find.byType(AchatCard), findsOneWidget);
    await tester.tap(find.text('ACH-2026-00001').first);
    await tester.pumpAndSettle();
    expect(find.byType(AchatDetailScreen), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });
}
