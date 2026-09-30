import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/media_item.dart';
import '../../../data/store.dart';
import '../../../models/produit.dart';
import '../../../models/tarif.dart';

/// Feuille de choix de la cible d'une image : un produit du stock **ou** un
/// article du catalogue, avec recherche. Retourne l'identifiant choisi
/// (ou null si l'utilisateur annule).
///
/// La liste est plafonnée à 200 entrées : au-delà, la recherche prend le
/// relais (une liste de plusieurs milliers d'items dans une bottom sheet
/// ferait s'étrangler le frame, pas la base).
class CibleGallerySheet extends StatefulWidget {
  final String titre;
  final String action;
  final MediaItem item;
  const CibleGallerySheet({
    super.key,
    required this.titre,
    required this.action,
    required this.item,
  });

  @override
  State<CibleGallerySheet> createState() => _State();
}

class _State extends State<CibleGallerySheet> {
  String _q = '';
  int _onglet = 0; // 0 = produits, 1 = catalogue
  static const _plafond = 200;

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final q = _q.trim().toLowerCase();
    bool ok(String l) => q.isEmpty || l.toLowerCase().contains(q);
    final produits = store.produitsBoutique
        .where((p) => ok(p.libelle))
        .take(_plafond)
        .toList();
    final articles = store.catalogue
        .where((t) => ok(t.libelle) && t.actif)
        .take(_plafond)
        .toList();
    final dejaLa = _onglet == 0
        ? produits.any((p) => p.images.contains(widget.item.cle))
        : articles.any((t) => t.images.contains(widget.item.cle));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poignée + titre : le contenu est scrollable, jamais de
            // débordement vertical (clavier ouvert compris).
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher…',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0, label: Text('Stock'), icon: Icon(Icons.inventory_2)),
                ButtonSegment(
                    value: 1, label: Text('Catalogue'), icon: Icon(Icons.sell)),
              ],
              selected: {_onglet},
              onSelectionChanged: (s) => setState(() => _onglet = s.first),
            ),
            const SizedBox(height: 8),
            if (dejaLa)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Cette image est déjà sur l\'élément sélectionné.'),
              ),
            Flexible(
              child: _onglet == 0
                  ? _listeProduits(context, produits)
                  : _listeArticles(context, articles),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  /// Liste des produits du stock (cible `produit`).
  Widget _listeProduits(BuildContext context, List<Produit> produits) {
    if (produits.isEmpty) return const _Aucun();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: produits.length,
      itemBuilder: (_, i) {
        final p = produits[i];
        final deja = p.images.contains(widget.item.cle);
        return ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(p.libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Stock ${p.stock} · ${p.categorie}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: deja ? const Icon(Icons.check, size: 18) : null,
          onTap: () => Navigator.of(context).pop(_Cible('produit', p.id)),
        );
      },
    );
  }

  /// Liste des articles du catalogue (cible `tarif`).
  Widget _listeArticles(BuildContext context, List<Tarif> articles) {
    if (articles.isEmpty) return const _Aucun();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: articles.length,
      itemBuilder: (_, i) {
        final t = articles[i];
        final deja = t.images.contains(widget.item.cle);
        return ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(t.libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${t.categorie} · ${t.prix.toStringAsFixed(0)}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: deja ? const Icon(Icons.check, size: 18) : null,
          onTap: () => Navigator.of(context).pop(_Cible('tarif', t.id)),
        );
      },
    );
  }
}

class _Aucun extends StatelessWidget {
  const _Aucun();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Aucun résultat.'),
      );
}
class _Cible {
  final String type;
  final String id;
  const _Cible(this.type, this.id);
}

/// Ouvre la feuille et exécute [action] avec la cible choisie.
/// [action] reçoit (`'produit'|'tarif'`, `id`) et rend un message
/// d'erreur, ou null si l'affectation a réussi.
Future<String?> choisirCible(
  BuildContext context, {
  required String titre,
  required String action,
  required MediaItem item,
  required Future<String?> Function(String type, String id) action_,
}) async {
  final cible = await showModalBottomSheet<_Cible>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CibleGallerySheet(
        titre: titre, action: action, item: item),
  );
  if (cible == null) return null;
  return action_(cible.type, cible.id);
}
