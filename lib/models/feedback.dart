/// Suggestion, recommandation, proposition, signalement de panne ou avis —
/// la boîte à idées et à signalements de l'entreprise.
enum TypeFeedback { recommandation, suggestion, proposition, panne, avis }

enum PrioriteFeedback { basse, normale, haute }

enum StatutFeedback { nouveau, enCours, traite }

extension TypeFeedbackX on TypeFeedback {
  String get label => switch (this) {
        TypeFeedback.recommandation => 'Recommandation',
        TypeFeedback.suggestion => 'Suggestion',
        TypeFeedback.proposition => 'Proposition',
        TypeFeedback.panne => 'Signalement de panne',
        TypeFeedback.avis => 'Avis',
      };
  String get icone => switch (this) {
        TypeFeedback.recommandation => '👍',
        TypeFeedback.suggestion => '💡',
        TypeFeedback.proposition => '📋',
        TypeFeedback.panne => '🔧',
        TypeFeedback.avis => '💬',
      };
}

extension PrioriteFeedbackX on PrioriteFeedback {
  String get label => switch (this) {
        PrioriteFeedback.basse => 'Basse',
        PrioriteFeedback.normale => 'Normale',
        PrioriteFeedback.haute => 'Haute 🔴',
      };
}

extension StatutFeedbackX on StatutFeedback {
  String get label => switch (this) {
        StatutFeedback.nouveau => 'Nouveau',
        StatutFeedback.enCours => 'En cours',
        StatutFeedback.traite => 'Traité ✅',
      };
}

class Feedback {
  final String id;
  final String auteurId;
  final String auteurNom;
  final String boutiqueId;
  final TypeFeedback type;
  final PrioriteFeedback priorite;
  final String titre;
  final String contenu;
  final StatutFeedback statut;
  final DateTime date;

  const Feedback({
    required this.id,
    required this.auteurId,
    required this.auteurNom,
    required this.boutiqueId,
    required this.type,
    required this.titre,
    required this.contenu,
    required this.date,
    this.priorite = PrioriteFeedback.normale,
    this.statut = StatutFeedback.nouveau,
  });

  Feedback copyWith({
    StatutFeedback? statut,
    TypeFeedback? type,
    PrioriteFeedback? priorite,
    String? titre,
    String? contenu,
  }) =>
      Feedback(
        id: id, auteurId: auteurId, auteurNom: auteurNom,
        boutiqueId: boutiqueId, type: type ?? this.type,
        titre: titre ?? this.titre, contenu: contenu ?? this.contenu,
        date: date, priorite: priorite ?? this.priorite,
        statut: statut ?? this.statut,
      );
}
