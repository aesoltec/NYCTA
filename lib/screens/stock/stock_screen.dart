import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/produit.dart';
import '../../services/media_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final produits = store.produitsBoutique;
    final peutVendre = store.peut(Permission.vendre);
    final peutGererStock = store.peut(Permission.gererStock);

    return Scaffold(
      body: produits.isEmpty
          ? const EmptyView(
              icon: Icons.inventory_2_outlined,
              message: 'Aucun produit dans cette boutique',
              hint: 'Ajoutez votre premier produit avec le bouton +')
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 12, 16, peutGererStock ? 90 : 24),
              itemCount: produits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LigneProduit(
                  produit: produits[i],
                  peutVendre: peutVendre,
                  peutGererStock: peutGererStock),
            ),
      floatingActionButton: peutGererStock
          ? FloatingActionButton.extended(
              onPressed: () => _formProduit(context, store, null),
              icon: const Icon(Icons.add),
              label: const Text('Produit'),
            )
          : null,
    );
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
}

class _LigneProduit extends StatelessWidget {
  final Produit produit;
  final bool peutVendre;
  final bool peutGererStock;
  const _LigneProduit({
    required this.produit, required this.peutVendre, required this.peutGererStock,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        // Photo produit (fallback : icône catégorie / alerte)
        leading: AppImage(
          produit.imagePath,
          size: 44,
          fallbackIcon: produit.alerte
              ? Icons.warning_amber_rounded
              : Icons.category_outlined,
          fallbackColor: produit.alerte
              ? const Color(0xFFD97706)
              : const Color(0xFF3D6FB4),
          fallbackBackground: produit.alerte
              ? const Color(0xFFFFE9D6)
              : const Color(0xFFE8F0FB),
        ),
        title: Text(produit.libelle,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(produit.categorie,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(produit.prixVente, style: const TextStyle(fontSize: 14)),
            Text('Stock : ${produit.stock}${produit.alerte ? ' ⚠️' : ''}',
                style: TextStyle(
                    fontSize: 12,
                    color: produit.alerte ? const Color(0xFFD97706) : Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        // Tap = modifier la fiche (admin/gérant/vendeur)
        onTap: peutGererStock ? () => StockScreen.formProduit(context, store, produit) : null,
        onLongPress: peutVendre && produit.stock > 0
            ? () => _vendre(context, store)
            : null,
      ),
    );
  }

  Future<void> _vendre(BuildContext context, Store store) async {
    var date = DateTime.now();
    final qte = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '1');
        return StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
          scrollable: true,
          title: Text('Vendre « ${produit.libelle} »'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité'),
            ),
            const SizedBox(height: 12),
            ChampDate(
              valeur: date,
              onChanged: (d) => setDlg(() => date = d),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0),
              child: const Text('Valider'),
            ),
          ],
        ));
      },
    );
    if (qte == null || qte <= 0) return;
    try {
      await store.vendreProduit(produit, qte, date: date);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $qte× ${produit.libelle} vendu(s)')));
      }
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ ${e.message}')));
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
  String? _imagePath;
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
    _imagePath = p?.imagePath;
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
        Row(children: [
          AppImage(_imagePath, size: 64, borderRadius: BorderRadius.circular(14)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galerie'),
                onPressed: () async {
                  final p = await MediaService.pickImage();
                  if (p != null) setState(() => _imagePath = p);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Photo'),
                onPressed: () async {
                  final p = await MediaService.pickImage(camera: true);
                  if (p != null) setState(() => _imagePath = p);
                },
              ),
              if ((_imagePath ?? '').isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Retirer'),
                  onPressed: () => setState(() => _imagePath = null),
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
            if (widget.produit != null) ...[
              const SizedBox(height: 8),
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
    if (confirme != true || !mounted) return;
    setState(() => _sauvegardeEnCours = true);
    // Capturés AVANT l'await : usage après trou async interdit par
    // use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final erreur = await store.supprimerProduit(p.id, forcerArchive: true);
    if (!mounted) return;
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
        imagePath: (_imagePath ?? '').isEmpty ? null : _imagePath,
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
