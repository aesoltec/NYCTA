import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../models/produit.dart';
import 'product_card.dart';

/// Grille responsive : 2 colonnes mobile, 3 tablette, 4 desktop.
/// Basée sur la largeur réelle ([LayoutBuilder]), pas sur la plateforme.
class ProductGrid extends StatelessWidget {
  final List<Produit> produits;
  final void Function(Produit p)? onTap;
  final void Function(Produit p)? onVendre;
  final void Function(Produit p, String action)? onMenu;

  const ProductGrid({
    super.key,
    required this.produits,
    this.onTap,
    this.onVendre,
    this.onMenu,
  });

  /// Nombre de colonnes pour une largeur donnée (testable).
  static int colonnesPour(double largeur) {
    if (largeur >= 1100) return 4;
    if (largeur >= 700) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, contraintes) {
      final colonnes = colonnesPour(contraintes.maxWidth);
      return MasonryGridView.count(
        crossAxisCount: colonnes,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.all(8),
        itemCount: produits.length,
        itemBuilder: (_, i) {
          final p = produits[i];
          return ProductCard(
            produit: p,
            onTap: onTap == null ? null : () => onTap!(p),
            onVendre: onVendre == null ? null : () => onVendre!(p),
            onMenu: onMenu == null ? null : (a) => onMenu!(p, a),
          );
        },
      );
    });
  }
}
