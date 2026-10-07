/// Ligne d'un document commercial (facture, devis, bon de commande…)
class LigneDoc {
  final String libelle;
  final int quantite;
  final double prixUnitaire;
  /// Unité de vente — quasi obligatoire en pratique : « 2 » ne veut rien
  /// dire sans savoir si ce sont 2 pièces, 2 kg ou 2 heures. Affichée sur
  /// le document, exigée sur facture et bordereau.
  final String unite;
  /// Référence de l'article (code article). Traçabilité : relie la ligne
  /// à la fiche produit après coup.
  final String reference;

  const LigneDoc({
    required this.libelle,
    required this.quantite,
    required this.prixUnitaire,
    this.unite = 'pcs',
    this.reference = '',
  });

  double get total => quantite * prixUnitaire;

  LigneDoc copyWith({
    String? libelle,
    int? quantite,
    double? prixUnitaire,
    String? unite,
    String? reference,
  }) =>
      LigneDoc(
        libelle: libelle ?? this.libelle,
        quantite: quantite ?? this.quantite,
        prixUnitaire: prixUnitaire ?? this.prixUnitaire,
        unite: unite ?? this.unite,
        reference: reference ?? this.reference,
      );

  Map<String, dynamic> toJson() => {
        'libelle': libelle,
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
        'unite': unite,
        'reference': reference,
      };

  /// Depuis une ligne Supabase (`document_lignes`). Les colonnes `unite`
  /// et `reference` sont absentes sur une base non migrée : une valeur
  /// nulle ou vide retombe sur 'pcs' plutôt que d'afficher une ligne
  /// sans unité.
  ///
  /// Source unique de désérialisation : le cloud ET la sauvegarde locale
  /// passent par ici, donc les deux donnent le même modèle.
  factory LigneDoc.fromMap(Map<String, dynamic> j) => LigneDoc(
        libelle: (j['libelle'] ?? '').toString(),
        quantite: (j['quantite'] as num?)?.round() ?? 1,
        prixUnitaire: (j['prix_unitaire'] as num?)?.toDouble() ?? 0,
        unite: _ouDefaut(j['unite'], 'pcs'),
        reference: (j['reference'] ?? '').toString(),
      );

  /// Valeur texte non vide, sinon le repli.
  static String _ouDefaut(Object? v, String defaut) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? defaut : s;
  }

  static LigneDoc depuisJson(Map<String, dynamic> j) => LigneDoc(
        libelle: (j['libelle'] ?? '') as String,
        quantite: (j['quantite'] as num?)?.round() ?? 0,
        prixUnitaire: (j['prix_unitaire'] as num?)?.toDouble() ?? 0,
        // Enregistrements antérieurs : pas de colonne -> unité par
        // défaut, plutôt qu'une ligne sans unité.
        unite: _ouDefaut(j['unite'], 'pcs'),
        reference: (j['reference'] ?? '').toString(),
      );
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

  /// Documents dont le contenu reste modifiable APRÈS émission.
  ///
  /// Règle professionnelle, différenciée par nature du document — un
  /// numéro de facture ne doit correspondre qu'à un seul contenu (c'est un
  /// justificatif fiscal), alors qu'un devis est une proposition et qu'un
  /// bordereau se corrige en pratique (reliquats, avaries).
  ///
  /// `facture` et `ticketCaisse` en sont donc EXCLUS : leur correction
  /// passe par un avoir (note de crédit) ou une annulation avec motif
  /// suivie d'une ré-émission. Voir `DocumentBati.peutModifier`.
  bool get modifiableApresEmission => switch (this) {
        TypeDocument.devisProforma ||
        TypeDocument.bonCommande ||
        TypeDocument.bonLivraison =>
          true,
        TypeDocument.facture || TypeDocument.ticketCaisse => false,
      };
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
