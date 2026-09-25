/// Ligne d'un document commercial (facture, devis, bon de commande…)
class LigneDoc {
  final String libelle;
  final int quantite;
  final double prixUnitaire;

  const LigneDoc({
    required this.libelle,
    required this.quantite,
    required this.prixUnitaire,
  });

  double get total => quantite * prixUnitaire;
}

enum TypeDocument { facture, devisProforma, bonCommande, ticketCaisse, bonLivraison }

extension TypeDocumentX on TypeDocument {
  String get prefixe => switch (this) {
        TypeDocument.facture => 'FACT',
        TypeDocument.devisProforma => 'DEV',
        TypeDocument.bonCommande => 'BC',
        TypeDocument.ticketCaisse => 'TCK',
        TypeDocument.bonLivraison => 'BL',
      };
  String get titre => switch (this) {
        TypeDocument.facture => 'FACTURE',
        TypeDocument.devisProforma => 'DEVIS PROFORMA',
        TypeDocument.bonCommande => 'BON DE COMMANDE',
        TypeDocument.ticketCaisse => 'TICKET DE CAISSE',
        TypeDocument.bonLivraison => 'BORDEREAU DE LIVRAISON',
      };

  /// Valeur de l'enum Postgres `type_document` (snake_case) — distincte du
  /// nom Dart camelCase pour devisProforma/bonCommande/ticketCaisse.
  String get dbValue => switch (this) {
        TypeDocument.facture => 'facture',
        TypeDocument.devisProforma => 'devis_proforma',
        TypeDocument.bonCommande => 'bon_commande',
        TypeDocument.ticketCaisse => 'ticket_caisse',
        TypeDocument.bonLivraison => 'bon_livraison',
      };

  /// Bordereau et facture décrémentent le stock à la validation ;
  /// devis et bon de commande : non (documents d'intention).
  bool get decrementeStock =>
      this == TypeDocument.facture ||
      this == TypeDocument.ticketCaisse ||
      this == TypeDocument.bonLivraison;

  /// Norme internationale : le bordereau de livraison ne contient AUCUN
  /// prix (quantités + désignations + signatures uniquement) — document
  /// de transport/réception, pas document commercial.
  bool get sansPrix => this == TypeDocument.bonLivraison;
}

/// Reconstruit un [TypeDocument] depuis la valeur snake_case Postgres
/// (l'inverse de [TypeDocumentX.dbValue] — `.byName()` échouerait ici).
TypeDocument typeDocumentDepuisDb(String v) => switch (v) {
      'facture' => TypeDocument.facture,
      'devis_proforma' => TypeDocument.devisProforma,
      'bon_commande' => TypeDocument.bonCommande,
      'ticket_caisse' => TypeDocument.ticketCaisse,
      'bon_livraison' => TypeDocument.bonLivraison,
      _ => throw ArgumentError('Type de document inconnu : $v'),
    };
