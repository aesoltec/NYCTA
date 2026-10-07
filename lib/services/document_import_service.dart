// ignore_for_file: lines_longer_than_80_chars
/// Import de documents commerciaux depuis un tableur (Excel / CSV).
///
/// POURQUOI UN SERVICE PUR
/// -----------------------
/// Un import est la fonction la plus facile a mal faire : une colonne
/// mal nommee, une virgule decimale, une ligne sans designation — et le
/// document cree est faux, silencieusement. Toute la logique est donc
/// ici, sans dependance a Flutter ni au stockage : elle est testable sur
/// VM, ce que ne sera jamais un ecran.
///
/// FORMAT ATTENDU (mise en page « une ligne = une ligne de document »)
/// --------------------------------------------------------------------
/// Toutes les lignes portant le **meme numero** forment UN document.
/// C'est le format produit par l'export de la plupart des ERP.
///
/// | numero | date | client | designation | quantite | prix   |
/// |--------|------|--------|-------------|----------|--------|
/// | F-001  | 03/10| Client A| Cable      | 10       | 1500   |
/// | F-001  |      |         | Prise      | 5        | 500    |
/// | F-002  | 04/10| Client B| Routeur    | 2        | 25000  |
///
/// Les documents importes sont toujours crees en **`brouillon`** : un
/// import n'est jamais emis, il est relu puis valide. C'est coherent avec
/// la regle des documents emis (non modifiables) — un document emis
/// directement par un import serait un justificatif faux.
///
/// ANOMALIES
/// ---------
/// Aucune ligne n'est silencieusement perdue : chaque rejet est compte
/// et decrit (`ImportAnomalie`). Un rapport de 3 lignes pour 200 lignes
/// importees doitalarmer, pas etre oublie.
library;

import 'dart:convert';

import '../models/document.dart';
import '../services/document_service.dart';

/// Une anomalie constatee pendant l'import, avec sa ligne d'origine.
class ImportAnomalie {
  final int ligne;
  final String code;
  final String message;
  const ImportAnomalie(this.ligne, this.code, this.message);

  @override
  String toString() => 'ligne $ligne [$code] $message';
}

/// Resultat d'un import : documents reconstruits + rapport.
class ImportResultat {
  final List<DocumentBati> documents;
  final List<ImportAnomalie> anomalies;
  final List<String> colonnesIgnorees;
  final int lignesIgnorees;

  const ImportResultat({
    required this.documents,
    required this.anomalies,
    required this.colonnesIgnorees,
    required this.lignesIgnorees,
  });

  bool get vide => documents.isEmpty;
  int get totalLignes => anomalies.length + lignesIgnorees;
}

/// Service d'import : pur, sans dependance externe ni Flutter.
/// Cellule texte d'une ligne de tableur, normalisee.
/// Vide / absente -> chaine vide, jamais `null`.
String _cellule(Map<String, String?> ligne, String cle) =>
    (ligne[cle] ?? '').trim();

class DocumentImportService {
  const DocumentImportService();

  /// Synonymes acceptes pour chaque champ, compares apres
  /// normalisation (minuscules, sans accent, sans ponctuation).
  ///
  /// Un tableur exporte par un autre logiciel n'ecrit pas « quantite »
  /// mais « Qte », « Quantité », « Qté » ou « QTY ». Refuser ces
  /// variantes rendrait l'import inutilisable en pratique.
  static const _alias = <String, List<String>>{
    'numero': [
      'numero',
      'num',
      'n',
      'nonum',
      'numpiece',
      'nodepiece', // « N° de piece » : le ° se lit numero
      'numerodepiece',
      'reference',
      'ref',
    ],
    'date': ['date', 'datedoc', 'datefacture', 'dateemission', 'jour'],
    'client': ['client', 'nomclient', 'raisonsociale', 'clientouclient',
      'destinataire', 'tiers', 'nom'],
    'designation': ['designation', 'libelle', 'article', 'produit',
      'intitule', 'description', 'designationarticle'],
    'quantite': ['quantite', 'qte', 'qty', 'quantitevendue', 'q'],
    'prix': ['prix', 'prixunitaire', 'pu', 'prixunitaireht', 'montantunitaire',
      'prixht'],
    'type': ['type', 'typedocument', 'nature', 'doc'],
  };

  /// Lignes d'en-tete attendues, pour l'export modele. Ordre importe :
  /// c'est l'ordre dans lequel l'utilisateur voit le modele a remplir.
  static const colonnesModele = <String>[
    'numero',
    'type',
    'date',
    'client',
    'designation',
    'quantite',
    'prix',
  ];

