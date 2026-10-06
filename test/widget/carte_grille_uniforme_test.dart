import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_card.dart';
import 'package:pme_gestion_pro/screens/stock/widgets/product_grid.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_card.dart';
import 'package:pme_gestion_pro/widgets/carte_grille.dart';

/// Les cartes de produits et d'articles doivent avoir une taille
/// UNIFORME, quel que soit le libellé.
///
/// Le défaut : titre sur 1 ou 2 lignes dans une grille « masonry », qui
/// empile les hauteurs par construction. Résultat : des cartes de
/// tailles différentes dans la même rangée.
void main() {
  Store _store() =>
      Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

  // Longueurs très différentes : c'est ce qui faisait varier la hauteur.
  const libellesCourt = 'Câble';
  const libellesLong =
      'Installation et configuration d\'un reseau intranet pour la '
      'societe';
  const libellesMoyen = 'Forfait telephonie';

  List<Produit> _produits() => [
        Produit(
            id: 'p1',
            boutiqueId: 'b1',
            libelle: libellesCourt,
            categorie: 'Reseau',
            prixAchat: 1000,
            prixVente: 1500,
            stock: 12),
        Produit(
            id: 'p2',
            boutiqueId: 'b1',
            libelle: libellesLong,
            categorie: 'Installation',
            prixAchat: 50000,
            prixVente: 80000,
            stock: 1),
        Produit(
            id: 'p3',
            boutiqueId: 'b1',
            libelle: libellesMoyen,
            categorie: 'Telephonie',
            prixAchat: 100,
            prixVente: 200,
            stock: 40),
      ];

  List<Tarif> _tarifs() => [
        Tarif(id: 't1', libelle: libellesCourt, prix: 1500, categorie: 'Reseau'),
        Tarif(
            id: 't2',
            libelle: libellesLong,
            prix: 80000,
            categorie: 'Installation'),
        Tarif(
            id: 't3',
            libelle: libellesMoyen,
            prix: 200,
            categorie: 'Telephonie'),
      ];

  Future<void> _hote(WidgetTester tester, Widget enfant, double largeur,
      {double scaler = 1.0}) async {
    tester.view.physicalSize = Size(largeur, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = _store();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<Store>.value(
        value: store,
        child: MaterialApp(
          home: MediaQuery(
            // `MediaQuery.of` exigerait un widget deja monte : on
            // construit donc les donnees directement.
            data: MediaQueryData(textScaler: TextScaler.linear(scaler)),
            child: Scaffold(body: enfant),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
  }

  group('cartes PRODUIT : taille uniforme', () {
    for (final largeur in [320.0, 360.0, 768.0]) {
      testWidgets('360 px de large, libell\u00e9s de longueurs diff\u00e9rentes',
          (tester) async {
        await _hote(
            tester, ProductGrid(produits: _produits()), largeur);
        final f = find.byType(ProductCard);
        final tailles = [
          for (var i = 0; i < f.evaluate().length; i++)
            tester.getSize(f.at(i)).height,
        ];
        expect(tailles.length, 3);
        expect(tailles.toSet().length, 1,
            reason: 'les $largeur px : hauteurs $tailles — les cartes '
                'doivent etre identiques');
      });
    }

    testWidgets('uniforme au TextScaler 1.5 et 2.0', (tester) async {
      for (final s in [1.5, 2.0]) {
        await _hote(tester, ProductGrid(produits: _produits()), 360, scaler: s);
        final f = find.byType(ProductCard);
        final tailles = [
          for (var i = 0; i < f.evaluate().length; i++)
            tester.getSize(f.at(i)).height,
        ];
        expect(tailles.toSet().length, 1, reason: 'TextScaler $s : $tailles');
        expect(tester.takeException(), isNull,
            reason: 'aucun debordement a l\u00e9chelle $s');
      }
    });
  });

  group('cartes ARTICLE : taille uniforme', () {
    Future<void> grille(WidgetTester tester, double largeur,
        {double scaler = 1.0}) =>
        _hote(
          tester,
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: CarteGrille.hauteurPour(
                scaler,
                texte: CarteGrille.texteArticle,
              ),
            ),
            itemCount: _tarifs().length,
            itemBuilder: (_, i) => TarifCard(
                tarif: _tarifs()[i], onUtiliser: () {}),
          ),
          largeur,
          scaler: scaler,
        );

    for (final largeur in [320.0, 360.0, 768.0]) {
      testWidgets('libellés de longueurs différentes', (tester) async {
        await grille(tester, largeur);
        final f = find.byType(TarifCard);
        final tailles = [
          for (var i = 0; i < f.evaluate().length; i++)
            tester.getSize(f.at(i)).height,
        ];
        expect(tailles.length, 3);
        expect(tailles.toSet().length, 1,
            reason: 'les $largeur px : hauteurs $tailles');
      });
    }

    testWidgets('uniforme et sans débordement au TextScaler 2.0',
        (tester) async {
      await grille(tester, 320, scaler: 2.0);
      final f = find.byType(TarifCard);
      final tailles = [
        for (var i = 0; i < f.evaluate().length; i++)
          tester.getSize(f.at(i)).height,
      ];
      expect(tailles.toSet().length, 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('le titre occupe toujours deux lignes : un libellé court '
      'ne rend pas la carte plus basse', (tester) async {
    await _hote(tester, ProductGrid(produits: _produits()), 360);
    final b = find.byType(TitreCarte);
    expect(b, findsNWidgets(3));
    final hauteurs = [
      for (var i = 0; i < b.evaluate().length; i++)
        tester.getSize(b.at(i)).height,
    ];
    expect(hauteurs.toSet().length, 1,
        reason: 'le bloc titre est a hauteur fixe : $hauteurs');
  });
}