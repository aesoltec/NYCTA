import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/services/document_import_service.dart';

const _service = DocumentImportService();

String _csv(List<List<String>> lignes) =>
    lignes.map((l) => l.join(';')).join('\n');

ImportResultat _importer(String csv,
        {TypeDocument type = TypeDocument.facture, double tva = 18}) =>
    _service.importerCsv(csv, typeParDefaut: type, tvaPct: tva);

void main() {
  group('en-tetes tolerants', () {
    test('normalisation : accents, casse, ponctuation', () {
      expect(DocumentImportService.normaliser('Quantité (HT)'), 'quantiteht');
      expect(DocumentImportService.normaliser('  Prix unitaire '),
          'prixunitaire');
      // « ° » se lit « numero » : variante reelle d'en-tete.
      expect(DocumentImportService.champPourEntete('N° de pièce'),
          'numero');
    });

    test('synonymes d ERP acceptes', () {
      for (final entete in ['Quantite', 'Qte', 'QTY', 'Quantité']) {
        expect(DocumentImportService.champPourEntete(entete), 'quantite',
            reason: entete);
      }
      for (final entete in ['Prix', 'PU', 'Prix unitaire HT']) {
        expect(DocumentImportService.champPourEntete(entete), 'prix',
            reason: entete);
      }
      for (final entete in ['Designation', 'Libelle', 'Article']) {
        expect(DocumentImportService.champPourEntete(entete), 'designation',
            reason: entete);
      }
    });

    test('une colonne inconnue est signalee, pas perdue', () {
      final r = _importer(_csv([
        ['numero', 'client', 'designation', 'quantite', 'prix', 'colonne_piege'],
        ['F1', 'A', 'Cable', '2', '1000', 'xyz'],
      ]));
      expect(r.documents.length, 1);
      expect(r.colonnesIgnorees, ['colonne_piege']);
    });
  });

  group('nombres et dates', () {
    test('virgule decimale', () {
      expect(DocumentImportService.nombre('1234,56'), closeTo(1234.56, 0.001));
      expect(DocumentImportService.nombre('1 234,56'), closeTo(1234.56, 0.001));
      expect(DocumentImportService.nombre('1\u00a0234,56'),
          closeTo(1234.56, 0.001));
    });

    test('point decimal et milliers', () {
      expect(DocumentImportService.nombre('1234.56'), closeTo(1234.56, 0.001));
      expect(DocumentImportService.nombre('1.234,56'), closeTo(1234.56, 0.001));
      expect(DocumentImportService.nombre('1,234.56'), closeTo(1234.56, 0.001));
    });

    test('monnaie et pourcent refuses proprement', () {
      expect(DocumentImportService.nombre(r'1 500 FCFA'), 1500);
      expect(DocumentImportService.nombre('18%'), 18);
      expect(DocumentImportService.nombre('abc'), isNull);
      expect(DocumentImportService.nombre(null), isNull);
    });

    test('dates FR, ISO et DateTime', () {
      expect(DocumentImportService.dateLisible('03/10/2026'), '03/10/2026');
      expect(DocumentImportService.dateLisible('3-10-2026'), '03/10/2026');
      expect(DocumentImportService.dateLisible('2026-10-03'), '03/10/2026');
      expect(DocumentImportService.dateLisible(DateTime(2026, 10, 3)),
          '03/10/2026');
      expect(DocumentImportService.dateLisible('32/13/2026'), isNull);
    });
  });

  group('regroupement par numero', () {
    test('les lignes d un meme numero forment UN document', () {
      final r = _importer(_csv([
        ['numero', 'date', 'client', 'designation', 'quantite', 'prix'],
        ['F-001', '03/10/2026', 'Client A', 'Cable', '10', '1500'],
        ['F-001', '03/10/2026', 'Client A', 'Prise', '5', '500'],
        ['F-002', '04/10/2026', 'Client B', 'Routeur', '2', '25000'],
      ]));
      expect(r.documents.length, 2);
      final f1 = r.documents.firstWhere((d) => d.numero == 'F-001');
      expect(f1.lignes.length, 2);
      expect(f1.client, 'Client A');
      expect(f1.date, '03/10/2026');
      expect(f1.totalHT, closeTo(17500, 0.01));
      expect(f1.totalTTC, closeTo(20650, 0.01));
    });

    test('un document sans numero est regroupe a part', () {
      final r = _importer(_csv([
        ['client', 'designation', 'quantite', 'prix'],
        ['A', 'Cable', '1', '100'],
        ['A', 'Prise', '2', '200'],
      ]));
      expect(r.documents.length, 1);
      expect(r.documents.first.lignes.length, 2,
          reason: 'sans numero, les lignes contiguës d un client forment '
              'un document');
    });

    test('un document sans client est refuse et signale', () {
      final r = _importer(_csv([
        ['numero', 'designation', 'quantite', 'prix'],
        ['F-9', 'Cable', '1', '100'],
      ]));
      expect(r.documents, isEmpty);
      expect(r.anomalies.any((a) => a.code == 'client'), isTrue);
    });
  });

  group('aucune perte silencieuse', () {
    test('une ligne sans designation est comptee et signalee', () {
      final r = _importer(_csv([
        ['numero', 'client', 'designation', 'quantite', 'prix'],
        ['F-1', 'A', 'Cable', '1', '100'],
        ['F-1', 'A', '', '2', '200'],
      ]));
      expect(r.lignesIgnorees, 1);
      expect(r.anomalies.single.code, 'designation');
      expect(r.anomalies.single.ligne, 3,
          reason: 'le numero de ligne doit pointer vers le fichier');
    });

    test('une quantite illisible est comptee', () {
      final r = _importer(_csv([
        ['numero', 'client', 'designation', 'quantite', 'prix'],
        ['F-1', 'A', 'Cable', 'beaucoup', '100'],
      ]));
      expect(r.documents, isEmpty);
      expect(r.anomalies.single.code, 'quantite');
    });

    test('une ligne entierement vide est ignoree SANS anomalie', () {
      // Elle ne porte aucune donnee : la signaler polluerait le rapport
      // d'un fichier qui contient des lignes vides entre deux blocs (cas
      // normal d'un export). Le principe « aucune perte silencieuse »
      // vise les lignes qui contiennent de l'information.
      final r = _importer(_csv([
        ['numero', 'client', 'designation', 'quantite', 'prix'],
        ['F-1', 'A', 'Cable', '1', '100'],
        ['', '', '', '', ''],
        ['F-2', 'A', 'Prise', '2', '200'],
      ]));
      expect(r.documents.length, 2);
      expect(r.anomalies, isEmpty);
      expect(r.lignesIgnorees, 0);
    });

    test('un fichier sans en-tete exploitable est refuse clairement', () {
      final r = _importer(_csv([
        ['aaaa', 'bbbb'],
        ['1', '2'],
      ]));
      expect(r.documents, isEmpty);
      expect(r.anomalies.single.code, 'entete');
      expect(r.anomalies.single.message, contains('Aucune colonne reconnue'));
    });

    test('un fichier vide ne plante pas', () {
      expect(_importer('').documents, isEmpty);
      expect(_importer('   ').documents, isEmpty);
    });
  });

  group('securite metier de l import', () {
    test('un importe n est JAMAIS emis', () {
      final r = _importer(_csv([
        ['numero', 'client', 'designation', 'quantite', 'prix'],
        ['F-1', 'A', 'Cable', '1', '100'],
      ]));
      expect(r.documents.first.statut, 'brouillon',
          reason: 'un document emis est un justificatif comptable et fiscal : '
              'un import doit etre relu et valide');
    });

    test('le type est deduit du libelle, sinon le type par defaut', () {
      expect(DocumentImportService.typeDepuisLibelle('FACTURE'),
          TypeDocument.facture);
      expect(DocumentImportService.typeDepuisLibelle('Bon de commande'),
          TypeDocument.bonCommande);
      expect(DocumentImportService.typeDepuisLibelle('BL'),
          TypeDocument.bonLivraison);
      expect(DocumentImportService.typeDepuisLibelle('Devis proforma'),
          TypeDocument.devisProforma);
      expect(DocumentImportService.typeDepuisLibelle('Ticket de caisse'),
          TypeDocument.ticketCaisse);
      expect(DocumentImportService.typeDepuisLibelle('n importe quoi'),
          isNull);

      final r = _importer(_csv([
        ['numero', 'type', 'client', 'designation', 'quantite', 'prix'],
        ['D-1', 'Devis', 'A', 'Cable', '1', '100'],
        ['B-1', 'Bon de commande', 'A', 'Cable', '1', '100'],
      ]));
      expect(r.documents[0].type, TypeDocument.devisProforma);
      expect(r.documents[1].type, TypeDocument.bonCommande);
    });
  });

  group('separateur CSV', () {
    test('point-virgule (Excel FR)', () {
      final r = _importer('numero;client;designation;quantite;prix\n'
          'F-1;A;Cable;1;100');
      expect(r.documents.length, 1);
    });

    test('virgule', () {
      final r = _importer('numero,client,designation,quantite,prix\n'
          'F-1,A,Cable,1,100');
      expect(r.documents.length, 1);
    });

    test('guillemets avec point-virgule interne', () {
      final r = _importer('numero;client;designation;quantite;prix\n'
          'F-1;"Client ; SARL";"Cable, epaisseur 2";1;100');
      expect(r.documents.single.client, 'Client ; SARL');
      expect(r.documents.single.lignes.single.libelle, 'Cable, epaisseur 2');
    });
  });

  group('modele', () {
    test('le modele contient les colonnes attendues', () {
      final m = DocumentImportService.modeleCsv();
      for (final c in ['numero', 'date', 'client', 'designation',
          'quantite', 'prix']) {
        expect(m, contains(c));
      }
    });

    test('le modele est reimportable tel quel', () {
      // un garde-fou : un modele que l'import ne sait pas lire est inutile
      final r = _importer('${DocumentImportService.modeleCsv()}'
          'F-1;Facture;03/10/2026;A;Cable;1;100');
      expect(r.documents.length, 1);
    });
  });
}
