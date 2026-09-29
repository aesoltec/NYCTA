import '../../models/achat.dart';
import '../../models/charge.dart';
import '../../models/ecriture.dart';
import '../../models/transaction.dart';

/// Construction des écritures SYSCOHADA (Phase 0 — PUR) : partie double,
/// TVA, contre-passation, balance, résultat.
/// Rôle ÉCRITURE seule : génère des lignes (dont 443/445). L'agrégation
/// de ces lignes (TVA par mois, balance, résultat lus depuis le journal)
/// relève de `AnalytiqueService` (rôle LECTURE). Les deux ne sont pas
/// redondants.
/// Extraites à l'identique de `Store` (l.1686-1814). Les ids/boutique/auteur
/// sont fournis par l'appelant (le service ne touche ni clock externe ni
/// I/O — `maintenant` est injecté pour la testabilité).
class ComptaService {
  const ComptaService._();

  /// Vente (journal VT) : D 411 / C 70x + C 443 (TVA du profil).
  /// Mobile Money (journal BQ) : flux caisse ↔ e-float + frais gagnés.
  static List<Ecriture> lignesVente(Tx tx, double tvaProfil,
      String Function() genererId, String boutiqueId, String userId) {
    Ecriture ligne(String journal, String compte, String libelle,
            double debit, double credit) =>
        Ecriture(
            id: genererId(),
            journal: journal,
            date: tx.date,
            compte: compte,
            libelle: libelle,
            debit: debit,
            credit: credit,
            refId: tx.id,
            boutiqueId: boutiqueId,
            createdBy: userId);
    if (tx.type == TypeTransaction.mobileMoney) {
      final op =
          (tx.details['operation']?.toString() ?? '').toLowerCase();
      final frais =
          (tx.details['frais'] as num?)?.toDouble() ?? 0;
      return [
        if (op.startsWith('retrait'))
          ligne('BQ', '571', 'Retrait MoMo ${tx.id}', tx.montant, 0),
        if (op.startsWith('retrait'))
          ligne('BQ', '521', 'Retrait MoMo ${tx.id}', 0, tx.montant),
        if (!op.startsWith('retrait'))
          ligne('BQ', '521', 'Dépôt/Transfert MoMo ${tx.id}',
              tx.montant, 0),
        if (!op.startsWith('retrait'))
          ligne('BQ', '571', 'Dépôt/Transfert MoMo ${tx.id}',
              0, tx.montant),
        if (frais > 0)
          ligne('BQ', '571', 'Frais MoMo ${tx.id}', frais, 0),
        if (frais > 0)
          ligne('BQ', '706', 'Frais MoMo ${tx.id}', 0, frais),
      ];
    }
    final ht =
        tvaProfil > 0 ? tx.montant / (1 + tvaProfil / 100) : tx.montant;
    final tva = tx.montant - ht;
    final cptProduit =
        tx.type == TypeTransaction.venteMateriel ? '701' : '706';
    return [
      ligne('VT', '411',
          'Vente ${tx.id}${tx.clientNom != null ? ' — ${tx.clientNom}' : ''}',
          tx.montant, 0),
      ligne('VT', cptProduit, 'Vente ${tx.id}', 0, ht),
      if (tva > 0.001)
        ligne('VT', '443', 'TVA vente ${tx.id}', 0, tva),
    ];
  }

  /// Réception achat (journal AC) : D 601 HT + D 445 TVA / C 401 TTC.
  static List<Ecriture> lignesReception(Achat a,
      String Function() genererId, String boutiqueId, String userId) {
    Ecriture ligne(String compte, String libelle, double debit,
            double credit) =>
        Ecriture(
            id: genererId(),
            journal: 'AC',
            date: a.date,
            compte: compte,
            libelle: libelle,
            debit: debit,
            credit: credit,
            refId: a.id,
            boutiqueId: boutiqueId,
            createdBy: userId);
    return [
      ligne('601', 'Achat ${a.numero}', a.montantHT, 0),
      if (a.montantTVA > 0.001)
        ligne('445', 'TVA achat ${a.numero}', a.montantTVA, 0),
      ligne('401', 'Dette ${a.fournisseurNom} ${a.numero}',
          0, a.montantTTC),
    ];
  }

