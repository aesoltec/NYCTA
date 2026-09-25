import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/collab/messagerie_screen.dart';
import 'package:pme_gestion_pro/screens/dashboard/dashboard_screen.dart';
import 'package:pme_gestion_pro/screens/journal/journal_screen.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';

/// Matrice anti-overflow (missionbis §6.4 n°3) : les écrans critiques ne
/// doivent ni lever d'exception ni produire de `RenderFlex overflowed`,
/// même avec le scaler d'accessibilité au maximum (2.0x).
Widget _hote(Widget enfant, double scaler) {
  final store = Store(const AppUser(
      id: 'u', nom: 'Test', role: Role.admin));
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scaler)),
        // Les onglets (Journal, Stock…) sont des corps sans Scaffold :
        // on leur donne un Scaffold + hauteur bornée comme AppShell.
        child: Scaffold(body: SizedBox(height: 800, child: enfant)),
      ),
    ),
  );
}

void main() {
  group('Anti-overflow TextScaler', () {
    for (final scaler in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('Dashboard à ${scaler}x', (tester) async {
        await tester.pumpWidget(_hote(const DashboardScreen(), scaler));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
      });

      testWidgets('Journal à ${scaler}x', (tester) async {
        await tester.pumpWidget(_hote(const JournalScreen(), scaler));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
      });

      testWidgets('Stock à ${scaler}x', (tester) async {
        await tester.pumpWidget(_hote(const StockScreen(), scaler));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
      });

      testWidgets('Messagerie à ${scaler}x', (tester) async {
        await tester.pumpWidget(
            _hote(const MessagerieScreen(), scaler));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
      });
    }
  });
}
