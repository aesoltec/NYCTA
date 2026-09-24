import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/money_text.dart';

/// Fiche détail d'un achat + actions contextuelles selon statut et rôle.
/// Chaque action sensible est confirmée et tracée (createdBy + motif).
class AchatDetailScreen extends StatelessWidget {
  final String achatId;
  const AchatDetailScreen({super.key, required this.achatId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final i = store.achats.indexWhere((a) => a.id == achatId);
    if (i < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achat')),
        body: const Center(child: Text('Achat introuvable')),
      );
    }
    final a = store.achats[i];
    final gere = store.peut(Permission.gererAchats);
    return Scaffold(
      appBar: AppBar(title: Text(a.numero)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Bloc(titre: 'Fournisseur', lignes: [
            a.fournisseurNom,
            if ((a.referenceFacture ?? '').isNotEmpty)
              'Réf : ${a.referenceFacture}',
          ]),
          const SizedBox(height: 12),
          _Bloc(titre: 'Lignes (${a.lignes.length})', lignes: [
            for (final l in a.lignes)
              '${l.quantite.toStringAsFixed(l.quantite.truncateToDouble() == l.quantite ? 0 : 2)} ${l.unite} × ${l.produitNom} — ${l.prixUnitaire.toStringAsFixed(0)}${l.tauxTVA > 0 ? ' (+${l.tauxTVA.toStringAsFixed(0)} % TVA)' : ''}',
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Column(children: [
              _Total('Total HT', a.montantHT),
              _Total('TVA', a.montantTVA),
              _Total('Payé', a.montantPaye),
              const Divider(height: 20),
              Row(children: [
                const Expanded(
                    child: Text('TOTAL TTC',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                MoneyText(a.montantTTC,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              if (!a.estSolde && a.statut != 'annule') ...[
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: Text('Reste dû',
                          style: TextStyle(
                              color: Colors.grey.shade700))),
                  MoneyText(a.montantRestant,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706))),
                ]),
              ],
            ]),
          ),
          if ((a.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _Bloc(titre: 'Notes', lignes: [a.notes!]),
          ],
          if ((a.motifAnnulation ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _Bloc(titre: 'Motif d\'annulation',
                lignes: [a.motifAnnulation!]),
          ],
          const SizedBox(height: 20),
          if (gere && a.peutValider)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Valider (dette fournisseur)'),
                onPressed: () => _executer(
                    context, store, () => store.validerAchat(a.id)),
              ),
            ),
          if (gere && a.peutRecevoir) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Réceptionner (entrée stock)'),
                onPressed: () => _executer(
                    context, store, () => store.recevoirAchat(a.id),
                    ok: '✅ Stock mis à jour'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (gere && a.peutPayer) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Enregistrer un paiement'),
                onPressed: () => _payer(context, store, a.id, a.montantRestant),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (gere && a.peutAnnuler)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined,
                    size: 19, color: Colors.redAccent),
                label: const Text('Annuler cet achat',
                    style: TextStyle(color: Colors.redAccent)),
                onPressed: () => _annuler(context, store, a.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _executer(BuildContext context, Store store,
      Future<String?> Function() action,
      {String ok = '✅ Opération enregistrée'}) async {
    final erreur = await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreur == null ? ok : '⚠️ $erreur')));
    if (erreur == null) Navigator.pop(context);
  }

  Future<void> _payer(
      BuildContext context, Store store, String id, double resteDu) async {
    final ctrl = TextEditingController(
        text: resteDu.toStringAsFixed(0));
    final montant = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Paiement fournisseur'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Montant (reste dû : ${resteDu.toStringAsFixed(0)})'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = V.prixValue(ctrl.text);
              Navigator.pop(ctx, v > 0 ? v : null);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (montant == null || !context.mounted) return;
    await _executer(
        context, store, () => store.payerAchat(id, montant),
        ok: '✅ Paiement enregistré');
  }

  Future<void> _annuler(
      BuildContext context, Store store, String id) async {
    final ctrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Annuler cet achat ?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Motif (obligatoire)',
              helperText:
                  'Si déjà reçu, les quantités seront retirées du stock'),
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
            child: const Text('Annuler l\'achat'),
          ),
        ],
      ),
    );
    if (motif == null || !context.mounted) return;
    await _executer(
        context, store, () => store.annulerAchat(id, motif),
        ok: 'Achat annulé');
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final List<String> lignes;
  const _Bloc({required this.titre, required this.lignes});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x10000000),
                blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              for (final l in lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ]),
      );
}

class _Total extends StatelessWidget {
  final String label;
  final double valeur;
  const _Total(this.label, this.valeur);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade700))),
          MoneyText(valeur,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
