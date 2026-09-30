import 'package:flutter/material.dart';

/// Barre supérieure de la galerie : titre, sortie du mode lot, ajout.
///
/// Isolée de l'écran (règle « widgets < 200 lignes »). En mode lot, le
/// compte de sélection **remplace** le titre (au lieu de s'y ajouter) :
/// à 320 px, « 3 sélectionnée(s) » + titre ne tient pas.
class GalleryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool modeBatch;
  final int selectionnees;
  final String titre;
  final bool occupe;
  final bool peutBatch;
  final bool batchActif;
  final bool visibleNonVide;
  final VoidCallback onQuitterBatch;
  final VoidCallback onBasculerBatch;
  final VoidCallback onAjouter;

  const GalleryAppBar({
    super.key,
    required this.modeBatch,
    required this.selectionnees,
    required this.titre,
    required this.occupe,
    required this.peutBatch,
    required this.batchActif,
    required this.visibleNonVide,
    required this.onQuitterBatch,
    required this.onBasculerBatch,
    required this.onAjouter,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        title: Text(modeBatch ? '$selectionnees sélectionnée(s)' : titre),
        leading: modeBatch
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Quitter la sélection',
                onPressed: onQuitterBatch,
              )
            : null,
        actions: [
          if (occupe)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else ...[
            if (peutBatch)
              IconButton(
                tooltip: batchActif ? 'Terminer la sélection' : 'Sélection',
                icon: Icon(
                    batchActif ? Icons.done_all : Icons.checklist_rounded),
                onPressed: visibleNonVide ? onBasculerBatch : null,
              ),
            IconButton(
              tooltip: 'Ajouter des images',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: onAjouter,
            ),
          ],
        ],
      );
}
