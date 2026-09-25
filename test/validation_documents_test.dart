import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/services/document_service.dart';

Future<DocumentBati> _brouillon(Store s) => DocumentService().build(
      profile: s.profile,
      numeroGenerator: s.numeroDocument,
      type: TypeDocument.facture,
      client: 'Client',
      lignes: const [
        LigneDoc(libelle: 'Article', quantite: 1, prixUnitaire: 1000)
      ],
    );

void main() {
  group('Validation manager des documents', () {
    test('vendeur émet en brouillon, manager valide', () async {
      final vendeur = Store(const AppUser(
          id: 'u_v', nom: 'V', role: Role.vendeur));
      final doc = await _brouillon(vendeur);
      await vendeur.enregistrerDocument(doc);
      expect(vendeur.documentsEmis.first.statut, 'brouillon');
      // Le vendeur ne peut pas valider lui-même.
      expect(
          await vendeur.validerDocument(
              vendeur.documentsEmis.first.numero),
          isNotNull);

      final admin = Store(const AppUser(
          id: 'u_a', nom: 'A', role: Role.admin));
      final doc2 = await _brouillon(admin);
      await admin.enregistrerDocument(doc2);
      expect(admin.documentsEmis.first.statut, 'emis');
    });

    test('roles financiers émettent directement en emis', () async {
      for (final role in [Role.admin, Role.gerant, Role.comptable]) {
        final s = Store(
            AppUser(id: 'u', nom: 'T', role: role));
        final doc = await _brouillon(s);
        await s.enregistrerDocument(doc);
        expect(s.documentsEmis.first.statut, 'emis',
            reason: role.name);
      }
    });

    test('validerDocument refuse l\'inconnu et le déjà validé', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      expect(await s.validerDocument('XXX'), isNotNull);
      final doc = await _brouillon(s);
      await s.enregistrerDocument(doc);
      expect(
          await s.validerDocument(s.documentsEmis.first.numero),
          contains('Déjà'));
    });

    test('payer puis annuler : transitions et gardes', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      final doc = await _brouillon(s);
      await s.enregistrerDocument(doc);
      final numero = s.documentsEmis.first.numero;
      // Émis direct (admin) : payable, annulable avec motif.
      expect(s.documentsEmis.first.statut, 'emis');
      expect(await s.annulerDocument(numero, 'x'), isNotNull);
      expect(await s.payerDocument(numero), isNull);
      expect(s.documentsEmis.first.statut, 'paye');
      // Vendeur exclu de tout le workflow.
      final v = Store(const AppUser(
          id: 'v', nom: 'V', role: Role.vendeur));
      final d2 = await _brouillon(v);
      await v.enregistrerDocument(d2);
      final n2 = v.documentsEmis.first.numero;
      expect(v.documentsEmis.first.statut, 'brouillon');
      expect(await v.payerDocument(n2), isNotNull);
      expect(await v.annulerDocument(n2, 'motif valable'), isNotNull);
      // Annulation admin avec motif, puis double annulation refusée.
      expect(await s.annulerDocument(numero, 'Doublon'), isNull);
      expect(s.documentsEmis.first.statut, 'annule');
      expect(s.documentsEmis.first.motifAnnulation, 'Doublon');
      expect(await s.annulerDocument(numero, 'Doublon'), isNotNull);
      expect(await s.payerDocument(numero), isNotNull);
    });
  });
}
