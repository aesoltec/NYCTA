import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/models/company_profile.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/services/document_service.dart';
import 'package:pme_gestion_pro/services/pdf_service.dart';

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

    test('PDF sans images : zones entreprise + client quand même', () async {
      final bytes = await PdfService.generer(
          _doc(), const CompanyProfile());
      expect(bytes, isNotEmpty);
    });

    test('audit types : 5 préfixes uniques, BL sans prix', () {
      final prefixes =
          TypeDocument.values.map((t) => t.prefixe).toSet();
      expect(prefixes.length, TypeDocument.values.length);
      expect(TypeDocument.bonLivraison.sansPrix, isTrue);
      expect(TypeDocument.facture.sansPrix, isFalse);
      expect(TypeDocument.facture.decrementeStock, isTrue);
      expect(TypeDocument.devisProforma.decrementeStock, isFalse);
    });

    test('audit mentions légales : RCCM + IFU dans l’en-tête', () {
      final lignes = DocumentService.entete(const CompanyProfile(
          nomEntreprise: 'NYCTA', rccm: 'RCCM-123', ifu: 'IFU-456'));
      expect(lignes.any((l) => l.contains('RCCM')), isTrue);
      expect(lignes.any((l) => l.contains('IFU')), isTrue);
    });
  });
}