  /// Paiement fournisseur (journal BQ) : D 401 / C 571 (ou 521 virement).
  static List<Ecriture> lignesPaiementAchat(
      Achat a,
      double montant,
      String mode,
      String Function() genererId,
      String boutiqueId,
      String userId,
      DateTime maintenant) {
    final caisse = mode == 'virement' ? '521' : '571';
    Ecriture ligne(String compte, String libelle, double debit,
            double credit) =>
        Ecriture(
            id: genererId(),
            journal: 'BQ',
            date: maintenant,
            compte: compte,
            libelle: libelle,
            debit: debit,
            credit: credit,
            refId: a.id,
            boutiqueId: boutiqueId,
            createdBy: userId);
    return [
      ligne('401', 'Paiement ${a.numero} — ${a.fournisseurNom}',
          montant, 0),
      ligne(caisse, 'Paiement ${a.numero}', 0, montant),
    ];
  }

  /// Charge (journal OD) : D 6xx / C 571.
  static List<Ecriture> lignesCharge(Charge c,
      String Function() genererId, String boutiqueId, String userId) {
    Ecriture ligne(String compte, double debit, double credit) =>
        Ecriture(
            id: genererId(),
            journal: 'OD',
            date: c.date,
            compte: compte,
            libelle: c.libelle,
            debit: debit,
            credit: credit,
            refId: c.id,
            boutiqueId: boutiqueId,
            createdBy: userId);
    return [
      ligne(PlanComptable.compteCharge(c.categorie), c.montant, 0),
      ligne('571', 0, c.montant),
    ];
  }

  /// Encaissement crédit (journal BQ) : D 571 / C 411.
  /// Identique à `Store.encaisserVente` (l.1275-1280).
  static List<Ecriture> lignesEncaissement(Tx tx,
      String Function() genererId, String boutiqueId, String userId,
      DateTime maintenant) {
    Ecriture ligne(String compte, double debit, double credit) =>
        Ecriture(
            id: genererId(),
            journal: 'BQ',
            date: maintenant,
            compte: compte,
            libelle: 'Encaissement ${tx.clientNom ?? tx.id}',
            debit: debit,
            credit: credit,
            refId: tx.id,
            boutiqueId: boutiqueId,
            createdBy: userId);
    return [
      ligne('571', tx.montant, 0),
      ligne('411', 0, tx.montant),
    ];
  }

  /// Contre-passation : inverse D/C des écritures liées à [refId].
  /// Identique à `Store._contrePasser` (l.1767-1776).
  static List<Ecriture> contrePassation(
      Iterable<Ecriture> origines,
      String motif,
      String refId,
      String Function() genererId,
      String boutiqueId,
      String userId,
      DateTime maintenant) =>
      [
        for (final o in origines.where((e) => e.refId == refId))
          Ecriture(
              id: genererId(),
              journal: o.journal,
              date: maintenant,
              compte: o.compte,
              libelle: 'Contre-passation : $motif',
              debit: o.credit,
              credit: o.debit,
              refId: refId,
              boutiqueId: boutiqueId,
              createdBy: userId),
      ];

  /// Invariant partie double sur un lot de lignes.
  static bool estEquilibre(Iterable<Ecriture> lignes,
      [double epsilon = 0.01]) {
    final d = lignes.fold(0.0, (s, e) => s + e.debit);
    final c = lignes.fold(0.0, (s, e) => s + e.credit);
    return (d - c).abs() < epsilon;
  }

  /// Balance : solde (D − C) par compte.
  static Map<String, double> balance(Iterable<Ecriture> ecritures) {
    final map = <String, double>{};
    for (final e in ecritures) {
      map[e.compte] = (map[e.compte] ?? 0) + e.solde;
    }
    return map;
  }

  /// Compte de résultat : produits (classe 7) − charges (classe 6).
  static double resultat(Map<String, double> balanceMap) {
    var produits = 0.0, charges = 0.0;
    for (final e in balanceMap.entries) {
      if (e.key.startsWith('7')) produits += -e.value;
      if (e.key.startsWith('6')) charges += e.value;
    }
    return produits - charges;
  }
}
