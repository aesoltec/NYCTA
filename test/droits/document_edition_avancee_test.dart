import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/core/constants.dart';
import 'package:pme_gestion_pro/data/notifiers/document_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/services/document_service.dart';
import 'package:pme_gestion_pro/services/pdf_service.dart';
import 'package:pme_gestion_pro/models/company_profile.dart';

/// Regle professionnelle de modification d'un document commercial.
///
/// Repartie par NATURE, pas seulement par statut :
/// - facture / ticket emis : IMMUABLE (justificatif fiscal — un numero
///   ne doit correspondre qu'a un seul contenu) ;
/// - devis / BC / BL emis : modifiable, mais AVEC motif et journal ;
/// - brouillon : libre ;
/// - annule / paye : fige.
///
/// Et les informations saisissables : unite et reference par ligne, note,
/// conditions de reglement, adresse de livraison.

DocumentBati _doc({
  TypeDocument type = TypeDocument.facture,
  String statut = 'emis',
  String numero = 'FACT-001',
  String client = 'Client A',
  List<LigneDoc>? lignes,
  double totalHT = 2000,
  double tva = 360,
  double totalTTC = 2360,
}) =>
    DocumentBati(
      id: 'doc1',
      type: type,
      numero: numero,
      date: '01/10/2026',
      client: client,
      lignes: lignes ??
          const [LigneDoc(libelle: 'Câble', quantite: 2, prixUnitaire: 1000)],
      totalHT: totalHT,
      tva: tva,
      totalTTC: totalTTC,
      devise: 'FCFA',
      statut: statut,
    );

DocumentNotifier _notifier(
    {List<DocumentBati>? init, Role role = Role.admin}) =>
    DocumentNotifier(
      session: SessionNotifier(AppUser(id: 'u', nom: 'Test', role: role)),
      numeroDocument: (p) async => 'X-1',
      boutiqueId: 'b1',
      documentsEmis: init ?? [_doc()],
    );

