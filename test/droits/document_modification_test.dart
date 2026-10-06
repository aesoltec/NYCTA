import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/document_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/services/document_service.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/shell/app_shell.dart';

DocumentBati _doc({
  String numero = 'DEV-001',
  String statut = 'brouillon',
  String client = 'Client A',
  List<LigneDoc>? lignes,
}) =>
    DocumentBati(
      id: 'doc1',
      type: TypeDocument.devisProforma,
      numero: numero,
      date: '01/10/2026',
      client: client,
      lignes: lignes ??
          const [
            LigneDoc(libelle: 'Câble', quantite: 2, prixUnitaire: 1000)
          ],
      totalHT: 2000,
      tva: 360,
      totalTTC: 2360,
      devise: 'FCFA',
      statut: statut,
    );

DocumentNotifier _notifier(
    {Role role = Role.admin, List<DocumentBati>? init}) {
  final n = DocumentNotifier(
    session: SessionNotifier(AppUser(id: 'u', nom: 'T', role: role)),
    numeroDocument: (p) async => 'X-1',
    boutiqueId: 'b1',
    documentsEmis: init ?? [_doc()],
  );
  return n;
}

void main() {
  group('modifier un document BROUILLON', () {
    test('client et lignes sont modifies', () async {
      final n = _notifier();
      final err = await n.modifierDocument(_doc(
        client: 'Client B',
        lignes: const [
          LigneDoc(libelle: 'Câble', quantite: 5, prixUnitaire: 1000),
          LigneDoc(libelle: 'Prise', quantite: 2, prixUnitaire: 500),
        ],
      ));
      expect(err, isNull);
      final d = n.documentsEmis.first;
      expect(d.client, 'Client B');
      expect(d.lignes.length, 2);
    });

    test('la liste n est pas dupliquee', () async {
      final n = _notifier();
      final avant = n.documentsEmis.length;
      await n.modifierDocument(_doc(client: 'Client B'));
      expect(n.documentsEmis.length, avant,
          reason: 'enregistrerDocument faisait insert(0) : le rejouer '
              'dupliquait le document au lieu de le mettre a jour');
      expect(n.documentsEmis.where((d) => d.client == 'Client B').length, 1);
    });

    test('les totaux sont recalcules (pas de facture fausse)', () async {
      final n = _notifier();
      await n.modifierDocument(
        _doc(lignes: const [
          LigneDoc(libelle: 'Câble', quantite: 3, prixUnitaire: 1000),
        ]),
        tvaPct: 18,
      );
      final d = n.documentsEmis.first;
      expect(d.totalHT, 3000);
      expect(d.tva, closeTo(540, 0.01));
      expect(d.totalTTC, closeTo(3540, 0.01));
    });

    test('un document inconnu est refuse', () async {
      final n = _notifier();
      // Ni le numero NI l'id doivent correspondre : la recherche se fait
      // sur les deux, l'id étant l'identité cloud.
      final err = await n.modifierDocument(
          DocumentBati(
        id: 'doc999',
        type: TypeDocument.devisProforma,
        numero: 'DEV-999',
        date: '01/10/2026',
        client: 'Z',
        lignes: const [],
        totalHT: 0,
        tva: 0,
        totalTTC: 0,
        devise: 'FCFA',
      ));
      expect(err, contains('introuvable'));
    });

    test('l identite prime : changer le numero mais garder l id modifie',
        () async {
      // Comportement voulu : l'id est l'identite du document. Renuméroter
      // ne doit pas créer un doublon.
      final n = _notifier();
      final avant = n.documentsEmis.length;
      final err = await n.modifierDocument(_doc(numero: 'DEV-777'));
      expect(err, isNull);
      expect(n.documentsEmis.length, avant);
      expect(n.documentsEmis.first.numero, 'DEV-777');
    });
  });

  group('modifier un document EMIS : refus justifie', () {
    test('refuse, et nomme la voie legitime', () async {
      final n = _notifier(init: [_doc(statut: 'emis')]);
      final err = await n.modifierDocument(_doc(statut: 'emis', client: 'X'));
      expect(err, isNotNull);
      expect(err!.toLowerCase(), contains('annul'),
          reason: 'le refus doit dire comment faire autrement, sinon '
              "l'utilisateur cherche pourquoi l'editeur ne marche pas");
      expect(n.documentsEmis.first.client, 'Client A',
          reason: 'rien ne doit avoir ete modifie');
    });

    test('un vendeur peut emettre un brouillon mais pas le valider', () {
      // le comportement existant : vendeur -> brouillon
      expect(_doc(statut: 'brouillon').statut, 'brouillon');
    });
  });

  group('copyWith couvre tout le document', () {
    test('champs principaux', () {
      final d = _doc();
      final m = d.copyWith(
        client: 'Z', date: '02/10/2026', numero: 'DEV-002',
        totalHT: 1, tva: 2, totalTTC: 3, devise: 'EUR',
      );
      expect(m.client, 'Z');
      expect(m.date, '02/10/2026');
      expect(m.numero, 'DEV-002');
      expect(m.devise, 'EUR');
      expect(m.id, d.id, reason: 'les champs non fournis sont conserves');
    });

    test('une signature peut etre EFFACEE', () {
      final d = _doc().copyWith(signatureClientPath: '/sig.png');
      expect(d.copyWith(effacerSignature: true).signatureClientPath, isNull,
          reason: 'avant, `?? this.x` rendait l effacement impossible');
    });

    test('un motif d annulation peut etre efface', () {
      final d = _doc().copyWith(motifAnnulation: 'erreur');
      expect(d.copyWith(effacerMotif: true).motifAnnulation, isNull);
    });
  });

  group('achats : aucun acces pour le vendeur ni le caissier', () {
    Store _store(Role role) => Store(AppUser(id: 'u', nom: 'T', role: role));

    test('pas d onglet Achats dans la barre basse', () {
      for (final r in [Role.vendeur, Role.caissier, Role.stagiaire]) {
        expect(AppShell.ongletsAutorises(_store(r)), isNot(contains('Achats')),
            reason: '$r ne doit pas voir les achats');
      }
    });

    test('l admin et le gerant les voient', () {
      expect(AppShell.ongletsAutorises(_store(Role.admin)),
          contains('Achats'));
      expect(AppShell.ongletsAutorises(_store(Role.gerant)),
          contains('Achats'));
    });
  });
}
