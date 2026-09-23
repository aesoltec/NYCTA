import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';

/// Trésorerie : fonds de roulement, solde de caisse, budgets du mois.
class TresorerieScreen extends StatelessWidget {
  const TresorerieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final solde = store.soldeCaisseCourant;
    final budgets = store.suiviBudgets;

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    return Scaffold(
      appBar: AppBar(title: const Text('Trésorerie')),
      backgroundColor: const Color(0xFFD5F0F0),
      body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SoftCard(
          color: solde >= 0 ? const Color(0xFF3E9D8F) : const Color(0xFFD97706),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Solde de caisse (boutique courante)',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            MoneyText(solde,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Fonds de roulement : ${C.money(store.fondsRoulementCourant, store.profile.devise)}  ·  '
              'CA encaissé − dépenses',
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier le fonds de roulement'),
            onPressed: () => _modifierFonds(context, store),
          ),
        ),
        const SizedBox(height: 8),
        Text('Budgets du mois ${store.moisCourant}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (budgets.isEmpty)
          const SoftCard(
            child: Text('Aucun budget défini.\nRendez-vous dans Configuration → Budgets.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          SoftCard(
            child: Column(children: [
              for (final e in budgets.entries)
                _BarreBudget(categorie: e.key, budget: e.value.$1, consomme: e.value.$2),
            ]),
          ),
        const SizedBox(height: 16),
        Text('Soldes de caisse par boutique',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final b in store.boutiques)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.storefront_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                MoneyText(store.soldeCaisse(b.id), style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
      ],
      ),
    );
  }

  Future<void> _modifierFonds(BuildContext context, Store store) async {
    final ctrl = TextEditingController(
        text: store.fondsRoulementCourant == 0 ? '' : store.fondsRoulementCourant.toStringAsFixed(0));
    final montant = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Fonds de roulement initial'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Montant (${store.profile.devise})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (V.entier(ctrl.text, min: 0, label: 'Montant') == null)
              ? V.prixValue(ctrl.text) : null),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (montant != null) {
      await store.definirFondsRoulement(store.boutiqueId, montant);
    }
  }
}

class _BarreBudget extends StatelessWidget {
  final String categorie;
  final double budget, consomme;
  const _BarreBudget(
      {required this.categorie, required this.budget, required this.consomme});

  @override
  Widget build(BuildContext context) {
    final ratio = (consomme / budget).clamp(0.0, 1.0);
    final depasse = consomme > budget;
    final couleur = depasse
        ? const Color(0xFFD97706)
        : ratio > 0.8
            ? const Color(0xFFD97706)
            : const Color(0xFF3E9D8F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(categorie,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '${C.money(consomme)} / ${C.money(budget)}${depasse ? ' ⚠️' : ''}',
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFEDF0F5),
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ]),
    );
  }
}
