import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';

import '../../services/export_service.dart';

/// Trésorerie : fonds de roulement, solde de caisse, budgets du mois.
class TresorerieScreen extends StatefulWidget {
  const TresorerieScreen({super.key});

  @override
  State<TresorerieScreen> createState() => _TresorerieScreenState();
}

class _TresorerieScreenState extends State<TresorerieScreen> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final solde = store.soldeCaisseCourant;
    final budgets = store.suiviBudgets;
    // Filtre unique (catégorie de budget + nom de boutique).
    final rech = _recherche.trim().toLowerCase();
    final budgetsFiltres = Map.fromEntries(budgets.entries.where((e) =>
        rech.isEmpty || e.key.toLowerCase().contains(rech)));
    final boutiquesFiltrees = store.boutiques
        .where((b) =>
            rech.isEmpty || b.nom.toLowerCase().contains(rech))
        .toList();

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trésorerie'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, store, f),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'pdf', child: Text('PDF (partage)')),
              PopupMenuItem(
                  value: 'xlsx', child: Text('Excel (.xlsx)')),
              PopupMenuItem(
                  value: 'csv', child: Text('CSV (Excel)')),
            ],
          ),
        ],
      ),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Filtrer (catégorie, boutique)…',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
            ),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        Text('Budgets du mois ${store.moisCourant}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (budgetsFiltres.isEmpty)
          const SoftCard(
            child: Text('Aucun budget (ou filtre sans résultat).\nRendez-vous dans Configuration → Budgets.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          SoftCard(
            child: Column(children: [
              for (final e in budgetsFiltres.entries)
                _BarreBudget(categorie: e.key, budget: e.value.$1, consomme: e.value.$2),
            ]),
          ),
        const SizedBox(height: 16),
        Text('Soldes de caisse par boutique',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final b in boutiquesFiltrees)
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

  Future<void> _exporter(
      BuildContext context, Store store, String format) async {
    const entetes = [
      'Rubrique', 'Catégorie / Boutique', 'Budget / Fonds', 'Consommé / CA',
      'Solde', 'Devise'
    ];
    final lignes = <List<dynamic>>[
      for (final e in store.suiviBudgets.entries)
        [
          'Budget ${store.moisCourant}',
          e.key,
          e.value.$1,
          e.value.$2,
          e.value.$1 - e.value.$2,
          store.profile.devise,
        ],
      for (final b in store.boutiques)
        [
          'Solde de caisse',
          b.nom,
          store.profile.fondsRoulement[b.id] ?? 0,
          '',
          store.soldeCaisse(b.id),
          store.profile.devise,
        ],
    ];
    final nom = 'tresorerie_${store.moisCourant}';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Trésorerie — ${store.moisCourant}',
              sousTitre:
                  'Solde courant : ${store.soldeCaisseCourant.toStringAsFixed(0)} ${store.profile.devise}',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Trésorerie', entetes, lignes);
        default:
          await ExportService.partagerCsv(nom, entetes, lignes);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Export impossible')));
      }
    }
  }

  Future<void> _modifierFonds(BuildContext context, Store store) async {    final ctrl = TextEditingController(
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
