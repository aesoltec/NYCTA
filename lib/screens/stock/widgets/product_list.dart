import 'package:flutter/material.dart';
import '../../../models/produit.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/money_text.dart';

/// Vue liste dense du stock (tableau) :
/// image | libellé | catégorie | prix achat | prix vente | stock | actions.
class ProductList extends StatelessWidget {
  final List<Produit> produits;
  final void Function(Produit p)? onTap;
  final void Function(Produit p)? onVendre;
  final void Function(Produit p, String action)? onMenu;

  const ProductList({
    super.key,
    required this.produits,
    this.onTap,
    this.onVendre,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: produits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = produits[i];
        return ProductListTile(
          produit: p,
          onTap: onTap == null ? null : () => onTap!(p),
          onVendre: onVendre == null ? null : () => onVendre!(p),
          onMenu: onMenu == null ? null : (a) => onMenu!(p, a),
        );
      },
    );
  }
}

/// Tuile unitaire de la vue liste (réutilisable en sliver).
class ProductListTile extends StatelessWidget {
  final Produit produit;
  final VoidCallback? onTap;
  final VoidCallback? onVendre;
  final ValueChanged<String>? onMenu;

  const ProductListTile({
    super.key,
    required this.produit,
    this.onTap,
    this.onVendre,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final image = p.images.isNotEmpty ? p.images.first : p.imagePath;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            AppImage(image, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.libelle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(p.categorie,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Wrap(spacing: 8, children: [
                      Text(
                          'Achat : ${p.prixAchat.toStringAsFixed(0)} F',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                      MoneyText(p.prixVente,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      Text('Stock : ${p.stock}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.enRupture
                                  ? const Color(0xFFDC2626)
                                  : p.stockFaible
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF16A34A))),
                    ]),
                  ]),
            ),
            IconButton(
              tooltip: 'Vendre',
              icon: const Icon(Icons.sell_outlined, size: 20),
              onPressed:
                  p.enRupture || onVendre == null ? null : onVendre,
            ),
            PopupMenuButton<String>(
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
          ]),
        ),
      ),
    );
  }
}
