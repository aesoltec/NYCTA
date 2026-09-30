
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import 'widgets/gallery_actions.dart';
import 'widgets/gallery_app_bar.dart';
import 'widgets/gallery_batch_bar.dart';
import 'widgets/gallery_empty.dart';
import 'widgets/gallery_filter_bar.dart';
import 'widgets/media_dialogs.dart';
import 'widgets/media_grid.dart';

/// Galerie interne : la banque d'images de l'entreprise.
///
/// On y parcourt les images déjà présentes (bucket en source de vérité),
/// on en téléverse, on les affecte à un produit du stock ou à un article
/// du catalogue, et on les supprime définitivement — en unitaire ou en
/// lot. Suppression réservée à l'admin / au gérant ; l'écran reste
/// lisible par tous.
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

  /// Multi-sélection (suppression en lot) : ensemble des clés choisies.
  final Set<String> _selection = {};
  bool _modeBatch = false;

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
      // Une image supprimée ne doit pas rester cochée.
      _selection.removeWhere((cle) => !items.any((m) => m.cle == cle));
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

  /// Coche / décoche une image (mode lot).
  void _basculer(MediaItem m) => setState(() {
        if (!_selection.remove(m.cle)) _selection.add(m.cle);
      });

  void _toutSelectionner(List<MediaItem> visibles) =>
      setState(() => _selection.addAll(visibles.map((m) => m.cle)));

  /// Barre d'actions du mode lot : tout sélectionner, tout désélectionner,
  /// supprimer la sélection. Isolée de l'écran (< 200 lignes).
  Widget _barreBatch(List<MediaItem> visibles, bool peutSupprimer) =>
      GalleryBatchBar(
        selectionnees: _selection.length,
        totalVisible: visibles.length,
        onToutSelectionner: () => _toutSelectionner(visibles),
        onDeselectionner: () => setState(_selection.clear),
        onSupprimer:
            peutSupprimer ? () => _supprimerLot(visibles) : null,
      );

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final g = store.gallery;
    final peutSupprimer = _peutSupprimer(store);
    final visibles = _visibles;
    final dossiers = {for (final m in _items) m.dossier}.toList()..sort();

    return Scaffold(
      appBar: GalleryAppBar(
        modeBatch: _modeBatch,
        selectionnees: _selection.length,
        titre: widget.modeSelection ? 'Choisir une image' : 'Galerie',
        occupe: g.occupe,
        peutBatch: peutSupprimer && !widget.modeSelection,
        batchActif: _modeBatch,
        visibleNonVide: visibles.isNotEmpty,
        onQuitterBatch: () => setState(() {
          _modeBatch = false;
          _selection.clear();
        }),
        onBasculerBatch: () => setState(() {
          _modeBatch = !_modeBatch;
          if (!_modeBatch) _selection.clear();
        }),
        onAjouter: _uploader,
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
                          onAffecter: (m) => _affecter(m),
                          onSupprimer: peutSupprimer && !_modeBatch
                              ? _supprimer
                              : null,
                          onApercu: (m) => widget.modeSelection
                              ? Navigator.of(context).pop(m)
                              : ouvrirApercuMedia(context, m),
                          onSelection: _modeBatch
                              ? (m) => _basculer(m)
                              : (m) => Navigator.of(context).pop(m),
                          selectionne: (m) => _selection.contains(m.cle),
                          modeSelection:
                              widget.modeSelection || _modeBatch,
                        ),
            ),
            if (_modeBatch)
              _barreBatch(visibles, peutSupprimer),
          ],
        ),
      ),
    );
  }

  // ---------- Actions ----------

  /// Actions déléguées (le contrôleur est construit à chaque build avec
  /// le contexte courant : un `BuildContext` ne doit pas être stocké).
  GalleryActions _actions() => GalleryActions(
        context: context,
        gallery: context.read<Store>().gallery,
        onRafraichir: _rafraichir,
        onMessage: _message,
      );

  Future<void> _uploader() => _actions().televerser();
  Future<void> _affecter(MediaItem m) => _actions().affecter(m);
  Future<void> _supprimer(MediaItem m) => _actions().supprimer(m);

  /// Suppression en LOT : la sélection cochée, puis passage par le
  /// contrôleur (une confirmation, puis chaque image).
  Future<void> _supprimerLot(List<MediaItem> visibles) async {
    final choisies =
        visibles.where((m) => _selection.contains(m.cle)).toList();
    if (choisies.isEmpty) return;
    final ok = await _actions().supprimerLot(choisies);
    if (ok && mounted) setState(_selection.clear);
  }
}
