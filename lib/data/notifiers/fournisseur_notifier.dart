import 'package:flutter/foundation.dart';
import '../../models/fournisseur.dart';
import '../../services/cloud_repository.dart';

/// Fournisseurs (Phase 2 — découpage Store) : fichier global.
/// Rôle : CRUD + anti-doublon nom (insensible casse).
/// Dépendances : `genererId` injecté.
/// Extrait à l'identique de `Store` (l.929-957).
class FournisseurNotifier extends ChangeNotifier {
  final String Function() genererId;

  final List<Fournisseur> fournisseurs = [];

  FournisseurNotifier({required this.genererId});

  Future<String?> ajouterFournisseur(Fournisseur f) async {
    if (f.nom.trim().length < 2) return 'Nom trop court';
    if (fournisseurs.any((x) =>
        x.nom.toLowerCase() == f.nom.trim().toLowerCase())) {
      return 'Ce fournisseur existe déjà';
    }
    final fournisseur = Fournisseur(
      id: genererId(),
      nom: f.nom,
      telephone: f.telephone,
      email: f.email,
      adresse: f.adresse,
      specialite: f.specialite,
      notes: f.notes,
    );
    fournisseurs.add(fournisseur);
    notifyListeners();
    await CloudRepository.upsertFournisseur(fournisseur);
    return null;
  }

  Future<void> majFournisseur(Fournisseur f) async {
    final i = fournisseurs.indexWhere((x) => x.id == f.id);
    if (i >= 0) {
      fournisseurs[i] = f;
      notifyListeners();
      await CloudRepository.upsertFournisseur(f);
    }
  }

  Future<void> supprimerFournisseur(String id) async {
    fournisseurs.removeWhere((f) => f.id == id);
    notifyListeners();
    await CloudRepository.supprimerFournisseur(id);
  }
}
