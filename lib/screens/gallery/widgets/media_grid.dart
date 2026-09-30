import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';
import '../../../data/models/media_item.dart' show MediaUsage;
import 'media_tile.dart';

/// Grille de la galerie : tuiles de largeur bornée (2 colonnes à 320 px,
/// 5 à 1024 px) — jamais de débordement, jamais de tuile déformée.
class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final List<MediaUsage> Function(MediaItem) usages;
  final void Function(MediaItem) onAffecter;
  final void Function(MediaItem)? onSupprimer;
  final void Function(MediaItem) onApercu;
  final void Function(MediaItem) onSelection;
  final bool modeSelection;
  final bool Function(MediaItem) selectionne;

  const MediaGrid({
    super.key,
    required this.items,
    required this.usages,
    required this.onAffecter,
    required this.onSupprimer,
    required this.onApercu,
    required this.onSelection,
    required this.modeSelection,
    this.selectionne = _jamais,
  });

  static bool _jamais(MediaItem _) => false;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 168,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final m = items[i];
          return MediaTile(
            key: ValueKey(m.cle),
            item: m,
            usages: usages(m),
            selectionne: selectionne(m),
            onAffecter: () => onAffecter(m),
            onSupprimer:
                onSupprimer == null ? null : () => onSupprimer!(m),
            onApercu: () => onApercu(m),
            onSelection: modeSelection ? () => onSelection(m) : null,
          );
        },
      );
}
