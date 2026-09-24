import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/mouvement_stock.dart';

Store _store() =>
    Store(const AppUser(id: 'u_admin', nom: 'Patron', role: Role.admin));

void main() {
  group('Mouvements de stock (mission 1, §1.3)', () {
    test('vente directe journalise une sortie', () async {
      final s = _store();
      final p = s.produits.firstWhere((e) => e.id == 'pr_1');
      final avant = p.stock;
      await s.vendreProduit(p, 2, clientNom: 'Test');
      final m = s.mouvementsProduit('pr_1');
      expect(m.length, 1);
      expect(m.first.type, MouvementStock.sortie);
      expect(m.first.quantite, -2);
      expect(m.first.stockApres, avant - 2);
      expect(m.first.refId.isNotEmpty, isTrue);
    });

    test('ajustement manuel : motif obligatoire + tracé', () async {
      final s = _store();
      expect(await s.ajusterStock('pr_2', 30, 'x'), isNotNull);
      expect(await s.ajusterStock('pr_2', -1, 'Perte'), isNotNull);
      expect(await s.ajusterStock('pr_2', 30, 'Inventaire annuel'),
          isNull);
      expect(s.produits.firstWhere((e) => e.id == 'pr_2').stock, 30);
      final m = s.mouvementsProduit('pr_2');
      expect(m.length, 1);
      expect(m.first.type, MouvementStock.ajustement);
      expect(m.first.quantite, 5); // 25 → 30
      expect(m.first.motif, 'Inventaire annuel');
    });

    test('valorisation = somme stock × prixAchat', () async {
      final s = _store();
      final attendu = s.produitsBoutique
          .fold(0.0, (t, p) => t + p.stock * p.prixAchat);
      expect(s.valeurStock, attendu);
      expect(s.valeurStock, greaterThan(0));
    });

    test('correction fiche avec stock modifié journalisée', () async {
      final s = _store();
      final p = s.produits.firstWhere((e) => e.id == 'pr_3');
      final err = await s.majProduit(p.copyWith(stock: p.stock + 3));
      expect(err, isNull);
      final m = s.mouvementsProduit('pr_3');
      expect(m.any((e) => e.quantite == 3), isTrue);
    });

    test('sérialisation aller-retour', () async {
      final s = _store();
      await s.vendreProduit(
          s.produits.firstWhere((e) => e.id == 'pr_4'), 1);
      final json = s.toJson();
      expect((json['mouvements'] as List).length, 1);
      final m = MouvementStock.fromJson(
          Map<String, dynamic>.from(
              (json['mouvements'] as List).first as Map));
      expect(m.type, MouvementStock.sortie);
      expect(m.quantite, -1);
    });
  });
}
