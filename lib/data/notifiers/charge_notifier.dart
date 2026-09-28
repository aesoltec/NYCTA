import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../models/charge.dart';
import '../../services/cloud_repository.dart';
import 'profile_notifier.dart';

/// Charges / dépenses (Phase 2 — découpage Store) : CRUD + récurrentes.
/// Rôle : dépenses par boutique, génération mensuelle anti-double,
/// suivi budgets (budget, consommé).
/// Dépendances : `ProfileNotifier` (budgets, mois généré) ;
/// `genererId` injecté ; `boutiqueId` mutable (façade Phase 5) ;
/// callbacks compta `comptabiliser`/`contrePasser` injectés
/// (câblés Phase 5 sur ComptaService+poster, no-op en test).
/// Extrait à l'identique de `Store` (l.1530-1635).
class ChargeNotifier extends ChangeNotifier {
  final String Function() genererId;
  final ProfileNotifier profile;
  final Future<void> Function(Charge charge)? comptabiliser;
  final Future<void> Function(String refId, String motif)? contrePasser;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;
  String boutiqueId;

  final List<Charge> depenses;

  ChargeNotifier({
    required this.genererId,
    required this.profile,
    this.comptabiliser,
    this.contrePasser,
    this.fileUpsert,
    this.boutiqueId = '',
    List<Charge>? depenses,
  }) : depenses = depenses ?? [];

  Map<String, dynamic> _payload(Charge c) => {
        'id': c.id,
        'boutique_id': c.boutiqueId,
        'categorie': c.categorie,
        'libelle': c.libelle,
        'montant': c.montant,
        'date_charge': c.date.toIso8601String(),
        'recurrente': c.recurrente,
      };

  List<Charge> get depensesBoutique =>
      depenses.where((c) => c.boutiqueId == boutiqueId).toList();

  Future<void> ajouterCharge(Charge c) async {
    final charge = Charge(
      id: genererId(),
      boutiqueId: c.boutiqueId,
      categorie: c.categorie,
      libelle: c.libelle,
      montant: c.montant,
      date: c.date,
      recurrente: c.recurrente,
    );
    depenses.insert(0, charge);
    notifyListeners();
    await CloudRepository.upsertCharge(charge);
    await fileUpsert?.call('charges', _payload(charge));
    await comptabiliser?.call(charge);
  }

  Future<String?> majCharge(Charge maj) async {
    final i = depenses.indexWhere((c) => c.id == maj.id);
    if (i < 0) return 'Dépense introuvable';
    if (maj.libelle.trim().isEmpty) return 'Libellé requis';
    if (maj.montant <= 0) return 'Le montant doit être > 0';
    depenses[i] = maj;
    notifyListeners();
    await CloudRepository.upsertCharge(maj);
    await fileUpsert?.call('charges', _payload(maj));
    // Correction = contre-passation de l'ancienne + nouvelle écriture.
    await contrePasser?.call(maj.id, 'correction dépense');
    await comptabiliser?.call(maj);
    return null;
  }

  Future<void> supprimerCharge(String id) async {
    depenses.removeWhere((c) => c.id == id);
    notifyListeners();
    await CloudRepository.supprimerCharge(id);
    // Comme les ventes : annulation par contre-écriture (point 30).
    await contrePasser?.call(id, 'charge supprimée');
  }

  List<Charge> depensesMois(String moisKey) => depensesBoutique
      .where((c) => C.moisKey(c.date) == moisKey)
      .toList();

  double totalDepensesMois(String moisKey) =>
      depensesMois(moisKey).fold(0.0, (s, c) => s + c.montant);

  double depensesCategorieMois(String categorie, String moisKey) =>
      depensesMois(moisKey)
          .where((c) => c.categorie == categorie)
          .fold(0.0, (s, c) => s + c.montant);

  Map<String, (double, double)> suiviBudgets(String moisKey) {
    final map = <String, (double, double)>{};
    for (final entry in profile.profile.budgetsMensuels.entries) {
      if (entry.value > 0) {
        map[entry.key] =
            (entry.value, depensesCategorieMois(entry.key, moisKey));
      }
    }
    return map;
  }

  /// Charges récurrentes : recopie à chaque nouveau mois (anti-double :
  /// un seul modèle par (boutique, catégorie, libellé), le plus récent).
  Future<void> genererChargesRecurrentesSiNouveauMois(
      String moisKey) async {
    if (profile.profile.moisChargesGenerees == moisKey) return;
    final parModele = <String, Charge>{};
    for (final c in depenses.where((c) => c.recurrente)) {
      final cle = '${c.boutiqueId}|${c.categorie}|${c.libelle}';
      final actuel = parModele[cle];
      if (actuel == null || c.date.isAfter(actuel.date)) {
        parModele[cle] = c;
      }
    }
    for (final c in parModele.values) {
      if (C.moisKey(c.date) == moisKey) continue;
      final charge = Charge(
        id: genererId(),
        boutiqueId: c.boutiqueId,
        categorie: c.categorie,
        libelle: c.libelle,
        montant: c.montant,
        date: DateTime.now(),
        recurrente: true,
      );
      depenses.insert(0, charge);
      await CloudRepository.upsertCharge(charge);
      await comptabiliser?.call(charge);
    }
    await profile.updateProfile(profile.profile
        .copyWith(moisChargesGenerees: moisKey));
    notifyListeners();
  }
}
