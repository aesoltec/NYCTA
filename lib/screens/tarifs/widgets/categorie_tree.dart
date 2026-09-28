import 'package:flutter/material.dart';

/// Arbre des catégories du catalogue (panneau latéral) :
/// compteur d'articles par catégorie, clic → filtre la grille.
/// « Toutes » réinitialise le filtre.
class CategorieTree extends StatelessWidget {
  final Map<String, int> compteurs;
  final String selection;
  final ValueChanged<String> onSelection;

  const CategorieTree({
    super.key,
    required this.compteurs,
    required this.selection,
    required this.onSelection,
  });

  @override
  Widget build(BuildContext context) {
    final cats = compteurs.keys.toList()..sort();
    final total = compteurs.values.fold(0, (s, n) => s + n);
    return ListView(children: [
      _tuile(context, 'Toutes', total, selection.isEmpty),
      const Divider(height: 8),
      for (final c in cats)
        _tuile(context, c, compteurs[c] ?? 0, selection == c),
    ]);
  }

  Widget _tuile(
      BuildContext context, String nom, int n, bool actif) =>
      ListTile(
        dense: true,
        selected: actif,
        selectedTileColor:
            Theme.of(context).colorScheme.primaryContainer,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: const Icon(Icons.folder_outlined, size: 20),
        title: Text(nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13)),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$n',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        onTap: () => onSelection(nom == 'Toutes' ? '' : nom),
      );
}
