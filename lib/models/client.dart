/// Client de l'entreprise (fichier clients).
/// Champs étendus (point 28) : email, RCCM, RIB, logo — tous optionnels.
/// Les lignes sans ces clés (anciennes sauvegardes, base non migrée)
/// retombent sur ''/null : aucune perte, aucune migration forcée.
class Client {
  final String id;
  final String boutiqueId;
  final String nom;
  final String telephone;
  final String email;
  final String adresse;
  final String rccm;
  final String rib;
  final String? logoPath;

  const Client({
    required this.id,
    required this.boutiqueId,
    required this.nom,
    this.telephone = '',
    this.email = '',
    this.adresse = '',
    this.rccm = '',
    this.rib = '',
    this.logoPath,
  });

  /// Professionnel si immatriculé (filtre « Professionnels »).
  bool get estPro => rccm.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id, 'boutique_id': boutiqueId, 'nom': nom,
        'telephone': telephone, 'email': email, 'adresse': adresse,
        'rccm': rccm, 'rib': rib, 'logo_path': logoPath,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'].toString(),
        boutiqueId: j['boutique_id']?.toString() ?? '',
        nom: j['nom']?.toString() ?? '',
        telephone: j['telephone']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        adresse: j['adresse']?.toString() ?? '',
        rccm: j['rccm']?.toString() ?? '',
        rib: j['rib']?.toString() ?? '',
        logoPath: j['logo_path']?.toString(),
      );
}
