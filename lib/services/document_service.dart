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
  /// Signature manuscrite du client/réceptionnaire capturée à l'émission
  /// (chemin local, ou fichier re-téléchargé du cloud après rechargement).
  final String? signatureClientPath;

  const DocumentBati({
    this.id,
    required this.type, required this.numero, required this.date,
    required this.client, required this.lignes,
    required this.totalHT, required this.tva, required this.totalTTC,
    required this.devise, this.signatureClientPath,
  });

  DocumentBati copyWith({String? signatureClientPath}) => DocumentBati(
        id: id, type: type, numero: numero, date: date, client: client,
        lignes: lignes, totalHT: totalHT, tva: tva, totalTTC: totalTTC,
        devise: devise,
        signatureClientPath:
            signatureClientPath ?? this.signatureClientPath,
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
      date: _formatDate(date ?? DateTime.now()),
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

  static String _formatDate(DateTime d) =>
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
