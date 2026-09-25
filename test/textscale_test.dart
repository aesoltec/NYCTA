import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/achat/achat_list_screen.dart';
import 'package:pme_gestion_pro/screens/collab/messagerie_screen.dart';
import 'package:pme_gestion_pro/screens/dashboard/dashboard_screen.dart';
import 'package:pme_gestion_pro/screens/documents/documents_screen.dart';
import 'package:pme_gestion_pro/screens/journal/journal_screen.dart';
import 'package:pme_gestion_pro/screens/rapports/analytique_screen.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';
import 'package:pme_gestion_pro/screens/users/users_screen.dart';

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

/// Variante sans hauteur imposée (écrans à Scaffold complet + surface
/// de test déjà dimensionnée).
Widget _hoteSur(Widget enfant, double scaler) {
  final store = Store(const AppUser(
      id: 'u', nom: 'Test', role: Role.admin));
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scaler)),
        child: Scaffold(body: enfant),
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

  // Mission §A4 : 4 écrans supplémentaires × petit téléphone, tablette.
  group('Anti-overflow multi-formats', () {
    Future<void> pomperFormat(
        WidgetTester tester, Widget ecran, Size taille, double scaler) async {
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_hoteSur(ecran, scaler));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 700));
    }

    const formats = [
      Size(320, 568), // petit téléphone
      Size(360, 740), // téléphone courant
      Size(768, 1024), // tablette
      Size(1024, 768), // desktop paysage
    ];
    for (final taille in formats) {
      testWidgets(
          'Achats ${taille.width.toInt()}x${taille.height.toInt()} @1.5x',
          (tester) async {
        await pomperFormat(
            tester, const AchatListScreen(), taille, 1.5);
      });
      testWidgets(
          'Documents ${taille.width.toInt()}x${taille.height.toInt()} @1.5x',
          (tester) async {
        await pomperFormat(
            tester, const DocumentsScreen(), taille, 1.5);
      });
      testWidgets(
          'Analytique ${taille.width.toInt()}x${taille.height.toInt()} @1.5x',
          (tester) async {
        await pomperFormat(
            tester, const AnalytiqueScreen(), taille, 1.5);
      });
      testWidgets(
          'Utilisateurs ${taille.width.toInt()}x${taille.height.toInt()} @2.0x',
          (tester) async {
        await pomperFormat(
            tester, const UsersScreen(), taille, 2.0);
      });
    }
  });
}
