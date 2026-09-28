import 'package:flutter/foundation.dart';
import '../../models/boutique.dart';
import '../../models/enums.dart';
import '../../services/cloud_repository.dart';
import 'session_notifier.dart';

/// Boutiques (Phase 1 — découpage Store).
/// Rôle : liste, boutique courante, CRUD + siège + fermeture/réouverture.
/// Dépendances : `SessionNotifier` (user, rôle, accès).
/// Extrait à l'identique de `Store` (l.688-701, l.1195-1280) ; `_nid`
/// devient `genererId` injecté (testabilité).
class BoutiqueNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;

  final List<Boutique> boutiques;
  String boutiqueId;

  BoutiqueNotifier({
    required this.session,
    required this.genererId,
    List<Boutique>? boutiques,
    this.boutiqueId = '',
  }) : boutiques = boutiques ?? [];

  Boutique get boutiqueCourante =>
      boutiques.firstWhere((b) => b.id == boutiqueId);

  List<Boutique> get boutiquesActives =>
      boutiques.where((b) => b.actif).toList();

  /// Boutiques actives que l'utilisateur courant peut choisir
  /// (garde anti-ventes-fantômes : voir `Store.boutiquesAccessibles`).
  List<Boutique> get boutiquesAccessibles => boutiquesActives
      .where((b) => session.user.accedeA(b.id))
      .toList();

  void changerBoutique(String id) {
    if (!session.user.accedeA(id)) return;
    boutiqueId = id;
    notifyListeners();
  }

  Future<String?> ajouterBoutique(
      Boutique b, List<String> userIds) async {
    if (b.nom.trim().length < 2) return 'Nom trop court';
    if (boutiques.any((x) =>
        x.actif && x.nom.toLowerCase() == b.nom.trim().toLowerCase())) {
      return 'Une boutique porte déjà ce nom';
    }
    if (b.siege) {
      for (var i = 0; i < boutiques.length; i++) {
        if (boutiques[i].siege) {
          boutiques[i] = boutiques[i].copyWith(siege: false);
        }
      }
    }
    final boutique = Boutique(
      id: genererId(),
      nom: b.nom,
      adresse: b.adresse,
      siege: b.siege,
      actif: b.actif,
    );
    boutiques.add(boutique);
    notifyListeners();
    await CloudRepository.upsertBoutique(boutique, userIds);
    return null;
  }

  Future<String?> majBoutique(
      Boutique b, List<String> userIds) async {
    final i = boutiques.indexWhere((x) => x.id == b.id);
    if (i < 0) return 'Boutique introuvable';
    if (b.siege) {
      for (var j = 0; j < boutiques.length; j++) {
        if (boutiques[j].siege && boutiques[j].id != b.id) {
          boutiques[j] = boutiques[j].copyWith(siege: false);
        }
      }
    }
    boutiques[i] = b;
    notifyListeners();
    await CloudRepository.upsertBoutique(b, userIds);
    return null;
  }

  /// Désactivation (jamais de suppression dure). Dernière active protégée.
  Future<String?> fermerBoutique(String id) async {
    if (boutiquesActives.length <= 1) {
      return 'Impossible : il doit rester au moins une boutique active.';
    }
    if (id == boutiqueId) {
      return 'Changez d\'abord de boutique courante (menu en haut).';
    }
    final i = boutiques.indexWhere((x) => x.id == id);
    if (i < 0) return 'Boutique introuvable';
    boutiques[i] = boutiques[i].copyWith(actif: false, siege: false);
    notifyListeners();
    await CloudRepository.desactiverBoutique(id);
    return null;
  }

  /// Réouverture (point 22bis) : admin/gérant uniquement.
  Future<String?> rouvrirBoutique(String id) async {
    if (session.role != Role.admin && session.role != Role.gerant) {
      return 'Réouverture réservée (admin, gérant)';
    }
    final i = boutiques.indexWhere((x) => x.id == id);
    if (i < 0) return 'Boutique introuvable';
    if (boutiques[i].actif) return 'Boutique déjà active';
    final erreur = await CloudRepository.rouvrirBoutique(id);
    if (erreur != null) return erreur;
    boutiques[i] = boutiques[i].copyWith(actif: true);
    notifyListeners();
    return null;
  }
}
