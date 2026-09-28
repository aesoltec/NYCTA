import 'package:flutter/foundation.dart';
import '../../models/evenement.dart';
import '../../models/feedback.dart';
import '../../models/message.dart';
import '../../services/cloud_repository.dart';
import 'session_notifier.dart';

/// Collaboration (Phase 1 — découpage Store) : messagerie, événements,
/// notes & rappels, suggestions.
/// Rôle : CRUD complet + getters (visibles, non-lus, à venir, nouveaux).
/// Dépendances : `SessionNotifier` (user.id/nom) ; `genererId` injecté.
/// La persistance locale/file de sync est déléguée à `fileUpsert`
/// (câblée par la façade en Phase 5 ; no-op par défaut pour les tests).
/// Extrait à l'identique de `Store` (l.959-1092, l.1138-1181+).
class CollabNotifier extends ChangeNotifier {
  final SessionNotifier session;
  final String Function() genererId;
  final Future<void> Function(String table, Map<String, dynamic> payload)?
      fileUpsert;

  final List<Message> messages;
  final List<Evenement> evenements;
  final List<Note> notesPerso;
  final List<Feedback> feedbacks;

  CollabNotifier({
    required this.session,
    required this.genererId,
    this.fileUpsert,
    List<Message>? messages,
    List<Evenement>? evenements,
    List<Note>? notesPerso,
    List<Feedback>? feedbacks,
  })  : messages = messages ?? [],
        evenements = evenements ?? [],
        notesPerso = notesPerso ?? [],
        feedbacks = feedbacks ?? [];

  // ---------- Messagerie ----------
  List<Message> get messagesVisibles => messages
      .where((m) =>
          m.mEstDestineA(session.user.id) ||
          m.expediteurId == session.user.id)
      .toList();

  int get messagesNonLus => messages
      .where((m) =>
          !m.lu &&
          m.mEstDestineA(session.user.id) &&
          m.expediteurId != session.user.id)
      .length;

  Future<void> envoyerMessage({
    required String sujet,
    required String contenu,
    String? destinataireId,
  }) async {
    final m = Message(
      id: genererId(),
      expediteurId: session.user.id,
      expediteurNom: session.user.nom,
      destinataireId: destinataireId,
      sujet: sujet.trim(),
      contenu: contenu.trim(),
      date: DateTime.now(),
    );
    messages.insert(0, m);
    notifyListeners();
    await CloudRepository.envoyerMessage(m);
  }

  Future<void> marquerMessageLu(String id) async {
    final i = messages.indexWhere((m) => m.id == id);
    if (i >= 0 && !messages[i].lu) {
      messages[i] = messages[i].copyWith(lu: true);
      notifyListeners();
      await CloudRepository.marquerMessageLu(id);
    }
  }

  Future<void> marquerTousMessagesLus() async {
    for (var i = 0; i < messages.length; i++) {
      if (!messages[i].lu &&
          messages[i].mEstDestineA(session.user.id)) {
        messages[i] = messages[i].copyWith(lu: true);
      }
    }
    notifyListeners();
    await CloudRepository.marquerTousMessagesLus();
  }

  Future<String?> majMessage(Message maj) async {
    final i = messages.indexWhere((m) => m.id == maj.id);
    if (i < 0) return 'Message introuvable';
    if (maj.sujet.trim().length < 3) return 'Sujet trop court';
    if (maj.contenu.trim().length < 3) return 'Message trop court';
    messages[i] = maj;
    notifyListeners();
    await CloudRepository.majMessage(maj);
    await fileUpsert?.call('messages', {
      'id': maj.id,
      'expediteur_id': maj.expediteurId,
      'expediteur_nom': maj.expediteurNom,
      'destinataire_id': maj.destinataireId,
      'sujet': maj.sujet,
      'contenu': maj.contenu,
    });
    return null;
  }

  Future<void> supprimerMessage(String id) async {
    messages.removeWhere((m) => m.id == id);
    notifyListeners();
    await CloudRepository.supprimerMessage(id);
  }

