import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';

/// Phase 1 — SessionNotifier isolé (aucune dépendance Notifier).
SessionNotifier _session({Role role = Role.admin}) =>
    SessionNotifier(
        AppUser(id: 'u1', nom: 'Test', role: role));

void main() {
  group('SessionNotifier', () {
    test('role + peut reflètent le user', () {
      final s = _session(role: Role.vendeur);
      expect(s.role, Role.vendeur);
      expect(s.peut(Permission.vendre), isTrue);
      expect(s.peut(Permission.configurer), isFalse);
    });

    test('changerRole conserve id/nom/boutiques', () {
      final s = SessionNotifier(const AppUser(
          id: 'u9', nom: 'Nadia', role: Role.caissier,
          boutiqueIds: ['b1']));
      s.changerRole(Role.gerant);
      expect(s.role, Role.gerant);
      expect(s.user.id, 'u9');
      expect(s.user.nom, 'Nadia');
      expect(s.user.boutiqueIds, ['b1']);
    });

    test('ajouterUtilisateur', () async {
      final s = _session();
      await s.ajouterUtilisateur(const AppUser(
          id: 'u2', nom: 'Ali', role: Role.vendeur));
      expect(s.users.length, 1);
      expect(s.users.first.nom, 'Ali');
    });

    test('majUtilisateur inexistant → sans effet', () async {
      final s = _session();
      await s.majUtilisateur(const AppUser(
          id: 'zz', nom: 'X', role: Role.vendeur));
      expect(s.users, isEmpty);
    });

    test('supprimerUtilisateur protège l\'admin', () async {
      final s = _session();
      await s.ajouterUtilisateur(const AppUser(
          id: 'a1', nom: 'Chef', role: Role.admin));
      await s.ajouterUtilisateur(const AppUser(
          id: 'v1', nom: 'Vendeur', role: Role.vendeur));
      await s.supprimerUtilisateur('a1');
      expect(s.users.length, 2);
      await s.supprimerUtilisateur('v1');
      expect(s.users.length, 1);
    });

    test('supprimerUtilisateur inexistant → sans effet', () async {
      final s = _session();
      await s.supprimerUtilisateur('zz');
      expect(s.users, isEmpty);
    });

    test('monPartenaireId + flags modifiables', () {
      final s = _session();
      s.monPartenaireId = 'pt1';
      s.profilCloudManquant = true;
      s.demarrageHorsLigne = true;
      expect(s.monPartenaireId, 'pt1');
      expect(s.profilCloudManquant, isTrue);
      expect(s.demarrageHorsLigne, isTrue);
    });
  });
}
