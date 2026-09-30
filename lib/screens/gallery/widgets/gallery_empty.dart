import 'package:flutter/material.dart';

/// État vide de la galerie : aucune image (ou upload en cours).
///
/// Isolé de l'écran (règle « widgets < 200 lignes »). Le bouton reste
/// désactivé pendant un upload : pas de double envoi si l'utilisateur
/// appuie frénétiquement.
class GalleryEmpty extends StatelessWidget {
  final bool occupe;
  final VoidCallback onAjouter;

  const GalleryEmpty({
    super.key,
    required this.occupe,
    required this.onAjouter,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 46, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                occupe
                    ? 'Traitement en cours…'
                    : 'La galerie est vide.\n'
                        'Ajoutez des images ou parcourez le stock.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: occupe ? null : onAjouter,
                icon: const Icon(Icons.upload),
                label: const Text('Ajouter des images'),
              ),
            ],
          ),
        ),
      );
}
