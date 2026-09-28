import 'package:flutter/foundation.dart';
import '../../models/achat.dart';
import '../../models/charge.dart';
import '../../models/ecriture.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart';
import '../services/compta_service.dart';

/// Comptabilité SYSCOHADA (Phase 4 — découpage Store) : journal immuable,
/// balance, résultat, rapprochement.
/// Rôle : état `ecritures`, postage, contre-passations, pointage.
/// Dépendances : `genererId` injecté ; `boutiqueId` et `userId` mutables
/// (façade Phase 5) ; liste `ecritures` partagée ; `fileUpsert` injecté
/// (câblé Phase 5, no-op en test). Génération via `ComptaService`.
/// Extrait à l'identique de `Store` (l.1658-1814) : journal immuable
/// (corrections par contre-écriture uniquement, jamais update/delete).
class ComptaNotifier extends ChangeNotifier {
  final String Function() genererId;
  final List<Ecriture> ecritures;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;
  String boutiqueId;
  String userId;

  ComptaNotifier({
    required this.genererId,
    required this.ecritures,
    this.fileUpsert,
    this.boutiqueId = '',
    this.userId = '',
  });

  List<Ecriture> get ecrituresBoutique =>
      ecritures.where((e) => e.boutiqueId == boutiqueId).toList();

  Future<void> poster(List<Ecriture> lignes) async {
    ecritures.insertAll(0, lignes);
    notifyListeners();
    for (final e in lignes) {
      await CloudRepository.upsertEcriture(e);
      await fileUpsert?.call('ecritures', _payload(e));
    }
  }

  Map<String, dynamic> _payload(Ecriture e) => {
        'id': e.id,
        'journal': e.journal,
        'date_ecriture': e.date.toIso8601String(),
        'compte': e.compte,
        'libelle': e.libelle,
        'debit': e.debit,
        'credit': e.credit,
        'ref_id': e.refId.isEmpty ? null : e.refId,
        'boutique_id': e.boutiqueId,
        'pointee': e.pointee,
      };

  Ecriture ligne(String journal, DateTime date, String compte,
          String libelle, double debit, double credit, String refId) =>
      Ecriture(
        id: genererId(),
        journal: journal,
        date: date,
        compte: compte,
        libelle: libelle,
        debit: debit,
        credit: credit,
        refId: refId,
        boutiqueId: boutiqueId,
        createdBy: userId,
      );

  Future<void> comptabiliserVente(Tx tx, double tvaProfil) =>
      poster(ComptaService.lignesVente(
          tx, tvaProfil, genererId, boutiqueId, userId));

  Future<void> comptabiliserReception(Achat a) => poster(
      ComptaService.lignesReception(a, genererId, boutiqueId, userId));

  Future<void> comptabiliserPaiementAchat(
          Achat a, double montant, String mode) =>
      poster(ComptaService.lignesPaiementAchat(
          a, montant, mode, genererId, boutiqueId, userId, DateTime.now()));

  Future<void> comptabiliserCharge(Charge c) => poster(
      ComptaService.lignesCharge(c, genererId, boutiqueId, userId));

  Future<void> comptabiliserEncaissement(Tx tx) => poster(
      ComptaService.lignesEncaissement(
          tx, genererId, boutiqueId, userId, DateTime.now()));

  /// Contre-passation : inverse D/C de toutes les écritures liées à
  /// [refId], avec motif. L'original reste lisible (audit trail).
  Future<void> contrePasser(String refId, String motif) async {
    final lignes = ComptaService.contrePassation(ecritures, motif,
        refId, genererId, boutiqueId, userId, DateTime.now());
    if (lignes.isEmpty) return;
    await poster(lignes);
  }

  /// Rapprochement bancaire : pointe/dépointe une écriture. Ce n'est pas
  /// une correction comptable : aucun montant ne change.
  Future<void> pointerEcriture(String id, bool pointee) async {
    final i = ecritures.indexWhere((e) => e.id == id);
    if (i < 0) return;
    ecritures[i] = ecritures[i].copyWith(pointee: pointee);
    notifyListeners();
    await CloudRepository.upsertEcriturePointee(id, pointee);
    await fileUpsert?.call('ecritures', _payload(ecritures[i]));
  }

  /// Écritures non rapprochées (journal BQ : banque/caisse).
  List<Ecriture> get ecrituresARapprocher => ecrituresBoutique
      .where((e) => (e.journal == 'BQ' || e.journal == 'CA') && !e.pointee)
      .toList();

  /// Balance : solde (D − C) par compte, boutique courante.
  Map<String, double> get balance =>
      ComptaService.balance(ecrituresBoutique);

  /// Compte de résultat simplifié : produits (classe 7) − charges (6).
  double get resultatExercice => ComptaService.resultat(balance);
}
