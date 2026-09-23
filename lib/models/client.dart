/// Client de l'entreprise (fichier clients).
class Client {
  final String id;
  final String boutiqueId;
  final String nom;
  final String telephone;
  final String adresse;

  const Client({
    required this.id,
    required this.boutiqueId,
    required this.nom,
    this.telephone = '',
    this.adresse = '',
  });
}
