import 'package:flutter/material.dart';
import '../../../models/achat.dart';
import '../../../widgets/app_image.dart';

/// Ligne d'achat compacte : image, libellé, quantité, PU, sous-total.
class LigneAchatCard extends StatelessWidget {
  final LigneAchat ligne;

  const LigneAchatCard({super.key, required this.ligne});

  @override
  Widget build(BuildContext context) {
    final l = ligne;
    return Row(children: [
      AppImage(l.images.firstOrNull, size: 40),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.produitNom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                  '${l.quantite.toStringAsFixed(l.quantite.truncateToDouble() == l.quantite ? 0 : 2)} ${l.unite} × ${l.prixUnitaire.toStringAsFixed(0)} F',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ]),
      ),
      const SizedBox(width: 8),
      Text('${l.totalTTC.toStringAsFixed(0)} F',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }
}
