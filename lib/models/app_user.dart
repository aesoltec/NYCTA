import 'enums.dart';

class AppUser {
  final String id;
  final String nom;
  final Role role;
  final List<String> boutiqueIds;
  /// Fiche Partenaire liée à ce compte — renseigné uniquement si
  /// role == Role.partenaire (voir écran Utilisateurs). Sans ce lien,
  /// l'espace partenaire ne peut pas savoir quelles ventes lui appartiennent.
  final String? partenaireId;

  const AppUser({
    required this.id,
    required this.nom,
    this.role = Role.admin,
    this.boutiqueIds = const [],
    this.partenaireId,
  });

  bool accedeA(String boutiqueId) =>
      role == Role.admin || boutiqueIds.contains(boutiqueId);

  /// Vrai si le rôle possède la permission (matrice rolePermissions).
  bool peut(Permission p) => rolePermissions[role]?.contains(p) ?? false;
}
