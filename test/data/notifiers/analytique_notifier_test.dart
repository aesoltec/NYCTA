import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/analytique_notifier.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 4 — AnalytiqueNotifier (séries 7j/mois/années).
Tx _tx(String id, double montant, DateTime date) => Tx(
    id: id,
    boutiqueId: 'b1',
    employeId: 'u',
    type: TypeTransaction.prestationService,
    montant: montant,
    cout: montant * 0.2,
    date: date);

Charge _charge(String id, double montant, DateTime date) => Charge(
    id: id,
    boutiqueId: 'b1',
    categorie: 'Loyer',
    libelle: 'Loyer',
    montant: montant,
    date: date);

AnalytiqueNotifier _notifier() => AnalytiqueNotifier(
      txBoutique: [
        _tx('t1', 10000, DateTime(2026, 9, 26, 10)),
        _tx('t2', 5000, DateTime(2026, 9, 25, 10)),
        _tx('t3', 7000, DateTime(2026, 8, 15, 10)),
      ],
      depensesBoutique: [
        _charge('c1', 3000, DateTime(2026, 9, 22)),
        _charge('c2', 4000, DateTime(2025, 5, 5)),
      ],
    );

void main() {
  group('AnalytiqueNotifier séries', () {
    test('ca7Jours : 7 entrées, labels jj/mm', () {
      final n = _notifier();
      final s = n.ca7Jours(fin: DateTime(2026, 9, 26));
      expect(s.length, 7);
      expect(s.last.label, '26/09');
      expect(s.last.montant, 10000.0);
      expect(s.last.nb, 1);
      expect(s.last.marge, 8000.0);
      expect(s.first.montant, 0.0);
    });

    test('depenses7Jours : montants sans marge', () {
      final n = _notifier();
      final s = n.depenses7Jours(fin: DateTime(2026, 9, 26));
      expect(s.length, 7);
      final total = s.fold(0.0, (t, e) => t + e.montant);
      expect(total, 3000.0);
      expect(s.every((e) => e.marge == 0), isTrue);
    });

    test('caParMois / depensesParMois : 12 mois', () {
      final n = _notifier();
      final ca = n.caParMois(2026);
      expect(ca.length, 12);
      expect(ca[8].label, '09');
      expect(ca[8].montant, 15000.0);
      expect(ca[8].nb, 2);
      expect(ca[0].montant, 0.0);
      final dep = n.depensesParMois(2026);
      expect(dep[8].montant, 3000.0);
    });

    test('caParAnnee / depensesParAnnee + anneesDonnees', () {
      final n = _notifier();
      expect(n.anneesDonnees(), [2025, 2026]);
      final ca = n.caParAnnee();
      expect(ca.length, 2);
      expect(ca.first.label, '2025');
      expect(ca.first.montant, 0.0);
      expect(ca.last.montant, 22000.0);
      final dep = n.depensesParAnnee();
      expect(dep.first.montant, 4000.0);
    });

    test('données vides → séries à zéro', () {
      final n = AnalytiqueNotifier(txBoutique: [], depensesBoutique: []);
      expect(n.ca7Jours(fin: DateTime(2026, 9, 26)).length, 7);
      expect(
          n.ca7Jours(fin: DateTime(2026, 9, 26))
              .every((e) => e.montant == 0 && e.nb == 0),
          isTrue);
      expect(n.anneesDonnees(), isEmpty);
      expect(n.caParAnnee(), isEmpty);
    });
  });
}
