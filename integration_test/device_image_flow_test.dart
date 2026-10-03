import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pme_gestion_pro/main.dart';
import 'package:pme_gestion_pro/screens/gallery/gallery_screen.dart';
import 'package:pme_gestion_pro/services/media_service.dart';

/// Parcours IMAGE de bout en bout, joue sur l'appareil reel.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stock : creer un produit avec une image de la galerie',
      (tester) async {
    await initializeDateFormatting('fr_FR', null);

    // --- 1. Une VRAIE image dans la banque interne, sur l'appareil.
    final racine = await Directory.systemTemp.createTemp('pme_galerie');
    MediaService.dossierRacineTest = racine;
    addTearDown(() async {
      MediaService.dossierRacineTest = null;
      if (racine.existsSync()) racine.deleteSync(recursive: true);
    });
    final dossier = await MediaService.dossierMedia('galerie');
    // PNG 1x1 valide : suffisant pour etre une vraie image lisible.
    final fichier = File('${dossier.path}${Platform.pathSeparator}'
        'produit_test_1700000000_aa11bb.png');
    await fichier.writeAsBytes(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature PNG
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
    expect(fichier.existsSync(), isTrue, reason: 'image de test ecrite');

    // --- 2. Demarrage reel + connexion demo.
    await tester.pumpWidget(const PmeApp());
    await tester.pumpAndSettle();
    expect(find.text('PME Gestion'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, "Nom de l'utilisateur"),
        'Testeur');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'), 'testeur1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // --- 3. Onglet Stock de la barre de navigation.
    final ongletStock = find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Stock'));
    expect(ongletStock, findsOneWidget,
        reason: 'la barre de navigation doit exposer Stock');
    await tester.tap(ongletStock);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // --- 4. Formulaire de produit.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Produit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Libellé'), 'Camion test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Prix achat'), '1000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Prix vente'), '1500');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantité en stock'), '4');
    await tester.pumpAndSettle();

    // --- 5. Galerie interne (bouton « Parcourir »).
    await tester.scrollUntilVisible(find.text('Parcourir'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Parcourir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryScreen), findsOneWidget,
        reason: 'Parcourir doit ouvrir la galerie interne');

    // --- 6. L'image injectee doit être listee (scan reel du dossier).
    expect(find.textContaining('aa11bb'), findsOneWidget,
        reason: 'la galerie doit lister le PNG ecrit sur l\'appareil');

    // --- 7. Selection + retour au formulaire.
    await tester.tap(find.textContaining('aa11bb').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Galerie (1/5)'), findsOneWidget,
        reason: 'l\'image doit être comptée dans le formulaire');

    // --- 8. Enregistrement.
    await tester.scrollUntilVisible(find.text('Ajouter au stock'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ajouter au stock'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // --- 9. Le produit cree est liste, avec son image principale.
    expect(find.textContaining('Camion test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
