import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/client_notifier.dart';
import 'package:pme_gestion_pro/models/client.dart';

/// Phase 2 — ClientNotifier.
int _seq = 0;

ClientNotifier _notifier() =>
    ClientNotifier(genererId: () => 'cl${_seq++}', boutiqueId: 'b1');

Client _client(String nom) => Client(
    id: '', boutiqueId: 'b1', nom: nom, telephone: '0700');

void main() {
  group('ClientNotifier', () {
    test('ajouter : nom court + doublon refusés', () async {
      final n = _notifier();
      expect(await n.ajouterClient(_client('X')), 'Nom trop court');
      expect(await n.ajouterClient(_client('Moussa')), isNull);
      expect(
          await n.ajouterClient(_client('moussa')),
          'Ce client existe déjà dans cette boutique');
      expect(n.clients.length, 1);
    });

    test('même nom, autre boutique → accepté', () async {
      final n = _notifier();
      await n.ajouterClient(_client('Moussa'));
      final autre = Client(
          id: '', boutiqueId: 'b2', nom: 'Moussa', telephone: '');
      // boutiqueId du client prime sur celle du notifier.
      expect(await n.ajouterClient(autre), isNull);
      expect(n.clients.length, 2);
    });

    test('clientsBoutique filtre', () async {
      final n = _notifier();
      await n.ajouterClient(_client('Awa'));
      n.clients.add(const Client(
          id: 'x', boutiqueId: 'b2', nom: 'Autre'));
      expect(n.clientsBoutique.length, 1);
      expect(n.clientsBoutique.first.nom, 'Awa');
    });

    test('champs étendus conservés (email, rccm, logo)', () async {
      final n = _notifier();
      await n.ajouterClient(const Client(
          id: '',
          boutiqueId: 'b1',
          nom: 'SARL Test',
          email: 'a@b.c',
          rccm: 'RCCM-1',
          logoPath: '/tmp/logo.png'));
      final c = n.clientsBoutique.first;
      expect(c.email, 'a@b.c');
      expect(c.rccm, 'RCCM-1');
      expect(c.logoPath, '/tmp/logo.png');
      expect(c.estPro, isTrue);
    });

    test('majClient : remplace + inexistant sans effet', () async {
      final n = _notifier();
      await n.ajouterClient(_client('Koffi'));
      final id = n.clientsBoutique.first.id;
      await n.majClient(Client(
          id: id, boutiqueId: 'b1', nom: 'Koffi', telephone: '0711'));
      expect(n.clientsBoutique.first.telephone, '0711');
      await n.majClient(const Client(
          id: 'zz', boutiqueId: 'b1', nom: 'X Ghost'));
      expect(n.clients.length, 1);
    });
  });
}