void main() {
  group('nature du document : modifiable apres emission ?', () {
    test('facture et ticket : NON, un numero = un seul contenu', () {
      expect(TypeDocument.facture.modifiableApresEmission, isFalse);
      expect(TypeDocument.ticketCaisse.modifiableApresEmission, isFalse);
    });

    test('devis, BC et bordereau : OUI, ce ne sont pas des '
        'justificatifs fiscaux', () {
      expect(TypeDocument.devisProforma.modifiableApresEmission, isTrue);
      expect(TypeDocument.bonCommande.modifiableApresEmission, isTrue);
      expect(TypeDocument.bonLivraison.modifiableApresEmission, isTrue);
    });
  });

  group('DocumentBati.peutModifier : source unique de la regle', () {
    test('un brouillon est toujours modifiable', () {
      for (final t in TypeDocument.values) {
        expect(_doc(type: t, statut: 'brouillon').peutModifier, isTrue,
            reason: t.name);
      }
    });

    test('un emis depend du type', () {
      expect(_doc(type: TypeDocument.facture).peutModifier, isFalse);
      expect(_doc(type: TypeDocument.ticketCaisse).peutModifier, isFalse);
      expect(_doc(type: TypeDocument.devisProforma).peutModifier, isTrue);
      expect(_doc(type: TypeDocument.bonCommande).peutModifier, isTrue);
      expect(_doc(type: TypeDocument.bonLivraison).peutModifier, isTrue);
    });

    test('annule et paye sont figes, quel que soit le type', () {
      for (final statut in ['annule', 'paye']) {
        for (final t in TypeDocument.values) {
          expect(_doc(type: t, statut: statut).peutModifier, isFalse,
              reason: '$statut / ${t.name}');
        }
      }
    });

    test('un emis exige un motif, un brouillon non', () {
      expect(_doc(statut: 'emis', type: TypeDocument.devisProforma)
          .exigeMotifModification, isTrue);
      expect(_doc(statut: 'brouillon').exigeMotifModification, isFalse);
    });
  });

  group('le refus nomme la voie legitime', () {
    test('facture : propose avoir ou annulation', () async {
      final n = _notifier(init: [_doc(type: TypeDocument.facture)]);
      final err = await n.modifierDocument(
          _doc(type: TypeDocument.facture, client: 'X'),
          motif: 'erreur');
      expect(err, isNotNull);
      final bas = err!.toLowerCase();
      // Sans chemin propose, l'utilisateur ne sait pas quoi faire.
      expect(bas, contains('avoir'));
      expect(bas, contains('annul'));
      expect(n.documentsEmis.first.client, 'Client A',
          reason: 'le document ne doit pas avoir bouge');
    });

    test('un motif manquant est refuse AVANT toute ecriture', () async {
      final n = _notifier(init: [
        _doc(type: TypeDocument.bonLivraison, statut: 'emis')
      ]);
      final err = await n.modifierDocument(
          _doc(type: TypeDocument.bonLivraison, client: 'X'));
      expect(err!.toLowerCase(), contains('motif'));
      expect(n.documentsEmis.first.client, 'Client A');
      expect(n.modifications, isEmpty, reason: 'rien ne doit etre journalise');
    });
  });

  group('journal des modifications', () {
    test('chaque modification d un emis est tracee', () async {
      final n = _notifier(
          init: [_doc(type: TypeDocument.bonLivraison, statut: 'emis')]);
      await n.modifierDocument(
        _doc(
            type: TypeDocument.bonLivraison,
            client: 'Client B',
            lignes: [
              const LigneDoc(
                  libelle: 'Cable', quantite: 3, prixUnitaire: 1000)
            ],
            totalHT: 3000,
            tva: 540,
            totalTTC: 3540),
        motif: 'quantite corrigee a la livraison',
      );
      expect(n.modifications.length, 1);
      final m = n.modifications.first;
      expect(m.numero, 'FACT-001');
      expect(m.motif, 'quantite corrigee a la livraison');
      expect(m.auteur, contains('Test'));
      expect(m.auteur, contains('admin'));
      expect(m.date, isNotEmpty);
    });

    test('le resume dit CE QUI a change', () async {
      final n = _notifier(init: [
        _doc(
            type: TypeDocument.devisProforma,
            statut: 'emis',
            lignes: [const LigneDoc(libelle: 'A', quantite: 1, prixUnitaire: 1000)],
            totalHT: 1000,
            tva: 180,
            totalTTC: 1180)
      ]);
      await n.modifierDocument(
        _doc(
            type: TypeDocument.devisProforma,
            client: 'Client B',
            lignes: [
              const LigneDoc(libelle: 'A', quantite: 2, prixUnitaire: 1000),
              const LigneDoc(libelle: 'B', quantite: 1, prixUnitaire: 500),
            ],
            totalHT: 2500,
            tva: 450,
            totalTTC: 2950),
        motif: 'ajout de ligne',
      );
      final r = n.modifications.first.resume;
      expect(r, contains('lignes'));
      expect(r, contains('total'));
      expect(r, contains('Client B'));
      // Un resume qui recopie tout n'apprend rien.
      expect(r.length, lessThan(200));
    });

    test('un changement invisible dans le total est signale quand meme',
        () async {
      final n = _notifier(init: [
        _doc(type: TypeDocument.devisProforma, statut: 'emis')
      ]);
      await n.modifierDocument(
        _doc(
            type: TypeDocument.devisProforma,
            lignes: [const LigneDoc(
                libelle: 'Cable revise', quantite: 2, prixUnitaire: 1000)],
            totalHT: 2000,
            tva: 360,
            totalTTC: 2360),
        motif: 'designation corrigee');
      expect(n.modifications.first.resume, contains('détail des lignes'));
    });

    test('un brouillon n est PAS journalise (personne ne l a vu)', () async {
      final n = _notifier(init: [_doc(statut: 'brouillon')]);
      await n.modifierDocument(_doc(statut: 'brouillon', client: 'Client C'));
      expect(n.modifications, isEmpty);
    });
  });

  group('LigneDoc : unite et reference', () {
    test('valeurs par defaut : pcs, reference vide', () {
      const l = LigneDoc(libelle: 'A', quantite: 1, prixUnitaire: 100);
      expect(l.unite, 'pcs');
      expect(l.reference, '');
    });

    test('copie complete, y compris unite et reference', () {
      const l = LigneDoc(
          libelle: 'A',
          quantite: 2,
          prixUnitaire: 500,
          unite: 'kg',
          reference: 'REF-9');
      final m = l.copyWith(quantite: 3);
      expect(m.quantite, 3);
      expect(m.unite, 'kg', reason: 'copyWith ne doit rien perdre');
      expect(m.reference, 'REF-9');
      expect(m.libelle, 'A');
    });

    test('lecture d une base non migree : unite retombe sur pcs', () {
      final l = LigneDoc.fromMap({
        'libelle': 'Câble',
        'quantite': 2,
        'prix_unitaire': 1000.0,
        // colonnes DML_DATES_DOCUMENTS.sql absentes
      });
      expect(l.unite, 'pcs', reason: 'jamais une ligne sans unite');
      expect(l.reference, '');
    });

    test('lecture : unite vide/null retombe sur pcs', () {
      for (final v in ['', '   ', null]) {
        expect(LigneDoc.fromMap({
          'libelle': 'A',
          'quantite': 1,
          'prix_unitaire': 0.0,
          'unite': v,
        }).unite, 'pcs');
      }
    });

    test('lecture cloud complet : unite et reference conservees', () {
      final l = LigneDoc.fromMap({
        'libelle': 'Câble',
        'quantite': 3,
        'prix_unitaire': 1500.0,
        'unite': 'kg',
        'reference': 'CAB-100',
      });
      expect(l.unite, 'kg');
      expect(l.reference, 'CAB-100');
      expect(l.total, 4500.0);
    });

    test('aller-retour JSON conserve unite et reference', () {
      const l = LigneDoc(
          libelle: 'A',
          quantite: 2,
          prixUnitaire: 500,
          unite: 'lot',
          reference: 'L-1');
      final r = LigneDoc.depuisJson(l.toJson());
      expect(r.unite, 'lot');
      expect(r.reference, 'L-1');
    });
  });

  group('conditions de reglement et pied de document', () {
    test('copyWith porte les nouveaux champs', () {
      final m = _doc().copyWith(
        note: 'Marchandise verifiee',
        adresseLivraison: 'Plateau, Dakar',
        delaiPaiementJours: 30,
        echeance: '31/10/2026',
      );
      expect(m.note, 'Marchandise verifiee');
      expect(m.adresseLivraison, 'Plateau, Dakar');
      expect(m.delaiPaiementJours, 30);
      expect(m.echeance, '31/10/2026');
    });

    test('un document sans conditions garde des valeurs neutres', () {
      final d = _doc();
      expect(d.note, '');
      expect(d.adresseLivraison, '');
      expect(d.echeance, '');
      expect(d.delaiPaiementJours, 0);
    });

    test('echeance calculee en JOURS, pas en mois', () {
      // Piège classique : au 31, +1 mois donnerait le 28/02 (ou le 3/03),
      // alors que la date du document + 1 jour est le 1er du mois suivant.
      final base = DateTime(2026, 1, 31);
      final echeance = base.add(const Duration(days: 1));
      expect(DocumentService.formatDate(echeance), '01/02/2026');
    });

    test('parseAffichage / formatDate font aller-retour', () {
      for (final s in ['01/10/2026', '31/12/2025', '15/06/2026']) {
        expect(DocumentService.formatDate(DocumentService.parseAffichage(s)!),
            s);
      }
    });
  });

  group('totaux : jamais de facture fausse', () {
    test('recalculeTaux reflette les nouvelles lignes', () {
      final m = _doc().copyWith(lignes: [
        const LigneDoc(libelle: 'A', quantite: 2, prixUnitaire: 1000),
        const LigneDoc(libelle: 'B', quantite: 1, prixUnitaire: 3000),
      ]).recalculeTaux(18);
      expect(m.totalHT, 5000);
      expect(m.tva, 900);
      expect(m.totalTTC, 5900);
    });

    test('l unite ne change pas le montant (elle est un libelle)', () {
      const avecPcs = LigneDoc(libelle: 'A', quantite: 2, prixUnitaire: 1000);
      const avecKg =
          LigneDoc(libelle: 'A', quantite: 2, prixUnitaire: 1000, unite: 'kg');
      expect(avecKg.total, avecPcs.total,
          reason: '« 2 kg a 1000 » vaut « 2 pcs a 1000 » : 2000. Sinon le '
              'prix au kilo serait lu comme un prix a l\'unite.');
    });
  });

  group('PDF : unite et reference imprimees', () {
    test('un PDF se genere avec unite, reference, note et echeance',
        () async {
      final d = _doc(
              type: TypeDocument.bonLivraison,
              lignes: const [
                LigneDoc(
                    libelle: 'Câble réseau',
                    quantite: 3,
                    prixUnitaire: 0,
                    unite: 'kg',
                    reference: 'CAB-100')
              ],
              totalHT: 0,
              tva: 0,
              totalTTC: 0)
          .copyWith(
        note: 'Livraison a confirmer par telephone',
        adresseLivraison: 'Plateau, Dakar',
      );
      final profile = CompanyProfile(nomEntreprise: 'AESOLTECH AFRIQUE');
      final bytes = await PdfService.generer(d, profile);
      expect(bytes.isNotEmpty, isTrue,
          reason: 'le PDF doit se generer : une valeur qui casse la '
              'generation serait invisible a l\'ecran');
    });
  });

  group('cout de l argent : la regle ne doit rien bloquer par surprise', () {
    test('modifier un devis emis aboutit vraiment', () async {
      final n = _notifier(init: [
        _doc(type: TypeDocument.devisProforma, statut: 'emis')
      ]);
      final err = await n.modifierDocument(
        _doc(type: TypeDocument.devisProforma, client: 'Nouveau client'),
        motif: 'client errone',
      );
      expect(err, isNull, reason: err);
      expect(n.documentsEmis.first.client, 'Nouveau client');
    });

    test('et un brouillon sans motif aussi', () async {
      final n = _notifier(init: [_doc(statut: 'brouillon')]);
      final err = await n.modifierDocument(
          _doc(statut: 'brouillon', client: 'X'));
      expect(err, isNull, reason: err);
    });
  });
}