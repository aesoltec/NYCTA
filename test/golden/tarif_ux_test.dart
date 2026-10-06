import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/screens/tarifs/widgets/tarif_card.dart';
import 'package:pme_gestion_pro/widgets/carte_grille.dart';

/// Golden de la grille ARTICLES, sur la meme geometrie que l'ecran
/// Tarifs : deux colonnes, hauteur fixe.
///
/// Ce golden existait pas : la carte article n'etait verifiee qu'isolée,
/// jamais dans sa grille — c'est-a-dire jamais dans la disposition reelle.
/// Les libelles ci-dessous ont volontairement des longueurs tres
/// differentes : c'est precisement ce qui faisait varier les hauteurs.
Tarif _t(String id, String libelle, {double prix = 5000}) => Tarif(
      id: id,
      libelle: libelle,
      prix: prix,
      categorie: 'Service',
    );

Future<void> _cadre(
    WidgetTester tester, Widget enfant, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: Store(const AppUser(id: 'u', nom: 'T', role: Role.admin)),
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
  group('Goldens UX Articles', () {
    testWidgets('grille 2 colonnes 360px', (tester) async {
      await _cadre(
          tester,
          Builder(builder: (context) {
            final tarifs = [
              _t('a', 'Forfait'),
              _t('b',
                  'Installation et configuration d\'un reseau intranet pour la societe',
                  prix: 80000),
              _t('c', 'Maintenance mensuelle du parc informatique', prix: 15000),
              _t('d', 'Depannage', prix: 5000),
            ];
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: CarteGrille.hauteur(context,
                    texte: CarteGrille.texteArticle),
              ),
              itemCount: tarifs.length,
              itemBuilder: (_, i) => TarifCard(
                  tarif: tarifs[i], onUtiliser: () {}),
            );
          }),
          const Size(360, 800));
      await expectLater(
          find.byType(GridView), matchesGoldenFile('goldens/tarif_grid_360.png'));
    });
  });
}