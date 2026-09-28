import 'package:flutter/foundation.dart';
import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../services/cloud_repository.dart';

/// Session + utilisateurs (Phase 1 — découpage Store).
/// Rôle : identité connectée, rôle/permissions, CRUD des comptes.
/// Dépendances : AUCUNE (testable en isolation).
/// Extrait à l'identique de `Store` (l.62, l.722-756) : `notifyListeners`
/// sans persistance différée (pas de timer ici — la façade s'en charge).
class SessionNotifier extends ChangeNotifier {
  AppUser user;
  String? monPartenaireId;
  bool profilCloudManquant = false;
  bool demarrageHorsLigne = false;

  final List<AppUser> users;

  SessionNotifier(this.user,
      {this.monPartenaireId, List<AppUser>? users})
      : users = users ?? [];

  Role get role => user.role;
  bool peut(Permission p) => user.peut(p);

  void changerRole(Role r) {
    user = AppUser(
        id: user.id,
        nom: user.nom,
        role: r,
        boutiqueIds: user.boutiqueIds);
    notifyListeners();
  }

  Future<void> ajouterUtilisateur(AppUser u) async {
    users.add(u);
    notifyListeners();
  }

  Future<void> majUtilisateur(AppUser u) async {
    final i = users.indexWhere((x) => x.id == u.id);
    if (i >= 0) {
      users[i] = u;
      notifyListeners();
      await CloudRepository.majUtilisateur(u);
    }
  }

  /// "Supprimer" = désactivation (l'anon key ne peut pas supprimer un
  /// compte Auth). L'admin est protégé (jamais désactivable).
  Future<void> supprimerUtilisateur(String id) async {
    final u = users.where((x) => x.id == id).firstOrNull;
    if (u == null || u.role == Role.admin) return;
    users.removeWhere((x) => x.id == id);
    notifyListeners();
    await CloudRepository.desactiverUtilisateur(id);
  }
}
