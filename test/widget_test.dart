import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pme_gestion_pro/main.dart';

/// Test de fumée (smoke test) : l'application démarre et affiche
/// l'écran de connexion. Doit rester VERT — tout écran rouge ici
/// signifie une régression avant chaque livraison.
void main() {
  testWidgets('Démarrage : écran de connexion affiché', (tester) async {
    await initializeDateFormatting('fr_FR', null);
    await tester.pumpWidget(const PmeApp());
    await tester.pumpAndSettle();
    expect(find.text('PME Gestion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Rôle (démo des permissions)'), findsOneWidget);
  });
}
