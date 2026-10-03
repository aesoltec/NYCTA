import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../data/gallery/gallery_service.dart';
import '../../data/models/media_item.dart';
import '../../models/produit.dart';
import '../../services/media_service.dart';
import '../gallery/gallery_screen.dart';
import '../../widgets/app_image.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import 'mouvements_screen.dart';
import 'widgets/produit_detail_screen.dart';
import 'widgets/product_card.dart';
import 'widgets/product_list.dart';

import '../../services/export_service.dart';
import '../../widgets/filtre_panel.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();

  static void formProduit(
      BuildContext context, Store store, Produit? produit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // jamais caché par le clavier / la zone système
      showDragHandle: true,
      builder: (ctx) => Padding(
        // ctx (celui du builder), pas context (l'écran appelant) : sinon le
        // padding reste figé à sa valeur au moment de l'ouverture (clavier
        // fermé) et ne suit jamais l'apparition du clavier ensuite.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormProduit(produit: produit),
      ),
    );
  }

}

class _StockScreenState extends State<StockScreen> {
  // Refonte UX e-commerce : grille par défaut + bascule liste.
  // Filtres via FiltrePanel (réutilisé) : recherche as-you-type,
  // boutique, catégorie, statut stock (chips), prix min-max, tri.
  // Pas de filtre sous-catégorie : le modèle Produit n'en a pas
  // (non inventé — écart documenté).
  var _grille = true;
  Map<String, dynamic> _filtres = const {'alerte': 'tous', 'tri': 'nom_az'};

