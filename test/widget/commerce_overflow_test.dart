import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/achat/widgets/achat_card.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_grid.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_card.dart';

/// Anti-overflow (refonte UX) : cartes Stock/Tarifs/Achats sur
/// 320/360/768/1024px × TextScaler 1.0/1.5/2.0 — aucun RenderFlex.
void main() {
  group('Anti-overflow UX e-commerce', () {
    final produits = [
      Produit(
          id: 'a',
          boutiqueId: 'b1',
          libelle: 'Câble RJ45 (305m) blindé extérieur',
          categorie: 'Télécom & Réseau',
          prixAchat: 18000,
          prixVente: 25000,
          stock: 0,
          seuil: 3,
          dateAjout:
              DateTime.now().subtract(const Duration(days: 1))),
      Produit(
          id: 'b',
          boutiqueId: 'b1',
          libelle: 'Disjoncteur 32A',
          categorie: 'Électricité',
          prixAchat: 2500,
          prixVente: 4000,
          stock: 2,
          seuil: 5),
    ];
    final tarif = Tarif(
        id: 't',
        libelle: 'Installation caméra IP avec câblage complet',
        categorie: 'Vidéosurveillance',
        prix: 25000,
        dateAjout:
            DateTime.now().subtract(const Duration(days: 1)));
    final achat = Achat(
        id: 'a1',
        numero: 'ACH-2026-00001',
        boutiqueId: 'b1',
        fournisseurNom: 'ETS Fournisseur Test Long Nom',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble RJ45',
              quantite: 10,
              prixUnitaire: 1800),
          LigneAchat(
              produitNom: 'Connecteurs',
              quantite: 50,
              prixUnitaire: 200),
          LigneAchat(
              produitNom: 'Goulottes', quantite: 5, prixUnitaire: 1500),
          LigneAchat(
              produitNom: 'Visserie', quantite: 2, prixUnitaire: 750),
        ],
        date: DateTime(2026, 9, 5),
        createdBy: 'u',
        createdAt: DateTime(2026, 9, 5));

    for (final largeur in [320.0, 360.0, 768.0, 1024.0]) {
      for (final echelle in [1.0, 1.5, 2.0]) {
        testWidgets('grille $largeur px × $echelle', (tester) async {
          tester.view.physicalSize = Size(largeur, 900);
          tester.view.devicePixelRatio = 1.0;
          tester.view.platformDispatcher.textScaleFactorTestValue =
              echelle;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.platformDispatcher
                .clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(
              ChangeNotifierProvider.value(
            value: Store(
                const AppUser(id: 'u', nom: 'T', role: Role.admin)),
            child: MaterialApp(
                home: Scaffold(
                    body: SizedBox(
                        width: largeur,
                        child: ProductGrid(produits: produits)))),
          ));
          // Pas de pumpAndSettle : le shimmer anime en continu.
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await tester.pump(
              const Duration(milliseconds: 700));
        });

        testWidgets('tarif+achat $largeur px × $echelle',
            (tester) async {
          tester.view.physicalSize = Size(largeur, 1200);
          tester.view.devicePixelRatio = 1.0;
          tester.view.platformDispatcher.textScaleFactorTestValue =
              echelle;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.platformDispatcher
                .clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(
              ChangeNotifierProvider.value(
            value: Store(
                const AppUser(id: 'u', nom: 'T', role: Role.admin)),
            child: MaterialApp(
                home: Scaffold(
                    body: ListView(children: [
              SizedBox(width: 180, child: TarifCard(tarif: tarif)),
              AchatCard(achat: achat),
            ])))),
          );
          // Pas de pumpAndSettle : le shimmer anime en continu.
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await tester.pump(
              const Duration(milliseconds: 700));
        });
      }
    }
  });
}
