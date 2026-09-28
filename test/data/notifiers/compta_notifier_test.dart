import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/compta_notifier.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/ecriture.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 4 — ComptaNotifier (journal immuable, contre-passations).
int _seq = 600;

ComptaNotifier _notifier() => ComptaNotifier(
      genererId: () => 'e${_seq++}',
      ecritures: [],
      boutiqueId: 'b1',
      userId: 'u1',
    );

Tx _vente({double montant = 11800, String id = 'v1'}) => Tx(
    id: id,
    boutiqueId: 'b1',
    employeId: 'u1',
    type: TypeTransaction.prestationService,
    montant: montant,
    date: DateTime(2026, 9, 26, 10),
    clientNom: 'Client');

void main() {
  group('ComptaNotifier journal', () {
    test('comptabiliserVente poste 3 lignes équilibrées', () async {
      final n = _notifier();
      await n.comptabiliserVente(_vente(), 18);
      expect(n.ecrituresBoutique.length, 3);
      final d = n.ecrituresBoutique
          .fold(0.0, (s, e) => s + e.debit);
      final c = n.ecrituresBoutique
          .fold(0.0, (s, e) => s + e.credit);
      expect(d, c);
      expect(n.ecrituresBoutique.every((e) => e.boutiqueId == 'b1'),
          isTrue);
    });

    test('contrePasser annule puis résultat nul', () async {
      final n = _notifier();
      await n.comptabiliserVente(_vente(), 18);
      await n.contrePasser('v1', 'correction vente');
      expect(n.ecrituresBoutique.length, 6);
      expect(n.balance.values.every((v) => v.abs() < 0.01), isTrue);
      expect(n.resultatExercice, moreOrLessEquals(0, epsilon: 0.01));
    });

    test('contrePasser sans origine → rien', () async {
      final n = _notifier();
      await n.contrePasser('zz', 'x');
      expect(n.ecritures, isEmpty);
    });

    test('pointerEcriture : suivi seul, montants intacts', () async {
      final n = _notifier();
      await n.comptabiliserVente(_vente(), 0);
      final id = n.ecrituresBoutique.first.id;
      final avant = n.balance['411'];
      await n.pointerEcriture(id, true);
      expect(
          n.ecrituresBoutique
              .firstWhere((e) => e.id == id)
              .pointee,
          isTrue);
      expect(n.balance['411'], avant);
      await n.pointerEcriture('zz', true); // sans effet
      await n.pointerEcriture(id, false);
      expect(
          n.ecrituresBoutique
              .firstWhere((e) => e.id == id)
              .pointee,
          isFalse);
    });

    test('ecrituresARapprocher : BQ/CA non pointées', () async {
      final n = _notifier();
      await n.comptabiliserVente(_vente(), 0);
      // VT uniquement → rien à rapprocher.
      expect(n.ecrituresARapprocher, isEmpty);
      n.ecritures.add(Ecriture(
          id: 'bq1',
          journal: 'BQ',
          date: DateTime.now(),
          compte: '571',
          libelle: 'Dépôt',
          debit: 1000,
          boutiqueId: 'b1',
          createdBy: 'u1'));
      expect(n.ecrituresARapprocher.length, 1);
      await n.pointerEcriture('bq1', true);
      expect(n.ecrituresARapprocher, isEmpty);
    });

    test('balance + résultat (produits − charges)', () async {
      final n = _notifier();
      await n.comptabiliserVente(_vente(montant: 10000), 0);
      await n.comptabiliserCharge(Charge(
          id: 'c1',
          boutiqueId: 'b1',
          categorie: 'Loyer',
          libelle: 'Loyer',
          montant: 4000,
          date: DateTime(2026, 9, 1)));
      expect(n.balance['411'], 10000.0);
      expect(n.balance['706'], -10000.0);
      expect(n.balance['622'], 4000.0);
      expect(n.resultatExercice, 6000.0);
    });

    test('réception + paiement achat', () async {
      final n = _notifier();
      final a = Achat(
          id: 'a1',
          numero: 'ACH-2026-00001',
          boutiqueId: 'b1',
          fournisseurNom: 'Fourn',
          lignes: const [
            LigneAchat(
                produitNom: 'Câble',
                quantite: 10,
                prixUnitaire: 1000)
          ],
          date: DateTime(2026, 9, 5),
          statut: Achat.statutValide,
          createdBy: 'u1',
          createdAt: DateTime(2026, 9, 5));
      await n.comptabiliserReception(a);
      await n.comptabiliserPaiementAchat(a, 4000, 'especes');
      expect(
          n.ecrituresBoutique
              .where((e) => e.compte == '401')
              .fold(0.0, (s, e) => s + e.debit - e.credit),
          // D401 4000 (paiement) − C401 10000 (dette) = −6000.
          -6000.0);
    });

    test('encaissement BQ équilibré', () async {
      final n = _notifier();
      await n.comptabiliserEncaissement(_vente(montant: 9000));
      final lignes =
          n.ecrituresBoutique.where((e) => e.journal == 'BQ').toList();
      expect(lignes.length, 2);
      expect(
          lignes.fold(0.0, (s, e) => s + e.debit),
          lignes.fold(0.0, (s, e) => s + e.credit));
    });
  });
}
