import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/analytique.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';

void main() {
  Store store() =>
      Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

  group('Analytique (mission 3, §3.1/3.2)', () {
    test('7 jours : 7 lignes couvrant aujourd\'hui', () {
      final s = store();
      final serie = s.ca7Jours();
      expect(serie.length, 7);
      final auj = DateTime.now();
      expect(serie.last.debut.day, auj.day);
      // Données démo : du CA présent sur la période.
      expect(serie.fold(0.0, (t, e) => t + e.montant), greaterThan(0));
    });

    test('mois : 12 lignes + total annuel cohérent', () {
      final s = store();
      final an = DateTime.now().year;
      final serie = s.caParMois(an);
      expect(serie.length, 12);
      expect(serie.first.debut, DateTime(an));
      final totalMois = serie.fold(0.0, (t, e) => t + e.montant);
      final parAnnees = {
        for (final a in s.caParAnnee()) a.label: a.montant
      };
      expect(parAnnees['$an'], totalMois);
    });

    test('dépenses : séries et panier moyen', () {
      final s = store();
      expect(s.depenses7Jours().length, 7);
      expect(s.depensesParMois(DateTime.now().year).length, 12);
      final a = s.depensesParAnnee();
      expect(a, isNotEmpty);
      expect(a.first.panierMoyen, greaterThanOrEqualTo(0));
    });

    test('variationPct : cas limites', () {
      expect(variationPct(0, 0), 0);
      expect(variationPct(100, 0), 100);
      expect(variationPct(150, 100), 50);
      expect(variationPct(50, 100), -50);
    });

    test('cagrMensuelAnnualise : doublement en 12 mois = +100 %', () {
      final serie = [
        AgregatPeriode(
            label: '01/26',
            debut: DateTime(2026, 1),
            montant: 1000,
            nb: 1),
        AgregatPeriode(
            label: '01/27',
            debut: DateTime(2027, 1),
            montant: 2000,
            nb: 1),
      ];
      expect(cagrMensuelAnnualise(serie), closeTo(100, 0.01));
      expect(cagrMensuelAnnualise([serie.first]), isNull);
      expect(cagrMensuelAnnualise([]), isNull);
    });

    test('anneesDonnees triées', () {
      final s = store();
      final a = s.anneesDonnees();
      expect(a, isNotEmpty);
      expect(a, orderedEquals([...a]..sort()));
    });
  });
}
