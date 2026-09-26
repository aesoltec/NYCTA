import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';
import 'package:pme_gestion_pro/screens/stats/stats_screen.dart';

/// Points 32-33 : filtres type/période + agrégations.
Tx _tx(String type, double montant, DateTime date) => Tx(
      id: 't${date.millisecondsSinceEpoch}$montant',
      boutiqueId: 'bt_siege',
      employeId: 'u',
      type: TypeTransaction.values.byName(type),
      montant: montant,
      date: date,
      details: const {},
    );

void main() {
  group('Statistiques (32)', () {
    final ventes = [
      _tx('prestationService', 10000, DateTime(2026, 9, 1, 10)),
      _tx('prestationService', 5000, DateTime(2026, 9, 2, 10)),
      _tx('venteMateriel', 20000, DateTime(2026, 9, 10, 10)),
      _tx('prestationService', 7000, DateTime(2026, 8, 1, 10)),
    ];

    test('ventesFiltrees : type + intervalle', () {
      final f = StatsScreen.ventesFiltrees(
          ventes, 'tous', DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(f.length, 3);
      final p = StatsScreen.ventesFiltrees(ventes, 'prestationService',
          DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(p.length, 2);
      // Fin inclusive (jour entier).
      final un = StatsScreen.ventesFiltrees(ventes, 'tous',
          DateTime(2026, 9, 10), DateTime(2026, 9, 10));
      expect(un.length, 1);
    });

    test('serie : seaux journaliers + totaux', () {
      final s = StatsScreen.serie(
          ventes, DateTime(2026, 9, 1), DateTime(2026, 9, 3), 1);
      expect(s.length, 3);
      expect(s[0].key, '01/09');
      expect(s[0].value, 10000.0);
      expect(s[1].value, 5000.0);
      expect(s[2].value, 0.0);
    });

    testWidgets('écran : titre + panel + graphiques', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: Store(
              const AppUser(id: 'u', nom: 'T', role: Role.admin)),
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Statistiques & graphiques'), findsOneWidget);
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.textContaining('Évolution du CA'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
