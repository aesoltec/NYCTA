import 'package:flutter/material.dart';
import '../../../models/produit.dart';
import '../../../widgets/money_text.dart';
import 'badge_produit.dart';
import 'image_carousel.dart';

/// Carte produit e-commerce : image + badges + prix + stock + actions.
/// Largeur contrainte par la grille parente (anti-overflow 320px).
class ProductCard extends StatelessWidget {
  final Produit produit;
  final VoidCallback? onVendre;
  final VoidCallback? onTap;
  final ValueChanged<String>? onMenu;

  const ProductCard({
    super.key,
    required this.produit,
    this.onVendre,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final badges = <BadgeProduit>[
      if (p.enRupture) BadgeProduit.rupture
      else if (p.stockFaible) BadgeProduit.stockFaible,
      if (p.nouveau) BadgeProduit.nouveau,
    ];
    final couleurStock = p.enRupture
        ? const Color(0xFFDC2626)
        : p.stockFaible
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(children: [
                Hero(
                  tag: 'produit_${p.id}',
                  child: ImageCarousel(
                      [...p.images, if (p.imagePath != null) p.imagePath!]
                          .toSet()
                          .toList()),
                ),
                if (badges.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Wrap(
                        spacing: 4, runSpacing: 4, children: [
                      for (final b in badges) BadgeProduitWidget(b),
                    ]),
                  ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: PopupMenuButton<String>(
                    tooltip: 'Actions',
                    iconSize: 20,
                    onSelected: onMenu,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'modifier', child: Text('Modifier')),
                      PopupMenuItem(
                          value: 'ajuster', child: Text('Ajuster')),
                      PopupMenuItem(
                          value: 'archiver', child: Text('Archiver')),
                      PopupMenuItem(
                          value: 'partager', child: Text('Partager')),
                    ],
                  ),
                ),
              ]),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.libelle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(p.categorie,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        MoneyText(p.prixVente,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        Text('Achat : ${p.prixAchat.toStringAsFixed(0)} F',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: couleurStock)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text('Stock : ${p.stock}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: couleurStock)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: p.enRupture ? null : onVendre,
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8)),
                            child: const Text('Vendre'),
                          ),
                        ),
                      ]),
                ),
              ),
            ]),
      ),
    );
  }
}
