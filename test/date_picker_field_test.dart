import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/widgets/date_picker_field.dart';

/// Hôte de test avec la même configuration locale que main.dart.
Widget _hote(Widget enfant) => MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: enfant),
    );

void main() {
  final debut = DateTime(2020, 1, 1);
  final fin = DateTime(2030, 12, 31);

  group('parseDateSaisie', () {
    test('date valide', () {
      expect(parseDateSaisie('05/09/2026'), DateTime(2026, 9, 5));
    });
    test('bissextile accepte, non-bissextile refuse', () {
      expect(parseDateSaisie('29/02/2024'), isNotNull);
      expect(parseDateSaisie('29/02/2023'), isNull);
      expect(parseDateSaisie('30/02/2024'), isNull);
      expect(parseDateSaisie('31/04/2026'), isNull);
    });
    test('formats invalides', () {
      expect(parseDateSaisie(''), isNull);
      expect(parseDateSaisie('5/9/2026'), isNull);
      expect(parseDateSaisie('05-09-2026'), isNull);
      expect(parseDateSaisie('99/99/9999'), isNull);
      expect(parseDateSaisie('00/01/2026'), isNull);
    });
  });

  group('validerDateSaisie', () {
    test('vide et hors plage', () {
      expect(validerDateSaisie('', firstDate: debut, lastDate: fin),
          contains('requise'));
      expect(validerDateSaisie('01/01/2019', firstDate: debut, lastDate: fin),
          contains('ancienne'));
      expect(validerDateSaisie('01/01/2031', firstDate: debut, lastDate: fin),
          contains('éloignée'));
      expect(validerDateSaisie('05/09/2026', firstDate: debut, lastDate: fin),
          isNull);
    });
  });

  group('clamperDate', () {
    test('borne dans les deux sens', () {
      expect(clamperDate(DateTime(2010, 5, 5), debut, fin), debut);
      expect(clamperDate(DateTime(2040, 5, 5), debut, fin), fin);
      final milieu = DateTime(2026, 9, 5);
      expect(clamperDate(milieu, debut, fin), milieu);
    });
  });

  group('DatePickerField (widget)', () {
    testWidgets('affiche la valeur et annulation conserve', (tester) async {
      DateTime? retenue = DateTime(2026, 9, 5);
      await tester.pumpWidget(_hote(DatePickerField(
        valeur: retenue,
        firstDate: debut,
        lastDate: fin,
        onChanged: (d) => retenue = d,
      )));
      expect(find.text('05/09/2026'), findsOneWidget);
      // Ouvre le calendrier puis annule : valeur inchangée.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Annuler').hitTestable());
      await tester.pumpAndSettle();
      expect(retenue, DateTime(2026, 9, 5));
    });

    testWidgets('saisie manuelle valide via clavier', (tester) async {
      DateTime? retenue;
      await tester.pumpWidget(_hote(DatePickerField(
            valeur: null,
            texteVide: 'Aucun rappel',
            firstDate: debut,
            lastDate: fin,
            onChanged: (d) => retenue = d,
      )));
      expect(find.text('Aucun rappel'), findsOneWidget);
      await tester.tap(find.byTooltip('Saisir au clavier (JJ/MM/AAAA)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12/10/2026');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(retenue, DateTime(2026, 10, 12));
    });

    testWidgets('saisie manuelle invalide refuse', (tester) async {
      DateTime? retenue;
      await tester.pumpWidget(_hote(DatePickerField(
            valeur: null,
            firstDate: debut,
            lastDate: fin,
            onChanged: (d) => retenue = d,
      )));
      await tester.tap(find.byTooltip('Saisir au clavier (JJ/MM/AAAA)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '31/02/2026');
      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(find.textContaining('invalide'), findsOneWidget);
      expect(retenue, isNull);
    });

    testWidgets('croix efface la valeur', (tester) async {
      DateTime? retenue = DateTime(2026, 9, 5);
      var efface = false;
      await tester.pumpWidget(_hote(DatePickerField(
            valeur: retenue,
            firstDate: debut,
            lastDate: fin,
            effacable: true,
            onChanged: (d) {
              retenue = d;
              efface = true;
            },
      )));
      await tester.tap(find.byTooltip('Effacer'));
      await tester.pump();
      expect(efface, isTrue);
      expect(retenue, isNull);
    });
  });
}