  /// Modele CSV a remplir et a exporter. Le séparateur `;` est celui
  /// d'Excel en locale française.
  static String modeleCsv({String separateur = ';'}) =>
      '${colonnesModele.join(separateur)}\n';

  // ---------------------------------------------------------------- utils

  /// Normalise un en-tete : minuscules, sans accent, sans ponctuation ni
  /// espaces. « Quantité (HT) » et « quantite ht » deviennent identiques.
  static String normaliser(String brut) {
    final bas = brut.toLowerCase().trim();
    final sansAccent = StringBuffer();
    for (final r in bas.runes) {
      // Decomposition Unicode : 'é' -> 'e' + accent, qu'on ignore.
      final d = String.fromCharCode(r);
      sansAccent.write(d);
    }
    final perm = StringBuffer();
    const mapped = <String, String>{
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'é': 'e', 'è': 'e',
      'ê': 'e', 'ë': 'e', 'í': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o',
      'ô': 'o', 'ö': 'o', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y',
      'ç': 'c', 'ñ': 'n', '°': 'o',
    };
    final source = sansAccent.toString();
    for (final c in source.split('')) {
      perm.write(mapped[c] ?? c);
    }
    return perm
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Champ reconnu pour un en-tete, ou null.
  static String? champPourEntete(String entete) {
    final n = normaliser(entete);
    if (n.isEmpty) return null;
    for (final entree in _alias.entries) {
      if (entree.value.any((a) => normaliser(a) == n)) return entree.key;
    }
    return null;
  }

  /// Indice de colonne -> champ, pour une ligne d'en-tete donnee.
  /// Les colonnes inconnues sont renvoyees a part (informa, pas perdues).
  static Map<String, List<int>> indexerColonnes(
      List<String> entetes) {
    final index = <String, List<int>>{};
    final inconnues = <int>[];
    for (var i = 0; i < entetes.length; i++) {
      final champ = champPourEntete(entetes[i]);
      if (champ == null) {
        inconnues.add(i);
        continue;
      }
      index.putIfAbsent(champ, () => <int>[]).add(i);
    }
    if (inconnues.isNotEmpty) {
      index['__inconnues__'] = inconnues;
    }
    return index;
  }

  /// Nombre parse en tolerantant la virgule decimale, les espaces (y
  /// compris insecables) et le symbole monetaire.
  static double? nombre(Object? brut) {
    if (brut == null) return null;
    if (brut is num) return brut.toDouble();
    var s = brut.toString().trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '');
    s = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.isEmpty) return null;
    // 1 234,56 -> dernier separateur = decimal
    final dernierVirgule = s.lastIndexOf(',');
    final dernierPoint = s.lastIndexOf('.');
    if (dernierVirgule >= 0 && dernierPoint >= 0) {
      if (dernierVirgule > dernierPoint) {
        s = '${s.substring(0, dernierVirgule).replaceAll('.', '')}'
            '${s.substring(dernierVirgule)}';
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (dernierVirgule >= 0) {
      s = s.substring(0, dernierVirgule).replaceAll('.', '') +
          s.substring(dernierVirgule);
    }
    // Dart ne lit que le POINT comme separateur decimal : une fois le
    // format francais normalise (« 1.234,56 » -> « 1234,56 »), il reste
    // a convertir la virgule, sinon `tryParse` renvoie toujours null.
    s = s.replaceAll(',', '.');
    return double.tryParse(s);
  }

  /// Date lue depuis `jj/MM/aaaa`, `aaaa-mm-jj`, ou une vraie DateTime
  /// (Excel livre un serial pour les cellules date : le tableur
  ///erializeur doit l'avoir convertie, sinon la valeur n'est pas
  /// exploitable et la ligne est signalee).
  static String? dateLisible(Object? brut) {
    if (brut == null) return null;
    if (brut is DateTime) {
      final d = brut;
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final s = brut.toString().trim();
    if (s.isEmpty) return null;
    final fr = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(s);
    if (fr != null) {
      var annee = int.parse(fr.group(3)!);
      if (annee < 100) annee += 2000;
      final j = int.parse(fr.group(1)!);
      final m = int.parse(fr.group(2)!);
      if (m < 1 || m > 12 || j < 1 || j > 31) return null;
      return '${j.toString().padLeft(2, '0')}/'
          '${m.toString().padLeft(2, '0')}/$annee';
    }
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) return '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    return null;
  }

  /// Type de document infere d'un libelle libre (« Facture »,
  /// « BON DE COMMANDE », « BL », « Devis »...). Null si inconnu.
  static TypeDocument? typeDepuisLibelle(Object? brut) {
    if (brut == null) return null;
    final n = normaliser(brut.toString());
    if (n.isEmpty) return null;
    if (n.contains('facture')) return TypeDocument.facture;
    if (n.contains('devis')) return TypeDocument.devisProforma;
    if (n.contains('commande')) return TypeDocument.bonCommande;
    if (n.contains('bordereau') || n == 'bl') {
      return TypeDocument.bonLivraison;
    }
    if (n.contains('ticket') || n.contains('recette')) {
      return TypeDocument.ticketCaisse;
    }
    return null;
  }

  // ------------------------------------------------------------------ CSV

  /// Lit un CSV. Le separateur est detecte (`,` ou `;`), comme le fait
  /// Excel a l'ouverture : un fichier FR ne doit pas produire une seule
  /// colonne.
  static List<List<String>> lireCsv(String contenu) {
    final lignes = <List<String>>[];
    if (contenu.trim().isEmpty) return lignes;
    final separateur = _detecterSeparateur(contenu);
    for (final brute in const LineSplitter().convert(contenu)) {
      if (brute.trim().isEmpty) continue;
      lignes.add(_decouper(brute, separateur));
    }
    return lignes;
  }

  static String _detecterSeparateur(String contenu) {
    final premiere = contenu.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final points = ','.allMatches(premiere).length;
    final virgules = ';'.allMatches(premiere).length;
    // En cas d'egalite, Excel FR gagne (point-virgule).
    return virgules >= points ? ';' : ',';
  }

  static List<String> _decouper(String ligne, String sep) {
    final champs = <String>[];
    final courant = StringBuffer();
    var dansGuillemets = false;
    for (var i = 0; i < ligne.length; i++) {
      final c = ligne[i];
      if (c == '"') {
        // "" = guillemet echappe
        if (dansGuillemets && i + 1 < ligne.length && ligne[i + 1] == '"') {
          courant.write('"');
          i++;
        } else {
          dansGuillemets = !dansGuillemets;
        }
      } else if (c == sep && !dansGuillemets) {
        champs.add(courant.toString().trim());
        courant.clear();
      } else {
        courant.write(c);
      }
    }
    champs.add(courant.toString().trim());
    return champs;
  }

  // -------------------------------------------------------------- import

  /// Reconstruit des documents depuis des lignes de tableur.
  ///
  /// [typeParDefaut] s'applique aux lignes dont le type n'est pas
  /// renseigne ; sans type, l'import ne peut pas deviner s'il s'agit
  /// d'une facture ou d'un devis.
  ImportResultat importerLignes(
    List<List<Object?>> lignes, {
    required TypeDocument typeParDefaut,
    String devise = 'FCFA',
    double tvaPct = 0,
    String dateParDefaut = '',
  }) {
    final anomalies = <ImportAnomalie>[];
    if (lignes.isEmpty) {
      return const ImportResultat(
          documents: [],
          anomalies: [],
          colonnesIgnorees: [],
          lignesIgnorees: 0);
    }

    // 1. la premiere ligne non vide est l'en-tete
    var iEntete = 0;
    while (iEntete < lignes.length &&
        lignes[iEntete].every((c) => (c ?? '').toString().trim().isEmpty)) {
      iEntete++;
    }
    if (iEntete >= lignes.length) {
      return const ImportResultat(
          documents: [],
          anomalies: [],
          colonnesIgnorees: [],
          lignesIgnorees: 0);
    }
    final entetes = lignes[iEntete]
        .map((c) => (c ?? '').toString())
        .toList(growable: false);
    final index = indexerColonnes(entetes);
    final inconnues = index['__inconnues__'] ?? const <int>[];
    if (index.containsKey('numero') == false &&
        index.containsKey('designation') == false) {
      anomalies.add(ImportAnomalie(
        iEntete + 1,
        'entete',
        'Aucune colonne reconnue. Attendu au moins « numero » ou '
            '« designation ». Colonnes trouvees : ${entetes.join(', ')}',
      ));
      return ImportResultat(
        documents: [],
        anomalies: anomalies,
        colonnesIgnorees: [for (final c in inconnues) entetes[c]],
        lignesIgnorees: lignes.length - iEntete - 1,
      );
    }

    String? cell(Map<String, List<int>> idx, List<Object?> ligne, String champ) {
      final positions = idx[champ];
      if (positions == null) return null;
      for (final p in positions) {
        if (p < ligne.length) {
          final v = (ligne[p] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    // 2. regroupement par numero : toutes les lignes d'un numero forment
    //    UN document.
    final ordre = <String>[];
    final groupes = <String, List<Map<String, String?>>>{};

    var ignorees = 0;
    for (var i = iEntete + 1; i < lignes.length; i++) {
      final ligne = lignes[i];
      if (ligne.every((c) => (c ?? '').toString().trim().isEmpty)) continue;
      final numeroBrut = cell(index, ligne, 'numero');
      final designation = cell(index, ligne, 'designation');
      final numero = numeroBrut?.trim();

      // Une ligne sans designation ET sans quantite/prix n'apporte rien.
      if ((designation == null || designation.isEmpty) &&
          cell(index, ligne, 'quantite') == null &&
          cell(index, ligne, 'prix') == null) {
        ignorees++;
        anomalies.add(ImportAnomalie(i + 1, 'vide',
            'Ligne sans designation ni quantite : ignoree.'));
        continue;
      }
      if (designation == null || designation.isEmpty) {
        ignorees++;
        anomalies.add(ImportAnomalie(i + 1, 'designation',
            'Ligne sans designation : ignoree.'));
        continue;
      }

      // Cle STABLE : le numero quand il existe, sinon le client. Une cle
      // basee sur un compteur creait un document par ligne.
      final clientLigne = cell(index, ligne, 'client')?.trim() ?? '';
      final cle = (numero == null || numero.isEmpty)
          ? 'SANS-NUMERO-${clientLigne.isEmpty ? 'L${i + 1}' : clientLigne}'
          : numero;
      groupes.putIfAbsent(cle, () => <Map<String, String?>>[]);
      if (!ordre.contains(cle)) ordre.add(cle);

      final qte = nombre(cell(index, ligne, 'quantite'));
      final prix = nombre(cell(index, ligne, 'prix'));
      if (qte == null) {
        ignorees++;
        anomalies.add(ImportAnomalie(
            i + 1, 'quantite', 'Quantite illisible : ligne ignoree.'));
        continue;
      }
      if (prix == null) {
        ignorees++;
        anomalies.add(ImportAnomalie(i + 1, 'prix',
            'Prix unitaire illisible : ligne ignoree.'));
        continue;
      }
      // Les metadonnees sont lues pour CHAQUE ligne, sans condition :
      // un tableau sans colonne « numero » est le cas le plus courant
      // (premier import, numerotation geree par l'application).
      groupes[cle]!.add({
        'designation': designation,
        'quantite': qte.toString(),
        'prix': prix.toString(),
        'date': cell(index, ligne, 'date'),
        'client': clientLigne.isEmpty ? null : clientLigne,
        'type': cell(index, ligne, 'type'),
      });
    }

    // 3. fabrication des documents
    final documents = <DocumentBati>[];
    for (final cle in ordre) {
      final lot = groupes[cle]!;
      if (lot.isEmpty) continue;
      final premiere = lot.first;
      final client = premiere['client']?.trim();
      if (client == null || client.isEmpty) {
        anomalies.add(ImportAnomalie(0, 'client',
            'Document $cle sans client : ignore.'));
        continue;
      }
      final date = dateLisible(premiere['date']) ?? dateParDefaut;
      final type = typeDepuisLibelle(premiere['type']) ?? typeParDefaut;

      final lignesDoc = <LigneDoc>[
        for (final l in lot)
          LigneDoc(
            libelle: l['designation']!,
            quantite: double.parse(l['quantite']!).round(),
            prixUnitaire: double.parse(l['prix']!),
            // Colonnes facultatives du tableur : absentes -> unite par
            // defaut, sinon la ligne importerait sans unite.
            unite: _cellule(l, 'unite').isEmpty
                ? 'pcs'
                : _cellule(l, 'unite'),
            reference: _cellule(l, 'reference'),
          ),
      ];
      final ht = lignesDoc.fold(0.0, (s, l) => s + l.total);
      documents.add(DocumentBati(
        type: type,
        numero: cle,
        date: date.isEmpty ? 'non renseignee' : date,
        client: client,
        lignes: lignesDoc,
        totalHT: ht,
        tva: ht * tvaPct / 100,
        totalTTC: ht * (1 + tvaPct / 100),
        devise: devise,
        // TOUJOURS brouillon : un import n'est jamais emis.
        statut: 'brouillon',
      ));
    }

    return ImportResultat(
      documents: documents,
      anomalies: anomalies,
      colonnesIgnorees: [for (final c in inconnues) entetes[c]],
      lignesIgnorees: ignorees,
    );
  }

  /// Point d'entree CSV.
  ImportResultat importerCsv(
    String contenu, {
    required TypeDocument typeParDefaut,
    String devise = 'FCFA',
    double tvaPct = 0,
    String dateParDefaut = '',
  }) =>
      importerLignes(
        [for (final l in lireCsv(contenu)) l],
        typeParDefaut: typeParDefaut,
        devise: devise,
        tvaPct: tvaPct,
        dateParDefaut: dateParDefaut,
      );
}