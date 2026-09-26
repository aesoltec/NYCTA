import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/documents/documents_history_screen.dart';

/// Golden (MISSION point 20) : Documents émis en 360px — prouve
/// l'absence d'overflow après la correction (actions en Wrap,
/// filtres sur 2 lignes en étroit).
void main() {
  testWidgets('Documents émis 360px sans overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: Store(
            const AppUser(id: 'u', nom: 'Test', role: Role.admin)),
        child: const MaterialApp(home: DocumentsHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(DocumentsHistoryScreen),
        matchesGoldenFile('goldens/documents_emis_360.png'));
    await tester.pump(const Duration(milliseconds: 700));
  });
}
