import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/export_service.dart';

void main() {
  const entetes = ['Date', 'Libellé', 'Montant'];
  final lignes = [
    [DateTime(2026, 9, 26, 10, 30), 'Vente café; "spécial"', 1500.0],
    [DateTime(2026, 9, 25), 'Loyer', 150000],
  ];

  group('ExportService unifié', () {
    test('CSV : BOM + séparateur ; + guillemets', () {
      final csv = ExportService.csv(entetes, lignes);
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv, contains(';'));
      expect(csv, contains('"Vente café; ""spécial"""'));
      expect(csv, contains('26/09/2026 10:30'));
    });

    test('Excel : octets .xlsx non vides', () {
      final octets = ExportService.excel('Test', entetes, lignes);
      expect(octets, isNotEmpty);
      // Signature ZIP d'un classeur xlsx.
      expect(octets[0], 0x50);
      expect(octets[1], 0x4B);
    });

    test('PDF : tableau jamais vide, même sans lignes', () async {
      final plein = await ExportService.pdfTableau(
        titre: 'Journal',
        sousTitre: 'Septembre 2026',
        entetes: entetes,
        lignes: lignes,
        total: 'Total : 151500',
      );
      expect(plein, isNotEmpty);
      final vide = await ExportService.pdfTableau(
        titre: 'Journal',
        sousTitre: 'Période vide',
        entetes: entetes,
        lignes: const [],
      );
      expect(vide, isNotEmpty);
      expect(vide.length, lessThan(plein.length));
    });
  });
}
