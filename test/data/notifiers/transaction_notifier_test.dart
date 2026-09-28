import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/transaction_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 3 — TransactionNotifier (callbacks compta injectés).
({TransactionNotifier n, List<String> appels}) _notifier(
    {Role role = Role.admin}) {
  final appels = <String>[];
  final n = TransactionNotifier(
    session: SessionNotifier(
        AppUser(id: 'u1', nom: 'T', role: role)),
    genererId: () => 'tx${appels.length}',
    transactions: [],
    produits: [
      const Produit(
          id: 'p1',
          boutiqueId: 'b1',
          libelle: 'Câble',
          categorie: 'A',
          prixAchat: 1000,
          prixVente: 1500,
          stock: 10),
    ],
    comptabiliserVente: (tx) async {
      appels.add('compta:${tx.id}');
    },
    contrePasser: (ref, motif) async {
      appels.add('contre:$ref:$motif');
    },
    posterEncaissement: (tx) async {
      appels.add('encaisse:${tx.id}');
    },
    boutiqueId: 'b1',
  );
  return (n: n, appels: appels);
}

void main() {
  group('TransactionNotifier CRUD', () {
    test('ajouter → comptabilise + id retourné', () async {
      final (:n, :appels) = _notifier();
      final id = await n.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 10000,
        cout: 1000,
        clientNom: 'Moussa',
        details: const {'domaine': 'Info'},
      );
      expect(id, isNotEmpty);
      expect(n.txBoutique.length, 1);
      expect(n.txBoutique.first.employeId, 'u1');
      expect(appels, ['compta:$id']);
    });

    test('maj : validations + contre-passe + re-poste', () async {
      final (:n, :appels) = _notifier();
      final id = await n.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 10000);
      final tx = n.transactions.first;
      expect(await n.majTransaction(tx.copyWith(montant: 0)),
          'Le montant doit être > 0');
      expect(
          await n.majTransaction(tx.copyWith(montant: 1, cout: -1)),
          'Le coût ne peut pas être négatif');
      expect(
          await n.majTransaction(
              tx.copyWith(id: 'zz', montant: 1)),
          'Vente introuvable');
      expect(await n.majTransaction(tx.copyWith(montant: 12000)),
          isNull);
      expect(n.transactions.first.montant, 12000.0);
      expect(appels, ['compta:$id', 'contre:$id:correction vente',
        'compta:$id']);
    });

    test('supprimer matériel : restaure le stock + contre-passe',
        () async {
      final (:n, :appels) = _notifier();
      final id = await n.ajouterTransaction(
        type: TypeTransaction.venteMateriel,
        montant: 3000,
        cout: 2000,
        details: {
          'lignes': [
            {'produitId': 'p1', 'quantite': 2}
          ]
        },
      );
      await n.supprimerTransaction(id);
      expect(n.transactions, isEmpty);
      expect(n.produits.first.stock, 12);
      expect(appels, contains('contre:$id:vente supprimée'));
      await n.supprimerTransaction('zz'); // sans effet
    });

    test('supprimer non-matériel : pas de touche stock', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      final id = await n.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 5000);
      await n.supprimerTransaction(id);
      expect(n.produits.first.stock, 10);
    });
  });

  group('TransactionNotifier crédit', () {
    test('encaisser : gardes + poste BQ', () async {
      final (n: stagiaire, appels: _) =
          _notifier(role: Role.stagiaire);
      expect(await stagiaire.encaisserVente('zz'),
          'Encaissement réservé à la vente');
      final (:n, :appels) = _notifier();
      expect(await n.encaisserVente('zz'), 'Vente introuvable');
      final id = await n.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 9000,
        statut: StatutPaiement.impaye,
      );
      expect(await n.encaisserVente(id), isNull);
      expect(n.transactions.first.statut, StatutPaiement.paye);
      expect(appels, contains('encaisse:$id'));
      expect(await n.encaisserVente(id), 'Déjà encaissée');
    });

    test('créances triées + total', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      await n.ajouterTransaction(
          type: TypeTransaction.prestationService,
          montant: 9000,
          statut: StatutPaiement.impaye,
          date: DateTime(2026, 9, 20));
      await n.ajouterTransaction(
          type: TypeTransaction.prestationService,
          montant: 5000,
          statut: StatutPaiement.paye);
      await n.ajouterTransaction(
          type: TypeTransaction.prestationService,
          montant: 3000,
          statut: StatutPaiement.impaye,
          date: DateTime(2026, 9, 1));
      expect(n.creances.length, 2);
      expect(n.creances.first.montant, 3000.0); // ancienne d'abord
      expect(n.totalCreances, 12000.0);
    });
  });
}
