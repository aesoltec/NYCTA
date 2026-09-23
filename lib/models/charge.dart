/// Charge / dépense de l'entreprise : loyer, salaire, fournisseur, taxe…
class Charge {
  final String id;
  final String boutiqueId;
  final String categorie;
  final String libelle;
  final double montant;
  final DateTime date;
  final bool recurrente;

  const Charge({
    required this.id,
    required this.boutiqueId,
    required this.categorie,
    required this.libelle,
    required this.montant,
    required this.date,
    this.recurrente = false,
  });
}

const categoriesCharge = [
  'Loyer', 'Salaires', 'Fournisseurs', 'Électricité & Eau',
  'Taxes & Fiscalité', 'Transport', 'Communication', 'Autre',
];
