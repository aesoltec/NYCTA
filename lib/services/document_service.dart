import '../core/constants.dart';
import '../models/company_profile.dart';
import '../models/document.dart';

/// Construit un document commercial à partir du profil d'entreprise
/// (100 % dynamique : nom, RCCM, IFU, contacts, devise, pied…).
class DocumentBati {
  final String? id; // identifiant cloud (documents.id) si persisté
  final TypeDocument type;
  final String numero;
  final String date;
  final String client;
  final List<LigneDoc> lignes;
  final double totalHT;
  final double tva;
  final double totalTTC;
  final String devise;
  /// Statut de validation : `brouillon` (émis par un vendeur, en attente
  /// de validation manager) ou `emis` (définitif). Les rôles financiers
  /// émettent directement en `emis`.
  final String statut;
  /// Signature manuscrite du client/réceptionnaire capturée à l'émission
  /// (chemin local, ou fichier re-téléchargé du cloud après rechargement).
  final String? signatureClientPath;
  /// Motif d'annulation (`annule` uniquement) — traçabilité.
  final String? motifAnnulation;
  /// Note libre / conditions imprimées en pied de document
  /// (« Paiement à 30 jours », « Marchandise vérifiée », garantie…).
  final String note;
  /// Adresse de livraison, quand elle diffère de l'adresse de facturation
  /// (typiquement un bon de livraison livré ailleurs).
  final String adresseLivraison;
  /// Date d'échéance de paiement (`jj/MM/aaaa`), vide si le document ne
  /// porte pas de condition de paiement. Alimente le suivi des impayés.
  final String echeance;
  /// Durée de règlement en jours, 0 si non renseignée. Permet de
  /// recalculer [echeance] quand la durée change.
  final int delaiPaiementJours;

  const DocumentBati({
    this.id,
    required this.type, required this.numero, required this.date,
    required this.client, required this.lignes,
    required this.totalHT, required this.tva, required this.totalTTC,
    required this.devise, this.statut = 'emis', this.signatureClientPath,
    this.motifAnnulation,
    this.note = '',
    this.adresseLivraison = '',
    this.echeance = '',
    this.delaiPaiementJours = 0,
  });

  /// Copie complete. Les trois premiers champs utilisaient `?? this.x`,
  /// ce qui rendait IMPOSSIBLE de les remettre a null (effacer une
  /// signature, retirer un motif) : un `effacer` explicite est fourni.
  DocumentBati copyWith({
    String? id,
    TypeDocument? type,
    String? numero,
    String? date,
    String? client,
    List<LigneDoc>? lignes,
    double? totalHT,
    double? tva,
    double? totalTTC,
    String? devise,
    String? statut,
    String? signatureClientPath,
    String? motifAnnulation,
    String? note,
    String? adresseLivraison,
    String? echeance,
    int? delaiPaiementJours,
    bool effacerSignature = false,
    bool effacerMotif = false,
  }) =>
      DocumentBati(
        id: id ?? this.id,
        type: type ?? this.type,
        numero: numero ?? this.numero,
        date: date ?? this.date,
        client: client ?? this.client,
        lignes: lignes ?? this.lignes,
        totalHT: totalHT ?? this.totalHT,
        tva: tva ?? this.tva,
        totalTTC: totalTTC ?? this.totalTTC,
        devise: devise ?? this.devise,
        statut: statut ?? this.statut,
        signatureClientPath: effacerSignature
            ? null
            : (signatureClientPath ?? this.signatureClientPath),
        motifAnnulation: effacerMotif
            ? null
            : (motifAnnulation ?? this.motifAnnulation),
        note: note ?? this.note,
        adresseLivraison: adresseLivraison ?? this.adresseLivraison,
        echeance: echeance ?? this.echeance,
        delaiPaiementJours: delaiPaiementJours ?? this.delaiPaiementJours,
      );

  /// Un document ÉMIS est-il encore modifiable ?
  ///
  /// Règle professionnelle : elle dépend de la NATURE du document, pas
  /// seulement de son statut.
  /// - `brouillon` : toujours modifiable — personne ne l'a encore vu.
  /// - `emis` : modifiable si le document n'est pas un justificatif fiscal
  ///   (devis, BC, BL — voir `TypeDocumentX.modifiableApresEmission`),
  ///   mais avec motif obligatoire et journal.
  /// - facture / ticket émis : IMMUABLE. Un numéro de facture ne doit
  ///   correspondre qu'à un seul contenu ; la correction passe par un
  ///   avoir ou par une annulation avec motif puis ré-émission.
  /// - `annule` / `paye` : figés, l'opération est terminée.
  bool get peutModifier =>
      statut == 'brouillon' ||
      (statut == 'emis' && type.modifiableApresEmission);

