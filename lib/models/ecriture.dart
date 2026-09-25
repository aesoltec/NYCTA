/// Écriture comptable SYSCOHADA simplifiée (mission §3.3/§4).
///
/// Immuabilité : on ne modifie/supprime JAMAIS une écriture — toute
/// correction passe par une contre-écriture liée (`refId` + motif).
/// Générées automatiquement : ventes (VT), réceptions (AC), paiements
/// (CA/BQ), charges (OD/CA).
class Ecriture {
  final String id;
  final String journal; // 'VT', 'AC', 'CA', 'BQ', 'OD'
  final DateTime date;
  final String compte; // ex : '411', '701', '443', '571'
  final String libelle;
  final double debit;
  final double credit;
  final String refId; // id vente/achat/charge d'origine
  final String boutiqueId;
  final String createdBy;
  /// Rapprochement bancaire : coché quand l'écriture est retrouvée sur
  /// le relevé (mission §3.3). Modifiable (pas une correction comptable).
  final bool pointee;

  const Ecriture({
    required this.id,
    required this.journal,
    required this.date,
    required this.compte,
    required this.libelle,
    this.debit = 0,
    this.credit = 0,
    this.refId = '',
    required this.boutiqueId,
    required this.createdBy,
    this.pointee = false,
  });

  double get solde => debit - credit;

  Map<String, dynamic> toJson() => {
        'id': id, 'journal': journal, 'date': date.toIso8601String(),
        'compte': compte, 'libelle': libelle, 'debit': debit,
        'credit': credit, 'ref_id': refId, 'boutique_id': boutiqueId,
        'created_by': createdBy, 'pointee': pointee,
      };

  factory Ecriture.fromJson(Map<String, dynamic> j) => Ecriture(
        id: j['id'].toString(), journal: j['journal']?.toString() ?? 'OD',
        date: DateTime.tryParse(j['date']?.toString() ?? '') ??
            DateTime.now(),
        compte: j['compte']?.toString() ?? '',
        libelle: j['libelle']?.toString() ?? '',
        debit: (j['debit'] as num?)?.toDouble() ?? 0,
        credit: (j['credit'] as num?)?.toDouble() ?? 0,
        refId: j['ref_id']?.toString() ?? '',
        boutiqueId: j['boutique_id']?.toString() ?? '',
        createdBy: j['created_by']?.toString() ?? '',
        pointee: j['pointee'] == true,
      );

  Ecriture copyWith({bool? pointee}) => Ecriture(
        id: id, journal: journal, date: date, compte: compte,
        libelle: libelle, debit: debit, credit: credit, refId: refId,
        boutiqueId: boutiqueId, createdBy: createdBy,
        pointee: pointee ?? this.pointee,
      );
}

/// Plan comptable minimal SYSCOHADA utilisé par l'app.
class PlanComptable {
  static const comptes = {
    '401': 'Fournisseurs',
    '411': 'Clients',
    '443': 'TVA collectée',
    '445': 'TVA déductible',
    '521': 'Banque',
    '571': 'Caisse',
    '601': 'Achats de marchandises',
    '605': 'Autres achats',
    '622': 'Locations et charges locatives',
    '628': 'Autres charges externes',
    '646': 'Impôts et taxes',
    '661': 'Salaires et appointements',
    '671': 'Frais financiers',
    '681': 'Dotations aux amortissements',
    '701': 'Ventes de marchandises',
    '706': 'Services vendus',
    '771': 'Produits financiers',
  };

  static String libelle(String compte) => comptes[compte] ?? 'Compte $compte';

  /// Catégorie de charge → compte de charge (repli : 628).
  static String compteCharge(String categorie) {
    final c = categorie.toLowerCase();
    if (c.contains('loyer')) return '622';
    if (c.contains('salaire')) return '661';
    if (c.contains('fournisseur')) return '605';
    if (c.contains('taxe') || c.contains('fiscal') || c.contains('impôt')) {
      return '646';
    }
    if (c.contains('transport')) return '628';
    if (c.contains('banque') || c.contains('frais financier')) return '671';
    return '628';
  }
}
