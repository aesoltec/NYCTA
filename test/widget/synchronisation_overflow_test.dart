import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/config/synchronisation_screen.dart';
import 'package:pme_gestion_pro/services/sync_service.dart';

/// Le nom de table etait dimensionne a sa largeur naturelle dans un
/// `Row` : il deborde des que le nom est long (cas reel :
/// `mouvements_stock` avec plusieurs erreurs) ou que le compteur
/// d'essais s'y ajoute.
void main() {
  const largeurs = [320.0, 360.0, 768.0, 1024.0];

  /// Message d'erreur SERVEUR : longueur non maitrisee. C'est la donnee
  /// la plus hostile du tableau de bord.
  const erreurServeur =
      'PostgrestException(message: invalid input syntax for type uuid: "", '
      'code: 22P02, details: Bad Request, hint: null)';

  late Store store;

  setUp(() {
    store = Store(const AppUser(id: 'u', nom: 'Test', role: Role.admin));
    SyncService.entreesPourTest = const [];
    SyncService.notifierPourTest();
  });

  tearDown(() {
    SyncService.entreesPourTest = null;
    store.dispose();
  });

  Map<String, dynamic> entree({
    required String table,
    required int essais,
    bool enErreur = true,
    String? erreur = erreurServeur,
  }) =>
      {
        'table': table,
        'payload': <String, dynamic>{},
        'cree_le': DateTime(2026, 10, 1, 8, 30).toIso8601String(),
        'essais': essais,
        'en_erreur': enErreur,
        'derniere_erreur': erreur,
      };

  /// [n] entrees bloquees, la 1re avec le nom de table le plus long
  /// observe sur l'appareil.
  List<Map> plusieursErreurs(int n) => [
        for (var i = 0; i < n; i++)
          entree(
              table: i == 0 ? 'mouvements_stock' : 'produits', essais: 8)
      ];

  Future<void> afficher(WidgetTester tester, double largeur, double scaler,
      List<Map> entrees) async {
    SyncService.entreesPourTest = entrees;
    SyncService.notifierPourTest();
    tester.view.physicalSize = Size(largeur, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<Store>.value(
        value: store,
        child: MaterialApp(
          builder: (context, enfant) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scaler)),
            child: enfant!,
          ),
          home: const SynchronisationScreen(),
        ),
      ),
    );
    await tester.pump();
    // Laisse s'ecouler les debounces de 600 ms du Store : sinon des
    // timers restent en attente et le test echoue sur ce motif-la.
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> balayer(WidgetTester tester, List<Map> entrees,
      {double scaler = 1.0}) async {
    for (final largeur in largeurs) {
      await afficher(tester, largeur, scaler, entrees);
      final e = tester.takeException();
      expect(e, isNull,
          reason: 'debordement a ${largeur.toInt()} px, TextScaler $scaler, '
              '${entrees.length} entree(s)');
    }
  }

  testWidgets('plusieurs erreurs (cas signale sur l\'appareil)',
      (tester) async {
    await balayer(tester, plusieursErreurs(3));
  });

  testWidgets('plusieurs erreurs aux TextScaler 1.5 puis 2.0',
      (tester) async {
    for (final s in [1.5, 2.0]) {
      for (final largeur in largeurs) {
        await afficher(tester, largeur, s, plusieursErreurs(3));
        expect(tester.takeException(), isNull,
            reason: '${largeur.toInt()} px / TextScaler $s');
      }
    }
  });

  testWidgets('une seule erreur', (tester) async {
    await balayer(tester, plusieursErreurs(1));
  });

  testWidgets('nom de table tres long + compteur eleve', (tester) async {
    await balayer(tester, [
      entree(table: 'partenaires__update_tresorerie_2026', essais: 128),
    ]);
  });

  testWidgets('entree en attente (pas une erreur)', (tester) async {
    await balayer(tester, [
      entree(table: 'mouvements_stock', essais: 0, enErreur: false,
          erreur: null)
    ]);
  });

  testWidgets('file vide (etat nominal)', (tester) async {
    await balayer(tester, const []);
  });

  testWidgets('beaucoup d\'erreurs (10) sans debordement', (tester) async {
    await balayer(tester, plusieursErreurs(10));
  });
}
