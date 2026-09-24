/// Achat fournisseur (Phase 2) : réapprovisionnement stock + dette fournisseur.
///
/// Cycle de vie : `demande` → `en_attente` → `valide` → `recu` (+ paiements
/// partiels) ; `annule` à tout moment avec motif (contre-écriture si reçu).
/// Impacts : réception ⇒ stock + (CUMP) ; paiement ⇒ charge
/// « Fournisseurs » (trésorerie) ; validation seule ⇒ dette (reste dû).
class LigneAchat {
  final String produitId; // '' si article libre (hors stock)
  final String produitNom;
  final double quantite;
  final String unite; // 'piece', 'kg', 'litre', 'metre', …
  final double prixUnitaire;
  final double tauxTVA; // % (ex : 18)

  const LigneAchat({
    this.produitId = '',
    required this.produitNom,
    required this.quantite,
    this.unite = 'piece',
    required this.prixUnitaire,
    this.tauxTVA = 0,
  });

  double get totalHT => quantite * prixUnitaire;
  double get totalTTC => totalHT * (1 + tauxTVA / 100);

  Map<String, dynamic> toJson() => {
        'produitId': produitId, 'produitNom': produitNom,
        'quantite': quantite, 'unite': unite,
        'prixUnitaire': prixUnitaire, 'tauxTVA': tauxTVA,
      };

  factory LigneAchat.fromJson(Map<String, dynamic> j) => LigneAchat(
        produitId: j['produitId']?.toString() ?? '',
        produitNom: j['produitNom']?.toString() ?? '',
        quantite: (j['quantite'] as num?)?.toDouble() ?? 0,
        unite: j['unite']?.toString() ?? 'piece',
        prixUnitaire: (j['prixUnitaire'] as num?)?.toDouble() ?? 0,
        tauxTVA: (j['tauxTVA'] as num?)?.toDouble() ?? 0,
      );
}

class Achat {
  static const statutDemande = 'demande';
  static const statutEnAttente = 'en_attente';
  static const statutValide = 'valide';
  static const statutRecu = 'recu';
  static const statutAnnule = 'annule';

  static const statuts = [
    statutDemande, statutEnAttente, statutValide, statutRecu, statutAnnule
  ];

  final String id;
  final String numero; // ACH-AAAA-NNNNN
  final String boutiqueId;
  final String fournisseurId; // '' si non référencé
  final String fournisseurNom;
  final List<LigneAchat> lignes;
  final DateTime date;
  final String statut;
  final String modePaiement; // 'especes', 'mobile_money', 'credit', 'virement'
  final String? referenceFacture;
  final String? notes;
  final String? motifAnnulation;
  final double montantPaye;
  final String createdBy;
  final DateTime createdAt;

  const Achat({
    required this.id,
    required this.numero,
    required this.boutiqueId,
    this.fournisseurId = '',
    required this.fournisseurNom,
    required this.lignes,
    required this.date,
    this.statut = statutEnAttente,
    this.modePaiement = 'especes',
    this.referenceFacture,
    this.notes,
    this.motifAnnulation,
    this.montantPaye = 0,
    required this.createdBy,
    required this.createdAt,
  });

  double get montantHT =>
      lignes.fold(0.0, (s, l) => s + l.totalHT);
  double get montantTVA =>
      lignes.fold(0.0, (s, l) => s + (l.totalTTC - l.totalHT));
  double get montantTTC =>
      lignes.fold(0.0, (s, l) => s + l.totalTTC);
  double get montantRestant => (montantTTC - montantPaye).clamp(0, montantTTC);
  bool get estSolde => montantRestant <= 0.001;

  bool get peutValider => statut == statutDemande || statut == statutEnAttente;
  bool get peutRecevoir => statut == statutValide;
  bool get peutPayer =>
      (statut == statutValide || statut == statutRecu) && !estSolde;
  bool get peutAnnuler => statut != statutAnnule;

  Achat copyWith({
    String? statut,
    double? montantPaye,
    String? motifAnnulation,
    String? modePaiement,
    List<LigneAchat>? lignes,
    DateTime? date,
    String? fournisseurNom,
    String? fournisseurId,
    String? referenceFacture,
    String? notes,
  }) =>
      Achat(
        id: id, numero: numero, boutiqueId: boutiqueId,
        fournisseurId: fournisseurId ?? this.fournisseurId,
        fournisseurNom: fournisseurNom ?? this.fournisseurNom,
        lignes: lignes ?? this.lignes, date: date ?? this.date,
        statut: statut ?? this.statut,
        modePaiement: modePaiement ?? this.modePaiement,
        referenceFacture: referenceFacture ?? this.referenceFacture,
        notes: notes ?? this.notes,
        motifAnnulation: motifAnnulation ?? this.motifAnnulation,
        montantPaye: montantPaye ?? this.montantPaye,
        createdBy: createdBy, createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'numero': numero, 'boutique_id': boutiqueId,
        'fournisseur_id': fournisseurId, 'fournisseur_nom': fournisseurNom,
        'lignes': [for (final l in lignes) l.toJson()],
        'date': date.toIso8601String(), 'statut': statut,
        'mode_paiement': modePaiement, 'reference_facture': referenceFacture,
        'notes': notes, 'motif_annulation': motifAnnulation,
        'montant_paye': montantPaye,
        'created_by': createdBy, 'created_at': createdAt.toIso8601String(),
      };

  factory Achat.fromJson(Map<String, dynamic> j) => Achat(
        id: j['id'].toString(), numero: j['numero']?.toString() ?? '',
        boutiqueId: j['boutique_id']?.toString() ?? '',
        fournisseurId: j['fournisseur_id']?.toString() ?? '',
        fournisseurNom: j['fournisseur_nom']?.toString() ?? '',
        lignes: [
          for (final l in (j['lignes'] as List? ?? const []))
            LigneAchat.fromJson(Map<String, dynamic>.from(l as Map)),
        ],
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        statut: j['statut']?.toString() ?? statutEnAttente,
        modePaiement: j['mode_paiement']?.toString() ?? 'especes',
        referenceFacture: j['reference_facture']?.toString(),
        notes: j['notes']?.toString(),
        motifAnnulation: j['motif_annulation']?.toString(),
        montantPaye: (j['montant_paye'] as num?)?.toDouble() ?? 0,
        createdBy: j['created_by']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
