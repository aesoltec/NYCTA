import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/tarif.dart';
import '../../services/media_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/filtre_panel.dart';
import '../../widgets/money_text.dart';

/// Tarifs & catalogue : articles vendus AVEC prix, y compris hors stock.
/// Accès lecture : tous les rôles (utile aux ventes) ; gestion : admin/gérant.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key});
  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  // Filtres via FiltrePanel : recherche + catégorie (point 34).
  Map<String, dynamic> _filtres = const {};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutGerer = store.role == Role.admin || store.role == Role.gerant;
    final categories = {
      for (final t in store.catalogue)
        if (t.categorie.trim().isNotEmpty) t.categorie.trim(),
    }.toList()
      ..sort();
    var tarifs = store.tarifsActifs;
    final cat = (_filtres['cat'] as String?) ?? '';
    if (cat.isNotEmpty) {
      tarifs = tarifs.where((t) => t.categorie == cat).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      tarifs = tarifs
          .where((t) =>
              t.libelle.toLowerCase().contains(rech) ||
              t.description.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifs & catalogue')),
      body: Column(children: [
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
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, peutGerer ? 90 : 24),
                  itemCount: tarifs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: ListTile(
                      leading: MediaService.existe(
                              tarifs[i].images.firstOrNull)
                          ? AppImage(tarifs[i].images.first,
                              size: 40,
                              borderRadius:
                                  BorderRadius.circular(12))
                          : Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0FB),
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              child: const Icon(
                                  Icons.sell_outlined,
                                  size: 18,
                                  color: Color(0xFF3D6FB4)),
                            ),
                      title: Text(tarifs[i].libelle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${tarifs[i].categorie}${tarifs[i].description.isNotEmpty ? ' · ${tarifs[i].description}' : ''}${tarifs[i].images.isNotEmpty ? ' · 📷${tarifs[i].images.length}' : ''}',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        MoneyText(tarifs[i].prix, style: const TextStyle(fontSize: 14)),
                        if (peutGerer) ...[
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                              onPressed: () => _form(context, store, tarifs[i])),
                          IconButton(
                              icon: const Icon(Icons.delete_outline, size: 19,
                                  color: Colors.redAccent),
                              onPressed: () => store.supprimerTarif(tarifs[i].id)),
                        ],
                      ]),
                    ),
                  ),
                ),
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