  List<Produit> _filtrer(Store store, List<Produit> base) {
    var produits = base;
    final bq = (_filtres['boutique'] as String?) ?? '';
    if (bq.isNotEmpty) {
      produits = produits.where((p) => p.boutiqueId == bq).toList();
    }
    final cat = (_filtres['cat'] as String?) ?? '';
    if (cat.isNotEmpty) {
      produits = produits.where((p) => p.categorie == cat).toList();
    }
    switch ((_filtres['alerte'] as String?) ?? 'tous') {
      case 'stock':
        produits = produits.where((p) => !p.enRupture).toList();
      case 'faible':
        produits = produits.where((p) => p.stockFaible).toList();
      case 'rupture':
        produits = produits.where((p) => p.enRupture).toList();
    }
    final min =
        double.tryParse((_filtres['prix_min'] as String?) ?? '');
    final max =
        double.tryParse((_filtres['prix_max'] as String?) ?? '');
    if (min != null) {
      produits = produits.where((p) => p.prixVente >= min).toList();
    }
    if (max != null) {
      produits = produits.where((p) => p.prixVente <= max).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      produits = produits
          .where((p) =>
              p.libelle.toLowerCase().contains(rech) ||
              p.categorie.toLowerCase().contains(rech))
          .toList();
    }
    switch ((_filtres['tri'] as String?) ?? 'nom_az') {
      case 'nom_za':
        produits.sort((a, b) => b.libelle.compareTo(a.libelle));
      case 'prix_asc':
        produits.sort((a, b) => a.prixVente.compareTo(b.prixVente));
      case 'prix_desc':
        produits.sort((a, b) => b.prixVente.compareTo(a.prixVente));
      case 'achat_asc':
        produits.sort((a, b) => a.prixAchat.compareTo(b.prixAchat));
      case 'achat_desc':
        produits.sort((a, b) => b.prixAchat.compareTo(a.prixAchat));
      case 'stock_asc':
        produits.sort((a, b) => a.stock.compareTo(b.stock));
      case 'stock_desc':
        produits.sort((a, b) => b.stock.compareTo(a.stock));
      case 'date_desc':
        produits.sort((a, b) => (b.dateAjout ?? DateTime(2000))
            .compareTo(a.dateAjout ?? DateTime(2000)));
      case 'date_asc':
        produits.sort((a, b) => (a.dateAjout ?? DateTime(2000))
            .compareTo(b.dateAjout ?? DateTime(2000)));
      default:
        produits.sort((a, b) => a.libelle.compareTo(b.libelle));
    }
    return produits;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutVendre = store.peut(Permission.vendre);
    // Quatre droits distincts : sans lui, l'UI confondait create,
    // modifier et retirer — et le vendeur pouvait creer un article.
    final peutCreer = store.peut(Permission.creerProduit);
    final peutModifier = store.peut(Permission.modifierProduit);
    final peutRetirer = store.peut(Permission.retirerProduit);
    // Actions proposees au menu contextuel : on n'affiche que ce que le
    // role a le droit de faire (avant : « Archiver » etait visible pour
    // tout le monde et refuse SEULEMENT apres selection).
    final actionsProduit = <String>[
      if (peutModifier) ...['modifier', 'ajuster'],
      if (peutRetirer) 'archiver',
      'partager',
    ];
    final cats = store.catsProduit;
    // Portée boutique : courante par défaut, globale au choix.
    final boutiqueId = (_filtres['boutique'] as String?) ?? '';
    final base = boutiqueId.isEmpty
        ? store.produitsBoutique
        : store.produits.where((p) => p.boutiqueId == boutiqueId).toList();
    final produits = _filtrer(store, base);

    return Scaffold(
      // AppBar seulement en navigation push (menu Plus) : en onglet,
      // l'AppBar globale du AppShell s'en charge déjà. Sans elle, aucun
      // titre ni bouton retour quand l'écran est poussé depuis le menu.
      appBar: (ModalRoute.of(context)?.canPop ?? false)
          ? AppBar(
              title: const Text('Stock'),
              actions: [
                IconButton(
                  tooltip: _grille ? 'Vue liste' : 'Vue grille',
                  icon: Icon(_grille
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined),
                  onPressed: () =>
                      setState(() => _grille = !_grille),
                ),
              ],
            )
          : null,
      // CustomScrollView : en-tête + filtres + cartes défilent ensemble
      // — aucun overflow même avec 6 filtres en 320px @2.0x.
      body: RefreshIndicator(
        onRefresh: store.rafraichir,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            // Valorisation + accès historique (mission 1, §1.3).
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Row(children: [
              const Icon(Icons.assessment_outlined,
                  size: 20, color: Color(0xFF3D6FB4)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Valorisation du stock',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                      MoneyText(store.valeurStock,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              // Bascule grille/liste (visible aussi en mode onglet).
              IconButton(
                tooltip: _grille ? 'Vue liste' : 'Vue grille',
                icon: Icon(_grille
                    ? Icons.view_list_outlined
                    : Icons.grid_view_outlined),
                onPressed: () =>
                    setState(() => _grille = !_grille),
              ),
              TextButton.icon(
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Mouvements'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MouvementsScreen())),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exporter la liste filtrée',
                icon: const Icon(Icons.ios_share_outlined, size: 20),
                onSelected: (f) => _exporter(context, store, produits, f),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'pdf', child: Text('PDF (partage)')),
                  PopupMenuItem(
                      value: 'xlsx', child: Text('Excel (.xlsx)')),
                  PopupMenuItem(
                      value: 'csv', child: Text('CSV (Excel)')),
                ],
              ),
            ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: FiltrePanel(
            filtres: [
              const FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher un produit…'),
              FiltreConfig(
                  cle: 'boutique',
                  kind: FiltreKind.dropdown,
                  label: 'Boutique',
                  options: [
                    ('', 'Boutique courante'),
                    for (final b in store.boutiques) (b.id, b.nom),
                  ]),
              FiltreConfig(
                  cle: 'cat',
                  kind: FiltreKind.dropdown,
                  label: 'Catégorie',
                  options: [
                    for (final c in cats) (c, c),
                  ]),
              const FiltreConfig(
                  cle: 'alerte',
                  kind: FiltreKind.chips,
                  label: 'Stock',
                  options: [
                    ('tous', 'Tous'),
                    ('stock', 'En stock'),
                    ('faible', 'Faible ⚠️'),
                    ('rupture', 'Rupture 🚫'),
                  ]),
              const FiltreConfig(
                  cle: 'prix',
                  kind: FiltreKind.minMax,
                  label: 'Prix vente (min-max)'),
              const FiltreConfig(
                  cle: 'tri',
                  kind: FiltreKind.dropdown,
                  label: 'Tri',
                  options: [
                    ('nom_az', 'Libellé A→Z'),
                    ('nom_za', 'Libellé Z→A'),
                    ('prix_asc', 'Prix vente ↑'),
                    ('prix_desc', 'Prix vente ↓'),
                    ('achat_asc', 'Prix achat ↑'),
                    ('achat_desc', 'Prix achat ↓'),
                    ('stock_asc', 'Stock ↑'),
                    ('stock_desc', 'Stock ↓'),
                    ('date_desc', 'Récents d\u2019abord'),
                    ('date_asc', 'Anciens d\u2019abord'),
                  ]),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          if (produits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: EmptyView(
                    icon: Icons.inventory_2_outlined,
                    message: _filtresActifs()
                        ? 'Aucun produit pour ces filtres'
                        : 'Aucun produit dans cette boutique',
                    hint:
                        'Ajoutez votre premier produit avec le bouton +'),
              ),
            )
          else if (_grille)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childCount: produits.length,
                itemBuilder: (_, i) => ProductCard(
                  produit: produits[i],
                  onTap: () => _ouvrirDetail(context, produits[i]),
                  onVendre: peutVendre
                      ? () => _vendreRapide(
                          context, store, produits[i])
                      : null,
                  onMenu: (a) => _menuProduit(context, store,
                      produits[i], a, peutModifier),
                  actions: actionsProduit,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverList.separated(
                itemCount: produits.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 6),
                itemBuilder: (_, i) => ProductListTile(
                  produit: produits[i],
                  onTap: () => _ouvrirDetail(context, produits[i]),
                  onVendre: peutVendre
                      ? () => _vendreRapide(
                          context, store, produits[i])
                      : null,
                  onMenu: (a) => _menuProduit(context, store,
                      produits[i], a, peutModifier),
                  actions: actionsProduit,
                ),
              ),
            ),
        ]),
      ),
      floatingActionButton: peutCreer
          ? FloatingActionButton.extended(
              onPressed: () => _formProduit(context, store, null),
              icon: const Icon(Icons.add),
              label: const Text('Produit'),
            )
          : null,
    );
  }

  /// Vrai si au moins un filtre restreint la vue (message vide adapté).
  bool _filtresActifs() {
    if (((_filtres['q'] as String?) ?? '').trim().isNotEmpty) return true;
    if (((_filtres['cat'] as String?) ?? '').isNotEmpty) return true;
    if (((_filtres['boutique'] as String?) ?? '').isNotEmpty) return true;
    if (((_filtres['alerte'] as String?) ?? 'tous') != 'tous') return true;
    if (((_filtres['prix_min'] as String?) ?? '').isNotEmpty) return true;
    if (((_filtres['prix_max'] as String?) ?? '').isNotEmpty) return true;
    return false;
  }

  void _ouvrirDetail(BuildContext context, Produit p) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProduitDetailScreen(produitId: p.id)));
  }

  /// Vente rapide (1 unité, date du jour) depuis la carte.
  Future<void> _vendreRapide(
      BuildContext context, Store store, Produit p) async {
    try {
      await store.vendreProduit(p, 1);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ 1× ${p.libelle} vendu')));
      }
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ ${e.message}')));
      }
    }
  }

  /// Menu contextuel carte (⋮) : Modifier, Ajuster, Archiver, Partager.
  Future<void> _menuProduit(BuildContext context, Store store,
      Produit p, String action, bool peutModifier) async {
    switch (action) {
      case 'modifier':
      case 'ajuster':
        if (!peutModifier) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('⚠️ Gestion du stock réservée')));
          }
          return;
        }
        if (context.mounted) formProduit(context, store, p);
      case 'archiver':
        if (store.role != Role.admin && store.role != Role.gerant) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('⚠️ Retrait réservé (admin, gérant)')));
          }
          return;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Archiver « ${p.libelle} » ?'),
            content: Text(p.stock > 0
                ? 'Il reste ${p.stock} unité(s).'
                : 'Le produit sera retiré de la liste.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Archiver')),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          final erreur =
              await store.supprimerProduit(p.id, forcerArchive: true);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(erreur == null
                    ? '« ${p.libelle} » archivé'
                    : '⚠️ $erreur')));
          }
        }
      case 'partager':
        await SharePlus.instance.share(ShareParams(
            text:
                '${p.libelle} — ${p.prixVente.toStringAsFixed(0)} F (${store.profile.devise})'));
    }
  }

  static void formProduit(BuildContext context, Store store, Produit? produit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // jamais caché par le clavier / la zone système
      showDragHandle: true,
      builder: (ctx) => Padding(
        // ctx (celui du builder), pas context (l'écran appelant) : sinon le
        // padding reste figé à sa valeur au moment de l'ouverture (clavier
        // fermé) et ne suit jamais l'apparition du clavier ensuite.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormProduit(produit: produit),
      ),
    );
  }

  void _formProduit(BuildContext context, Store store, Produit? p) =>
      formProduit(context, store, p);

  /// Lignes d'export de la liste filtrée (mêmes colonnes partout).
  static List<List<dynamic>> _lignesExport(
      List<Produit> produits, String devise) => [
        for (final p in produits)
          [
            p.libelle,
            p.categorie,
            p.prixAchat,
            p.prixVente,
            p.stock,
            p.seuil,
            p.stock * p.prixAchat,
            devise,
          ],
      ];

  Future<void> _exporter(BuildContext context, Store store,
      List<Produit> produits, String format) async {
    const entetes = [
      'Produit', 'Catégorie', 'Prix achat', 'Prix vente', 'Stock',
      'Seuil', 'Valorisation', 'Devise'
    ];
    final lignes = _lignesExport(produits, store.profile.devise);
    final total =
        produits.fold(0.0, (s, p) => s + p.stock * p.prixAchat);
    final nom =
        'stock_${store.boutiqueCourante.nom.replaceAll(' ', '_')}_${produits.length}articles';
    final titre = 'Stock — ${store.boutiqueCourante.nom}';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: titre,
              sousTitre:
                  '${produits.length} article(s) · Valorisation : ${total.toStringAsFixed(0)} ${store.profile.devise}',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Stock', entetes, lignes);
        default:
          await ExportService.partagerCsv(nom, entetes, lignes);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Export impossible')));
      }
    }
  }
}

