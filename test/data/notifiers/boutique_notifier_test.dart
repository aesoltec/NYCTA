import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/boutique_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/boutique.dart';
import 'package:pme_gestion_pro/models/enums.dart';

/// Phase 1 — BoutiqueNotifier (dépend de SessionNotifier).
int _seq = 0;

BoutiqueNotifier _notifier({Role role = Role.admin}) {
  final session = SessionNotifier(
      AppUser(id: 'u1', nom: 'T', role: role));
  final n = BoutiqueNotifier(
      session: session, genererId: () => 'b${_seq++}');
  n.boutiques.addAll(const [
    Boutique(id: 'b1', nom: 'Siège', siege: true),
    Boutique(id: 'b2', nom: 'Marché'),
  ]);
  n.boutiqueId = 'b1';
  return n;
}

void main() {
  group('BoutiqueNotifier', () {
    test('boutiqueCourante + actives', () {
      final n = _notifier();
      expect(n.boutiqueCourante.id, 'b1');
      expect(n.boutiquesActives.length, 2);
    });

    test('changerBoutique refuse hors accès', () {
      final n = _notifier(role: Role.vendeur);
      n.changerBoutique('b2'); // vendeur sans boutiqueIds
      expect(n.boutiqueId, 'b1');
    });

    test('changerBoutique accepte avec accès', () {
      final session = SessionNotifier(const AppUser(
          id: 'u', nom: 'V', role: Role.vendeur,
          boutiqueIds: ['b1', 'b2']));
      final n = BoutiqueNotifier(
          session: session, genererId: () => 'x');
      n.boutiques.addAll(const [
        Boutique(id: 'b1', nom: 'A'),
        Boutique(id: 'b2', nom: 'B'),
      ]);
      n.boutiqueId = 'b1';
      n.changerBoutique('b2');
      expect(n.boutiqueId, 'b2');
    });

    test('ajouterBoutique : nom court + doublon refusés', () async {
      final n = _notifier();
      expect(await n.ajouterBoutique(
          const Boutique(id: '', nom: 'X'), []), isNotNull);
      expect(await n.ajouterBoutique(
          const Boutique(id: '', nom: 'siège'), []), isNotNull);
      expect(n.boutiques.length, 2);
    });

    test('ajouterBoutique siège unique : démets les autres', () async {
      final n = _notifier();
      final err = await n.ajouterBoutique(
          const Boutique(id: '', nom: 'Nouveau', siege: true), []);
      expect(err, isNull);
      expect(n.boutiques.where((b) => b.siege).length, 1);
      expect(n.boutiques.last.nom, 'Nouveau');
    });

    test('fermerBoutique : dernière + courante protégées', () async {
      final n = _notifier();
      expect(await n.fermerBoutique('b2'), isNull);
      expect(n.boutiquesActives.length, 1);
      expect(await n.fermerBoutique('b1'), isNotNull); // dernière
      expect(await n.fermerBoutique('zz'), isNotNull); // introuvable
    });

    test('fermerBoutique refuse la courante', () async {
      final n = _notifier();
      n.boutiques.add(const Boutique(id: 'b3', nom: 'C'));
      expect(await n.fermerBoutique('b1'), isNotNull);
    });

    test('rouvrirBoutique : gardes + cycle', () async {
      final vendeur = _notifier(role: Role.vendeur);
      expect(await vendeur.rouvrirBoutique('b1'),
          contains('Réouverture réservée'));
      final n = _notifier();
      expect(await n.rouvrirBoutique('b1'), 'Boutique déjà active');
      expect(await n.rouvrirBoutique('zz'), 'Boutique introuvable');
      await n.fermerBoutique('b2');
      // RPC absente hors cloud → erreur réseau, état inchangé.
      final err = await n.rouvrirBoutique('b2');
      expect(err, isNotNull);
      expect(n.boutiquesActives.length, 1);
    });
  });
}
