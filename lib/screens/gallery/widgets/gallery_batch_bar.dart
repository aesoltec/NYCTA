import 'package:flutter/material.dart';

/// Barre d'actions du mode lot (multi-sélection) de la galerie.
///
/// Isolé de l'écran (règle « widgets < 200 lignes »). Le bouton de
/// suppression reste désactivé tant que rien n'est coché, et le bouton
/// « Supprimer » est rouge : la suppression est définitive.
class GalleryBatchBar extends StatelessWidget {
  final int selectionnees;
  final int totalVisible;
  final VoidCallback? onToutSelectionner;
  final VoidCallback? onDeselectionner;
  final VoidCallback? onSupprimer;

  const GalleryBatchBar({
    super.key,
    required this.selectionnees,
    required this.totalVisible,
    this.onToutSelectionner,
    this.onDeselectionner,
    this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) => Material(
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectionnees == 0
                        ? 'Aucune image sélectionnée'
                        : '$selectionnees image(s) sélectionnée(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectionnees == 0)
                  TextButton(
                    onPressed:
                        totalVisible == 0 ? null : onToutSelectionner,
                    child: const Text('Tout'),
                  )
                else
                  TextButton(
                    onPressed: onDeselectionner,
                    child: const Text('Désélectionner'),
                  ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  onPressed: selectionnees == 0 ? null : onSupprimer,
                ),
              ],
            ),
          ),
        ),
      );
}
