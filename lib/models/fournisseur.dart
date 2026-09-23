/// Fournisseur de l'entreprise.
class Fournisseur {
  final String id;
  final String nom;
  final String telephone;
  final String email;
  final String adresse;
  final String specialite; // ce qu'il fournit
  final String notes;

  const Fournisseur({
    required this.id,
    required this.nom,
    this.telephone = '',
    this.email = '',
    this.adresse = '',
    this.specialite = '',
    this.notes = '',
  });
}
