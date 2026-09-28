import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/collab_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/evenement.dart';
import 'package:pme_gestion_pro/models/feedback.dart';
import 'package:pme_gestion_pro/models/message.dart';

/// Phase 1 — CollabNotifier (dépend de SessionNotifier).
int _seq = 0;

CollabNotifier _notifier() => CollabNotifier(
    session: SessionNotifier(
        const AppUser(id: 'u1', nom: 'Moi', role: Role.admin)),
    genererId: () => 'id${_seq++}');

void main() {
  group('CollabNotifier messagerie', () {
    test('envoyer + visibles + non-lus', () async {
      final n = _notifier();
      await n.envoyerMessage(
          sujet: 'Bonjour', contenu: 'Contenu ici');
      expect(n.messages.length, 1);
      // Envoyé par soi : visible mais pas compté non-lu.
      expect(n.messagesVisibles.length, 1);
      expect(n.messagesNonLus, 0);
      // Reçu d'un autre, non lu.
      n.messages.add(Message(
          id: 'm2',
          expediteurId: 'u2',
          expediteurNom: 'Autre',
          destinataireId: 'u1',
          sujet: 'Salut',
          contenu: 'Hello',
          date: DateTime.now()));
      expect(n.messagesNonLus, 1);
      await n.marquerMessageLu('m2');
      expect(n.messagesNonLus, 0);
    });

    test('marquerTousMessagesLus', () async {
      final n = _notifier();
      n.messages.addAll([
        Message(
            id: 'a',
            expediteurId: 'u2',
            expediteurNom: 'A',
            destinataireId: 'u1',
            sujet: 'S1',
            contenu: 'C1',
            date: DateTime.now()),
        Message(
            id: 'b',
            expediteurId: 'u2',
            expediteurNom: 'A',
            destinataireId: 'u1',
            sujet: 'S2',
            contenu: 'C2',
            date: DateTime.now(),
            lu: true),
      ]);
      await n.marquerTousMessagesLus();
      expect(n.messagesNonLus, 0);
    });

    test('majMessage : validations + introuvable', () async {
      final n = _notifier();
      await n.envoyerMessage(
          sujet: 'Sujet valide', contenu: 'Contenu valide');
      final m = n.messages.first;
      expect(
          await n.majMessage(
              m.copyWith(sujet: 'OK', contenu: 'OK')),
          isNotNull); // trop courts
      expect(
          await n.majMessage(m.copyWith(
              sujet: 'Nouveau sujet', contenu: 'Nouveau contenu')),
          isNull);
      expect(n.messages.first.sujet, 'Nouveau sujet');
    });

    test('supprimerMessage', () async {
      final n = _notifier();
      await n.envoyerMessage(sujet: 'S', contenu: 'C');
      await n.supprimerMessage(n.messages.first.id);
      expect(n.messages, isEmpty);
    });
  });

  group('CollabNotifier événements + notes', () {
    test('evenementsAVenir : futurs triés, passés exclus', () async {
      final n = _notifier();
      await n.ajouterEvenement(Evenement(
          id: '', titre: 'Lointain', date: DateTime(2030, 1, 2)));
      await n.ajouterEvenement(Evenement(
          id: '', titre: 'Proche', date: DateTime(2030, 1, 1)));
      await n.ajouterEvenement(Evenement(
          id: '', titre: 'Passé', date: DateTime(2020, 1, 1)));
      final avenir = n.evenementsAVenir;
      expect(avenir.length, 2);
      expect(avenir.first.titre, 'Proche');
      final id = avenir.first.id;
      await n.majEvenement(Evenement(
          id: id, titre: 'Proche!', date: DateTime(2030, 1, 1)));
      expect(
          n.evenements.firstWhere((e) => e.id == id).titre,
          'Proche!');
      await n.supprimerEvenement(id);
      expect(n.evenementsAVenir.length, 1);
    });

    test('notes CRUD', () async {
      final n = _notifier();
      await n.ajouterNote(Note(
          id: '',
          titre: 'Liste',
          contenu: 'Acheter du café',
          date: DateTime(2026, 9, 1),
          createurId: 'u1'));
      expect(n.notesPerso.length, 1);
      final id = n.notesPerso.first.id;
      await n.majNote(Note(
          id: id,
          titre: 'Liste!',
          contenu: 'Acheter du café',
          date: DateTime(2026, 9, 1),
          createurId: 'u1'));
      expect(n.notesPerso.first.titre, 'Liste!');
      await n.supprimerNote(id);
      expect(n.notesPerso, isEmpty);
    });
  });

  group('CollabNotifier feedbacks', () {
    Feedback fb(String titre, String contenu) => Feedback(
        id: '',
        auteurId: 'u1',
        auteurNom: 'Moi',
        boutiqueId: 'b1',
        type: TypeFeedback.suggestion,
        titre: titre,
        contenu: contenu,
        date: DateTime(2026, 9, 1));

    test('ajouter : validations', () async {
      final n = _notifier();
      expect(await n.ajouterFeedback(fb('AB', 'Contenu assez long')),
          'Titre trop court');
      expect(await n.ajouterFeedback(fb('Titre ok', 'abc')),
          'Description trop courte');
      expect(await n.ajouterFeedback(fb('Titre ok', 'Contenu assez long')),
          isNull);
      expect(n.nouveauxFeedbacks, 1);
    });

    test('statut + maj + suppression', () async {
      final n = _notifier();
      await n.ajouterFeedback(fb('Titre ok', 'Contenu assez long'));
      final id = n.feedbacks.first.id;
      await n.changerStatutFeedback(id, StatutFeedback.enCours);
      expect(n.nouveauxFeedbacks, 0);
      expect(
          await n.majFeedback(
              n.feedbacks.first.copyWith(titre: 'AB', contenu: 'CD')),
          'Titre trop court');
      expect(
          await n.majFeedback(n.feedbacks.first
              .copyWith(titre: 'Mieux', contenu: 'Bien mieux rédigé')),
          isNull);
      await n.supprimerFeedback(id);
      expect(n.feedbacks, isEmpty);
    });
  });
}
