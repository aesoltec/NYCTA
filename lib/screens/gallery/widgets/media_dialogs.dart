import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';
import 'media_thumb.dart';

/// Boîte de confirmation de suppression DÉFINITIVE d'une image.
///
/// Isolée de l'écran (règle « widgets < 200 lignes ») : elle ne fait que
/// décrire le dialogue, l'appelant décide et exécute.
Future<bool> confirmerSuppressionMedia(
    BuildContext context, MediaItem item, List<MediaUsage> usages) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer définitivement ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("L'image sera effacée du stockage local ET du cloud. "
              'Cette action est irréversible.'),
          if (usages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Rattachée à :', style: Theme.of(ctx).textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final u in usages.take(6))
              Text('• ${u.libelleAffiche}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            if (usages.length > 6) Text('… et ${usages.length - 6} autre(s)'),
            const SizedBox(height: 8),
            const Text('Elle sera détachée de tous ces éléments.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Confirmation d'une suppression en LOT.
///
/// Une seule fenêtre pour N images : le détail affiche le nombre TOTAL
/// de rattachements, pas la liste complète — sinon 30 images
/// produiraient un dialogue illisible.
Future<bool> confirmerSuppressionLot(
  BuildContext context,
  List<MediaItem> items,
  List<MediaUsage> Function(MediaItem) usages,
) async {
  var totalRefs = 0;
  for (final m in items) {
    totalRefs += usages(m).length;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Supprimer ${items.length} image(s) ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elles seront effacées du stockage local ET du cloud. '
            'Action irréversible.',
          ),
          if (totalRefs > 0) ...[
            const SizedBox(height: 10),
            Text('Détachées de $totalRefs entité(s) au total.',
                style: Theme.of(ctx).textTheme.labelLarge),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Supprimer ${items.length}'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Plein écran d'aperçu (zoom au pincement) d'une image de la galerie.
void ouvrirApercuMedia(BuildContext context, MediaItem item) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: MediaThumb(item.apercu,
              taille: 320, borderRadius: BorderRadius.zero),
        ),
      ),
    ),
  ));
}
