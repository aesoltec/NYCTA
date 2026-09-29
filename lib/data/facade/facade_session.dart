// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/app_user.dart';
import '../../models/enums.dart';

/// Façade StoreSessionFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreSessionFacade on Store {
  // ---------- Utilisateurs (gestion, délégué à `session`) ----------
  Role get role => session.role;
  bool peut(Permission p) => session.peut(p);

  void changerRole(Role r) => session.changerRole(r);

  Future<void> ajouterUtilisateur(AppUser u) =>
      session.ajouterUtilisateur(u);

  Future<void> majUtilisateur(AppUser u) =>
      session.majUtilisateur(u);

  Future<void> supprimerUtilisateur(String id) =>
      session.supprimerUtilisateur(id);

}