  /// Une modification d'un document émis exige-t-elle un motif ? Les
  /// brouillons non (personne ne les a vus), les émis modifiables oui :
  /// la trace est ce qui distingue une correction professionnelle d'une
  /// réécriture.
  bool get exigeMotifModification => statut == 'emis';

  /// Recalcule HT/TVA/TTC a partir des lignes et d'un taux.
  ///
  /// Un document modifie doit avoir des totaux COHERENTS avec ses
  /// lignes : recalculer ici evite qu'une modification laisse un total
  /// incoherent (erreur de facture).
  DocumentBati recalculeTaux(double tauxPct) {
    final ht = lignes.fold(0.0, (s, l) => s + l.total);
    return copyWith(
      totalHT: ht,
      tva: ht * tauxPct / 100,
      totalTTC: ht * (1 + tauxPct / 100),
    );
  }
}

/// Une modification d'un document, conservée pour la traçabilité.
///
/// C'est ce qui rend une correction d'un document ÉMIS professionnelle :
/// le contenu a changé, mais on sait QUI l'a changé, QUAND et POURQUOI.
/// Un document modifié sans trace n'est plus un justificatif.
class ModificationDocument {
  final String numero;
  /// Horodatage de la modification (ISO 8601).
  final String date;
  /// Rôle + nom de l'auteur.
  final String auteur;
  /// Motif obligatoire saisi par l'utilisateur.
  final String motif;
  /// Résumé lisible du changement, déjà calculé (« 3 lignes → 4 lignes,
  /// total 12 000 → 15 000 FCFA »).
  final String resume;

  const ModificationDocument({
    required this.numero,
    required this.date,
    required this.auteur,
    required this.motif,
    required this.resume,
  });

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'date': date,
        'auteur': auteur,
        'motif': motif,
        'resume': resume,
      };

  static ModificationDocument depuisJson(Map<String, dynamic> j) =>
      ModificationDocument(
        numero: (j['numero'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        auteur: (j['auteur'] ?? '') as String,
        motif: (j['motif'] ?? '') as String,
        resume: (j['resume'] ?? '') as String,
      );
}

class DocumentService {
  /// Assemble le document : numérotation automatique via le Store (compteur
  /// persisté dans le profil), totaux HT/TVA/TTC selon le tva du profil.
  /// [date] = date d'émission choisie dans le formulaire (hier, avant-hier…)
  /// — par défaut aujourd'hui. C'est cette date qui figure sur le document,
  /// dans l'historique et dans la base cloud (date_doc).
  Future<DocumentBati> build({
    required CompanyProfile profile,
    required Future<String> Function(String prefixe) numeroGenerator,
    required TypeDocument type,
    required String client,
    required List<LigneDoc> lignes,
    DateTime? date,
  }) async {
    final ht = lignes.fold(0.0, (s, l) => s + l.total);
    final tvaMontant = ht * profile.tva / 100;
    return DocumentBati(
      type: type,
      numero: await numeroGenerator(type.prefixe),
      date: formatDate(date ?? DateTime.now()),
      client: client,
      lignes: lignes,
      totalHT: ht,
      tva: tvaMontant,
      totalTTC: ht + tvaMontant,
      devise: profile.devise,
    );
  }

  /// Inverse de l'affichage jj/MM/aaaa → DateTime (conserve la date d'un
  /// devis lors de sa transformation en facture, y compris après un
  /// rechargement cloud où seule la chaîne subsiste).
  static DateTime? parseAffichage(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
    if (m == null) return null;
    final d = DateTime(
        int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    // Garde anti-absurdité (ex. 99/99/9999) : DateTime normalise sans erreur.
    if (d.day != int.parse(m.group(1)!) ||
        d.month != int.parse(m.group(2)!)) {
      return null;
    }
    return d;
  }

  /// Format jj/MM/aaaa — source unique : l'échéance et la date du
  /// document doivent s'écrire pareil.
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// En-tête légal unifié — utilisé par tous les documents.
  static List<String> entete(CompanyProfile p) => [
        p.nomEntreprise,
        if (p.adresse.isNotEmpty) p.adresse,
        if (p.telephone.isNotEmpty) 'Tél : ${p.telephone}${p.telephone2.isNotEmpty ? ' / ${p.telephone2}' : ''}',
        if (p.email.isNotEmpty) p.email,
        if (p.rccm.isNotEmpty) 'RCCM : ${p.rccm}',
        if (p.ifu.isNotEmpty) 'IFU : ${p.ifu}',
        if (p.autreRefFiscale.isNotEmpty) p.autreRefFiscale,
      ];

  static String montant(num v, String devise) => C.money(v, devise);
}
