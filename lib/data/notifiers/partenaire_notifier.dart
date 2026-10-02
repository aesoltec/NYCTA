import 'package:flutter/foundation.dart';
import '../../models/partage.dart';
import '../../models/partenaire.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart';
import '../services/partage_service.dart';

/// Partenaires hotspot (Phase 2 — découpage Store) : fiches + clôture.
/// Rôle : CRUD (anti-doublon accents), désactivation, suppression
/// protégée, clôture mensuelle via `PartageService`.
/// Dépendances : `genererId` injecté ; listes `transactions` et
/// `partages` partagées (garde historique suppression) ; `fileUpsert`
/// injecté (câblé Phase 5, no-op en test).
/// Extrait à l'identique de `Store` (l.2394-2503).
class PartenaireNotifier extends ChangeNotifier {
  final String Function() genererId;
  final List<Tx> transactions;
  final List<Partage> partages;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;

  final List<Partenaire> partenaires;

  PartenaireNotifier({
    required this.genererId,
    required this.transactions,
    required this.partages,
    this.fileUpsert,
    List<Partenaire>? partenaires,
  }) : partenaires = partenaires ?? [];

  Future<String?> ajouterPartenaire(Partenaire p) async {
    if (p.nom.trim().length < 2) return 'Nom requis (2 car. min.)';
    // Fidèle au Store (`_memeLibelle` : casse seule, pas accents).
    if (partenaires.any((x) =>
        x.nom.trim().toLowerCase() == p.nom.trim().toLowerCase())) {
      return '« ${p.nom.trim()} » existe déjà — modifiez sa fiche au lieu de le recréer';
    }
    final partenaire = Partenaire(
      id: genererId(),
      nom: p.nom.trim(),
      telephone: p.telephone.trim(),
      localisation: p.localisation.trim(),
      taux: p.taux,
      actif: p.actif,
    );
    partenaires.add(partenaire);
    notifyListeners();
    await CloudRepository.upsertPartenaire(partenaire);
    await fileUpsert?.call('partenaires', {
      'id': partenaire.id,
      'nom': partenaire.nom,
      'telephone': partenaire.telephone,
      'localisation': partenaire.localisation,
      'taux_partage': partenaire.taux,
      'actif': partenaire.actif,
    });
    return null;
  }

  Future<String?> majPartenaire(Partenaire p) async {
    final i = partenaires.indexWhere((x) => x.id == p.id);
    if (i < 0) return 'Partenaire introuvable';
    // Fidèle au Store (`_memeLibelle` : casse seule).
    if (partenaires.any((x) =>
        x.id != p.id &&
        x.nom.trim().toLowerCase() == p.nom.trim().toLowerCase())) {
      return 'Un autre partenaire porte déjà ce nom';
    }
    partenaires[i] = p;
    notifyListeners();
    await CloudRepository.upsertPartenaire(p);
    await fileUpsert?.call('partenaires', {
      'id': p.id,
      'nom': p.nom,
      'telephone': p.telephone,
      'localisation': p.localisation,
      'taux_partage': p.taux,
      'actif': p.actif,
    });
    return null;
  }

  /// Désactivation (conserve l'historique : ventes et partages).
  Future<void> desactiverPartenaire(String id) async {
    final i = partenaires.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final p = partenaires[i].copyWith(actif: false);
    partenaires[i] = p;
    notifyListeners();
    await CloudRepository.upsertPartenaire(p);
    await fileUpsert?.call(
          'partenaires__update', {'id': p.id, 'actif': false});
  }

  /// Suppression définitive : refusée si ventes ou clôtures.
  Future<String?> supprimerPartenaire(String id) async {
    final i = partenaires.indexWhere((x) => x.id == id);
    if (i < 0) return 'Partenaire introuvable';
    final aVendu = transactions.any((t) => t.partenaireId == id);
    final aCloture = partages.any((p) => p.partenaireId == id);
    if (aVendu || aCloture) {
      return 'Ce partenaire a un historique (ventes/clôtures) — désactivez-le plutôt pour le conserver';
    }
    partenaires.removeAt(i);
    notifyListeners();
    await CloudRepository.supprimerPartenaire(id);
    // Suppression : la file doit rejouer une SUPPRESSION. Un
    // `{id, actif: false}` passe par `upsert` recraitait la ligne
    // qu'on vient de supprimer (ou tentait de la creer, 23502).
    await fileUpsert?.call('partenaires__delete', {'id': id});
    return null;
  }

  List<Partage> partagesDe(String partenaireId) => partages
      .where((p) => p.partenaireId == partenaireId)
      .toList();

  bool partageExiste(String partenaireId, String mois) => partages.any(
      (p) => p.partenaireId == partenaireId && p.mois == mois);

  Future<Partage> cloturerMois(
      String partenaireId, String mois, String boutiqueId) async {
    final partenaire =
        partenaires.firstWhere((p) => p.id == partenaireId);
    if (CloudRepository.actif) {
      final res = await CloudRepository.cloturer(
          partenaireId, boutiqueId, mois);
      if (res == null) {
        throw StateError('Clôture impossible (réseau ou déjà clôturé)');
      }
      final pg = Partage.calculer(
        id: res['id'].toString(),
        partenaireId: partenaireId,
        mois: mois,
        totalVentes: (res['total_ventes'] as num).toDouble(),
        taux: (res['taux_partage'] as num).toDouble(),
      );
      partages.insert(0, pg);
      notifyListeners();
      return pg;
    }
    final total =
        PartageService.totalVentes(transactions, partenaireId, mois);
    final pg = PartageService.cloturer(
      id: genererId(),
      partenaireId: partenaireId,
      mois: mois,
      totalVentes: total,
      taux: partenaire.taux,
    );
    partages.insert(0, pg);
    notifyListeners();
    return pg;
  }
}
