import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/services/caisse_service.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 0 — CaisseService pur : solde = fonds + CA payé − dépenses.
Tx _tx(String id, double montant,
        {StatutPaiement statut = StatutPaiement.paye,
        String boutique = 'b1'}) =>
    Tx(
        id: id,
        boutiqueId: boutique,
        employeId: 'u',
        type: TypeTransaction.prestationService,
        montant: montant,
        date: DateTime(2026, 9, 1),
        statut: statut);

Charge _charge(String id, double montant, {String boutique = 'b1'}) =>
    Charge(
        id: id,
        boutiqueId: boutique,
        categorie: 'Loyer',
        libelle: 'Loyer',
        montant: montant,
        date: DateTime(2026, 9, 1));

void main() {
  group('CaisseService.solde', () {
    test('fonds + payé − dépenses', () {
      expect(
          CaisseService.solde(
            transactions: [
              _tx('t1', 10000),
              _tx('t2', 5000,
                  statut: StatutPaiement.impaye), // exclu
              _tx('t3', 7000, boutique: 'b2'), // autre boutique
            ],
            depenses: [_charge('c1', 3000)],
            boutiqueId: 'b1',
            fondsRoulement: 50000,
          ),
          50000 + 10000 - 3000);
    });

    test('sans fonds ni mouvements → 0', () {
      expect(
          CaisseService.solde(
              transactions: const [],
              depenses: const [],
              boutiqueId: 'b1',
              fondsRoulement: 0),
          0.0);
    });

    test('dépenses autre boutique ignorées', () {
      expect(
          CaisseService.solde(
            transactions: [_tx('t1', 10000)],
            depenses: [_charge('c1', 99999, boutique: 'b2')],
            boutiqueId: 'b1',
            fondsRoulement: 0,
          ),
          10000.0);
    });

    test('solde négatif possible (découvert)', () {
      expect(
          CaisseService.solde(
            transactions: const [],
            depenses: [_charge('c1', 5000)],
            boutiqueId: 'b1',
            fondsRoulement: 1000,
          ),
          -4000.0);
    });
  });
}
