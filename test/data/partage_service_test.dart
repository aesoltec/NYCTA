import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/services/partage_service.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 0 — PartageService pur : total forfait + clôture équilibrée.
Tx _tx(String id, String? partenaire, String type, double montant,
        String mois) =>
    Tx(
        id: id,
        boutiqueId: 'b1',
        employeId: 'u',
        type: TypeTransaction.values.byName(type),
        montant: montant,
        date: DateTime(
            int.parse(mois.split('-')[0]), int.parse(mois.split('-')[1]), 5),
        partenaireId: partenaire);

void main() {
  final txs = [
    _tx('t1', 'pt1', 'forfaitHotspot', 10000, '2026-09'),
    _tx('t2', 'pt1', 'forfaitHotspot', 5000, '2026-09'),
    _tx('t3', 'pt1', 'prestationService', 99999, '2026-09'), // autre type
    _tx('t4', 'pt1', 'forfaitHotspot', 77777, '2026-08'), // autre mois
    _tx('t5', 'pt2', 'forfaitHotspot', 3000, '2026-09'), // autre partenaire
    _tx('t6', null, 'forfaitHotspot', 11111, '2026-09'), // sans partenaire
  ];

  group('PartageService.totalVentes', () {
    test('filtre partenaire + forfait + mois', () {
      expect(
          PartageService.totalVentes(txs, 'pt1', '2026-09'), 15000.0);
    });

    test('aucune vente → 0', () {
      expect(PartageService.totalVentes(txs, 'ptX', '2026-09'), 0.0);
    });
  });

  group('PartageService.cloturer', () {
    test('parts 60/40 équilibrées', () {
      final p = PartageService.cloturer(
          id: 'pg1',
          partenaireId: 'pt1',
          mois: '2026-09',
          totalVentes: 15000,
          taux: 0.60);
      expect(p.partPartenaire, 9000.0);
      expect(p.partEntreprise, 6000.0);
      expect(PartageService.estEquilibre(p), isTrue);
    });

    test('taux 0 et 1 bornes', () {
      final zero = PartageService.cloturer(
          id: 'a',
          partenaireId: 'p',
          mois: 'm',
          totalVentes: 1000,
          taux: 0);
      expect(zero.partPartenaire, 0.0);
      expect(zero.partEntreprise, 1000.0);
      final cent = PartageService.cloturer(
          id: 'b',
          partenaireId: 'p',
          mois: 'm',
          totalVentes: 1000,
          taux: 1);
      expect(cent.partPartenaire, 1000.0);
      expect(cent.partEntreprise, 0.0);
    });
  });
}
