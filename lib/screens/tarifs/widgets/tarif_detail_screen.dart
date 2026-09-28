import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/store.dart';
import '../../../widgets/money_text.dart';
import '../../stock/widgets/badge_produit.dart';
import '../../stock/widgets/image_carousel.dart';

/// Fiche détail article : galerie, fiche complète, historique
/// des ventes, actions (utiliser, modifier, désactiver).
class TarifDetailScreen extends StatelessWidget {
  final String tarifId;

  const TarifDetailScreen({super.key, required this.tarifId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final i = store.catalogue.indexWhere((t) => t.id == tarifId);
    if (i < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Article introuvable')),
      );
    }
    final t = store.catalogue[i];
    return Scaffold(
      appBar: AppBar(title: Text(t.libelle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        ImageCarousel(t.images, height: 220),
        const SizedBox(height: 8),
        if (t.nouveau)
          const Wrap(children: [
            BadgeProduitWidget(BadgeProduit.nouveau),
          ]),
        const SizedBox(height: 8),
        Text(t.libelle,
            style: Theme.of(context).textTheme.titleLarge),
        Text(t.categorie,
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        MoneyText(t.prix,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800)),
        if (t.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.description, style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            icon: const Icon(Icons.point_of_sale_outlined, size: 18),
            label: const Text('Utiliser dans vente'),
            onPressed: () =>
                Navigator.of(context).pop(tarifId),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Partager'),
            onPressed: () => SharePlus.instance.share(ShareParams(
                text:
                    '${t.libelle} — ${t.prix.toStringAsFixed(0)} F (${store.profile.devise})')),
          ),
        ]),
      ]),
    );
  }
}
