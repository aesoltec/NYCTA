import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../services/media_service.dart';
import 'widgets/cible_gallery_sheet.dart';
import 'widgets/gallery_empty.dart';
import 'widgets/gallery_filter_bar.dart';
import 'widgets/media_dialogs.dart';
import 'widgets/media_grid.dart';

/// Galerie interne : la banque d'images de l'entreprise.
///
/// Ouverte par la tuile du menu « Plus » et par le bouton « Parcourir »
/// du formulaire produit. On y parcourt les images déjà présentes, on en
/// téléverse (compression 1280 px / < 300 Ko), on les affecte à un
/// produit du stock ou à un article du catalogue, et on les supprime
/// définitivement (admin / gérant uniquement — l'écran est lisible par
/// tous, mais la poubelle n'apparaît qu'aux rôles autorisés, et une image
/// rattachée exige une confirmation explicite).
class GalleryScreen extends StatefulWidget {
  /// En modes sélection : on renvoie l'image choisie puis on pop (usage
  /// depuis le formulaire produit). Sinon, usage autonome.
  final bool modeSelection;

  const GalleryScreen({super.key, this.modeSelection = false});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<MediaItem> _items = const [];
  bool _chargement = true;
  String _q = '';
  String? _filtre; // null = toutes, sinon dossier

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final g = context.read<Store>().gallery;
    final items = await g.charger();
    if (!mounted) return;
    setState(() {
      _items = items;
      _chargement = false;
    });
    _message(g.succes ?? g.erreur);
    g.razMessages();
  }

  void _message(String? texte) {
    if (texte == null || texte.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texte)));
  }

  /// Réservé admin / gérant (policy RLS « media suppression » incluse).
  bool _peutSupprimer(Store store) =>
      store.role == Role.admin || store.role == Role.gerant;

  List<MediaItem> get _visibles {
    final q = _q.trim().toLowerCase();
    return _items.where((m) {
      if (_filtre != null && m.dossier != _filtre) return false;
      if (q.isEmpty) return true;
      return m.cle.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final g = store.gallery;
    final peutSupprimer = _peutSupprimer(store);
    final visibles = _visibles;
    final dossiers = {for (final m in _items) m.dossier}.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modeSelection ? 'Choisir une image' : 'Galerie'),
        actions: [
          if (g.occupe)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              tooltip: 'Ajouter des images',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _uploader,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            GalleryFilterBar(
              recherche: _q,
              onRecherche: (v) => setState(() => _q = v),
              dossiers: dossiers,
              filtre: _filtre,
              onFiltre: (v) => setState(() => _filtre = v),
              total: visibles.length,
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : visibles.isEmpty
                      ? GalleryEmpty(occupe: g.occupe, onAjouter: _uploader)
                      : MediaGrid(
                          items: visibles,
                          usages: g.usagesDe,
                          onAffecter: (m) => _affecter(context, m),
                          onSupprimer:
                              peutSupprimer ? (m) => _supprimer(context, m) : null,
                          onApercu: (m) => widget.modeSelection
                              ? Navigator.of(context).pop(m)
                              : ouvrirApercuMedia(context, m),
                          onSelection: (m) => Navigator.of(context).pop(m),
                          modeSelection: widget.modeSelection,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Actions ----------

  Future<void> _uploader() async {
    final chemins = await MediaService.pickImages(max: 10, entite: 'galerie');
    if (chemins.isEmpty || !mounted) return;
    final g = context.read<Store>().gallery;
    for (final c in chemins) {
      await g.televerser(File(c));
    }
    await _rafraichir();
  }

  Future<void> _affecter(BuildContext context, MediaItem m) async {
    final store = context.read<Store>();
    final g = store.gallery;
    final erreur = await choisirCible(
      context,
      titre: 'Affecter l\'image à…',
      action: 'Affecter',
      item: m,
      action_: (type, id) => type == 'produit'
          ? g.affecterProduit(id, m)
          : g.affecterTarif(id, m),
    );
    if (erreur != null) {
      _message(erreur);
      return;
    }
    await _rafraichir();
  }

  Future<void> _supprimer(BuildContext context, MediaItem m) async {
    final g = context.read<Store>().gallery;
    if (!await confirmerSuppressionMedia(context, m, g.usagesDe(m))) return;
    final err = await g.supprimerDefinitif(m);
    if (err != null) {
      _message(err);
      return;
    }
    await _rafraichir();
  }
}
