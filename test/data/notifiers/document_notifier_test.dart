import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/document_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/services/document_service.dart';

/// Phase 3 — DocumentNotifier : workflow + signature + transformation.
DocumentNotifier _notifier({Role role = Role.admin}) =>
    DocumentNotifier(
      session: SessionNotifier(
          AppUser(id: 'u1', nom: 'T', role: role)),
      numeroDocument: (p) async => '$p-2026-00042',
      deduireStock: (lignes) async => const [],
      boutiqueId: 'b1',
    );

DocumentBati _doc({String numero = 'FACT-2026-00001'}) => DocumentBati(
    type: TypeDocument.facture,
    numero: numero,
    date: '26/09/2026',
    client: 'Moussa',
    lignes: const [
      LigneDoc(libelle: 'Câble', quantite: 2, prixUnitaire: 1000)
    ],
    totalHT: 2000,
    tva: 0,
    totalTTC: 2000,
    devise: 'FCFA');

void main() {
  group('DocumentNotifier émission', () {
    test('vendeur → brouillon, admin → emis', () async {
      final vendeur = _notifier(role: Role.vendeur);
      expect(await vendeur.enregistrerDocument(_doc()), isNull);
      expect(vendeur.documentsEmis.first.statut, 'brouillon');
      final admin = _notifier();
      expect(await admin.enregistrerDocument(_doc()), isNull);
      expect(admin.documentsEmis.first.statut, 'emis');
    });
  });

  group('DocumentNotifier workflow', () {
    test('valider : gardes + transition', () async {
      final vendeur = _notifier(role: Role.vendeur);
      await vendeur.enregistrerDocument(_doc());
      expect(await vendeur.validerDocument('FACT-2026-00001'),
          contains('Validation réservée'));
      final n = _notifier();
      expect(await n.validerDocument('zz'), 'Document introuvable');
      await n.enregistrerDocument(_doc());
      // Déjà emis (admin) → refus.
      expect(await n.validerDocument('FACT-2026-00001'),
          'Déjà validé');
      // Brouillon manuel → valide.
      n.documentsEmis.insert(
          0, _doc(numero: 'DEV-1').copyWith(statut: 'brouillon'));
      expect(await n.validerDocument('DEV-1'), isNull);
      expect(
          n.documentsEmis
              .firstWhere((d) => d.numero == 'DEV-1')
              .statut,
          'emis');
    });

    test('payer : emis seul + gardes', () async {
      final n = _notifier();
      expect(await n.payerDocument('zz'), 'Document introuvable');
      await n.enregistrerDocument(_doc());
      expect(await n.payerDocument('FACT-2026-00001'), isNull);
      expect(n.documentsEmis.first.statut, 'paye');
      expect(await n.payerDocument('FACT-2026-00001'),
          contains('émis'));
      final vendeur = _notifier(role: Role.vendeur);
      expect(await vendeur.payerDocument('zz'),
          contains('Réservé'));
    });

    test('annuler : motif + rôles + idempotence', () async {
      final n = _notifier();
      await n.enregistrerDocument(_doc());
      expect(await n.annulerDocument('FACT-2026-00001', 'ab'),
          contains('Motif'));
      expect(await n.annulerDocument('zz', 'Motif valable'),
          'Document introuvable');
      expect(
          await n.annulerDocument(
              'FACT-2026-00001', 'Erreur de saisie'),
          isNull);
      final d = n.documentsEmis.first;
      expect(d.statut, 'annule');
      expect(d.motifAnnulation, 'Erreur de saisie');
      expect(await n.annulerDocument('FACT-2026-00001', 'Encore'),
          'Déjà annulé');
      final comptable = _notifier(role: Role.comptable);
      expect(
          await comptable.annulerDocument('X', 'Motif valable'),
          contains('Annulation réservée'));
    });

    test('signature client jointe', () async {
      final n = _notifier();
      await n.enregistrerDocument(_doc());
      await n.joindreSignatureClient(
          'FACT-2026-00001', '/tmp/sig.png');
      expect(n.documentsEmis.first.signatureClientPath,
          '/tmp/sig.png');
      await n.joindreSignatureClient('zz', '/tmp/x.png'); // sans effet
    });

    test('transformer devis → facture (signature transmise)', () async {
      var deduit = false;
      final n = DocumentNotifier(
        session: SessionNotifier(
            const AppUser(id: 'u1', nom: 'T', role: Role.admin)),
        numeroDocument: (p) async => 'FACT-2026-00042',
        deduireStock: (lignes) async {
          deduit = true;
          return const [];
        },
        boutiqueId: 'b1',
      );
      final devis = DocumentBati(
          type: TypeDocument.devisProforma,
          numero: 'DEV-2026-00007',
          date: '25/09/2026',
          client: 'Awa',
          lignes: const [
            LigneDoc(libelle: 'Presta', quantite: 1, prixUnitaire: 5000)
          ],
          totalHT: 5000,
          tva: 0,
          totalTTC: 5000,
          devise: 'FCFA',
          signatureClientPath: '/tmp/sig.png');
      final facture = await n.transformerDevisEnFacture(devis);
      expect(facture.type, TypeDocument.facture);
      expect(facture.numero, 'FACT-2026-00042');
      expect(facture.date, '25/09/2026'); // date du devis conservée
      expect(facture.signatureClientPath, '/tmp/sig.png');
      expect(deduit, isTrue);
      expect(n.documentsEmis.first.numero, 'FACT-2026-00042');
    });
  });
}
