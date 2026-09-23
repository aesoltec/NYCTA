import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/tarif.dart';
import '../../widgets/money_text.dart';

/// Tarifs & catalogue : articles vendus AVEC prix, y compris hors stock.
/// Accès lecture : tous les rôles (utile aux ventes) ; gestion : admin/gérant.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key});
  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutGerer = store.role == Role.admin || store.role == Role.gerant;
    final tarifs = store.tarifsActifs
        .where((t) => t.libelle.toLowerCase().contains(_recherche.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifs & catalogue')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Rechercher un article…',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        Expanded(
          child: tarifs.isEmpty
              ? const Center(child: Text('Aucun article au tarif',
                  style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, peutGerer ? 90 : 24),
                  itemCount: tarifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FB),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.sell_outlined,
                            size: 18, color: Color(0xFF3D6FB4)),
                      ),
                      title: Text(tarifs[i].libelle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${tarifs[i].categorie}${tarifs[i].description.isNotEmpty ? ' · ${tarifs[i].description}' : ''}',
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
    final libelle = TextEditingController(text: existant?.libelle ?? '');
    final prix = TextEditingController(
        text: existant == null ? '' : existant.prix.toStringAsFixed(0));
    final cat = TextEditingController(text: existant?.categorie ?? 'Général');
    final desc = TextEditingController(text: existant?.description ?? '');
    final key = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Nouvel article au tarif' : 'Modifier l\'article',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Pour les produits/services vendus sans suivi de stock.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              TextFormField(
                  controller: libelle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                  validator: (v) => V.texte(v, 2, 'Libellé')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: prix,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Prix de vente (${store.profile.devise})'),
                  validator: (v) => V.prix(v, label: 'Prix')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: cat,
                  decoration: const InputDecoration(labelText: 'Catégorie')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: desc,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (optionnel)')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  final t = Tarif(
                    id: existant?.id ?? 'tr_${DateTime.now().millisecondsSinceEpoch}',
                    libelle: libelle.text.trim(),
                    prix: V.prixValue(prix.text),
                    categorie: cat.text.trim().isEmpty ? 'Général' : cat.text.trim(),
                    description: desc.text.trim(),
                  );
                  final e = existant == null
                      ? await store.ajouterTarif(t)
                      : await store.majTarif(t);
                  if (ctx.mounted) {
                    if (e != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('⚠️ $e')));
                    } else { Navigator.pop(ctx); }
                  }
                },
              )),
            ])),
          ]),
      ),
    );
  }
}
