import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/produit_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/mouvement_stock.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 3 — ProduitNotifier (listes partagées injectées).
int _seq = 400;

({ProduitNotifier n, List<String> appels}) _notifier(
    {Role role = Role.admin}) {
  final appels = <String>[];
  final n = ProduitNotifier(
    session: SessionNotifier(
        AppUser(id: 'u1', nom: 'T', role: role)),
    genererId: () => 'p${_seq++}',
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
    catalogue: [],
    transactions: [],
    mouvements: [],
    journaliserMouvement: (
        {required String produitId,
        required String produitNom,
        required String type,
        required int quantite,
        required int stockApres,
        required String boutiqueId,
        String motif = '',
        String refId = '',
        DateTime? date}) async {
      appels.add('mvt:$type:$quantite');
    },
    boutiqueId: 'b1',
  );
  return (n: n, appels: appels);
}

Produit _produit(String libelle) => Produit(
    id: '',
    boutiqueId: 'b1',
    libelle: libelle,
    categorie: 'A',
    prixAchat: 100,
    prixVente: 150,
    stock: 5);

void main() {
  group('ProduitNotifier CRUD', () {
    test('ajouter : libellé court + doublon refusés', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      expect(await n.ajouterProduit(_produit('X')),
          contains('Libellé requis'));
      expect(await n.ajouterProduit(_produit('câble')),
          contains('existe déjà'));
      expect(await n.ajouterProduit(_produit('Prise')), isNull);
      expect(n.produitsBoutique.length, 2);
      // Sync catalogue automatique.
      expect(n.catalogue.any((t) => t.libelle == 'Prise'), isTrue);
    });

    test('maj : introuvable + collision + traçabilité stock', () async {
      final (:n, :appels) = _notifier();
      expect(
          await n.majProduit(_produit('X').copyWith(stock: 1)),
          'Produit introuvable');
      await n.ajouterProduit(_produit('Prise'));
      final prise =
          n.produits.firstWhere((p) => p.libelle == 'Prise');
      expect(
          await n.majProduit(prise.copyWith(libelle: 'CÂBLE')),
          contains('Un autre produit'));
      expect(
          await n.majProduit(prise.copyWith(stock: 9)), isNull);
      expect(appels, ['mvt:ajustement:4']);
      expect(
          await n.majProduit(prise.copyWith(stock: 9)), isNull);
      expect(appels.length, 1); // stock inchangé → pas de mouvement
    });

    test('archiver retire de la liste', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      await n.archiverProduit('p1');
      expect(n.produits, isEmpty);
      await n.archiverProduit('zz'); // sans effet
    });

    test('supprimer : garde rôle + historique', () async {
      final (n: vendeur, appels: _) = _notifier(role: Role.vendeur);
      expect(await vendeur.supprimerProduit('p1'),
          contains('réservé'));
      final (:n, appels: _) = _notifier();
      expect(await n.supprimerProduit('zz'), 'Produit introuvable');
      // Produit lié à une vente → refus sans forcer.
      n.transactions.add(Tx(
          id: 't1',
          boutiqueId: 'b1',
          employeId: 'u',
          type: TypeTransaction.venteMateriel,
          montant: 1500,
          date: DateTime(2026, 9, 1),
          details: {
            'lignes': [
              {'produitId': 'p1', 'quantite': 1}
            ]
          }));
      expect(await n.supprimerProduit('p1'), contains('archivez-le'));
      expect(await n.supprimerProduit('p1', forcerArchive: true),
          isNull);
      expect(n.produits, isEmpty);
    });
  });

  group('ProduitNotifier stock', () {
    test('deduireStockPourLignes : sortie + ignorés', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      final ignores = await n.deduireStockPourLignes([
        {'libelle': 'Câble', 'quantite': 3},
        {'libelle': 'Câble', 'quantite': 99}, // stock insuffisant
        {'libelle': 'Inconnu', 'quantite': 1}, // ignoré silencieusement
      ], refId: 'doc1');
      expect(n.produits.first.stock, 7);
      expect(ignores.length, 1);
      expect(ignores.first, contains('stock 7'));
      expect(appels, ['mvt:sortie:-3']);
    });

    test('vendreProduit : atomique stock + mouvement', () async {
      var txCrees = 0;
      final base = _notifier();
      final mouvements = base.n.mouvements;
      final n = ProduitNotifier(
        session: base.n.session,
        genererId: base.n.genererId,
        produits: base.n.produits,
        catalogue: base.n.catalogue,
        transactions: base.n.transactions,
        mouvements: mouvements,
        journaliserMouvement: (
            {required String produitId,
            required String produitNom,
            required String type,
            required int quantite,
            required int stockApres,
            required String boutiqueId,
            String motif = '',
            String refId = '',
            DateTime? date}) async {
          mouvements.insert(
              0,
              MouvementStock(
                  id: 'm-test',
                  boutiqueId: boutiqueId,
                  produitId: produitId,
                  produitNom: produitNom,
                  type: type,
                  quantite: quantite,
                  stockApres: stockApres,
                  motif: motif,
                  refId: refId,
                  date: date ?? DateTime.now(),
                  createdBy: 'u1'));
        },
        ajouterVente: (
            {required TypeTransaction type,
            required double montant,
            double cout = 0,
            String? clientNom,
            DateTime? date,
            Map<String, dynamic> details = const {}}) async {
          txCrees++;
          expect(type, TypeTransaction.venteMateriel);
          expect(montant, 3000.0);
          expect(cout, 2000.0);
          return 'tx1';
        },
        boutiqueId: 'b1',
      );
      await n.vendreProduit(n.produits.first, 2,
          clientNom: 'Moussa');
      expect(n.produits.first.stock, 8);
      expect(txCrees, 1);
      expect(
          n.mouvements.firstWhere((m) => m.type == 'sortie').refId,
          'tx1');
      expect(
          () => n.vendreProduit(n.produits.first, 999),
          throwsStateError);
    });

    test('produitsBoutique + alertesStock filtrent', () async {
      final (:n, :appels) = _notifier();
      expect(appels, isEmpty);
      n.produits.add(const Produit(
          id: 'p9',
          boutiqueId: 'b2',
          libelle: 'Autre',
          categorie: 'A',
          prixAchat: 1,
          prixVente: 2,
          stock: 0,
          seuil: 5));
      expect(n.produitsBoutique.length, 1);
      expect(n.alertesStock, isEmpty);
    });
  });
}
