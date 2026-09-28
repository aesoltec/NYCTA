import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/achat/widgets/achat_card.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_card.dart';

/// Goldens Phases 2-3 : carte tarif + carte commande.
/// Génération : `flutter test test/golden/commerce_ux_test.dart --update-goldens`.
Future<void> _cadre(
    WidgetTester tester, Widget enfant, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value:
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin)),
      child: MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: taille.width,
                  height: taille.height,
                  child: enfant)))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('Goldens UX Tarifs/Achats', () {
    testWidgets('carte tarif nouveau', (tester) async {
      await _cadre(
          tester,
          Center(
              child: SizedBox(
                  width: 180,
                  child: TarifCard(
                      tarif: Tarif(
                          id: 't',
                          libelle: 'Installation caméra IP',
                          categorie: 'Vidéosurveillance',
                          prix: 25000,
                          dateAjout: DateTime.now().subtract(
                              const Duration(days: 1)))))),
          const Size(360, 640));
      await expectLater(
          find.byType(TarifCard),
          matchesGoldenFile('goldens/tarif_card_nouveau.png'));
    });

    testWidgets('carte commande', (tester) async {
      await _cadre(
          tester,
          Center(
              child: SizedBox(
                  width: 340,
                  child: AchatCard(
                      achat: Achat(
                          id: 'a1',
                          numero: 'ACH-2026-00001',
                          boutiqueId: 'b1',
                          fournisseurNom: 'ETS Test',
                          lignes: const [
                        LigneAchat(
                            produitNom: 'Câble',
                            quantite: 2,
                            prixUnitaire: 1000),
                      ],
                          date: DateTime(2026, 9, 5),
                          createdBy: 'u',
                          createdAt: DateTime(2026, 9, 5))))),
          const Size(400, 700));
      await expectLater(
          find.byType(AchatCard),
          matchesGoldenFile('goldens/achat_card.png'));
    });
  });
}
