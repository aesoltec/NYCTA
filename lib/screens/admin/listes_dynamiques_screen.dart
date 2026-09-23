import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';

/// Listes dynamiques du formulaire "Nouvelle opération" : opérateurs Mobile
/// Money, opérateurs Crédit communication, domaines de prestation, durées
/// de forfait hotspot. Ajouter/renommer/supprimer — même principe que
/// CategoriesScreen (produits/charges), sur 4 onglets au lieu de 2.
///
/// Avant l'introduction de cet écran (migration v1.7), ces 4 listes étaient
/// codées en dur dans lib/core/constants.dart : aucun formulaire ne
/// permettait de les modifier sans recompiler l'application.
class ListesDynamiquesScreen extends StatelessWidget {
  const ListesDynamiquesScreen({super.key});

  static const _onglets = [
    (type: 'operateur_momo', titre: 'Mobile Money', icone: Icons.phone_android_rounded),
    (type: 'operateur_credit', titre: 'Crédit', icone: Icons.sms_rounded),
    (type: 'domaine_prestation', titre: 'Domaines', icone: Icons.build_rounded),
    (type: 'duree_forfait', titre: 'Durées forfait', icone: Icons.wifi_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listes du formulaire de vente'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final o in _onglets) Tab(text: o.titre, icon: Icon(o.icone))],
          ),
        ),
        body: TabBarView(
          children: [for (final o in _onglets) _ListeDynamique(type: o.type, titre: o.titre)],
        ),
        floatingActionButton: Builder(builder: (context) {
          final controller = DefaultTabController.of(context);
          // AnimatedBuilder : DefaultTabController.of(context) ne reconstruit
          // ce widget que si l'INSTANCE du contrôleur change, pas quand son
          // .index change (changement d'onglet) — même piège que dans
          // CategoriesScreen, corrigé de la même façon ici.
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final o = _onglets[controller.index];
              return FloatingActionButton.extended(
                onPressed: () => _dialog(context, o.type, o.titre),
                icon: const Icon(Icons.add),
                label: Text('Ajouter (${o.titre})'),
              );
            },
          );
        }),
      ),
    );
  }

  static void _dialog(BuildContext context, String type, String titre,
      [String? existante]) {
    final ctrl = TextEditingController(text: existante ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(existante == null
            ? 'Nouvelle valeur — $titre'
            : 'Renommer « $existante »'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Valeur'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final store = context.read<Store>();
              final String? erreur;
              if (existante == null) {
                erreur = await store.ajouterValeurListe(type, ctrl.text);
              } else {
                erreur = await store
                    .renommerValeurListe(type, existante, ctrl.text);
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

class _ListeDynamique extends StatelessWidget {
  final String type;
  final String titre;
  const _ListeDynamique({required this.type, required this.titre});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final liste = switch (type) {
      'operateur_momo' => store.opsMobileMoney,
      'operateur_credit' => store.opsCredit,
      'domaine_prestation' => store.domainesPresta,
      'duree_forfait' => store.dureesForfaitListe,
      _ => const <String>[],
    };
    if (liste.isEmpty) {
      return const Center(
          child: Text('Aucune valeur', style: TextStyle(color: Colors.grey)));
    }
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
          leading: const Icon(Icons.label_outline, size: 20, color: Color(0xFF3D6FB4)),
          title: Text(liste[i],
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                onPressed: () => ListesDynamiquesScreen._dialog(
                    context, type, titre, liste[i])),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
              onPressed: () async {
                final erreur = await context
                    .read<Store>().supprimerValeurListe(type, liste[i]);
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
