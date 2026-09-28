import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/tarif.dart';
import '../../services/media_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/filtre_panel.dart';
import 'widgets/categorie_tree.dart';
import 'widgets/tarif_card.dart';
import 'widgets/tarif_detail_screen.dart';

/// Tarifs & catalogue : articles vendus AVEC prix, y compris hors stock.
/// Accès lecture : tous les rôles (utile aux ventes) ; gestion : admin/gérant.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key});
  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  // Refonte UX e-commerce : grille + arbre catégories (drawer mobile,
  // panneau latéral en large) + recherche + prix min-max + tri.
  Map<String, dynamic> _filtres = const {'tri': 'nom_az'};

  List<Tarif> _filtrer(List<Tarif> base) {
    var tarifs = base;
    final cat = (_filtres['cat'] as String?) ?? '';
    if (cat.isNotEmpty) {
      tarifs = tarifs.where((t) => t.categorie == cat).toList();
    }
    final min =
        double.tryParse((_filtres['prix_min'] as String?) ?? '');
    final max =
        double.tryParse((_filtres['prix_max'] as String?) ?? '');
    if (min != null) {
      tarifs = tarifs.where((t) => t.prix >= min).toList();
    }
    if (max != null) {
      tarifs = tarifs.where((t) => t.prix <= max).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      tarifs = tarifs
          .where((t) =>
              t.libelle.toLowerCase().contains(rech) ||
              t.description.toLowerCase().contains(rech))
          .toList();
    }
    switch ((_filtres['tri'] as String?) ?? 'nom_az') {
      case 'nom_za':
        tarifs.sort((a, b) => b.libelle.compareTo(a.libelle));
      case 'prix_asc':
        tarifs.sort((a, b) => a.prix.compareTo(b.prix));
      case 'prix_desc':
        tarifs.sort((a, b) => b.prix.compareTo(a.prix));
      case 'date_desc':
        tarifs.sort((a, b) => (b.dateAjout ?? DateTime(2000))
            .compareTo(a.dateAjout ?? DateTime(2000)));
      case 'date_asc':
        tarifs.sort((a, b) => (a.dateAjout ?? DateTime(2000))
            .compareTo(b.dateAjout ?? DateTime(2000)));
      default:
        tarifs.sort((a, b) => a.libelle.compareTo(b.libelle));
    }
    return tarifs;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutGerer = store.role == Role.admin || store.role == Role.gerant;
    final compteurs = <String, int>{};
    for (final t in store.tarifsActifs) {
      final c = t.categorie.trim().isEmpty ? 'Général' : t.categorie.trim();
      compteurs[c] = (compteurs[c] ?? 0) + 1;
    }
    final categories = compteurs.keys.toList()..sort();
    final catSel = (_filtres['cat'] as String?) ?? '';
    final tarifs = _filtrer(store.tarifsActifs
        .where((t) =>
            catSel.isEmpty || t.categorie == catSel)
        .toList());
    final arbre = CategorieTree(
      compteurs: compteurs,
      selection: catSel,
      onSelection: (c) => setState(() => _filtres = {
            ..._filtres,
            'cat': c,
          }),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifs & catalogue')),
      drawer: MediaQuery.sizeOf(context).width < 700
          ? Drawer(child: SafeArea(child: arbre))
          : null,
      body: Row(children: [
        if (MediaQuery.sizeOf(context).width >= 700)
          SizedBox(width: 240, child: Card(child: arbre)),
        Expanded(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FiltrePanel(
                filtres: [
                  const FiltreConfig(
                      cle: 'q',
                      kind: FiltreKind.recherche,
                      label: 'Rechercher un article…'),
                  FiltreConfig(
                      cle: 'cat',
                      kind: FiltreKind.dropdown,
                      label: 'Catégorie',
                      options: [
                        for (final c in categories) (c, c),
                      ]),
                  const FiltreConfig(
                      cle: 'prix',
                      kind: FiltreKind.minMax,
                      label: 'Prix (min-max)'),
                  const FiltreConfig(
                      cle: 'tri',
                      kind: FiltreKind.dropdown,
                      label: 'Tri',
                      options: [
                        ('nom_az', 'Libellé A→Z'),
                        ('nom_za', 'Libellé Z→A'),
                        ('prix_asc', 'Prix ↑'),
                        ('prix_desc', 'Prix ↓'),
                        ('date_desc', 'Récents d\u2019abord'),
                        ('date_asc', 'Anciens d\u2019abord'),
                      ]),
                ],
                valeurs: _filtres,
                onFiltreChange: (m) => setState(() => _filtres = m),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: tarifs.isEmpty
                  ? const Center(
                      child: Text('Aucun article (filtre sans résultat)',
                          style: TextStyle(color: Colors.grey)))
                  : LayoutBuilder(builder: (ctx, contraintes) {
                      final colonnes =
                          contraintes.maxWidth >= 1100
                              ? 4
                              : contraintes.maxWidth >= 700
                                  ? 3
                                  : 2;
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                            16, 8, 16, peutGerer ? 90 : 24),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: colonnes,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 340,
                        ),
                        itemCount: tarifs.length,
                        itemBuilder: (_, i) {
                          final t = tarifs[i];
                          return TarifCard(
                            tarif: t,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => TarifDetailScreen(
                                        tarifId: t.id))),
                            onUtiliser: () =>
                                Navigator.of(context).pop(t.id),
                            onMenu: (a) => _menu(
                                context, store, t, a, peutGerer),
                          );
                        },
                      );
                    }),
            ),
          ]),
        ),
      ]),
      floatingActionButton: peutGerer
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, store, null),
              icon: const Icon(Icons.add),
              label: const Text('Article'),
            )
          : null,
    );
  }

  Future<void> _menu(BuildContext context, Store store, Tarif t,
      String action, bool peutGerer) async {
    switch (action) {
      case 'modifier':
        if (peutGerer && context.mounted) _form(context, store, t);
      case 'desactiver':
        if (peutGerer && context.mounted) {
          await store.supprimerTarif(t.id);
        }
      case 'partager':
        await SharePlus.instance.share(ShareParams(
            text:
                '${t.libelle} — ${t.prix.toStringAsFixed(0)} F (${store.profile.devise})'));
    }
  }

  void _form(BuildContext context, Store store, Tarif? existant) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormArticle(store: store, existant: existant),
      ),
    );
  }
}

