import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/partenaire_notifier.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/partage.dart';
import 'package:pme_gestion_pro/models/partenaire.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 2 — PartenaireNotifier (listes partagées injectées).
int _seq = 200;

PartenaireNotifier _notifier(
        {List<Tx> txs = const [], List<Partage> pgs = const []}) =>
    PartenaireNotifier(
        genererId: () => 'pt${_seq++}',
        transactions: [...txs],
        partages: [...pgs]);

Partenaire _p(String nom) => Partenaire(
    id: '', nom: nom, telephone: '0700', localisation: 'Q', taux: 0.6);

void main() {
  group('PartenaireNotifier CRUD', () {
    test('ajouter : nom court + doublon (casse) refusés', () async {
      final n = _notifier();
      expect(await n.ajouterPartenaire(_p('X')),
          contains('Nom requis'));
      expect(await n.ajouterPartenaire(_p('Kouassi')), isNull);
      expect(await n.ajouterPartenaire(_p('KOUASSI')),
          contains('existe déjà'));
    });

    test('maj : introuvable + collision autre fiche', () async {
      final n = _notifier();
      expect(
          await n.majPartenaire(Partenaire(
              id: 'zz',
              nom: 'X',
              telephone: '',
              localisation: '')),
          'Partenaire introuvable');
      await n.ajouterPartenaire(_p('Awa'));
      await n.ajouterPartenaire(_p('Moussa'));
      final awa =
          n.partenaires.firstWhere((p) => p.nom == 'Awa');
      expect(
          await n.majPartenaire(Partenaire(
              id: awa.id,
              nom: 'moussa',
              telephone: '',
              localisation: '')),
          'Un autre partenaire porte déjà ce nom');
    });

    test('desactiver conserve la fiche', () async {
      final n = _notifier();
      await n.ajouterPartenaire(_p('Kouassi'));
      final id = n.partenaires.first.id;
      await n.desactiverPartenaire(id);
      expect(n.partenaires.first.actif, isFalse);
      expect(n.partenaires.length, 1);
      await n.desactiverPartenaire('zz'); // sans effet
    });

    test('supprimer : protégée avec historique', () async {
      final avecVentes = _notifier(txs: [
        Tx(
            id: 't1',
            boutiqueId: 'b1',
            employeId: 'u',
            type: TypeTransaction.forfaitHotspot,
            montant: 1000,
            date: DateTime(2026, 9, 1),
            partenaireId: 'PX'),
      ]);
      avecVentes.partenaires.add(const Partenaire(
          id: 'PX', nom: 'Hist', telephone: '', localisation: ''));
      expect(await avecVentes.supprimerPartenaire('PX'),
          contains('désactivez-le'));
      expect(await avecVentes.supprimerPartenaire('zz'),
          'Partenaire introuvable');
      final n = _notifier();
      await n.ajouterPartenaire(_p('Temporaire'));
      expect(
          await n.supprimerPartenaire(n.partenaires.first.id),
          isNull);
      expect(n.partenaires, isEmpty);
    });
  });

  group('PartenaireNotifier clôture', () {
    test('cloturerMois local : total + parts', () async {
      final n = _notifier(txs: [
        Tx(
            id: 't1',
            boutiqueId: 'b1',
            employeId: 'u',
            type: TypeTransaction.forfaitHotspot,
            montant: 10000,
            date: DateTime(2026, 9, 5),
            partenaireId: 'PX'),
        Tx(
            id: 't2',
            boutiqueId: 'b1',
            employeId: 'u',
            type: TypeTransaction.forfaitHotspot,
            montant: 5000,
            date: DateTime(2026, 9, 6),
            partenaireId: 'PX'),
      ]);
      n.partenaires.add(const Partenaire(
          id: 'PX',
          nom: 'K',
          telephone: '',
          localisation: '',
          taux: 0.6));
      final pg = await n.cloturerMois('PX', '2026-09', 'b1');
      expect(pg.totalVentes, 15000.0);
      expect(pg.partPartenaire, 9000.0);
      expect(pg.partEntreprise, 6000.0);
      expect(n.partageExiste('PX', '2026-09'), isTrue);
      expect(n.partagesDe('PX').length, 1);
    });

    test('partagesDe vide + partageExiste faux', () {
      final n = _notifier();
      expect(n.partagesDe('zz'), isEmpty);
      expect(n.partageExiste('zz', '2026-09'), isFalse);
    });
  });
}
