import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/services/analytique_service.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/ecriture.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 0 — AnalytiqueService pur : CA/marges, types, jours, créances,
/// balance âgée, TVA.
Tx _tx(String id, String type, double montant, DateTime date,
        {double cout = 0,
        StatutPaiement statut = StatutPaiement.paye,
        String boutique = 'b1'}) =>
    Tx(
        id: id,
        boutiqueId: boutique,
        employeId: 'u',
        type: TypeTransaction.values.byName(type),
        montant: montant,
        cout: cout,
        date: date,
        statut: statut);

Ecriture _ecr(String compte, double debit, double credit,
        DateTime date) =>
    Ecriture(
        id: 'e$compte$debit$credit${date.day}',
        journal: 'VT',
        date: date,
        compte: compte,
        libelle: 't',
        debit: debit,
        credit: credit,
        boutiqueId: 'b1',
        createdBy: 'u');

void main() {
  final jour = DateTime(2026, 9, 26, 10);
  final txs = [
    _tx('t1', 'prestationService', 10000, jour, cout: 2000),
    _tx('t2', 'venteMateriel', 5000, jour),
    _tx('t3', 'prestationService', 3000,
        DateTime(2026, 9, 25, 10)),
    _tx('t4', 'prestationService', 99999, DateTime(2026, 8, 5),
        boutique: 'b2'),
  ];

  group('AnalytiqueService jour/mois', () {
    test('memeJour', () {
      expect(
          AnalytiqueService.memeJour(
              DateTime(2026, 9, 26, 8), DateTime(2026, 9, 26, 20)),
          isTrue);
      expect(
          AnalytiqueService.memeJour(
              DateTime(2026, 9, 26), DateTime(2026, 9, 27)),
          isFalse);
    });

    test('caJour / margeJour (boutique + jour)', () {
      expect(AnalytiqueService.caJour(txs, 'b1', jour), 15000.0);
      expect(AnalytiqueService.margeJour(txs, 'b1', jour), 13000.0);
    });

    test('caMois / margeMois (clé AAAA-MM)', () {
      expect(
          AnalytiqueService.caMois(txs, 'b1', '2026-09'), 18000.0);
      expect(
          AnalytiqueService.margeMois(txs, 'b1', '2026-09'), 16000.0);
      expect(AnalytiqueService.caMois(txs, 'b1', '2026-08'), 0.0);
    });
  });

  group('AnalytiqueService.caParType / caParJour', () {
    test('caParType agrège par type', () {
      final map = AnalytiqueService.caParType(
          AnalytiqueService.duMois(txs, 'b1', '2026-09'));
      expect(map[TypeTransaction.prestationService], 13000.0);
      expect(map[TypeTransaction.venteMateriel], 5000.0);
    });

    test('caParJour : 30 entrées, zéros inclus', () {
      final map = AnalytiqueService.caParJour(txs, jour);
      expect(map.length, 30);
      expect(map['26/09'], 15000.0);
      expect(map['25/09'], 3000.0);
      expect(map['24/09'], 0.0);
    });
  });

  group('AnalytiqueService créances / balance âgée', () {
    final impayes = [
      _tx('i1', 'prestationService', 10000,
          DateTime(2026, 9, 20),
          statut: StatutPaiement.impaye),
      _tx('i2', 'prestationService', 5000, DateTime(2026, 7, 1),
          statut: StatutPaiement.impaye),
      _tx('i3', 'prestationService', 7000, DateTime(2026, 9, 1)),
    ];

    test('creances : impayés seuls, triés anciens d\'abord', () {
      final c = AnalytiqueService.creances(impayes);
      expect(c.length, 2);
      expect(c.first.id, 'i2');
      expect(AnalytiqueService.totalCreances(c), 15000.0);
    });

    test('balanceAgee : tranches', () {
      final c = AnalytiqueService.creances(impayes);
      final b = AnalytiqueService.balanceAgee(
          c, DateTime(2026, 9, 26));
      expect(b['0-30 j'], 10000.0);
      expect(b['+90 j'], 0.0);
      // i2 : 01/07 → 26/09 = 87 jours → 61-90.
      expect(b['61-90 j'], 5000.0);
    });
  });

  group('AnalytiqueService.tvaParMois', () {
    test('collectée 443 − déductible 445', () {
      final ecr = [
        _ecr('443', 0, 1800, DateTime(2026, 9, 5)),
        _ecr('443', 0, 200, DateTime(2026, 9, 6)),
        _ecr('445', 500, 0, DateTime(2026, 9, 7)),
        _ecr('443', 0, 9999, DateTime(2026, 8, 1)),
      ];
      final m = AnalytiqueService.tvaParMois(ecr, 2026);
      expect(m[9], (2000.0, 500.0));
      expect(m[8], (9999.0, 0.0));
      expect(m[1], (0.0, 0.0));
    });
  });

  group('AnalytiqueService.series (Phase 5)', () {
    test('serieJours : 7 entrées datées, hors fenêtre ignorés', () {
      final s = AnalytiqueService.serieJours(
          DateTime(2026, 9, 26), 7, [(DateTime(2026, 9, 26, 10), 100.0, 20.0),
            (DateTime(2026, 9, 1, 10), 999.0, 0.0)]);
      expect(s.length, 7);
      expect(s.last.label, '26/09');
      expect(s.last.montant, 100.0);
      expect(s.last.nb, 1);
      expect(s.last.marge, 20.0);
      expect(s.fold(0.0, (t, e) => t + e.montant), 100.0);
    });

    test('serieMois : 12 mois même vides', () {
      final s = AnalytiqueService.serieMois(2026,
          [(DateTime(2026, 3, 5), 500.0, 100.0)]);
      expect(s.length, 12);
      expect(s[2].label, '03');
      expect(s[2].montant, 500.0);
      expect(s[2].nb, 1);
      expect(s[0].montant, 0.0);
    });

    test('serieAnnees : une entrée par année', () {
      final s = AnalytiqueService.serieAnnees([2025, 2026],
          [(DateTime(2026, 1, 1), 700.0, 70.0)]);
      expect(s.length, 2);
      expect(s.first.label, '2025');
      expect(s.first.montant, 0.0);
      expect(s.last.montant, 700.0);
    });

    test('fraisMoMo : par opérateur, mobileMoney seul', () {
      final m1 = Tx(
          id: 'm1',
          boutiqueId: 'b1',
          employeId: 'u',
          type: TypeTransaction.mobileMoney,
          montant: 10000,
          date: DateTime(2026, 9, 1),
          details: {'operateur': 'Orange Money', 'frais': 400});
      final txs = [
        m1,
        _tx('m2', 'prestationService', 50000, DateTime(2026, 9, 2)),
      ];
      final map = AnalytiqueService.fraisMoMo(txs);
      expect(map, {'Orange Money': 400.0});
    });

    test('fraisMoMo : opérateur absent → Autre', () {
      final map = AnalytiqueService.fraisMoMo(
          [_tx('m', 'mobileMoney', 100, DateTime(2026, 9, 1))]);
      expect(map, {'Autre': 0.0});
    });
  });

  group('AnalytiqueService.totalDepensesMois', () {    test('somme', () {
      expect(
          AnalytiqueService.totalDepensesMois([
            Charge(
                id: 'c1',
                boutiqueId: 'b1',
                categorie: 'Loyer',
                libelle: 'Loyer',
                montant: 150000,
                date: DateTime(2026, 9, 1)),
            Charge(
                id: 'c2',
                boutiqueId: 'b1',
                categorie: 'Autre',
                libelle: 'X',
                montant: 5000,
                date: DateTime(2026, 9, 2)),
          ]),
          155000.0);
    });
  });
}
