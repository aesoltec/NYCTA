import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/documents/documents_history_screen.dart';
import 'package:pme_gestion_pro/services/document_service.dart';

/// Le journal des corrections doit être VISIBLE dans l'historique.
///
/// Un journal écrit mais non affiché ne sert à rien : la question « ce
/// document a-t-il été corrigé après émission ? » se pose en regardant le
/// document, pas en allant le chercher ailleurs.

DocumentBati _doc(String numero, {TypeDocument type = TypeDocument.bonLivraison}) =>
    DocumentBati(
      id: numero,
      type: type,
      numero: numero,
      date: '01/10/2026',
      client: 'Client A',
      lignes: const [
        LigneDoc(libelle: 'Câble', quantite: 2, prixUnitaire: 1000)
      ],
      totalHT: 2000,
      tva: 360,
      totalTTC: 2360,
      devise: 'FCFA',
      statut: 'emis',
    );

Future<void> _hote(WidgetTester tester, Store store) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<Store>.value(
      value: store,
      child: const MaterialApp(home: DocumentsHistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  // `Store` programme des debounces de 600 ms a sa construction.
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('un document corrige affiche le nombre de corrections',
      (tester) async {
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.add(_doc('BL-001'));
    store.document.modifications.addAll([
      ModificationDocument(
        numero: 'BL-001',
        date: '2026-10-06T10:30:00.000',
        auteur: 'Test (admin)',
        motif: 'quantite corrigee a la livraison',
        resume: '2 → 3 lignes, total 2 000 → 3 000 FCFA',
      ),
    ]);

    await _hote(tester, store);

    expect(find.text('1 correction après émission'), findsOneWidget,
        reason: 'sans ce bandeau, la correction est invisible');
  });

  testWidgets('le motif et le resume sont consultables en detail',
      (tester) async {
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.add(_doc('BL-002'));
    store.document.modifications.add(ModificationDocument(
      numero: 'BL-002',
      date: '2026-10-06T10:30:00.000',
      auteur: 'Test (admin)',
      motif: 'quantite corrigee a la livraison',
      resume: '2 → 3 lignes',
    ));

    await _hote(tester, store);

    // Replié par défaut : l'historique reste lisible d'un coup d'oeil.
    expect(find.text('quantite corrigee a la livraison'), findsNothing);

    await tester.tap(find.text('1 correction après émission'));
    await tester.pumpAndSettle();

    expect(find.textContaining('quantite corrigee'), findsOneWidget);
    expect(find.textContaining('Test (admin)'), findsOneWidget);
    expect(find.textContaining('2 → 3 lignes'), findsOneWidget);
  });

  testWidgets('le journal ne concerne QUE son document', (tester) async {
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.addAll([_doc('BL-100'), _doc('BL-200')]);
    store.document.modifications.add(ModificationDocument(
      numero: 'BL-100',
      date: '2026-10-06T10:30:00.000',
      auteur: 'Test (admin)',
      motif: 'correction de BL-100',
      resume: '1 ligne ajoutee',
    ));

    await _hote(tester, store);

    expect(find.text('1 correction après émission'), findsOneWidget,
        reason: 'BL-200 na pas ete corrige : il ne doit pas porter le '
            'journal de BL-100');
  });

  testWidgets('aucun bandeau sur un document jamais corrige', (tester) async {
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.add(_doc('BL-300'));

    await _hote(tester, store);

    expect(find.textContaining('correction après émission'), findsNothing);
  });

  testWidgets('sans overflow a TextScaler 2.0 avec un bandeau deplie',
      (tester) async {
    final store = Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
    addTearDown(store.dispose);
    store.document.documentsEmis.add(_doc('BL-400'));
    store.document.modifications.add(ModificationDocument(
      numero: 'BL-400',
      date: '2026-10-06T10:30:00.000',
      auteur: 'Un Nom Tres Long De Collaborateur (admin)',
      motif: 'quantite corrigee apres reception chez le client, '
          'deux sacs manquants sur la commande du mois',
      resume: '2 lignes → 3 lignes, total 12 000 → 15 000 FCFA, '
          'client modifie',
    ));
    tester.view.physicalSize = const Size(320, 900);
    tester.view.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);

    await _hote(tester, store);
    await tester.tap(find.text('1 correction après émission'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'le journal ne doit pas deborder a 320 px x 2.0');
  });
}