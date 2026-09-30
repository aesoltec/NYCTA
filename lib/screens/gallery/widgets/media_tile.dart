import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';
import 'media_thumb.dart';

/// Tuile de la galerie : vignette, état d'usage, et actions.
///
/// La suppression définitive n'est proposée qu'aux rôles autorisés
/// (c'est l'écran qui filtre, pas ce widget) : la tuile affiche alors la
/// poubelle, sinon elle montre le nombre d'utilisateurs de l'image.
class MediaTile extends StatelessWidget {
  final MediaItem item;
  final List<MediaUsage> usages;
  final VoidCallback? onAffecter;
  final VoidCallback? onSupprimer;
  final VoidCallback? onApercu;
  final bool selectionne;
  final VoidCallback? onSelection;

  const MediaTile({
    super.key,
    required this.item,
    required this.usages,
    this.onAffecter,
    this.onSupprimer,
    this.onApercu,
    this.selectionne = false,
    this.onSelection,
  });

  @override
  Widget build(BuildContext context) {
    final affichee = usages.isNotEmpty;
    return Material(
      color: selectionne
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelection ?? onApercu,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'galerie_${item.cle}', child: MediaThumb(item.apercu)),
                  if (selectionne)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  if (affichee)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _Puce(
                        texte: usages.length == 1
                            ? usages.first.libelle
                            : '${usages.length} entités',
                        icone: Icons.link_rounded,
                      ),
                    ),
                ],
              ),
            ),
            // Actions : Wrap + ellipsis => jamais de débordement, même à
            // 320 px avec un libellé de produit long.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.seulementLocale ? 'Locale' : 'Cloud',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (onAffecter != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Affecter à un produit ou un article',
                      icon: const Icon(Icons.link_rounded, size: 20),
                      onPressed: onAffecter,
                    ),
                  if (onSupprimer != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Supprimer définitivement',
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      onPressed: onSupprimer,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  final String texte;
  final IconData icone;
  const _Puce({required this.texte, required this.icone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
      );
}
