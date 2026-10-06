import 'package:flutter/material.dart';
import '../../../models/produit.dart';
import '../../../widgets/carte_grille.dart';
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
  /// Actions proposees au menu contextuel, deja filtrees par
  /// les droits du role. Liste `const` ici = on proposerait
  /// « Archiver » a un vendeur, qui ne peut pas le faire.
  final List<String> actions;

  const ProductCard({
    super.key,
    required this.produit,
    this.onVendre,
    this.onTap,
    this.onMenu,
    this.actions = const [],
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
        // `mainAxisSize` par defaut (max) : avec `min`, Flutter donne des
        // contraintes NON bornees aux enfants non flexibles, et `SlotCorps`
        // ne pourrait plus distinguer une grille d'une liste.
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    itemBuilder: (_) => [
                      for (final a in actions)
                        PopupMenuItem(value: a, child: Text(libelleActionProduit(a))),
                    ],
                  ),
                ),
              ]),
              // `Expanded` : la grille impose une hauteur fixe, le bloc
              // texte occupe donc TOUT l'espace restant au lieu de
              // laisser une carte plus basse qu'une autre.
              SlotCorps(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TitreCarte(
                          texte: p.libelle,
                          echelle:
                              MediaQuery.textScalerOf(context).scale(1.0),
                        ),
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
                        // Le reste de l'espace va entre le stock et le
                        // bouton : le bouton est toujours en bas de la
                        // carte, quelle que soit la longueur du libelle.
                        const EspaceCarte(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: p.enRupture ? null : onVendre,
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8)),
                            // Libellé sur une seule ligne : un bouton qui passe à la la
                            // ligne change la hauteur de la carte selon la
                            // largeur, ce qui casserait l'uniformité.
                            child: const Text(
                              'Vendre',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

/// Libelle affichable d'une action de menu contextuel produit.
/// Source unique : le menu doit dire la meme chose sur la carte ET sur
/// la ligne de liste.
String libelleActionProduit(String action) => switch (action) {
      'modifier' => 'Modifier',
      'ajuster' => 'Ajuster',
      'archiver' => 'Archiver',
      'partager' => 'Partager',
      _ => action,
    };
