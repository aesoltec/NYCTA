import 'package:flutter/material.dart';

/// Badges INFORMATIFS produit (refonte UX e-commerce) : 3 UNIQUEMENT.
/// - 🟢 « Nouveau » (< 7 jours, [ProduitExtension.nouveau]).
/// - ⚠️ « Stock faible » (0 < stock ≤ seuil).
/// - 🚫 « Rupture » (stock = 0).
/// Tout badge marketing est définitivement supprimé.
enum BadgeProduit { nouveau, stockFaible, rupture }

/// Pastille compacte en surimpression de carte.
class BadgeProduitWidget extends StatelessWidget {
  final BadgeProduit badge;

  const BadgeProduitWidget(this.badge, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, couleur, icone) = switch (badge) {
      BadgeProduit.nouveau =>
        ('Nouveau', const Color(0xFF16A34A), Icons.fiber_new_rounded),
      BadgeProduit.stockFaible =>
        ('Stock faible', const Color(0xFFD97706), Icons.warning_amber_rounded),
      BadgeProduit.rupture =>
        ('Rupture', const Color(0xFFDC2626), Icons.remove_shopping_cart_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 12, color: Colors.white),
        const SizedBox(width: 3),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ]),
    );
  }
}
