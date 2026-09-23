/// Message de la messagerie interne.
/// [destinataireId] null = diffusé à TOUS les utilisateurs.
class Message {
  final String id;
  final String expediteurId;
  final String expediteurNom;
  final String? destinataireId;
  final String sujet;
  final String contenu;
  final DateTime date;
  final bool lu;

  const Message({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    this.destinataireId,
    required this.sujet,
    required this.contenu,
    required this.date,
    this.lu = false,
  });

  bool mEstDestineA(String userId) =>
      destinataireId == null || destinataireId == userId;

  Message copyWith({bool? lu, String? sujet, String? contenu}) => Message(
        id: id, expediteurId: expediteurId, expediteurNom: expediteurNom,
        destinataireId: destinataireId,
        sujet: sujet ?? this.sujet, contenu: contenu ?? this.contenu,
        date: date, lu: lu ?? this.lu,
      );
}
