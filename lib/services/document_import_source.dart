// ignore_for_file: lines_longer_than_80_chars
/// Lecture d'un fichier de tableur (CSV ou XLSX) en lignes de cellules.
///
/// Séparée de `DocumentImportService` (qui est pur) parce qu'elle
/// touche au DISQUE : la logique d'import reste testable sans fichier,
/// celle-ci se teste avec de vrais octets temporaires.
library;

import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';

import 'document_import_service.dart';

class ImportSourceErreur implements Exception {
  final String message;
  const ImportSourceErreur(this.message);
  @override
  String toString() => message;
}

/// Résultat de la lecture brute, avant interpretation.
class FichierLu {
  final List<List<Object?>> lignes;
  final List<String> feuilles;
  const FichierLu(this.lignes, this.feuilles);
}

class DocumentImportSource {
  const DocumentImportSource();

  /// Extensions acceptees. `.csv` et `.xlsx` couvrent l'essentiel des
  /// exports d'ERP ; `.xls` (ancien format binaire) n'est pas supporte
  /// par le paquet `excel` : le dire plutot que d'echouer a l'import.
  static const extensions = ['csv', 'xlsx', 'txt'];

  static bool extensionAcceptee(String? nomFichier) {
    if (nomFichier == null) return false;
    final e = nomFichier.toLowerCase().split('.').last;
    return extensions.contains(e);
  }

  /// Lit un fichier et renvoie ses lignes de cellules.
  ///
  /// [feuille] selectionne la feuille XLSX (0 = premiere). Les fichiers
  /// CSV et TXT ont une seule feuille.
  FichierLu lire(String chemin, {int feuille = 0}) {
    final fichier = File(chemin);
    if (!fichier.existsSync()) {
      throw ImportSourceErreur('Fichier introuvable : $chemin');
    }
    final nom = chemin.toLowerCase();
    if (nom.endsWith('.xlsx')) {
      return _lireXlsx(fichier, feuille);
    }
    return FichierLu(_lireCsv(fichier), const ['CSV']);
  }

  List<List<Object?>> _lireCsv(File f) {
    // BOM UTF-8 (Excel FR ecrit un BOM) : invisible mais il pollue la
    // premiere colonne.
    // `allowMalformed` : un fichier produit par un outil tiers peut
    // contenir un octet invalide ; planter ici perdrait tout l'import
    // pour une ligne parasite. Le BOM UTF-8 est traite juste apres.
    var contenu = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
    if (contenu.startsWith('\uFEFF')) contenu = contenu.substring(1);
    return [
      for (final l in DocumentImportService.lireCsv(contenu)) l,
    ];
  }

  FichierLu _lireXlsx(File f, int indexFeuille) {
    final classeur = Excel.decodeBytes(f.readAsBytesSync());
    final noms = classeur.sheets.keys.toList();
    if (noms.isEmpty) {
      throw const ImportSourceErreur('Le classeur ne contient aucune feuille.');
    }
    if (indexFeuille < 0 || indexFeuille >= noms.length) {
      throw ImportSourceErreur(
          'Feuille $indexFeuille inexistante (le classeur en a ${noms.length}).');
    }
    final feuille = classeur.sheets[noms[indexFeuille]]!;
    final lignes = <List<Object?>>[];
    for (final ligne in feuille.rows) {
      final cellules = <Object?>[];
      for (final c in ligne) {
        final v = c?.value;
        // Une cellule date est un DateTime : on la laisse telle quelle,
        // `dateLisible()` la formate.
        cellules.add(v is DateTime ? v : v?.toString());
      }
      lignes.add(cellules);
    }
    return FichierLu(lignes, noms);
  }

  /// Ecrit le modele CSV vide, pret a etre rempli puis renvoye.
  void ecrireModele(String chemin) {
    File(chemin).writeAsStringSync(DocumentImportService.modeleCsv());
  }
}