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
