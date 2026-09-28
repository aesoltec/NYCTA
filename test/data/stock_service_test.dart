import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/services/stock_service.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Phase 0 — StockService pur : CUMP, valorisation, mouvements, alertes.
void main() {
  const p1 = Produit(
      id: 'p1', boutiqueId: 'b1', libelle: 'Câble', categorie: 'A',
      prixAchat: 1000, prixVente: 1500, stock: 10, seuil: 3);
  const p2 = Produit(
      id: 'p2', boutiqueId: 'b1', libelle: 'Prise', categorie: 'A',
      prixAchat: 500, prixVente: 800, stock: 2, seuil: 3);

  group('StockService.cump', () {
    test('moyenne pondérée exacte', () {
      // (10×1000 + 10×1500) / 20 = 1250.
      expect(
          StockService.cump(
              stockActuel: 10,
              prixAchatActuel: 1000,
              quantiteEntree: 10,
              prixUnitaireEntree: 1500),
          1250.0);
    });

    test('stock nul → prix entrée (pas de division par zéro)', () {
      expect(
          StockService.cump(
              stockActuel: 0,
              prixAchatActuel: 0,
              quantiteEntree: 5,
              prixUnitaireEntree: 200),
          200.0);
    });

    test('même prix → prix inchangé', () {
      expect(
          StockService.cump(
              stockActuel: 7,
              prixAchatActuel: 300,
              quantiteEntree: 3,
              prixUnitaireEntree: 300),
          300.0);
    });
  });

  group('StockService.valorisation', () {
    test('Σ(stock × PA)', () {
      expect(StockService.valorisation([p1, p2]),
          10 * 1000 + 2 * 500);
    });

    test('liste vide → 0', () {
      expect(StockService.valorisation(const []), 0.0);
    });
  });

  group('StockService.mouvements', () {
    test('réception ajoute', () {
      expect(StockService.apresReception(10, 4), 14);
    });

    test('annulation : plancher 0', () {
      expect(StockService.apresAnnulationReception(10, 4), 6);
      expect(StockService.apresAnnulationReception(2, 10), 0);
    });

    test('retour vente remet en rayon', () {
      expect(StockService.apresRetourVente(8, 2), 10);
    });

    test('delta ajustement signé', () {
      expect(StockService.deltaAjustement(10, 7), -3);
      expect(StockService.deltaAjustement(7, 10), 3);
      expect(StockService.deltaAjustement(5, 5), 0);
    });
  });

  group('StockService.enAlerte', () {
    test('stock ≤ seuil uniquement', () {
      final alertes = StockService.enAlerte([p1, p2]);
      expect(alertes.length, 1);
      expect(alertes.first.id, 'p2');
    });

    test('aucune alerte → vide', () {
      expect(StockService.enAlerte([p1]), isEmpty);
    });
  });
}
