import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/store.dart';
import '../../../models/produit.dart';
import '../../../widgets/money_text.dart';
import 'badge_produit.dart';
import 'image_carousel.dart';

/// Fiche détail produit : galerie, fiche complète, historique
/// mouvements + 5 dernières ventes, actions rapides.
/// Ouverte au tap sur une carte ([ProductCard]) avec Hero sur l'image.
class ProduitDetailScreen extends StatelessWidget {
  final String produitId;

  const ProduitDetailScreen({super.key, required this.produitId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final i = store.produits.indexWhere((p) => p.id == produitId);
    if (i < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Produit introuvable')),
      );
    }
    final p = store.produits[i];
    final badges = <BadgeProduit>[
      if (p.enRupture) BadgeProduit.rupture
      else if (p.stockFaible) BadgeProduit.stockFaible,
      if (p.nouveau) BadgeProduit.nouveau,
    ];
    final mouvements = store.mouvementsProduit(p.id);
    final ventes = store.transactions
        .where((t) => ((t.details['lignes'] as List?) ?? const [])
            .any((l) => l is Map && l['produitId']?.toString() == p.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(p.libelle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Hero(
          tag: 'produit_${p.id}',
          child: ImageCarousel(
              [...p.images, if (p.imagePath != null) p.imagePath!]
                  .toSet()
                  .toList(),
              height: 220),
        ),
        const SizedBox(height: 8),
        if (badges.isNotEmpty)
          Wrap(spacing: 6, children: [
            for (final b in badges) BadgeProduitWidget(b),
          ]),
        const SizedBox(height: 8),
        Text(p.libelle,
            style: Theme.of(context).textTheme.titleLarge),
        Text(p.categorie,
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        _fiche(context, store, p),
        const SizedBox(height: 12),
        _actions(context, store, p),
        const SizedBox(height: 12),
        Text('Mouvements de stock',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (mouvements.isEmpty)
          const Text('Aucun mouvement tracé.')
        else
          for (final m in mouvements.take(10))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  m.quantite >= 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18),
              title: Text('${m.type} : ${m.quantite > 0 ? '+' : ''}${m.quantite}',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  '${m.motif} · stock après : ${m.stockApres}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
            ),
        const SizedBox(height: 8),
        Text('Dernières ventes',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (ventes.isEmpty)
          const Text('Aucune vente enregistrée.')
        else
          for (final v in ventes.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(v.clientNom ?? 'Vente',
                  style: const TextStyle(fontSize: 13)),
              trailing: MoneyText(v.montant,
                  style: const TextStyle(fontSize: 13)),
            ),
      ]),
    );
  }

  Widget _fiche(BuildContext context, Store store, Produit p) => Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _ligne('Prix de vente', '${p.prixVente.toStringAsFixed(0)} F'),
            _ligne('Prix d\u2019achat', '${p.prixAchat.toStringAsFixed(0)} F'),
            _ligne('Stock', '${p.stock} (seuil ${p.seuil})'),
            _ligne('Marge / unité',
                '${(p.prixVente - p.prixAchat).toStringAsFixed(0)} F'),
          ]),
        ),
      );

  Widget _ligne(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
          Flexible(
            child: Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _actions(BuildContext context, Store store, Produit p) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          icon: const Icon(Icons.sell_outlined, size: 18),
          label: const Text('Vendre'),
          onPressed: p.enRupture
              ? null
              : () async {
                  try {
                    await store.vendreProduit(p, 1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('✅ 1× ${p.libelle} vendu')));
                    }
                  } on StateError catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ ${e.message}')));
                    }
                  }
                },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Partager'),
          onPressed: () => SharePlus.instance.share(ShareParams(
              text:
                  '${p.libelle} — ${p.prixVente.toStringAsFixed(0)} F (${store.profile.devise})')),
        ),
      ]);
}
