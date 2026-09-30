import 'package:flutter/material.dart';

/// Barre de filtres de la galerie : recherche + sélecteur de dossier.
///
/// Séparée de l'écran (règle « widgets < 200 lignes »). Le `Wrap` avec
/// libellés ellipsés garantit l'absence de débordement à 320 px comme à
/// 1024 px, quel que soit le nombre de dossiers.
class GalleryFilterBar extends StatelessWidget {
  final String recherche;
  final ValueChanged<String> onRecherche;
  final List<String> dossiers;
  final String? filtre;
  final ValueChanged<String?> onFiltre;
  final int total;

  const GalleryFilterBar({
    super.key,
    required this.recherche,
    required this.onRecherche,
    required this.dossiers,
    required this.filtre,
    required this.onFiltre,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un fichier…',
              ),
              onChanged: onRecherche,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in [null, ...dossiers])
                  ChoiceChip(
                    label: Text(d ?? 'Toutes'),
                    selected: filtre == d,
                    onSelected: (_) => onFiltre(d),
                  ),
                Chip(
                  label: Text('$total image(s)'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      );
}