  // ---------- Événements ----------
  List<Evenement> get evenementsAVenir {
    final l = evenements.where((e) => !e.estPasse).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  Future<void> ajouterEvenement(Evenement e) async {
    final evenement = Evenement(
      id: genererId(),
      titre: e.titre,
      date: e.date,
      heure: e.heure,
      lieu: e.lieu,
      description: e.description,
      createurId: e.createurId,
    );
    evenements.add(evenement);
    notifyListeners();
    await CloudRepository.upsertEvenement(evenement);
  }

  Future<void> majEvenement(Evenement e) async {
    final i = evenements.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      evenements[i] = e;
      notifyListeners();
      await CloudRepository.upsertEvenement(e);
    }
  }

  Future<void> supprimerEvenement(String id) async {
    evenements.removeWhere((e) => e.id == id);
    notifyListeners();
    await CloudRepository.supprimerEvenement(id);
  }

  // ---------- Notes ----------
  Future<void> ajouterNote(Note n) async {
    final note = Note(
      id: genererId(),
      titre: n.titre,
      contenu: n.contenu,
      date: n.date,
      rappelLe: n.rappelLe,
      createurId: n.createurId,
    );
    notesPerso.add(note);
    notifyListeners();
    await CloudRepository.upsertNote(note);
  }

  Future<void> majNote(Note n) async {
    final i = notesPerso.indexWhere((x) => x.id == n.id);
    if (i >= 0) {
      notesPerso[i] = n;
      notifyListeners();
      await CloudRepository.upsertNote(n);
    }
  }

  Future<void> supprimerNote(String id) async {
    notesPerso.removeWhere((n) => n.id == id);
    notifyListeners();
    await CloudRepository.supprimerNote(id);
  }

  // ---------- Suggestions & signalements ----------
  int get nouveauxFeedbacks => feedbacks
      .where((f) => f.statut == StatutFeedback.nouveau)
      .length;

  Future<String?> ajouterFeedback(Feedback f) async {
    if (f.titre.trim().length < 3) return 'Titre trop court';
    if (f.contenu.trim().length < 5) return 'Description trop courte';
    final feedback = Feedback(
      id: genererId(),
      auteurId: f.auteurId,
      auteurNom: f.auteurNom,
      boutiqueId: f.boutiqueId,
      type: f.type,
      priorite: f.priorite,
      titre: f.titre,
      contenu: f.contenu,
      statut: f.statut,
      date: f.date,
    );
    feedbacks.insert(0, feedback);
    notifyListeners();
    await CloudRepository.ajouterFeedback(feedback);
    return null;
  }

  Future<void> changerStatutFeedback(
      String id, StatutFeedback statut) async {
    final i = feedbacks.indexWhere((f) => f.id == id);
    if (i >= 0) {
      feedbacks[i] = feedbacks[i].copyWith(statut: statut);
      notifyListeners();
      await CloudRepository.majStatutFeedback(id, statut);
    }
  }

  Future<String?> majFeedback(Feedback maj) async {
    final i = feedbacks.indexWhere((f) => f.id == maj.id);
    if (i < 0) return 'Contribution introuvable';
    if (maj.titre.trim().length < 3) return 'Titre trop court';
    if (maj.contenu.trim().length < 5) return 'Description trop courte';
    feedbacks[i] = maj;
    notifyListeners();
    await CloudRepository.majFeedback(maj);
    await fileUpsert?.call('feedbacks', {
      'id': maj.id,
      'type': maj.type.name,
      'priorite': maj.priorite.name,
      'titre': maj.titre,
      'contenu': maj.contenu,
      'statut': maj.statut.name,
    });
    return null;
  }

  Future<void> supprimerFeedback(String id) async {
    feedbacks.removeWhere((f) => f.id == id);
    notifyListeners();
    await CloudRepository.supprimerFeedback(id);
  }
}
