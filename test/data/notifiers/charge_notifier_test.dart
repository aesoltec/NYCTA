import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/charge_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/profile_notifier.dart';
import 'package:pme_gestion_pro/models/charge.dart';

/// Phase 2 — ChargeNotifier (ProfileNotifier + callbacks compta injectés).
({ChargeNotifier n, List<String> appels}) _notifier() {
  final appels = <String>[];
  final n = ChargeNotifier(
    genererId: () => 'c${appels.length}${DateTime.now().microsecondsSinceEpoch}',
    profile: ProfileNotifier(),
    comptabiliser: (c) async {
      appels.add('compta:${c.id}');
    },
    contrePasser: (ref, motif) async {
      appels.add('contre:$ref:$motif');
    },
    boutiqueId: 'b1',
  );
  return (n: n, appels: appels);
}

Charge _charge(String libelle, double montant) => Charge(
    id: '',
    boutiqueId: 'b1',
    categorie: 'Loyer',
    libelle: libelle,
    montant: montant,
    date: DateTime(2026, 9, 10));

void main() {
  group('ChargeNotifier CRUD + compta', () {
    test('ajouter → comptabilise', () async {
      final (:n, :appels) = _notifier();
      await n.ajouterCharge(_charge('Loyer sept', 150000));
      expect(n.depensesBoutique.length, 1);
      expect(appels.length, 1);
      expect(appels.first.startsWith('compta:'), isTrue);
    });

    test('maj : validations + contre-passe + re-poste', () async {
      final (:n, :appels) = _notifier();
      await n.ajouterCharge(_charge('Loyer', 150000));
      final id = n.depensesBoutique.first.id;
      expect(
          await n.majCharge(Charge(
              id: 'zz',
              boutiqueId: 'b1',
              categorie: 'X',
              libelle: 'Y',
              montant: 1,
              date: DateTime.now())),
          'Dépense introuvable');
      expect(
          await n.majCharge(Charge(
              id: id,
              boutiqueId: 'b1',
              categorie: 'X',
              libelle: '',
              montant: 1,
              date: DateTime.now())),
          'Libellé requis');
      expect(
          await n.majCharge(Charge(
              id: id,
              boutiqueId: 'b1',
              categorie: 'X',
              libelle: 'Y',
              montant: 0,
              date: DateTime.now())),
          'Le montant doit être > 0');
      expect(
          await n.majCharge(Charge(
              id: id,
              boutiqueId: 'b1',
              categorie: 'Loyer',
              libelle: 'Loyer maj',
              montant: 160000,
              date: DateTime(2026, 9, 10))),
          isNull);
      expect(
          appels,
          containsAll([
            'contre:$id:correction dépense',
          ]));
      expect(appels.where((a) => a.startsWith('compta:')).length, 2);
    });

    test('supprimer → contre-passe', () async {
      final (:n, :appels) = _notifier();
      await n.ajouterCharge(_charge('Loyer', 150000));
      final id = n.depensesBoutique.first.id;
      await n.supprimerCharge(id);
      expect(n.depenses, isEmpty);
      expect(appels, contains('contre:$id:charge supprimée'));
    });

    test('totaux mois + suivi budgets', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      await n.profile.definirBudget('Loyer', 200000);
      await n.ajouterCharge(_charge('Loyer sept', 150000));
      await n.ajouterCharge(Charge(
          id: '',
          boutiqueId: 'b1',
          categorie: 'Autre',
          libelle: 'X',
          montant: 5000,
          date: DateTime(2026, 9, 11)));
      expect(n.totalDepensesMois('2026-09'), 155000.0);
      expect(n.depensesCategorieMois('Loyer', '2026-09'), 150000.0);
      expect(n.suiviBudgets('2026-09')['Loyer'], (200000.0, 150000.0));
    });

    test('récurrentes : un modèle → une copie, anti-double', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      await n.ajouterCharge(Charge(
          id: '',
          boutiqueId: 'b1',
          categorie: 'Loyer',
          libelle: 'Loyer',
          montant: 150000,
          date: DateTime(2026, 8, 1),
          recurrente: true));
      await n.genererChargesRecurrentesSiNouveauMois('2026-09');
      expect(
          n.depenses.where((c) => c.libelle == 'Loyer').length, 2);
      // Rejoué : pas de doublon (mois déjà marqué).
      await n.genererChargesRecurrentesSiNouveauMois('2026-09');
      expect(
          n.depenses.where((c) => c.libelle == 'Loyer').length, 2);
      // Modèle déjà dans le mois → pas de copie.
      await n.genererChargesRecurrentesSiNouveauMois('2026-08');
      expect(n.profile.profile.moisChargesGenerees, '2026-08');
    });
  });
}
