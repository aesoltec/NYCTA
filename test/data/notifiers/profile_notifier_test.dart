import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/profile_notifier.dart';

/// Phase 1 — ProfileNotifier isolé (aucune dépendance Notifier).
void main() {
  group('ProfileNotifier', () {
    test('profil par défaut', () {
      final n = ProfileNotifier();
      expect(n.profile.nomEntreprise, 'Mon Entreprise');
      expect(n.profile.devise, 'FCFA');
    });

    test('updateProfile remplace', () async {
      final n = ProfileNotifier();
      await n.updateProfile(
          n.profile.copyWith(nomEntreprise: 'SARL Test', tva: 18));
      expect(n.profile.nomEntreprise, 'SARL Test');
      expect(n.profile.tva, 18.0);
    });

    test('definirFonds fusionne par boutique', () async {
      final n = ProfileNotifier();
      await n.definirFonds('b1', 50000);
      await n.definirFonds('b2', 30000);
      expect(n.profile.fondsRoulement['b1'], 50000.0);
      expect(n.profile.fondsRoulement['b2'], 30000.0);
      await n.definirFonds('b1', 60000);
      expect(n.profile.fondsRoulement['b1'], 60000.0);
      expect(n.profile.fondsRoulement.length, 2);
    });

    test('definirBudget fusionne par catégorie', () async {
      final n = ProfileNotifier();
      await n.definirBudget('Loyer', 150000);
      expect(n.profile.budgetsMensuels['Loyer'], 150000.0);
    });

    test('supprimerBudget retire sans toucher le reste', () async {
      final n = ProfileNotifier();
      await n.definirBudget('Loyer', 150000);
      await n.definirBudget('Salaires', 400000);
      await n.supprimerBudget('Loyer');
      expect(n.profile.budgetsMensuels.containsKey('Loyer'), isFalse);
      expect(n.profile.budgetsMensuels['Salaires'], 400000.0);
    });

    test('supprimerBudget inexistant → sans effet', () async {
      final n = ProfileNotifier();
      await n.supprimerBudget('ZZZ');
      expect(n.profile.budgetsMensuels, isEmpty);
    });
  });
}