class _FormProduit extends StatefulWidget {
  final Produit? produit; // null = création, sinon modification
  const _FormProduit({this.produit});

  @override
  State<_FormProduit> createState() => _FormProduitState();
}

class _FormProduitState extends State<_FormProduit> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelle, _pa, _pv, _stock, _seuil;
  late String _categorie;
  // Galerie (max 05) : _imagePath historique = première image.
  final List<String> _images = [];
  String? get _imagePath => _images.isEmpty ? null : _images.first;
  bool _sauvegardeEnCours = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    _libelle = TextEditingController(text: p?.libelle ?? '');
    _pa = TextEditingController(text: p == null ? '' : p.prixAchat.toStringAsFixed(0));
    _pv = TextEditingController(text: p == null ? '' : p.prixVente.toStringAsFixed(0));
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    // Seuil FACULTATIF : vide = 0 (alerte uniquement à la rupture).
    // Avant, le champ exigeait une valeur et son validateur bloquait la
    // fiche — toute correction repartait de zéro et favorisait les doublons.
    _seuil = TextEditingController(text: p == null ? '' : '${p.seuil}');
    _categorie = p?.categorie ?? ''; // ajusté dans build selon la liste dynamique
    if (p != null) {
      // Fusionne l'ancienne photo unique + la galerie (dédupliquées).
      final vus = <String>{};
      for (final u in [p.imagePath, ...p.images]) {
        if (u != null && u.isNotEmpty && vus.add(u)) {
          _images.add(u);
        }
        if (_images.length >= Produit.maxImages) break;
      }
    }
  }

  @override
  void dispose() {
    _libelle.dispose(); _pa.dispose(); _pv.dispose();
    _stock.dispose(); _seuil.dispose();
    super.dispose();
  }

  String? _positif(String? v, {bool strict = true}) => strict
      ? V.prix(v)
      : V.entier(v, min: 0);

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final cats = store.catsProduit;
    if (_categorie.isEmpty || !cats.contains(_categorie)) {
      _categorie = cats.isNotEmpty ? cats.first : 'Autre';
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(widget.produit == null ? 'Nouveau produit' : 'Modifier le produit',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        // Galerie (max 05, optionnelle) : ajout, aperçu, ordre (tap =
        // photo principale), suppression. Stockée dans Supabase Storage
        // (bucket « produits ») + colonne JSON — survit au redémarrage.
        if (_images.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(children: [
                GestureDetector(
                  onTap: () => setState(() {
                    final u = _images.removeAt(i);
                    _images.insert(0, u);
                  }),
                  child: AppImage(_images[i],
                      size: 68,
                      borderRadius: BorderRadius.circular(12)),
                ),
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
                if (i == 0)
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: Icon(Icons.star_rounded,
                        size: 16, color: Colors.amber),
                  ),
              ]),
            ),
          ),
        if (_images.isNotEmpty) const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                    'Galerie (${_images.length}/${Produit.maxImages})'),
                onPressed: _images.length >= Produit.maxImages
                    ? null
                    : () async {
                        final ajouts =
                            await MediaService.pickImages(
                                max: Produit.maxImages -
                                    _images.length);
                        if (ajouts.isNotEmpty) {
                          setState(() => _images.addAll(ajouts));
                        }
                      },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.collections_outlined, size: 18),
                label: const Text('Parcourir'),
                onPressed: _images.length >= Produit.maxImages
                    ? null
                    : () async {
                        final choisi = await Navigator.of(context).push<
                            MediaItem>(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const GalleryScreen(modeSelection: true)),
                        );
                        if (choisi == null) return;
                        // On stocke la VALEUR STOCKABLE (chemin local si
                        // disponible, sinon URL), jamais `choisi.cle` qui
                        // n'est qu'un nom de fichier : un nom seul ne
                        // s'affiche pas (AppImage teste existsSync) et ne
                        // peut pas etre televerse. Le doublon se detecte
                        // par NOM de fichier, pas par egalite de chaine.
                        if (_images.any((c) => GalleryService.meme(choisi, c))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Deja dans la galerie')));
                          return;
                        }
                        if (_images.length >= Produit.maxImages) return;
                        setState(() => _images
                            .add(GalleryService.valeurStockable(choisi)));
                      },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Photo'),
                onPressed: () async {
                  final p = await MediaService.pickImage(camera: true);
                  if (p != null &&
                      _images.length < Produit.maxImages) {
                    setState(() => _images.add(p));
                  }
                },
              ),
              if (_images.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tout retirer'),
                  onPressed: () =>
                      setState(() => _images.clear()),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _libelle,
              decoration: const InputDecoration(labelText: 'Libellé'),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Libellé requis (2 car. min.)' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categorie,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [for (final c in cats)
                  DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _categorie = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _pa,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix achat'),
                  validator: (v) => _positif(v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pv,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix vente'),
                  validator: (v) => _positif(v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité en stock'),
                  validator: (v) => V.entier(v, min: 0, label: 'Stock'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Seuil d'alerte FACULTATIF : vide = 0 (alerte à la rupture).
                child: TextFormField(
                  controller: _seuil,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Seuil d'alerte (optionnel)",
                      helperText: 'Vide = alerte à la rupture'),
                  validator: (v) => V.entierFacultatif(v, min: 0, label: 'Seuil'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sauvegardeEnCours ? null : _sauvegarder,
                child: Text(_sauvegardeEnCours
                    ? 'Enregistrement…'
                    : (widget.produit == null
                        ? 'Ajouter au stock'
                        : 'Enregistrer les modifications')),
              ),
            ),
            // Retrait réservé admin/gérant (mission §2.6) : un vendeur
            // peut créer/modifier/vendre mais jamais retirer un article.
            if (widget.produit != null &&
                (store.role == Role.admin ||
                    store.role == Role.gerant)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 19),
                  label: Text(
                      'Ajuster le stock (actuel : ${widget.produit!.stock})'),
                  onPressed: _sauvegardeEnCours
                      ? null
                      : () => _ajuster(context, store),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Historique de ce produit'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MouvementsScreen(
                            produitId: widget.produit!.id))),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline,
                      size: 19, color: Colors.redAccent),
                  label: const Text('Retirer ce produit du stock',
                      style: TextStyle(color: Colors.redAccent)),
                  onPressed: _sauvegardeEnCours
                      ? null
                      : () => _confirmerSuppression(context, store),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Future<void> _ajuster(BuildContext context, Store store) async {
    final p = widget.produit!;
    final qteCtrl = TextEditingController(text: '${p.stock}');
    final motifCtrl = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Ajuster « ${p.libelle} »'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: qteCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Nouveau stock',
                  helperText:
                      'Correction, perte, casse, don, inventaire…'),
              validator: (v) => V.entier(v, min: 0, label: 'Stock'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: motifCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)'),
              validator: (v) => V.texte(v, 3, 'Motif'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Appliquer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final erreur = await store.ajusterStock(
        p.id, int.parse(qteCtrl.text.trim()), motifCtrl.text.trim());
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text(erreur == null
            ? '✅ Stock ajusté (mouvement tracé)'
            : '⚠️ $erreur')));
    if (erreur == null) Navigator.pop(context);
  }

  Future<void> _confirmerSuppression(BuildContext context, Store store) async {
    final p = widget.produit!;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « ${p.libelle} » ?'),
        content: Text(p.stock > 0
            ? 'Il reste ${p.stock} unité(s) en stock. Le produit sera retiré '
              'de la liste (conservé côté serveur pour l\'historique).'
            : 'Le produit sera retiré de la liste.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    setState(() => _sauvegardeEnCours = true);
    // Capturés AVANT l'await + garde context.mounted : usage après trou
    // async autorisé (use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final erreur = await store.supprimerProduit(p.id, forcerArchive: true);
    if (!context.mounted) return;
    setState(() => _sauvegardeEnCours = false);
    if (erreur != null) {
      messenger.showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
      return;
    }
    navigator.pop(context);
    messenger.showSnackBar(
        SnackBar(content: Text('« ${p.libelle} » retiré du stock')));
  }

  Future<void> _sauvegarder() async {
    final store = context.read<Store>();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sauvegardeEnCours = true);
    try {
      final pa = V.prixValue(_pa.text);
      final pv = V.prixValue(_pv.text);
      if (pv < pa) {
        // INCOHÉRENCE MÉTIER : vente à perte — jamais silencieuse.
        final confirme = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD97706)),
            title: const Text('Marge négative ⚠️'),
            content: Text(
                'Le prix de vente (${pv.toStringAsFixed(0)}) est '
                'inférieur au prix d\'achat (${pa.toStringAsFixed(0)}).\n\n'
                'Perte : ${(pa - pv).toStringAsFixed(0)} '
                '${store.profile.devise} par unité vendue.\n\n'
                'Vendre à perte est possible (liquidation) mais '
                'doit être un choix délibéré.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Corriger')),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Vendre à perte (confirmer)')),
            ],
          ),
        );
        if (confirme != true) return;
      }
      final seuil = V.entierOpt(_seuil.text, min: 0) ?? 0;
      final p = Produit(
        id: widget.produit?.id ?? 'nouveau',
        boutiqueId: widget.produit?.boutiqueId ?? store.boutiqueId,
        libelle: _libelle.text.trim(),
        categorie: _categorie,
        prixAchat: pa,
        prixVente: pv,
        stock: int.parse(_stock.text.trim()),
        seuil: seuil,
        imagePath: _imagePath,
        images: [..._images],
      );
      final String? erreur;
      if (widget.produit == null) {
        erreur = await store.ajouterProduit(p);
      } else {
        erreur = await store.majProduit(p);
      }
      if (!mounted) return;
      if (erreur != null) {
        // Doublon ou règle métier : on reste sur le formulaire, RIEN n'est
        // ajouté une seconde fois — l'utilisateur corrige puis re-soumet.
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.produit == null
              ? '✅ Produit ajouté (stock + catalogue)'
              : '✅ Modifications enregistrées')));
    } finally {
      if (mounted) setState(() => _sauvegardeEnCours = false);
    }
  }
}
