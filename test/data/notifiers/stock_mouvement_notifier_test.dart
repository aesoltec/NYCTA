import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/stock_mouvement_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/mouvement_stock.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Phase 2 — StockMouvementNotifier.
int _seq = 300;

StockMouvementNotifier _notifier({Role role = Role.admin}) =>
    StockMouvementNotifier(
      session: SessionNotifier(
          AppUser(id: 'u1', nom: 'T', role: role)),
      genererId: () => 'm${_seq++}',
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
    );

void main() {
  group('StockMouvementNotifier', () {
    test('journaliser : en-tête + payload', () async {
      String? table;
      final n = StockMouvementNotifier(
        session: SessionNotifier(
            const AppUser(id: 'u1', nom: 'T', role: Role.admin)),
        genererId: () => 'm1',
        produits: [],
        fileUpsert: (t, p) async {
          table = t;
        },
      );
      await n.journaliser(
          produitId: 'p1',
          produitNom: 'Câble',
          type: MouvementStock.entree,
          quantite: 5,
          stockApres: 15,
          boutiqueId: 'b1',
          motif: 'Réception');
      expect(n.mouvements.length, 1);
      expect(n.mouvements.first.quantite, 5);
      expect(n.mouvements.first.createdBy, 'u1');
      expect(table, 'mouvements_stock');
      expect(n.mouvementsProduit('p1').length, 1);
      expect(n.mouvementsProduit('zz'), isEmpty);
    });

    test('ajusterStock : gardes + mouvement signé', () async {
      // Stagiaire : sans Permission.gererStock (le vendeur, lui, l'a).
      final sansDroit = _notifier(role: Role.stagiaire);
      expect(await sansDroit.ajusterStock('p1', 5, 'Perte', 'b1'),
          'Réservé à la gestion du stock');
      final n = _notifier();
      expect(await n.ajusterStock('p1', 5, 'Ajustement', 'b1'), isNull);
      expect(await n.ajusterStock('p1', 5, 'Ajustement', 'b1'),
          'Aucun changement');
      expect(await n.ajusterStock('p1', -1, 'Motif ok', 'b1'),
          'Le stock ne peut pas être négatif');
      expect(await n.ajusterStock('zz', 5, 'Motif ok', 'b1'),
          'Produit introuvable');
      expect(await n.ajusterStock('p1', 3, 'ab', 'b1'),
          contains('Motif'));
    });

    test('ajusterStock : traçabilité ajustement', () async {
      final n = _notifier();
      await n.ajusterStock('p1', 7, 'Casse', 'b1');
      expect(n.produits.first.stock, 7);
      final m = n.mouvements.first;
      expect(m.type, MouvementStock.ajustement);
      expect(m.quantite, -3);
      expect(m.stockApres, 7);
      expect(m.motif, 'Casse');
    });

    test('mouvementsBoutique filtre', () async {
      final n = _notifier();
      await n.journaliser(
          produitId: 'p1',
          produitNom: 'Câble',
          type: MouvementStock.entree,
          quantite: 5,
          stockApres: 15,
          boutiqueId: 'b2');
      expect(n.mouvementsBoutique('b1'), isEmpty);
      expect(n.mouvementsBoutique('b2').length, 1);
    });
  });
}
