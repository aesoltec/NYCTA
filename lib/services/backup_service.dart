import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../data/store.dart';
import '../models/document.dart';
import '../models/transaction.dart';
import 'document_service.dart';

/// Exports CSV (Excel) + sauvegarde complète JSON avec restauration.
/// Principe senior : VOS DONNÉES FINANCIÈRES VOUS APPARTIENNENT —
/// exportables à tout moment, lisibles dans Excel, restaurables partout.
class BackupService {
  static final _fmtCsv = DateFormat('dd/MM/yyyy HH:mm');

  // ---------- CSV (Excel) ----------
  /// BOM UTF-8 (﻿) → les accents s'ouvrent correctement dans Excel.
  static String _csv(Iterable<List<dynamic>> lignes) =>
      '﻿${lignes.map((l) => l.map(_cellule).join(';')).join('\n')}';

  static String _cellule(dynamic v) {
    var s = '${v ?? ''}';
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<void> exporterTransactionsCsv(Store store) async {
    final lignes = <List<dynamic>>[
      ['Date', 'Boutique', 'Activité', 'Client', 'Détail', 'Montant',
       'Coût', 'Marge', 'Devise'],
      for (final t in store.txBoutique)
        [_fmtCsv.format(t.date), t.boutiqueId, t.type.name,
         t.clientNom ?? '', _detail(t), t.montant, t.cout, t.marge,
         store.profile.devise],
    ];
    await partagerFichier(
        'transactions_${store.moisCourant}.csv', _csv(lignes));
  }

  static Future<void> exporterChargesCsv(Store store) async {
    final lignes = <List<dynamic>>[
      ['Date', 'Catégorie', 'Libellé', 'Montant', 'Récurrente', 'Devise'],
      for (final c in store.depensesBoutique)
        [_fmtCsv.format(c.date), c.categorie, c.libelle, c.montant,
         c.recurrente ? 'Oui' : 'Non', store.profile.devise],
    ];
    await partagerFichier(
        'depenses_${store.moisCourant}.csv', _csv(lignes));
  }

  static String _detail(Tx t) {
    final d = t.details;
    return switch (t.type) {
      TypeTransaction.prestationService =>
        '${d['domaine'] ?? ''}${d['description'] != null ? ' — ${d['description']}' : ''}',
      TypeTransaction.mobileMoney =>
        '${d['operateur'] ?? ''} ${d['operation'] ?? ''}',
      TypeTransaction.creditCommunication => '${d['operateur'] ?? ''}',
      TypeTransaction.forfaitHotspot => '${d['duree'] ?? ''}',
      TypeTransaction.venteMateriel =>
        (d['lignes'] as List?)?.map((l) => '${l['quantite']}× ${l['libelle']}').join(', ') ?? '',
    };
  }

  // ---------- Sauvegarde complète JSON ----------
  static Future<void> sauvegardeComplete(Store store) async {
    final backup = {
      'application': 'PME Gestion',
      'version_backup': 1,
      'date': DateTime.now().toIso8601String(),
      'profil': {
        'nom_entreprise': store.profile.nomEntreprise,
        'devise': store.profile.devise,
        'telephone': store.profile.telephone,
        'email': store.profile.email,
        'adresse': store.profile.adresse,
        'rccm': store.profile.rccm,
        'ifu': store.profile.ifu,
        'banque': store.profile.banque,
        'tva': store.profile.tva,
        'message_pied': store.profile.messagePied,
        'fonds_roulement': store.profile.fondsRoulement,
        'budgets': store.profile.budgetsMensuels,
      },
      'boutiques': [
        for (final b in store.boutiques)
          {'id': b.id, 'nom': b.nom, 'adresse': b.adresse, 'siege': b.siege},
      ],
      'produits': [
        for (final p in store.produits)
          {'id': p.id, 'boutique_id': p.boutiqueId, 'libelle': p.libelle,
           'categorie': p.categorie, 'prix_achat': p.prixAchat,
           'prix_vente': p.prixVente, 'stock': p.stock, 'seuil': p.seuil},
      ],
      'partenaires': [
        for (final p in store.partenaires)
          {'id': p.id, 'nom': p.nom, 'telephone': p.telephone,
           'localisation': p.localisation, 'taux': p.taux},
      ],
      'transactions': [
        for (final t in store.transactions)
          {'id': t.id, 'boutique_id': t.boutiqueId, 'type': t.type.name,
           'montant': t.montant, 'cout': t.cout, 'statut': t.statut.name,
           'client_nom': t.clientNom, 'partenaire_id': t.partenaireId,
           'details': t.details, 'date': t.date.toIso8601String()},
      ],
      'charges': [
        for (final c in store.depenses)
          {'id': c.id, 'boutique_id': c.boutiqueId, 'categorie': c.categorie,
           'libelle': c.libelle, 'montant': c.montant,
           'date': c.date.toIso8601String(), 'recurrente': c.recurrente},
      ],
      'partages': [
        for (final p in store.partages)
          {'partenaire_id': p.partenaireId, 'mois': p.mois,
           'total_ventes': p.totalVentes, 'taux': p.taux,
           'part_partenaire': p.partPartenaire,
           'part_entreprise': p.partEntreprise},
      ],
    };
    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final nom = 'sauvegarde_pme_${C.moisKey(DateTime.now())}.json';
    await partagerFichier(nom, json);
  }

  /// Restauration : l'utilisateur choisit un fichier .json de sauvegarde.
  /// Retourne un message de résultat, ou null si annulé.
  static Future<String?> restaurer(Store store) async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['json']);
    if (picked.isEmpty) return null;
    final file = picked.first;
    try {
      final contenu = utf8.decode(await file.readAsBytes());
      final data = jsonDecode(contenu) as Map<String, dynamic>;
      if (data['application'] != 'PME Gestion') {
        return '❌ Fichier invalide (pas une sauvegarde PME Gestion)';
      }
      await store.restaurerSauvegarde(data);
      final nbTx = (data['transactions'] as List?)?.length ?? 0;
      return '✅ Restauration réussie : $nbTx transactions, '
          '${(data['produits'] as List?)?.length ?? 0} produits, '
          '${(data['partenaires'] as List?)?.length ?? 0} partenaires';
    } catch (e) {
      return '❌ Erreur de lecture : $e';
    }
  }

  /// Export CSV d'un document commercial (lignes + totaux) — s'ouvre dans
  /// Excel. Partagé comme les autres exports.
  static Future<void> exporterDocumentCsv(DocumentBati doc) async {
    final lignes = <List<dynamic>>[
      ['Document', doc.numero],
      ['Type', doc.type.titre],
      ['Date', doc.date],
      ['Client', doc.client],
      [],
      ['Article', 'Quantité', 'Prix unitaire', 'Total', 'Devise'],
      for (final l in doc.lignes)
        [l.libelle, l.quantite, l.prixUnitaire, l.total, doc.devise],
      [],
      ['Total HT', '', '', doc.totalHT, doc.devise],
      ['TVA', '', '', doc.tva, doc.devise],
      ['TOTAL À PAYER', '', '', doc.totalTTC, doc.devise],
    ];
    await partagerFichier(
        '${doc.numero.replaceAll('/', '-')}.csv', _csv(lignes));
  }

  static Future<void> partagerFichier(String nom, String contenu) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nom');
    await f.writeAsString(contenu, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: nom));
  }
}
