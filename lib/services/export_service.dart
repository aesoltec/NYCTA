import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Service d'export UNIFIÉ (MISSION.md §5) : CSV + Excel (.xlsx) + PDF
/// avec les mêmes conventions partout — BOM UTF-8 + `;` (Excel FR),
/// dates `JJ/MM/AAAA HH:mm`, partage WhatsApp/Drive.
/// Remplace au fil des lots les exports artisanaux épars.
class ExportService {
  static final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');
  static final _fmtJour = DateFormat('dd/MM/yyyy');

  static String dateHeure(DateTime d) => _fmtDate.format(d);
  static String jour(DateTime d) => _fmtJour.format(d);

  // ---------- CSV ----------
  /// CSV compatible Excel FR : BOM UTF-8 + séparateur `;`.
  static String csv(List<String> entetes, List<List<dynamic>> lignes) =>
      '﻿${ListToCsvConverter(fieldDelimiter: ';').convert([
            entetes,
            for (final l in lignes) [for (final c in l) _texte(c)],
          ])}';

  static String _texte(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return dateHeure(v);
    if (v is double) {
      return v.toStringAsFixed(
          v.truncateToDouble() == v ? 0 : 2);
    }
    final s = '$v';
    // Protection formules Excel (injection CSV) : =, +, -, @ en tête
    // sont neutralisés par un préfixe apostrophe (plan A3).
    if (s.isNotEmpty && '=+-@'.contains(s[0])) return "'$s";
    return s;
  }

  // ---------- Excel ----------
  /// Classeur .xlsx à une feuille (noms de feuilles ≤ 31 car. Excel).
  static List<int> excel(
      String feuille, List<String> entetes, List<List<dynamic>> lignes) {
    final classeur = Excel.createExcel();
    final nom = feuille.length > 31 ? feuille.substring(0, 31) : feuille;
    final onglet = classeur[nom];
    onglet.appendRow(entetes.map((e) => TextCellValue(e)).toList());
    for (final l in lignes) {
      onglet.appendRow([for (final c in l) _cellule(c)]);
    }
    return classeur.encode() ?? [];
  }

  static CellValue _cellule(dynamic v) {
    if (v == null) return TextCellValue('');
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is bool) return BoolCellValue(v);
    if (v is DateTime) return TextCellValue(dateHeure(v));
    return TextCellValue('$v');
  }

  // ---------- PDF ----------
  /// En-tête entreprise réutilisable (plan A3) : nom + mentions
  /// RCCM/IFU pour `pdfTableau(entreprise:, mentions:)`.
  static (String, String) enteteEntreprise(
      {required String nom, String rccm = '', String ifu = ''}) {
    final mentions = [
      if (rccm.trim().isNotEmpty) 'RCCM : ${rccm.trim()}',
      if (ifu.trim().isNotEmpty) 'IFU : ${ifu.trim()}',
    ].join(' · ');
    return (nom, mentions);
  }  /// Tableau PDF générique (jamais vide : une ligne « Aucune donnée » sinon,
  /// ce qui corrige le bug du cadre vide sans contenu).
  /// En-tête entreprise + date de génération + filtres appliqués (plan A3) :
  /// tous optionnels pour ne pas casser les 8+ appelants existants.
  static Future<List<int>> pdfTableau({
    required String titre,
    required String sousTitre,
    required List<String> entetes,
    required List<List<dynamic>> lignes,
    String total = '',
    String entreprise = '',
    String mentions = '',
    String filtres = '',
  }) async {
    final doc = pw.Document();
    final donnees = lignes.isEmpty
        ? [
            ['Aucune donnée sur la période.', '', '']
          ]
        : [
            for (final l in lignes)
              [for (final c in l) _texte(c)],
          ];
    final genereLe = 'Généré le ${jour(DateTime.now())} à '
        '${DateTime.now().hour.toString().padLeft(2, '0')}h'
        '${DateTime.now().minute.toString().padLeft(2, '0')}';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          if (entreprise.isNotEmpty) ...[
            pw.Text(entreprise,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (mentions.isNotEmpty)
              pw.Text(mentions,
                  style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 6),
          ],
          pw.Text(titre,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(sousTitre,
              style: const pw.TextStyle(fontSize: 10)),
          pw.Text(genereLe,
              style: const pw.TextStyle(fontSize: 9)),
          if (filtres.isNotEmpty)
            pw.Text('Filtres : $filtres',
                style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: entetes,
            data: donnees,
          ),
          if (total.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(total,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ---------- Partage ----------
  static Future<String> _fichierTemp(
      String nom, List<int> octets) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nom');
    await f.writeAsBytes(octets, flush: true);
    return f.path;
  }

  static Future<void> partagerCsv(
      String nomBase, List<String> entetes, List<List<dynamic>> lignes) async {
    final chemin = await _fichierTemp(
        '$nomBase.csv', csv(entetes, lignes).codeUnits);
    await SharePlus.instance.share(
        ShareParams(files: [XFile(chemin)], text: nomBase));
  }

  static Future<void> partagerExcel(String nomBase, String feuille,
      List<String> entetes, List<List<dynamic>> lignes) async {
    final chemin = await _fichierTemp(
        '$nomBase.xlsx', excel(feuille, entetes, lignes));
    await SharePlus.instance.share(
        ShareParams(files: [XFile(chemin)], text: nomBase));
  }

  static Future<void> partagerPdf(String nomBase,
      {required String titre,
      required String sousTitre,
      required List<String> entetes,
      required List<List<dynamic>> lignes,
      String total = '',
      String entreprise = '',
      String mentions = '',
      String filtres = ''}) async {
    final octets = await pdfTableau(
        titre: titre,
        sousTitre: sousTitre,
        entetes: entetes,
        lignes: lignes,
        total: total,
        entreprise: entreprise,
        mentions: mentions,
        filtres: filtres);
    await Printing.sharePdf(bytes: Uint8List.fromList(octets),
        filename: '$nomBase.pdf');
  }
}
