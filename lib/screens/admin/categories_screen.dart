import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';

/// Catégories dynamiques : produits et charges — ajouter, renommer,
/// supprimer (avec garde-fou si utilisées). Utilisées partout dans l'app.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catégories'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Produits', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Charges', icon: Icon(Icons.receipt_outlined)),
          ]),
        ),
        body: const TabBarView(children: [
          _ListeCategories(produit: true),
          _ListeCategories(produit: false),
        ]),
        floatingActionButton: Builder(builder: (context) {
          final controller = DefaultTabController.of(context);
          // AnimatedBuilder : DefaultTabController.of(context) ne reconstruit
          // ce widget que si l'INSTANCE du contrôleur change, pas quand son
          // .index change (changement d'onglet). Sans ça, le bouton restait
          // bloqué sur "Catégorie produit" — y compris l'action déclenchée —
          // même une fois sur l'onglet Charges.
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final produit = controller.index == 0;
              return FloatingActionButton.extended(
                onPressed: () => _dialog(context, produit),
                icon: const Icon(Icons.add),
                label: Text(produit ? 'Catégorie produit' : 'Catégorie charge'),
              );
            },
          );
        }),
      ),
    );
  }

  static void _dialog(BuildContext context, bool produit, [String? existante]) {
    final ctrl = TextEditingController(text: existante ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(existante == null
            ? (produit ? 'Nouvelle catégorie produit' : 'Nouvelle catégorie de charge')
            : 'Renommer « $existante »'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final store = context.read<Store>();
              final String? erreur;
              if (existante == null) {
                erreur = await store.ajouterCategorie(ctrl.text, produit: produit);
              } else {
                erreur = await store
                    .renommerCategorie(existante, ctrl.text, produit: produit);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (erreur != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _ListeCategories extends StatelessWidget {
  final bool produit;
  const _ListeCategories({required this.produit});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final liste = produit ? store.catsProduit : store.catsCharge;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: liste.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: ListTile(
          leading: Icon(produit ? Icons.label_outline : Icons.receipt_long_outlined,
              size: 20, color: const Color(0xFF3D6FB4)),
          title: Text(liste[i],
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                onPressed: () => CategoriesScreen._dialog(context, produit, liste[i])),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
              onPressed: () async {
                final erreur = await context
                    .read<Store>().supprimerCategorie(liste[i], produit: produit);
                if (context.mounted && erreur != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}
