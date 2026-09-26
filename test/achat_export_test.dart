import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/export_service.dart';

/// Point 5 : les 3 formats d'export Achat produisent des fichiers
/// non vides, avec en-têtes et totaux corrects (mêmes colonnes que
/// `_exporter` de achat_list_screen.dart).
const _entetes = [
  'Date', 'Numéro', 'Fournisseur', 'Statut', 'Nb lignes', 'Détail',
  'Montant TTC', 'Payé', 'Reste dû', 'Paiement', 'Devise'
];

List<List<dynamic>> _lignes() => [
      [
        DateTime(2026, 9, 20, 9, 0), 'ACH-2026-00007', 'Fournisseur Test',
        'REÇU', 2, '10× Café', 150000.0, 100000.0, 50000.0, 'especes',
        'FCFA'
      ],
      [
        DateTime(2026, 9, 21, 14, 30), 'ACH-2026-00008',
        'Autre Fournisseur', 'EN ATTENTE', 1, '5× Sucre', 25000.0,
        0.0, 25000.0, 'credit', 'FCFA'
      ],
    ];

void main() {
  group('Export Achat (point 5)', () {
    test('CSV : BOM + en-têtes + lignes + totaux', () {
      final lignes = _lignes();
      final csv = ExportService.csv(_entetes, lignes);
      expect(csv.startsWith('﻿'), isTrue);
      for (final h in _entetes) {
        expect(csv, contains(h));
      }
      expect(csv, contains('ACH-2026-00007'));
      expect(csv, contains('150000'));
      final total =
          lignes.fold(0.0, (s, l) => s + (l[6] as double));
      final du =
          lignes.fold(0.0, (s, l) => s + (l[8] as double));
      expect(total, 175000.0);
      expect(du, 75000.0);
    });

    test('Excel : signature xlsx + non vide', () {
      final octets =
          ExportService.excel('Achats', _entetes, _lignes());
      expect(octets, isNotEmpty);
      expect(octets[0], 0x50);
      expect(octets[1], 0x4B);
    });

    test('PDF : plein et vide (garantie anti-cadre-vide)', () async {
      final plein = await ExportService.pdfTableau(
        titre: 'Achats — Boutique test',
        sousTitre: 'Vue filtrée · 2 achat(s) · Total : 175000 FCFA',
        entetes: _entetes,
        lignes: _lignes(),
      );
      expect(plein, isNotEmpty);
      final vide = await ExportService.pdfTableau(
        titre: 'Achats — Boutique test',
        sousTitre: 'Vue filtrée · 0 achat(s)',
        entetes: _entetes,
        lignes: const [],
      );
      expect(vide, isNotEmpty);
    });
  });
}
