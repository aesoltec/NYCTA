// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/boutique.dart';
import '../../models/company_profile.dart';
import '../../models/evenement.dart';
import '../../models/feedback.dart';
import '../../models/message.dart';

/// Façade StoreCollabFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreCollabFacade on Store {
  // ---------- Messagerie / Événements / Notes (délégué à `collab`) ----------
  List<Message> get messagesVisibles => collab.messagesVisibles;

  int get messagesNonLus => collab.messagesNonLus;

  Future<void> envoyerMessage({
    required String sujet,
    required String contenu,
    String? destinataireId,
  }) =>
      collab.envoyerMessage(
          sujet: sujet,
          contenu: contenu,
          destinataireId: destinataireId);

  Future<void> marquerMessageLu(String id) =>
      collab.marquerMessageLu(id);

  Future<void> marquerTousMessagesLus() =>
      collab.marquerTousMessagesLus();

  Future<String?> majMessage(Message maj) => collab.majMessage(maj);

  Future<void> supprimerMessage(String id) =>
      collab.supprimerMessage(id);

  List<Evenement> get evenementsAVenir => collab.evenementsAVenir;

  Future<void> ajouterEvenement(Evenement e) =>
      collab.ajouterEvenement(e);

  Future<void> majEvenement(Evenement e) => collab.majEvenement(e);

  Future<void> supprimerEvenement(String id) =>
      collab.supprimerEvenement(id);

  Future<void> ajouterNote(Note n) => collab.ajouterNote(n);

  Future<void> majNote(Note n) => collab.majNote(n);

  Future<void> supprimerNote(String id) => collab.supprimerNote(id);

  // ---------- Suggestions (délégué à `collab`, Phase 5) ----------
  int get nouveauxFeedbacks => collab.nouveauxFeedbacks;

  Future<String?> ajouterFeedback(Feedback f) =>
      collab.ajouterFeedback(f);

  Future<void> changerStatutFeedback(
          String id, StatutFeedback statut) =>
      collab.changerStatutFeedback(id, statut);

  Future<String?> majFeedback(Feedback maj) =>
      collab.majFeedback(maj);

  Future<void> supprimerFeedback(String id) =>
      collab.supprimerFeedback(id);

  // ---------- Boutiques (délégué à `boutique`, Phase 5) ----------
  List<Boutique> get boutiquesActives => boutique.boutiquesActives;

  List<Boutique> get boutiquesAccessibles =>
      boutique.boutiquesAccessibles;

  Boutique get boutiqueCourante => boutique.boutiqueCourante;

  Future<String?> ajouterBoutique(Boutique b, List<String> userIds) =>
      boutique.ajouterBoutique(b, userIds);

  Future<String?> majBoutique(Boutique b, List<String> userIds) =>
      boutique.majBoutique(b, userIds);

  Future<String?> fermerBoutique(String id) =>
      boutique.fermerBoutique(id);

  Future<String?> rouvrirBoutique(String id) =>
      boutique.rouvrirBoutique(id);

  // ---------- Configuration entreprise (délégué à `profil`) ----------
  Future<void> updateProfile(CompanyProfile p) =>
      profil.updateProfile(p);

}
