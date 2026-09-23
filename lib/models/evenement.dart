/// Réunion ou événement planifié.
class Evenement {
  final String id;
  final String titre;
  final DateTime date;
  final String heure;   // libre : '14h30'
  final String lieu;
  final String description;
  final String createurId;

  const Evenement({
    required this.id,
    required this.titre,
    required this.date,
    this.heure = '',
    this.lieu = '',
    this.description = '',
    this.createurId = '',
  });

  bool get estPasse => date.isBefore(DateTime.now());
}

/// Note personnelle avec rappel optionnel.
class Note {
  final String id;
  final String titre;
  final String contenu;
  final DateTime date;
  final DateTime? rappelLe; // notification ce jour-là
  final String createurId;

  const Note({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.date,
    this.rappelLe,
    this.createurId = '',
  });

  bool get rappelAujourdhui {
    final r = rappelLe;
    if (r == null) return false;
    final n = DateTime.now();
    return r.year == n.year && r.month == n.month && r.day == n.day;
  }
}