/// Formulaire article (points 35-36) : catégorie CONNECTÉE au module
/// Catégories (suggestions + saisie manuelle + création auto) et
/// galerie multi-images (max 05, optionnelle).
class _FormArticle extends StatefulWidget {
  final Store store;
  final Tarif? existant;
  const _FormArticle({required this.store, this.existant});

  @override
  State<_FormArticle> createState() => _FormArticleState();
}

class _FormArticleState extends State<_FormArticle> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _libelle, _prix, _desc;
  TextEditingController? _catCtrl;
  final List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _libelle = TextEditingController(text: e?.libelle ?? '');
    _prix = TextEditingController(
        text: e == null ? '' : e.prix.toStringAsFixed(0));
    _desc = TextEditingController(text: e?.description ?? '');
    if (e != null) _images.addAll(e.images.take(Tarif.maxImages));
  }

  @override
  void dispose() {
    _libelle.dispose();
    _prix.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// Catégories proposées : module Catégories ∪ catalogue existant.
  List<String> _options() {
    final set = <String>{
      for (final c in widget.store.catsProduit) c.trim(),
      for (final t in widget.store.catalogue)
        if (t.categorie.trim().isNotEmpty) t.categorie.trim(),
    }..remove('');
    final liste = set.toList()..sort();
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final existant = widget.existant;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(existant == null ? 'Nouvel article au tarif' : 'Modifier l\'article',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('Pour les produits/services vendus sans suivi de stock.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Form(
          key: _key,
          child: Column(children: [
            TextFormField(
                controller: _libelle,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Libellé'),
                validator: (v) => V.texte(v, 2, 'Libellé')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _prix,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Prix de vente (${store.profile.devise})'),
                validator: (v) => V.prix(v, label: 'Prix')),
            const SizedBox(height: 12),
            // Catégorie connectée : suggestions (insensible casse +
            // accents) ou saisie libre → création auto si absente.
            Autocomplete<String>(
              initialValue: TextEditingValue(
                  text: existant?.categorie ?? 'Général'),
              optionsBuilder: (v) {
                final q = Store.sansAccents(v.text.trim().toLowerCase());
                if (q.isEmpty) return _options();
                return _options().where((o) => Store.sansAccents(
                    o.toLowerCase()).contains(q));
              },
              fieldViewBuilder:
                  (ctx, ctrl, focus, onSubmit) {
                _catCtrl = ctrl;
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      helperText:
                          'Choisir ou saisir — créée si absente',
                      prefixIcon:
                          Icon(Icons.category_outlined)),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optionnel)')),
            const SizedBox(height: 12),
            // Galerie (max 05, optionnelle) : ajout, aperçu, retrait.
            if (_images.isNotEmpty)
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(children: [
                    AppImage(_images[i],
                        size: 68,
                        borderRadius:
                            BorderRadius.circular(12)),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            if (_images.isNotEmpty) const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined,
                        size: 18),
                    label: Text(
                        'Images (${_images.length}/${Tarif.maxImages})'),
                    onPressed: _images.length >= Tarif.maxImages
                        ? null
                        : () async {
                            final ajouts =
                                await MediaService.pickImages(
                                    max: Tarif.maxImages -
                                        _images.length);
                            if (ajouts.isNotEmpty) {
                              setState(
                                  () => _images.addAll(ajouts));
                            }
                          },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined,
                        size: 18),
                    label: const Text('Photo'),
                    onPressed: _images.length >= Tarif.maxImages
                        ? null
                        : () async {
                            final p =
                                await MediaService.pickImage(
                                    camera: true);
                            if (p != null) {
                              setState(() => _images.add(p));
                            }
                          },
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () => _enregistrer(context, store),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _enregistrer(BuildContext context, Store store) async {
    if (!_key.currentState!.validate()) return;
    final saisie =
        (_catCtrl?.text ?? '').trim().isEmpty ? 'Général' : _catCtrl!.text.trim();
    // Orthographe canonique si la catégorie existe (casse/accents).
    final canonique = _options()
        .where((o) => Store.memeCategorie(o, saisie))
        .firstOrNull;
    final categorie = canonique ?? saisie;
    final t = Tarif(
      id: widget.existant?.id ??
          'tr_${DateTime.now().millisecondsSinceEpoch}',
      libelle: _libelle.text.trim(),
      prix: V.prixValue(_prix.text),
      categorie: categorie,
      description: _desc.text.trim(),
      images: [..._images],
    );
    // TRANSACTIONNEL : la catégorie n'est créée qu'APRÈS le succès
    // de l'article — jamais d'orpheline (point 35).
    final e = widget.existant == null
        ? await store.ajouterTarif(t)
        : await store.majTarif(t);
    if (!context.mounted) return;
    if (e != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ $e')));
      return;
    }
    if (canonique == null &&
        saisie != 'Général' &&
        !_options().any((o) => Store.memeCategorie(o, saisie))) {
      final errCat =
          await store.ajouterCategorie(saisie, produit: true);
      if (!context.mounted) return;
      if (errCat != null && !errCat.contains('existe déjà')) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ $errCat')));
        return;
      }
    }
    if (context.mounted) Navigator.pop(context);
  }
}
