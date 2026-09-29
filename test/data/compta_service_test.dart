import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/services/compta_service.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 0 — ComptaService pur : lignes partie double, TVA,
/// contre-passation, balance, résultat.
int _seq = 0;
String _nid() => 'id${_seq++}';

Tx _vente({double montant = 11800, String id = 'v1'}) => Tx(
    id: id,
    boutiqueId: 'b1',
    employeId: 'u',
    type: TypeTransaction.prestationService,
    montant: montant,
    date: DateTime(2026, 9, 26, 10),
    clientNom: 'Client');

void main() {
  group('ComptaService.lignesVente', () {
    test('TVA 18% : D411 = C706 + C443, équilibré', () {
      final lignes = ComptaService.lignesVente(
          _vente(), 18, _nid, 'b1', 'u');
      expect(lignes.length, 3);
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .firstWhere((e) => e.compte == '411')
              .debit,
          11800.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '706')
              .credit,
          10000.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '443')
              .credit,
          1800.0);
    });

    test('TVA 0 : pas de ligne 443', () {
      final lignes = ComptaService.lignesVente(
          _vente(montant: 5000), 0, _nid, 'b1', 'u');
      expect(lignes.length, 2);
      expect(lignes.any((e) => e.compte == '443'), isFalse);
      expect(ComptaService.estEquilibre(lignes), isTrue);
    });

    test('vente matériel → compte 701', () {
      final tx = Tx(
          id: 'm1',
          boutiqueId: 'b1',
          employeId: 'u',
          type: TypeTransaction.venteMateriel,
          montant: 10000,
          date: DateTime(2026, 9, 26));
      final lignes =
          ComptaService.lignesVente(tx, 0, _nid, 'b1', 'u');
      expect(lignes.any((e) => e.compte == '701'), isTrue);
    });

    test('Mobile Money retrait : BQ 571/521 + frais 706', () {
      final tx = Tx(
          id: 'mm1',
          boutiqueId: 'b1',
          employeId: 'u',
          type: TypeTransaction.mobileMoney,
          montant: 10000,
          date: DateTime(2026, 9, 26),
          details: const {
            'operation': 'Retrait',
            'frais': 400
          });
      final lignes =
          ComptaService.lignesVente(tx, 0, _nid, 'b1', 'u');
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .where((e) => e.compte == '571')
              .fold(0.0, (s, e) => s + e.debit),
          10400.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '706')
              .credit,
          400.0);
    });

    test('Mobile Money dépôt : sens inverse, sans frais', () {
      final tx = Tx(
          id: 'mm2',
          boutiqueId: 'b1',
          employeId: 'u',
          type: TypeTransaction.mobileMoney,
          montant: 20000,
          date: DateTime(2026, 9, 26),
          details: const {'operation': 'Dépôt'});
      final lignes =
          ComptaService.lignesVente(tx, 0, _nid, 'b1', 'u');
      expect(lignes.length, 2);
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .firstWhere((e) => e.compte == '521')
              .debit,
          20000.0);
    });
  });

  group('ComptaService achats', () {
    Achat achat() => Achat(
        id: 'a1',
        numero: 'ACH-2026-00001',
        boutiqueId: 'b1',
        fournisseurNom: 'Fourn',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble',
              quantite: 10,
              prixUnitaire: 1000,
              tauxTVA: 18),
        ],
        date: DateTime(2026, 9, 5),
        statut: Achat.statutValide,
        createdBy: 'u',
        createdAt: DateTime(2026, 9, 5));

    test('réception : D601 + D445 / C401', () {
      final lignes = ComptaService.lignesReception(
          achat(), _nid, 'b1', 'u');
      expect(lignes.length, 3);
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .firstWhere((e) => e.compte == '601')
              .debit,
          10000.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '445')
              .debit,
          1800.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '401')
              .credit,
          11800.0);
    });

    test('paiement espèces : D401 / C571 ; virement → C521', () {
      final esp = ComptaService.lignesPaiementAchat(
          achat(), 4000, 'especes', _nid, 'b1', 'u',
          DateTime(2026, 9, 6));
      expect(ComptaService.estEquilibre(esp), isTrue);
      expect(
          esp
              .firstWhere((e) => e.compte == '571')
              .credit,
          4000.0);
      final vir = ComptaService.lignesPaiementAchat(
          achat(), 4000, 'virement', _nid, 'b1', 'u',
          DateTime(2026, 9, 6));
      expect(vir.any((e) => e.compte == '521'), isTrue);
      expect(vir.any((e) => e.compte == '571'), isFalse);
    });
  });

  group('ComptaService charge + encaissement', () {
    test('charge Loyer : D622 / C571', () {
      final lignes = ComptaService.lignesCharge(
          Charge(
              id: 'c1',
              boutiqueId: 'b1',
              categorie: 'Loyer local',
              libelle: 'Loyer sept',
              montant: 150000,
              date: DateTime(2026, 9, 1)),
          _nid,
          'b1',
          'u');
      expect(lignes.length, 2);
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .firstWhere((e) => e.compte == '622')
              .debit,
          150000.0);
    });

    test('charge inconnue → 628', () {
      final lignes = ComptaService.lignesCharge(
          Charge(
              id: 'c2',
              boutiqueId: 'b1',
              categorie: 'Truc bizarre',
              libelle: 'X',
              montant: 100,
              date: DateTime(2026, 9, 1)),
          _nid,
          'b1',
          'u');
      expect(lignes.first.compte, '628');
    });

    test('encaissement : D571 / C411', () {
      final lignes = ComptaService.lignesEncaissement(
          _vente(montant: 9000, id: 'v9'),
          _nid,
          'b1',
          'u',
          DateTime(2026, 9, 26));
      expect(lignes.length, 2);
      expect(ComptaService.estEquilibre(lignes), isTrue);
      expect(
          lignes
              .firstWhere((e) => e.compte == '571')
              .debit,
          9000.0);
      expect(
          lignes
              .firstWhere((e) => e.compte == '411')
              .credit,
          9000.0);
    });
  });

  group('ComptaService contre-passation / balance / résultat', () {
    test('contre-passe inverse D/C et garde le motif', () {
      final origine =
          ComptaService.lignesVente(_vente(), 0, _nid, 'b1', 'u');
      final cp = ComptaService.contrePassation(
          origine, 'correction vente', 'v1', _nid, 'b1', 'u',
          DateTime(2026, 9, 27));
      expect(cp.length, origine.length);
      expect(
          cp.every((e) =>
              e.libelle == 'Contre-passation : correction vente'),
          isTrue);
      for (var i = 0; i < origine.length; i++) {
        expect(cp[i].debit, origine[i].credit);
        expect(cp[i].credit, origine[i].debit);
      }
      // Origine + contre-passe = net nul par compte.
      final net = ComptaService.balance([...origine, ...cp]);
      expect(net.values.every((v) => v.abs() < 0.01), isTrue);
    });

    test('contre-passe vide sans refId → []', () {
      expect(
          ComptaService.contrePassation(
              [], 'x', 'zzz', _nid, 'b1', 'u', DateTime.now()),
          isEmpty);
    });

    test('balance + résultat (7 − 6)', () {
      final lignes = [
        ...ComptaService.lignesVente(_vente(montant: 10000), 0,
            _nid, 'b1', 'u'),
        ...ComptaService.lignesCharge(
            Charge(
                id: 'c9',
                boutiqueId: 'b1',
                categorie: 'Loyer',
                libelle: 'Loyer',
                montant: 4000,
                date: DateTime(2026, 9, 1)),
            _nid,
            'b1',
            'u'),
      ];
      final bal = ComptaService.balance(lignes);
      expect(bal['411'], 10000.0);
      expect(bal['706'], -10000.0);
      expect(bal['622'], 4000.0);
      expect(ComptaService.resultat(bal), 6000.0);
    });

    test('estEquilibre détecte le déséquilibre', () {
      final lignes =
          ComptaService.lignesVente(_vente(), 0, _nid, 'b1', 'u');
      expect(ComptaService.estEquilibre([lignes.first]), isFalse);
    });
  });
}
