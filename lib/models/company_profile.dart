/// Profil d'entreprise — 100 % dynamique depuis la base (écran Configuration).
/// Alimente les en-têtes de factures, devis, bons de commande et tickets.
class CompanyProfile {
  final String nomEntreprise;
  final String devise;
  final String telephone;
  final String telephone2;
  final String email;
  final String adresse;
  final String rccm;
  final String ifu;
  final String autreRefFiscale; // N° contribuable, etc.
  final String banque;
  final String coordonneesBancaires;
  final String messagePied; // ex: « Merci de votre confiance »
  final double tva; // taux TVA en % (0 par défaut)

  /// Image de marque (fichiers locaux, importés ou signés à la main)
  final String? logoPath;
  final String? cachetPath;
  final String? signaturePath;

  /// Trésorerie : fonds de roulement initial par boutique : {boutiqueId: montant}
  final Map<String, double> fondsRoulement;

  /// Budgets mensuels par catégorie de charge : {catégorie: montant}
  final Map<String, double> budgetsMensuels;

  /// Numérotation des documents : {prefixe: compteur}
  final Map<String, int> compteursDocs;

  /// Dernier mois pour lequel les charges récurrentes ont été générées
  /// ('AAAA-MM') — évite les doublons à chaque ouverture.
  final String? moisChargesGenerees;

  const CompanyProfile({
    this.nomEntreprise = 'Mon Entreprise',
    this.devise = 'FCFA',
    this.telephone = '',
    this.telephone2 = '',
    this.email = '',
    this.adresse = '',
    this.rccm = '',
    this.ifu = '',
    this.autreRefFiscale = '',
    this.banque = '',
    this.coordonneesBancaires = '',
    this.messagePied = 'Merci de votre confiance.',
    this.tva = 0,
    this.logoPath,
    this.cachetPath,
    this.signaturePath,
    this.fondsRoulement = const {},
    this.budgetsMensuels = const {},
    this.compteursDocs = const {},
    this.moisChargesGenerees,
  });

  CompanyProfile copyWith({
    String? nomEntreprise, String? devise, String? telephone, String? telephone2,
    String? email, String? adresse, String? rccm, String? ifu,
    String? autreRefFiscale, String? banque, String? coordonneesBancaires,
    String? messagePied, double? tva,
    String? logoPath, String? cachetPath, String? signaturePath,
    bool effacerLogo = false, bool effacerCachet = false, bool effacerSignature = false,
    Map<String, double>? fondsRoulement,
    Map<String, double>? budgetsMensuels,
    Map<String, int>? compteursDocs,
    String? moisChargesGenerees,
  }) =>
      CompanyProfile(
        nomEntreprise: nomEntreprise ?? this.nomEntreprise,
        devise: devise ?? this.devise,
        telephone: telephone ?? this.telephone,
        telephone2: telephone2 ?? this.telephone2,
        email: email ?? this.email,
        adresse: adresse ?? this.adresse,
        rccm: rccm ?? this.rccm,
        ifu: ifu ?? this.ifu,
        autreRefFiscale: autreRefFiscale ?? this.autreRefFiscale,
        banque: banque ?? this.banque,
        coordonneesBancaires: coordonneesBancaires ?? this.coordonneesBancaires,
        messagePied: messagePied ?? this.messagePied,
        tva: tva ?? this.tva,
        logoPath: effacerLogo ? null : (logoPath ?? this.logoPath),
        cachetPath: effacerCachet ? null : (cachetPath ?? this.cachetPath),
        signaturePath: effacerSignature ? null : (signaturePath ?? this.signaturePath),
        fondsRoulement: fondsRoulement ?? this.fondsRoulement,
        budgetsMensuels: budgetsMensuels ?? this.budgetsMensuels,
        compteursDocs: compteursDocs ?? this.compteursDocs,
        moisChargesGenerees: moisChargesGenerees ?? this.moisChargesGenerees,
      );

  /// Numéro de document automatique : "FACT-2026-00042"
  (String, CompanyProfile) prochainNumero(String prefixe) {
    final an = DateTime.now().year;
    final compteurs = Map<String, int>.from(compteursDocs);
    final n = (compteurs[prefixe] ?? 0) + 1;
    compteurs[prefixe] = n;
    return ('$prefixe-$an-${n.toString().padLeft(5, '0')}', copyWith(compteursDocs: compteurs));
  }
}
