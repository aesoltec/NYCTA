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

/// P9 — Historique des documents émis : chaque facture, devis, bon ou
/// ticket généré est listé ici ; un tap rouvre l'aperçu (et le PDF).
class DocumentsHistoryScreen extends StatelessWidget {
  const DocumentsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final docs = store.documentsEmis;

    return Scaffold(
      appBar: AppBar(title: const Text('Documents émis')),
      body: docs.isEmpty
          ? const EmptyView(
              icon: Icons.folder_outlined,
              message: 'Aucun document émis',
              hint: 'Les factures, devis, bons et tickets générés apparaîtront ici')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LigneDocument(doc: docs[i]),
            ),
    );
  }
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.description_outlined, color: couleur, size: 20),
        ),
        title: Row(children: [
          Expanded(
            child: Text(doc.numero,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          if (doc.statut != 'emis')
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _couleurStatut(doc.statut).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_libelleStatut(doc.statut),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _couleurStatut(doc.statut))),
            ),
        ]),
        subtitle: Text(
          '${doc.type.titre} · ${doc.client}${doc.type == TypeDocument.devisProforma ? ' · → facture possible' : ''}',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(doc.totalTTC, style: const TextStyle(fontSize: 13)),
            Text(doc.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            // Export CSV (Excel) de la copie enregistrée
            InkWell(
              onTap: () => BackupService.exporterDocumentCsv(doc),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('CSV ⤓',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            if (aValider)
              InkWell(
                onTap: () async {
                  final erreur =
                      await store.validerDocument(doc.numero);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(erreur == null
                              ? '✅ Document validé'
                              : '⚠️ $erreur')));
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Valider ✓',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: Color(0xFF3E9D8F))),
                ),
              ),
            if (aPayer)
              InkWell(
                onTap: () async {
                  final erreur =
                      await store.payerDocument(doc.numero);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(erreur == null
                              ? '✅ Marqué payé'
                              : '⚠️ $erreur')));
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Marquer payé',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: Color(0xFF3D6FB4))),
                ),
              ),
            if (aAnnuler)
              InkWell(
                onTap: () => _annuler(context, store, doc.numero),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Annuler',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: Colors.redAccent)),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(docExistant: doc),
        )),
      ),
    );
  }
}
