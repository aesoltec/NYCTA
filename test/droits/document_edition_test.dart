import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/documents/documents_screen.dart';
import 'package:pme_gestion_pro/services/document_service.dart';

DocumentBati _brouillon() => DocumentBati(
      id: 'd1',
      type: TypeDocument.devisProforma,
      numero: 'DEV-001',
      date: '03/10/2026',
      client: 'Client A',
      lignes: const [
        LigneDoc(libelle: 'Câble', quantite: 2, prixUnitaire: 1000),
      ],
      totalHT: 2000,
      tva: 360,
      totalTTC: 2360,
      devise: 'FCFA',
      statut: 'brouillon',
    );

void main() {
  // Le formulaire est ouvert depuis une carte de la liste des documents
  // émis : il doit tenir dans la largeur d'un téléphone courant (360 px).
  Future<Store> _ouvrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.add(_brouillon());
    await tester.pumpWidget(
      ChangeNotifierProvider<Store>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(body: DocumentsScreen(docExistant: _pourLeMontage)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // `Store` programme des debounces de 600 ms a sa construction ;
    // sans faire avancer l'horloge virtuelle le test echoue sur
    // « A Timer is still pending ».
    await tester.pump(const Duration(milliseconds: 700));
    return store;
  }

  testWidgets('edition : le document est pre-rempli, type verrouille',
      (tester) async {
    await _ouvrir(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Modifier le document'), findsOneWidget);
    expect(find.textContaining('verrouill'), findsOneWidget,
        reason: 'le type ne doit pas pouvoir changer en edition : cela '
            'changerait le prefixe de numero et la nature du justificatif');
    final champ = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Client'));
    expect(champ.controller?.text, 'Client A');
  });

  testWidgets('edition : enregistrer appelle modifierDocument',
      (tester) async {
    final store = await _ouvrir(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Client'), 'Client Modifié');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // soit le document est modifie, soit le refus est explique : dans les
    // deux cas la liste ne doit pas contenir de doublon
    expect(store.document.documentsEmis.length, 1,
        reason: 'enregistrerDocument faisait insert(0) : le rejeu '
            'dupliquait au lieu de mettre a jour');
    expect(store.document.documentsEmis.first.client, 'Client Modifié');
  });

  testWidgets('edition : client vide refuse, document intact',
      (tester) async {
    final store = await _ouvrir(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Client'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();
    expect(store.document.documentsEmis.first.client, 'Client A');
    expect(tester.takeException(), isNull);
  });
}

/// Document passe au `const MaterialApp` du montage ; l objet
/// utilise par le test est celui enregistre dans le Store.
final _pourLeMontage = _brouillon();
