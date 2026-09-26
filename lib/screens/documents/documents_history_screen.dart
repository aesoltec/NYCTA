import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/document.dart';
import '../../models/enums.dart';
import '../../services/document_service.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../services/backup_service.dart';
import 'document_preview_screen.dart';
import '../../widgets/date_picker_field.dart';

/// P9 — Historique des documents émis : chaque facture, devis, bon ou
/// ticket généré est listé ici ; un tap rouvre l'aperçu (et le PDF).
class DocumentsHistoryScreen extends StatefulWidget {
  const DocumentsHistoryScreen({super.key});

  @override
  State<DocumentsHistoryScreen> createState() =>
      _DocumentsHistoryScreenState();
}

class _DocumentsHistoryScreenState
    extends State<DocumentsHistoryScreen> {
  TypeDocument? _type;
  String _recherche = '';
  DateTime? _debut;
  DateTime? _fin;
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var docs = store.documentsEmis.toList();
    if (_type != null) {
      docs = docs.where((d) => d.type == _type).toList();
    }
    final rech = _recherche.trim().toLowerCase();
    if (rech.isNotEmpty) {
      docs = docs
          .where((d) =>
              d.client.toLowerCase().contains(rech) ||
              d.numero.toLowerCase().contains(rech))
          .toList();
    }
    if (_debut != null) {
      docs = docs
          .where((d) =>
              _dateDoc(d) == null || !_dateDoc(d)!.isBefore(_debut!))
          .toList();
    }
    if (_fin != null) {
      final finJour =
          DateTime(_fin!.year, _fin!.month, _fin!.day, 23, 59, 59);
      docs = docs
          .where((d) =>
              _dateDoc(d) == null || !_dateDoc(d)!.isAfter(finJour))
          .toList();
    }
    final min = double.tryParse(
            _min.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ??
        0;
    final max = double.tryParse(
            _max.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ??
        double.infinity;
    docs = docs
        .where((d) => d.totalTTC >= min && d.totalTTC <= max)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Documents émis')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher (client, numéro)…',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
            ),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tous'),
                  selected: _type == null,
                  onSelected: (_) =>
                      setState(() => _type = null),
                ),
              ),
              for (final t in TypeDocument.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.titre),
                    selected: _type == t,
                    onSelected: (_) => setState(
                        () => _type = _type == t ? null : t),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: LayoutBuilder(builder: (ctx, c) {
            // Écrans étroits (320/360) : 2 lignes pour éviter l'écrasement.
            final etroit = c.maxWidth < 560;
            final dates = Row(children: [
              Expanded(
                child: DatePickerField(
                  valeur: _debut,
                  label: 'Début',
                  onChanged: (d) => setState(() => _debut = d),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DatePickerField(
                  valeur: _fin,
                  label: 'Fin',
                  onChanged: (d) => setState(() => _fin = d),
                ),
              ),
            ]);
            final montants = Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Min'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Max'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]);
            if (etroit) {
              return Column(children: [
                dates,
                const SizedBox(height: 8),
                montants,
              ]);
            }
            return Row(children: [
              Expanded(child: dates),
              const SizedBox(width: 10),
              Expanded(child: montants),
            ]);
          }),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: docs.isEmpty
              ? const EmptyView(
                  icon: Icons.folder_outlined,
                  message: 'Aucun document émis',
                  hint:
                      'Les factures, devis, bons et tickets générés apparaîtront ici')
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _LigneDocument(doc: docs[i]),
                ),
        ),
      ]),
    );
  }

  /// Date réelle du document (chaîne JJ/MM/AAAA) — null si illisible
  /// (le document reste visible : jamais exclu silencieusement).
  static DateTime? _dateDoc(DocumentBati doc) =>
      DocumentService.parseAffichage(doc.date);
}

class _LigneDocument extends StatelessWidget {
  final DocumentBati doc;
  const _LigneDocument({required this.doc});

  static String _libelleStatut(String statut) => switch (statut) {
        'brouillon' => 'BROUILLON',
        'paye' => 'PAYÉ',
        'annule' => 'ANNULÉ',
        _ => statut.toUpperCase(),
      };

  static Color _couleurStatut(String statut) => switch (statut) {
        'paye' => const Color(0xFF3E9D8F),
        'annule' => const Color(0xFFC62828),
        _ => const Color(0xFFB26A00),
      };

  static Future<void> _annuler(
      BuildContext context, Store store, String numero) async {
    final ctrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Annuler ce document ?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Motif (obligatoire)',
              helperText: 'Le document reste lisible avec son motif'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(
                ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Annuler le document'),
          ),
        ],
      ),
    );
    if (motif == null || !context.mounted) return;
    final erreur = await store.annulerDocument(numero, motif);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            erreur == null ? 'Document annulé' : '⚠️ $erreur')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final couleur = switch (doc.type) {
      TypeDocument.facture => const Color(0xFF3D6FB4),
      TypeDocument.devisProforma => const Color(0xFF7E57C2),
      TypeDocument.bonCommande => const Color(0xFFEF6C00),
      TypeDocument.ticketCaisse => const Color(0xFF00897B),
      TypeDocument.bonLivraison => const Color(0xFF3E9D8F),
    };
    // Workflow de validation (mission §2.9) : brouillon → émis →
    // payé, annulation motivée. Qui fait quoi : voir MATRICE_PERMISSIONS.
    final aValider = doc.statut == 'brouillon' &&
        (store.role == Role.admin ||
            store.role == Role.gerant ||
            store.role == Role.comptable);
    final aPayer = doc.statut == 'emis' && store.peut(Permission.gererDocuments);
    final aAnnuler = (doc.statut == 'brouillon' || doc.statut == 'emis') &&
        (store.role == Role.admin || store.role == Role.gerant);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(docExistant: doc),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(Icons.description_outlined,
                      color: couleur, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(doc.numero,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                        if (doc.statut != 'emis')
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _couleurStatut(doc.statut)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_libelleStatut(doc.statut),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        _couleurStatut(doc.statut))),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        '${doc.type.titre} · ${doc.client}${doc.type == TypeDocument.devisProforma ? ' · → facture possible' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyText(doc.totalTTC,
                        style: const TextStyle(fontSize: 13)),
                    Text(doc.date,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ]),
              // Actions : ligne wrappée sous l'en-tête — jamais de
              // dépassement vertical (corrige « bottom overflowed by
              // 33 pixels » de l'ancien trailing en colonne).
              if (aValider || aPayer || aAnnuler)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        onTap: () =>
                            BackupService.exporterDocumentCsv(doc),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Text('CSV ⤓',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary)),
                        ),
                      ),
                      if (aValider)
                        InkWell(
                          onTap: () async {
                            final erreur = await store
                                .validerDocument(doc.numero);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                    content: Text(erreur == null
                                        ? '✅ Document validé'
                                        : '⚠️ $erreur')));
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text('Valider ✓',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3E9D8F))),
                          ),
                        ),
                      if (aPayer)
                        InkWell(
                          onTap: () async {
                            final erreur = await store
                                .payerDocument(doc.numero);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                    content: Text(erreur == null
                                        ? '✅ Marqué payé'
                                        : '⚠️ $erreur')));
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text('Marquer payé',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3D6FB4))),
                          ),
                        ),
                      if (aAnnuler)
                        InkWell(
                          onTap: () =>
                              _annuler(context, store, doc.numero),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text('Annuler',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent)),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () =>
                        BackupService.exporterDocumentCsv(doc),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 2),
                      child: Text('CSV ⤓',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
