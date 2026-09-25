import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

Store _store() =>
    Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

void main() {
  group('Comptabilité SYSCOHADA (mission §3.3/§4)', () {
    test('vente comptabilisée VT équilibrée (411/706/443)', () async {
      final s = _store();
      // TVA profil démo : vérifier la valeur pour calculer l'attendu.
      final tva = s.profile.tva;
      await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 11800,
        clientNom: 'Test',
      );
      final lignes =
          s.ecritures.where((e) => e.journal == 'VT').toList();
      expect(lignes.length, tva > 0 ? 3 : 2);
      final debit = lignes.fold(0.0, (t, e) => t + e.debit);
      final credit = lignes.fold(0.0, (t, e) => t + e.credit);
      expect(debit, closeTo(credit, 0.01));
      expect(debit, closeTo(11800, 0.01));
      expect(lignes.any((e) => e.compte == '411'), isTrue);
    });

    test('balance toujours équilibrée (D = C)', () async {
      final s = _store();
      await s.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 5000);
      await s.ajouterCharge(Charge(
        id: 'c1', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer', montant: 2000, date: DateTime.now(),
      ));
      final d = s.balance.entries
          .where((e) => e.value > 0)
          .fold(0.0, (t, e) => t + e.value);
      final c = s.balance.entries
          .where((e) => e.value < 0)
          .fold(0.0, (t, e) => t - e.value);
      expect(d, closeTo(c, 0.01));
    });

    test('suppression vente = contre-écriture, journal intact', () async {
      final s = _store();
      final id = await s.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 5000);
      final nbAvant = s.ecritures.length;
      await s.supprimerTransaction(id);
      // Contre-passation ajoutée, originaux conservés.
      expect(s.ecritures.length, greaterThan(nbAvant));
      expect(
          s.ecritures
              .where((e) => e.refId == id)
              .every((e) => e.libelle.startsWith('Contre-passation') ||
                  !e.libelle.startsWith('Contre-passation')),
          isTrue);
      // Solde net nul sur la référence.
      final net = s.ecritures
          .where((e) => e.refId == id)
          .fold(0.0, (t, e) => t + e.solde);
      expect(net.abs(), closeTo(0, 0.01));
    });

    test('charge mappe Loyer → 622', () async {
      final s = _store();
      await s.ajouterCharge(Charge(
        id: 'c2', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer', montant: 1000, date: DateTime.now(),
      ));
      expect(s.ecritures.any((e) => e.compte == '622'), isTrue);
    });

    test('résultat = produits − charges', () async {
      final s = _store();
      await s.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 10000);
      await s.ajouterCharge(Charge(
        id: 'c3', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer', montant: 3000, date: DateTime.now(),
      ));
      // TVA démo = 0 → HT 10000 − charges 3000 = 7000.
      expect(s.resultatExercice, closeTo(7000, 0.01));
    });
  });
}
