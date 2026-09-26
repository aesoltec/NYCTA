import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/transaction.dart';
import 'package:pme_gestion_pro/models/enums.dart';

/// Point 30 — chaque opération poste des écritures ÉQUILIBRÉES (D=C),
/// corrections par contre-écriture, soldes nets vérifiés par refId.
Store _store() =>
    Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

/// Solde net (D − C) des écritures liées à [refId].
double _net(Store s, String refId) => s.ecritures
    .where((e) => e.refId == refId)
    .fold(0.0, (t, e) => t + e.debit - e.credit);

/// Invariant partie double sur un sous-ensemble.
void _equilibre(Iterable<dynamic> lignes) {
  final d = lignes.fold(0.0, (t, e) => t + (e.debit as double));
  final c = lignes.fold(0.0, (t, e) => t + (e.credit as double));
  expect(d, moreOrLessEquals(c, epsilon: 0.01));
}

void main() {
  group('Comptabilité (point 30)', () {
    test('vente TTC 18% : D411 = C706 + C443', () async {
      final s = _store();
      s.profile = s.profile.copyWith(tva: 18);
      final id = await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 11800,
        clientNom: 'Client Test',
        details: const {'domaine': 'Informatique'},
      );
      final lignes =
          s.ecritures.where((e) => e.refId == id).toList();
      expect(lignes.length, 3);
      _equilibre(lignes);
      final d411 = lignes.firstWhere((e) => e.compte == '411');
      expect(d411.debit, 11800.0);
      final c706 = lignes.firstWhere((e) => e.compte == '706');
      expect(c706.credit, 10000.0);
      final c443 = lignes.firstWhere((e) => e.compte == '443');
      expect(c443.credit, 1800.0);
    });

    test('modification vente : annule puis re-poste (E1)', () async {
      final s = _store();
      final id = await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 10000,
        details: const {'domaine': 'Informatique'},
      );
      final tx = s.transactions.firstWhere((t) => t.id == id);
      final err = await s.majTransaction(tx.copyWith(montant: 20000));
      expect(err, isNull);
      // L'historique (10000 + contre-passation −10000) s'annule,
      // ne reste que la NOUVELLE vente : D411 net = 20000.
      final d411 = s.ecritures
          .where((e) => e.refId == id && e.compte == '411')
          .fold(0.0, (t, e) => t + e.debit - e.credit);
      expect(d411, 20000.0);
      _equilibre(s.ecritures.where((e) => e.refId == id));
    });

    test('suppression vente : solde net nul', () async {
      final s = _store();
      final id = await s.ajouterTransaction(
        type: TypeTransaction.creditCommunication,
        montant: 5000,
        details: const {'operateur': 'Orange'},
      );
      await s.supprimerTransaction(id);
      expect(_net(s, id), moreOrLessEquals(0, epsilon: 0.01));
      expect(
          s.ecritures.any((e) =>
              e.refId == id &&
              e.libelle.startsWith('Contre-passation')),
          isTrue);
    });

    test('charge Loyer : D622/C571 + suppression annule (E2)',
        () async {
      final s = _store();
      await s.ajouterCharge(Charge(
        id: 'x', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer sept', montant: 150000, date: DateTime(2026, 9, 1),
      ));
      final c = s.depenses.first;
      final lignes =
          s.ecritures.where((e) => e.refId == c.id).toList();
      expect(lignes.length, 2);
      _equilibre(lignes);
      expect(lignes.any((e) => e.compte == '622' && e.debit == 150000),
          isTrue);
      await s.supprimerCharge(c.id);
      expect(_net(s, c.id), moreOrLessEquals(0, epsilon: 0.01));
    });

    test('achat : réception + paiement équilibrés, sans double caisse',
        () async {
      final s = _store();
      final a = Achat(
        id: 'a1', numero: 'ACH-2026-00001', boutiqueId: s.boutiqueId,
        fournisseurNom: 'Fourn Test',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble', quantite: 10, prixUnitaire: 1000),
        ],
        date: DateTime(2026, 9, 5),
        statut: Achat.statutValide,
        createdBy: 'u', createdAt: DateTime(2026, 9, 5),
      );
      s.achats.add(a);
      expect(await s.recevoirAchat('a1'), isNull);
      var lignes =
          s.ecritures.where((e) => e.refId == 'a1').toList();
      _equilibre(lignes);
      // Réception : D601 10000 / C401 10000.
      expect(
          lignes
              .where((e) => e.compte == '601')
              .fold(0.0, (t, e) => t + e.debit),
          10000.0);
      expect(await s.payerAchat('a1', 4000, mode: 'especes'), isNull);
      lignes = s.ecritures.where((e) => e.refId == 'a1').toList();
      _equilibre(lignes);
      // Caisse créditée UNE fois (E3 : plus de double OD+BQ).
      final creditCaisse = lignes
          .where((e) => e.compte == '571')
          .fold(0.0, (t, e) => t + e.credit);
      expect(creditCaisse, 4000.0);
    });

    test('annulation achat reçu : solde net nul', () async {
      final s = _store();
      final a = Achat(
        id: 'a2', numero: 'ACH-2026-00002', boutiqueId: s.boutiqueId,
        fournisseurNom: 'Fourn Test',
        lignes: const [
          LigneAchat(
              produitNom: 'Câble', quantite: 5, prixUnitaire: 2000),
        ],
        date: DateTime(2026, 9, 6),
        statut: Achat.statutValide,
        createdBy: 'u', createdAt: DateTime(2026, 9, 6),
      );
      s.achats.add(a);
      expect(await s.recevoirAchat('a2'), isNull);
      expect(await s.annulerAchat('a2', 'erreur commande'), isNull);
      expect(_net(s, 'a2'), moreOrLessEquals(0, epsilon: 0.01));
    });

    test('invariant global D=C après opérations', () async {
      final s = _store();
      await s.ajouterTransaction(
        type: TypeTransaction.forfaitHotspot,
        montant: 2000,
        details: const {'duree': '1 jour'},
      );
      await s.ajouterCharge(Charge(
        id: 'y', boutiqueId: s.boutiqueId, categorie: 'Transport',
        libelle: 'Taxi', montant: 5000, date: DateTime(2026, 9, 7),
      ));
      _equilibre(s.ecritures);
    });
  });
}
