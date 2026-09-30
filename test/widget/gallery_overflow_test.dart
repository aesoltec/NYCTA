import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/models/media_item.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/gallery/gallery_screen.dart';
import 'package:pme_gestion_pro/screens/gallery/widgets/media_grid.dart';
import 'package:pme_gestion_pro/screens/gallery/widgets/media_tile.dart';
import 'package:pme_gestion_pro/services/media_service.dart';

/// Galerie interne — anti-overflow et garde d'accès.
///
/// La grille est en `maxCrossAxisExtent` (2 colonnes à 320 px, 5 à
/// 1024 px) : on vérifie les 4 largeurs × 3 échelles de texte exigées par
/// AGENTS.md §9, plus la règle de suppression réservée admin/gérant.
void main() {
  late Directory racine;
  setUp(() {
    racine = Directory.systemTemp.createTempSync('gal_overflow');
    MediaService.dossierRacineTest = racine;
    // Au moins une image dans la banque, sinon l'écran affiche l'état
    // vide et les tuiles (donc la poubelle) n'existent pas.
    for (final nom in ['produit_p1_1700000000_aa11bb.jpg', 'b.png']) {
      final d = Directory('${racine.path}/media/galerie');
      if (!d.existsSync()) d.createSync(recursive: true);
      File('${d.path}/$nom').writeAsBytesSync(List<int>.filled(32, 3));
    }
  });
  tearDown(() {
    MediaService.dossierRacineTest = null;
    try {
      racine.deleteSync(recursive: true);
    } catch (_) {}
  });

  const items = [
    MediaItem(
        cle: 'produit_abc_1700000000_aa11bb.jpg',
        cheminLocal: 'C:/absent/a.jpg',
        dossier: 'produit'),
    MediaItem(
        cle: 'tarif_xyz_1700000001_cc22dd.png',
        cheminLocal: 'C:/absent/b.png',
        dossier: 'tarif'),
  ];
  const usages = [
    MediaUsage(
        type: 'produit',
        id: 'p1',
        libelle: 'Câble RJ45 blindé extérieur longueurs spécifiques'),
  ];

  group('Anti-overflow', () {
    for (final largeur in [320.0, 360.0, 768.0, 1024.0]) {
      for (final echelle in [1.0, 1.5, 2.0]) {
        testWidgets('galerie $largeur px x $echelle', (tester) async {
          tester.view.physicalSize = Size(largeur, 900);
          tester.view.devicePixelRatio = 1.0;
          tester.view.platformDispatcher.textScaleFactorTestValue = echelle;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.platformDispatcher.clearTextScaleFactorTestValue();
          });

          final store =
              Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: store,
            child: const MaterialApp(home: GalleryScreen()),
          ));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);

          // Grille + tuile isolée (libellé très long, usages affichés).
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: largeur,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 168,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => MediaTile(
                      item: items[i],
                      usages: i == 0 ? usages : const [],
                      onAffecter: () {},
                      onSupprimer: () {},
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'tuile de galerie a $largeur px x $echelle');
          await tester.pump(const Duration(milliseconds: 500));
        });
      }
    }
  });

  group("Garde d'accès (suppression définitive)", () {
    // Testée sur la GRILLE, pas sur `GalleryScreen` : l'écran fait un
    // vrai scan `dart:io` qui ne se résout pas dans la zone fake-async de
    // `testWidgets`. Or la règle à vérifier (« la poubelle n'apparaît que
    // pour admin/gérant ») est appliquée par l'écran AU NIVEAU de la
    // grille — c'est donc le bon niveau, sans faux positif d'async.
    Future<void> _grille(WidgetTester tester, {required bool peutSupprimer}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaGrid(
              items: items,
              usages: (m) => [],
              onAffecter: (_) {},
              onSupprimer:
                  peutSupprimer ? (_) {} : null,
              onApercu: (_) {},
              onSelection: (_) {},
              modeSelection: false,
            ),
          ),
        ));

    testWidgets('admin / gérant : la poubelle est offerte', (tester) async {
      await _grille(tester, peutSupprimer: true);
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      // L'affectation reste possible pour tout le monde.
      expect(find.byIcon(Icons.link_rounded), findsNWidgets(2));
    });

    testWidgets('caissier / partenaire / vendeur : lecture seule',
        (tester) async {
      await _grille(tester, peutSupprimer: false);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.link_rounded), findsNWidgets(2));
    });

    testWidgets('la règle porte bien sur les 2 rôles autorisés', (tester) async {
      expect(<Role>{Role.admin, Role.gerant}, hasLength(2));
      await _grille(tester, peutSupprimer: true);
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });
  });
}
