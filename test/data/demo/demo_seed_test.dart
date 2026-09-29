import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/demo/demo_seed.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/boutique.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/company_profile.dart';
import 'package:pme_gestion_pro/models/partenaire.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 6 — demo_seed : volumes + cohérence du jeu de démo.
void main() {
  group('DemoSeed.appliquer', () {
    late List<Boutique> boutiques;
    late List<AppUser> users;
    late CompanyProfile profile;
    late List<Partenaire> partenaires;
    late List<Produit> produits;
    late List<Charge> depenses;
    late List<Tx> transactions;
    var seq = 0;

    setUp(() {
      boutiques = [];
      users = [];
      profile = const CompanyProfile();
      partenaires = [];
      produits = [];
      depenses = [];
      transactions = [];
      seq = 0;
      DemoSeed.appliquer(
        boutiques: boutiques,
        users: users,
        setProfile: (p) => profile = p,
        partenaires: partenaires,
        produits: produits,
        depenses: depenses,
        transactions: transactions,
        genererId: () => 'id${++seq}',
        employeId: 'u_admin',
      );
    });

    test('volumes', () {
      expect(boutiques.length, 2);
      expect(users.length, 1);
      expect(partenaires.length, 2);
      expect(produits.length, 5);
      expect(depenses.length, 3);
      expect(transactions.length, 16);
    });

    test('profil entreprise', () {
      expect(profile.nomEntreprise, contains('TECH-SERVICES'));
      expect(profile.devise, 'FCFA');
      expect(profile.fondsRoulement['bt_siege'], 500000.0);
      expect(profile.budgetsMensuels['Loyer'], 150000.0);
    });

    test('cohérence boutiques', () {
      final ids = {for (final b in boutiques) b.id};
      expect(ids, {'bt_siege', 'bt_marche'});
      for (final p in produits) {
        expect(ids, contains(p.boutiqueId));
      }
      for (final t in transactions) {
        expect(ids, contains(t.boutiqueId));
        expect(t.employeId, 'u_admin');
      }
      for (final c in depenses) {
        expect(ids, contains(c.boutiqueId));
      }
    });

    test('ids uniques', () {
      final ids = [
        for (final c in depenses) c.id,
        for (final t in transactions) t.id,
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('badge Nouveau démo (pr_1 récent)', () {
      final pr1 = produits.firstWhere((p) => p.id == 'pr_1');
      expect(pr1.nouveau, isTrue);
      expect(
          produits
              .where((p) => p.id != 'pr_1')
              .every((p) => !p.nouveau),
          isTrue);
    });
  });
}
