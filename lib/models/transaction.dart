import 'enums.dart';

enum TypeTransaction {
  prestationService,
  venteMateriel,
  mobileMoney,
  creditCommunication,
  forfaitHotspot,
}

class Tx {
  final String id;
  final String boutiqueId;
  final String employeId;
  final TypeTransaction type;
  final double montant;
  final double cout;
  final StatutPaiement statut;
  final String? clientNom;
  final String? partenaireId;
  final Map<String, dynamic> details;
  final DateTime date;

  const Tx({
    required this.id,
    required this.boutiqueId,
    required this.employeId,
    required this.type,
    required this.montant,
    this.cout = 0,
    this.statut = StatutPaiement.paye,
    this.clientNom,
    this.partenaireId,
    this.details = const {},
    required this.date,
  });

  double get marge => montant - cout;

  Tx copyWith({
    String? id,
    String? boutiqueId,
    String? employeId,
    TypeTransaction? type,
    double? montant,
    double? cout,
    StatutPaiement? statut,
    String? clientNom,
    String? partenaireId,
    Map<String, dynamic>? details,
    DateTime? date,
  }) =>
      Tx(
        id: id ?? this.id,
        boutiqueId: boutiqueId ?? this.boutiqueId,
        employeId: employeId ?? this.employeId,
        type: type ?? this.type,
        montant: montant ?? this.montant,
        cout: cout ?? this.cout,
        statut: statut ?? this.statut,
        clientNom: clientNom ?? this.clientNom,
        partenaireId: partenaireId ?? this.partenaireId,
        details: details ?? this.details,
        date: date ?? this.date,
      );

  /// Remise à null explicite (copyWith ne distingue pas null = inchangé).
  Tx sansPartenaire() => Tx(
        id: id,
        boutiqueId: boutiqueId,
        employeId: employeId,
        type: type,
        montant: montant,
        cout: cout,
        statut: statut,
        clientNom: clientNom,
        partenaireId: null,
        details: details,
        date: date,
      );
}
