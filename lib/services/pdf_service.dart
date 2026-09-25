import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../core/constants.dart';
import '../models/company_profile.dart';
import '../models/document.dart';
import '../models/transaction.dart';
import '../services/document_service.dart';

/// Génère le PDF d'un document commercial (facture, devis, bon, ticket)
/// avec en-tête légal (logo, RCCM, IFU), totaux et signature/cachet.
class PdfService {
  static Future<Uint8List> generer(DocumentBati doc, CompanyProfile profile) async {
    final pdf = pw.Document();
    pw.MemoryImage? logo, signature, cachet;
    try {
      if (mediaServiceExiste(profile.logoPath)) {
        logo = pw.MemoryImage(File(profile.logoPath!).readAsBytesSync());
      }
      if (mediaServiceExiste(profile.signaturePath)) {
        signature = pw.MemoryImage(File(profile.signaturePath!).readAsBytesSync());
      }
      if (mediaServiceExiste(profile.cachetPath)) {
        cachet = pw.MemoryImage(File(profile.cachetPath!).readAsBytesSync());
      }
    } catch (_) {/* images illisibles : le PDF reste généré sans elles */}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ---------- En-tête ----------
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                      width: 70, height: 70,
                      child: pw.Image(logo, fit: pw.BoxFit.contain)),
                if (logo != null) pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(profile.nomEntreprise,
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      for (final l in DocumentService.entete(profile).skip(1))
                        pw.Text(l, style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(doc.type.titre,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#3D6FB4'))),
                    pw.SizedBox(height: 4),
                    pw.Text(doc.numero,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(doc.date,
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F4F6FA'),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(children: [
                pw.Text('${doc.type == TypeDocument.bonCommande ? 'Fournisseur' : 'Client'} : ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Expanded(child: pw.Text(doc.client)),
              ]),
            ),
            pw.SizedBox(height: 16),
            // ---------- Tableau des lignes ----------
            // BL : quantités + désignations uniquement, JAMAIS de prix.
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3D6FB4')),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#E8F0FB')),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: doc.type.sansPrix
                  ? {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1.5),
                    }
                  : {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(2.5),
                      3: const pw.FlexColumnWidth(2.5),
                    },
              headers: doc.type.sansPrix
                  ? ['Article', 'Qté']
                  : ['Article', 'Qté', 'P.U.', 'Total'],
              data: [
                for (final l in doc.lignes)
                  if (doc.type.sansPrix)
                    [l.libelle, '${l.quantite}']
                  else
                    [l.libelle, '${l.quantite}',
                     C.money(l.prixUnitaire, doc.devise),
                     C.money(l.total, doc.devise)],
              ],
            ),
            pw.SizedBox(height: 12),
            // ---------- Totaux (jamais sur un BL) ----------
            if (doc.type.sansPrix)
              pw.Row(children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 70,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#999999'))),
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Livreur (nom + signature + date)',
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    height: 70,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#999999'))),
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Réceptionnaire (nom + signature + date)',
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ),
              ])
            else
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  child: pw.Column(children: [
                    _total('Total HT', doc.totalHT, doc.devise),
                    _total('TVA (${profile.tva} %)', doc.tva, doc.devise),
                    pw.Divider(height: 6),
                    pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text(C.money(doc.totalTTC, doc.devise),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ]),
                ),
              ),
            pw.Spacer(),
            // ---------- Signature & cachet ----------
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (signature != null)
                  pw.Column(children: [
                    pw.Container(width: 110, height: 50,
                        child: pw.Image(signature, fit: pw.BoxFit.contain)),
                    pw.Text('Signature',
                        style: const pw.TextStyle(fontSize: 8)),
                  ]),
                if (cachet != null)
                  pw.Container(width: 80, height: 80,
                      child: pw.Image(cachet, fit: pw.BoxFit.contain)),
              ],
            ),
            pw.SizedBox(height: 10),
            if (profile.banque.isNotEmpty)
              pw.Text('Banque : ${profile.banque} — ${profile.coordonneesBancaires}',
                  style: const pw.TextStyle(fontSize: 8)),
            pw.Text(profile.messagePied,
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static pw.Widget _total(String label, double valeur, String devise) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(C.money(valeur, devise),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      );

  /// Partage direct (WhatsApp, Gmail, Drive…) — le choix terrain n°1.
  /// Archive automatiquement une copie PDF dans le bucket privé
  /// Supabase « documents » (ré-exploitable à volonté côté serveur/app).
  static Future<void> partager(DocumentBati doc, CompanyProfile profile) async {
    final bytes = await generer(doc, profile);
    await Printing.sharePdf(
        bytes: bytes, filename: '${doc.numero.replaceAll('/', '-')}.pdf');
    await _archiver(doc, bytes);
  }

  static Future<void> _archiver(DocumentBati doc, Uint8List bytes) async {
    try {
      final client = SupabaseService.client;
      if (client == null) return;
      final nom = '${doc.numero.replaceAll('/', '-')}.pdf';
      await client.storage
          .from('documents')
          .uploadBinary(nom, bytes, fileOptions: const FileOptions(upsert: true));
    } catch (_) {
      // Bucket absent ou hors-ligne : le document reste enregistré en
      // structure (tables documents/document_lignes) — régénérable à volonté.
    }
  }

  /// Impression (imprimante thermique ticket ou bureau).
  static Future<void> imprimer(DocumentBati doc, CompanyProfile profile) async {
    final bytes = await generer(doc, profile);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Rapport de clôture journalière : toutes les transactions du jour,
  /// CA et marge par activité, totaux — à envoyer au gérant chaque soir.
  static Future<Uint8List> rapportJournalier({
    required List<Tx> transactions,
    required String boutiqueNom,
    required String date,
    required String devise,
  }) async {
    final pdf = pw.Document();
    final ca = transactions.fold(0.0, (s, t) => s + t.montant);
    final marge = transactions.fold(0.0, (s, t) => s + t.marge);
    final parType = <TypeTransaction, double>{};
    for (final t in transactions) {
      parType[t.type] = (parType[t.type] ?? 0) + t.montant;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('RAPPORT JOURNALIER — $boutiqueNom',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _chiffre('Opérations', '${transactions.length}'),
                _chiffre('Chiffre d\'affaires', C.money(ca, devise)),
                _chiffre('Marge', C.money(marge, devise)),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('Détail par activité',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Activité', 'Montant'],
              data: [
                for (final e in parType.entries)
                  [e.key.name, C.money(e.value, devise)],
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('Transactions du jour',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
              cellStyle: const pw.TextStyle(fontSize: 8),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.6),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2.4),
              },
              headers: ['Heure', 'Détail', 'Montant'],
              data: [
                for (final t in transactions)
                  [
                    '${t.date.hour.toString().padLeft(2, '0')}h${t.date.minute.toString().padLeft(2, '0')}',
                    '${t.type.name}${t.clientNom != null ? ' — ${t.clientNom}' : ''}',
                    C.money(t.montant, devise),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static pw.Widget _chiffre(String label, String valeur) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(valeur,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      );

  /// Partage le rapport du jour (WhatsApp vers le gérant).
  static Future<void> partagerRapportJournalier({
    required List<Tx> transactions,
    required String boutiqueNom,
    required String devise,
  }) async {
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final bytes = await rapportJournalier(
        transactions: transactions, boutiqueNom: boutiqueNom,
        date: date, devise: devise);
    await Printing.sharePdf(
        bytes: bytes,
        filename: 'rapport_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf');
  }
}

/// Existence de fichier image (évite l'import circulaire avec media_service).
bool mediaServiceExiste(String? path) =>
    path != null && path.isNotEmpty && File(path).existsSync();
