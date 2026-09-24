/// Mouvement de stock traçable (mission 1, §1.3) : chaque entrée/sortie
/// est journalisée avec auteur, motif et stock résultant — jamais de
/// modification silencieuse des quantités.
///
/// Types : `entree` (achat/réception), `sortie` (vente, document),
/// `ajustement` (correction manuelle, perte, casse), `retour`
/// (annulation/suppression : remise en rayon), `inventaire` (comptage).
class MouvementStock {
  static const entree = 'entree';
  static const sortie = 'sortie';
  static const ajustement = 'ajustement';
  static const retour = 'retour';
  static const inventaire = 'inventaire';

  static const types = [entree, sortie, ajustement, retour, inventaire];

  final String id;
  final String boutiqueId;
  final String produitId;
  final String produitNom;
  final String type;
  final int quantite; // signée : + entrée, − sortie
  final int stockApres;
  final String motif;
  final String refId; // id achat/vente/document d'origine ('' si manuel)
  final DateTime date;
  final String createdBy;

  const MouvementStock({
    required this.id,
    required this.boutiqueId,
    required this.produitId,
    required this.produitNom,
    required this.type,
    required this.quantite,
    required this.stockApres,
    this.motif = '',
    this.refId = '',
    required this.date,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'boutique_id': boutiqueId, 'produit_id': produitId,
        'produit_nom': produitNom, 'type': type, 'quantite': quantite,
        'stock_apres': stockApres, 'motif': motif, 'ref_id': refId,
        'date': date.toIso8601String(), 'created_by': createdBy,
      };

  factory MouvementStock.fromJson(Map<String, dynamic> j) => MouvementStock(
        id: j['id'].toString(),
        boutiqueId: j['boutique_id']?.toString() ?? '',
        produitId: j['produit_id']?.toString() ?? '',
        produitNom: j['produit_nom']?.toString() ?? '',
        type: j['type']?.toString() ?? ajustement,
        quantite: (j['quantite'] as num?)?.toInt() ?? 0,
        stockApres: (j['stock_apres'] as num?)?.toInt() ?? 0,
        motif: j['motif']?.toString() ?? '',
        refId: j['ref_id']?.toString() ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        createdBy: j['created_by']?.toString() ?? '',
      );
}
