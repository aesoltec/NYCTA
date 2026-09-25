import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pme_gestion_pro/main.dart';

/// Parcours bout-en-bout (missionbis §6.4 n°2) : démarrage → connexion
/// démo → tableau de bord → saisie d'une prestation → journal.
/// Exécutable sur émulateur/appareil : `flutter test integration_test`.
/// Fonctionne aussi sur VM (flutter_tester).
void main() {
  testWidgets('Parcours : connexion → vente prestation → journal',
      (tester) async {
    await initializeDateFormatting('fr_FR', null);
    // Grande surface : tout le dashboard est construit d'un coup
    // (pas de lazy-build à scroller).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const PmeApp());
    await tester.pumpAndSettle();

    // 1. Connexion démo (pas de Supabase configuré en test).
    expect(find.text('PME Gestion'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, "Nom de l'utilisateur"),
        'Testeur');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'), 'testeur1');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    // 2. Tableau de bord visible.
    expect(find.text('Nouvelle opération'), findsOneWidget);

    // 3. Ouvre le formulaire Prestation (1re tuile) et saisit la vente.
    // .first : la barre de répartition du mois affiche aussi ce libellé.
    await tester.tap(find.text('Prestation').first);
    await tester.pumpAndSettle();
    // Repasse en surface normale : le menu déroulant natif s'y positionne
    // correctement (sur très grande surface, l'overlay tombe hors hit-test).
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Description de la prestation'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Montant (FCFA)'), '5000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Description de la prestation'),
        'Test intégration');
    // Domaine requis : ouvre le dropdown et choisit la 1re valeur.
    await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>,
            "Domaine d'intervention"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informatique').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la vente'));
    await tester.pumpAndSettle();

    // 4. Retour dashboard, vente visible au journal (onglet Journal).
    await tester.scrollUntilVisible(
        find.text('Nouvelle opération'), 400);
    expect(find.text('Nouvelle opération'), findsOneWidget);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test intégration'), findsOneWidget);
  });
}
