import 'package:flutter/material.dart';
import '../../../models/tarif.dart';
import '../../../widgets/money_text.dart';
import '../../stock/widgets/badge_produit.dart';
import '../../stock/widgets/image_carousel.dart';

/// Carte article catalogue : image + badge Nouveau + prix + actions.
/// Même style que [ProductCard] (cohérence inter-modules).
class TarifCard extends StatelessWidget {
  final Tarif tarif;
  final VoidCallback? onUtiliser;
  final VoidCallback? onTap;
  final ValueChanged<String>? onMenu;

  const TarifCard({
    super.key,
    required this.tarif,
    this.onUtiliser,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = tarif;
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
                ImageCarousel(t.images),
                if (t.nouveau)
                  const Positioned(
                    top: 6,
                    left: 6,
                    child: BadgeProduitWidget(
                        BadgeProduit.nouveau),
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
                          value: 'modifier',
                          child: Text('Modifier')),
                      PopupMenuItem(
                          value: 'desactiver',
                          child: Text('Désactiver')),
                      PopupMenuItem(
                          value: 'partager',
                          child: Text('Partager')),
                    ],
                  ),
                ),
              ]),
              Flexible(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.libelle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.categorie,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        MoneyText(t.prix,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onUtiliser,
                            style: FilledButton.styleFrom(
                                visualDensity:
                                    VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 8)),
                            child:
                                const Text('Utiliser dans vente'),
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
