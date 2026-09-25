import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../models/transaction.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';

/// Relances clients (mission §3.3) : créances impayées, relance WhatsApp,
/// encaissement en un tap. Accessible aux rôles de vente.
class RelancesScreen extends StatelessWidget {
  const RelancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final creances = store.creances;
    return Scaffold(
      appBar: AppBar(title: const Text('Relances clients')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFC62828)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '${creances.length} impayé(s) · ${C.money(store.totalCreances, store.profile.devise)} à recouvrer',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
        Expanded(
          child: creances.isEmpty
              ? const EmptyView(
                  icon: Icons.check_circle_outline,
                  message: 'Aucun impayé 🎉',
                  hint: 'Toutes les ventes sont encaissées')
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: creances.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _LigneCreance(tx: creances[i]),
                ),
        ),
      ]),
    );
  }
}

class _LigneCreance extends StatelessWidget {
  final Tx tx;
  const _LigneCreance({required this.tx});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final jours =
        DateTime.now().difference(tx.date).inDays;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    tx.clientNom ?? C.infosTypes[tx.type]!.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
              ),
              MoneyText(tx.montant,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 2),
            Text(
              'Il y a $jours j · ${C.infosTypes[tx.type]!.$1}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.message_outlined, size: 18),
                  label: const Text('Relancer'),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                        text:
                            'Bonjour ${tx.clientNom ?? ''}, rappel amical : facture ${C.money(tx.montant, store.profile.devise)} du ${tx.date.day}/${tx.date.month}/${tx.date.year} (${C.infosTypes[tx.type]!.$1}) restant due à ${store.profile.nomEntreprise}. Merci de régulariser.'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Encaisser'),
                  onPressed: () async {
                    final erreur =
                        await store.encaisserVente(tx.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(erreur == null
                                ? '✅ Encaissé'
                                : '⚠️ $erreur')));
                  },
                ),
              ),
            ]),
          ]),
    );
  }
}
