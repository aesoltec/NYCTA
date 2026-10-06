import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/store.dart';
import '../../../models/document.dart';
import '../../../models/enums.dart';
import '../../../services/document_import_service.dart';
import '../../../services/document_import_source.dart';
import 'widgets/import_choix.dart';
import 'widgets/import_rapport.dart';

/// Import de documents commerciaux depuis un tableur (Excel / CSV).
///
/// Le but métier est la REPRISE D'UN PORTEFEUILLE EXISTANT : des
/// factures, bordereaux de livraison, bons de commande ou devis venus
/// d'un autre logiciel, que l'on veut pouvoir corriger puis réutiliser.
///
/// Trois garanties, non négociables :
///
/// 1. **Rien n'est émis automatiquement.** Tout import nait en
///    `brouillon`. Un document émis est un justificatif comptable et
///    fiscal ; un import non relu ne peut pas en être un. Le
///    brouillon, lui, est modifiable.
/// 2. **Aucune perte silencieuse.** Chaque ligne rejetée est comptée et
///    décrite. Un rapport de 3 anomalies pour 200 lignes doit alerter,
///    pas se perdre.
/// 3. **Le service d'import est pur** (`DocumentImportService`) : la
///    logique de lecture est testable sans fichier ni interface. Cet
///    écran ne fait que lui passer des lignes et afficher son rapport.
class DocumentImportScreen extends StatefulWidget {
  const DocumentImportScreen({super.key});

  @override
  State<DocumentImportScreen> createState() => _DocumentImportScreenState();
}

class _DocumentImportScreenState extends State<DocumentImportScreen> {
  static const _service = DocumentImportService();
  static const _source = DocumentImportSource();

  TypeDocument _type = TypeDocument.facture;
  double _tvaPct = 18;
  String? _fichier;
  ImportResultat? _rapport;
  String? _erreur;
  bool _ocuppe = false;
  int _importes = 0;

  String get _devise => context.read<Store>().profile.devise;

  Future<void> _analyser() async {
    final chemin = _fichier;
    if (chemin == null) return;
    setState(() {
      _ocuppe = true;
      _erreur = null;
      _rapport = null;
    });
    try {
      final lu = _source.lire(chemin);
      final rapport = _service.importerLignes(
        lu.lignes,
        typeParDefaut: _type,
        devise: _devise,
        tvaPct: _tvaPct,
      );
      if (!mounted) return;
      setState(() {
        _rapport = rapport;
        _ocuppe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ImportSourceErreur
            ? e.message
            : 'Lecture impossible : $e';
        _ocuppe = false;
      });
    }
  }

  /// Enregistre les documents un à un. Un échec isolé ne doit pas
  /// interrompre le lot : le rapport doit dire ce qui a été importé et ce
  /// qui ne l'a pas été.
  Future<void> _importer() async {
    final rapport = _rapport;
    if (rapport == null || rapport.documents.isEmpty) return;
    final store = context.read<Store>();
    var ok = 0;
    final echecs = <String>[];
    setState(() => _ocuppe = true);
    for (final d in rapport.documents) {
      final err = await store.enregistrerDocument(d);
      if (err == null) {
        ok++;
      } else {
        echecs.add('${d.numero} : $err');
      }
    }
    if (!mounted) return;
    setState(() {
      _importes = ok;
      _ocuppe = false;
      if (echecs.isNotEmpty) {
        _erreur = '${echecs.length} document(s) refusé(s) :\n'
            '${echecs.take(3).join('\n')}';
      }
    });
    if (ok > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$ok document(s) importé(s) en brouillon'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    // Même règle que le bouton d'entrée dans l'historique : le vendeur
    // peut importer un brouillon, pas émettre.
    if (!store.peut(Permission.gererDocuments) &&
        store.role != Role.vendeur) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importer des documents')),
        body: const Center(child: Text('Import réservé aux rôles autorisés')),
      );
    }

    final rapport = _rapport;
    return Scaffold(
      appBar: AppBar(title: const Text('Importer des documents')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ImportChoix(
            type: _type,
            tvaPct: _tvaPct,
            fichier: _fichier,
            occupe: _ocuppe,
            onType: (t) => setState(() {
              _type = t;
              _rapport = null;
            }),
            onTva: (v) => setState(() {
              _tvaPct = v;
              _rapport = null;
            }),
            onFichier: (chemin) => setState(() {
              _fichier = chemin;
              _rapport = null;
              _erreur = null;
            }),
            onModele: () => setState(() => _erreur = null),
            onAnalyser: _analyser,
          ),
          const SizedBox(height: 16),
          if (_erreur != null)
            Card(
              color: const Color(0xFFFDECEA),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_erreur!,
                    style: const TextStyle(color: Color(0xFFC62828))),
              ),
            ),
          if (rapport != null) ...[
            ImportRapport(rapport: rapport, importes: _importes),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_ocuppe || rapport.documents.isEmpty) ? null : _importer,
              icon: const Icon(Icons.download_done),
              label: Text(
                  'Importer ${rapport.documents.length} document(s) en brouillon'),
            ),
          ],
          const SizedBox(height: 24),
          const _AideFormat(),
        ],
      ),
    );
  }
}

/// Rappel du format attendu, affiché en permanence.
///
/// Un import qui échoue parce que l'utilisateur n'avait pas le bon
/// format est un import raté : la règle doit être visible AVANT, pas
/// expliquée dans un rapport d'erreur.
class _AideFormat extends StatelessWidget {
  const _AideFormat();

  @override
  Widget build(BuildContext context) {
    final clair = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: clair ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Format attendu',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Une ligne = une ligne de document. Toutes les lignes du '
              'même numéro forment un seul document.\n\n'
              'numero ; date ; client ; designation ; quantite ; prix\n'
              'F-001 ; 03/10/2026 ; Client A ; Câble ; 10 ; 1500\n'
              'F-001 ; ; Client A ; Prise ; 5 ; 500\n\n'
              'En-têtes tolérés : Qte, PU, Libellé, N° de pièce…\n'
              'Sans colonne « numero », les lignes d’un même client '
              'forment un document.\n'
              '« type » est optionnel (Facture, Devis, Bon de commande, BL).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}