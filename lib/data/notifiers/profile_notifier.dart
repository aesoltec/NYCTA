import 'package:flutter/foundation.dart';
import '../../models/company_profile.dart';
import '../../services/cloud_repository.dart';

/// Profil entreprise (Phase 1 — découpage Store).
/// Rôle : état `CompanyProfile` + écriture + helpers budgets/fonds.
/// Dépendances : AUCUNE (testable en isolation).
/// Extrait à l'identique de `Store` (l.1283-1287, l.1639-1642) ; les
/// helpers `definirBudget`/`definirFonds`/`supprimerBudget` factorisent
/// les `profile.copyWith(...)` épars des écrans (config, trésorerie).
class ProfileNotifier extends ChangeNotifier {
  CompanyProfile profile;

  ProfileNotifier([this.profile = const CompanyProfile()]);

  Future<void> updateProfile(CompanyProfile p) async {
    profile = p;
    notifyListeners();
    await CloudRepository.updateProfile(p);
  }

  Future<void> definirFonds(String boutiqueId, double montant) =>
      updateProfile(profile.copyWith(
        fondsRoulement: {...profile.fondsRoulement, boutiqueId: montant},
      ));

  Future<void> definirBudget(String categorie, double montant) =>
      updateProfile(profile.copyWith(
        budgetsMensuels: {...profile.budgetsMensuels, categorie: montant},
      ));

  Future<void> supprimerBudget(String categorie) async {
    final budgets = Map<String, double>.of(profile.budgetsMensuels);
    budgets.remove(categorie);
    await updateProfile(profile.copyWith(budgetsMensuels: budgets));
  }
}
