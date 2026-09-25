import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/services/document_service.dart';

DocumentBati _doc() => const DocumentBati(
      type: TypeDocument.facture,
      numero: 'FACT-2026-00001',
      date: '25/09/2026',
      client: 'Client',
      lignes: [LigneDoc(libelle: 'Article', quantite: 2, prixUnitaire: 1000)],
      totalHT: 2000,
      tva: 0,
      totalTTC: 2000,
      devise: 'FCFA',
    );

void main() {
  group('Signature client par document', () {
    test('absente par défaut, conservée par copyWith', () {
      final d = _doc();
      expect(d.signatureClientPath, isNull);
      final signe = d.copyWith(signatureClientPath: '/tmp/sig.png');
      expect(signe.signatureClientPath, '/tmp/sig.png');
      // Champs métier intacts.
      expect(signe.numero, d.numero);
      expect(signe.totalTTC, d.totalTTC);
      expect(signe.lignes.length, 1);
    });

    test('transformation devis→facture : signature transmise', () async {
      // Via copyWith, comme le fait transformerDevisEnFacture.
      final devis = _doc().copyWith(signatureClientPath: '/tmp/sig.png');
      final facture = devis.copyWith();
      expect(facture.signatureClientPath, '/tmp/sig.png');
    });
  });
}
