import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/fournisseur.dart';
import '../../services/export_service.dart';
import '../../widgets/filtre_panel.dart';

/// Fournisseurs : recherche (nom, téléphone), filtre spécialité, exports.
class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

class _FournisseursScreenState extends State<FournisseursScreen> {
  Map<String, dynamic> _filtres = const {};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    // Spécialités existantes (distinctes, non vides) pour le dropdown.
    final specialites = {
      for (final f in store.fournisseurs)
        if (f.specialite.trim().isNotEmpty) f.specialite.trim(),
    }.toList()
      ..sort();
    var liste = store.fournisseurs.toList();
    final spe = (_filtres['spe'] as String?) ?? '';
    if (spe.isNotEmpty) {
      liste = liste.where((f) => f.specialite.trim() == spe).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      liste = liste
          .where((f) =>
              f.nom.toLowerCase().contains(rech) ||
              f.telephone.toLowerCase().contains(rech) ||
              f.specialite.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter la vue filtrée',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, store, liste, f),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'pdf', child: Text('PDF (partage)')),
              PopupMenuItem(
                  value: 'xlsx', child: Text('Excel (.xlsx)')),
              PopupMenuItem(
                  value: 'csv', child: Text('CSV (Excel)')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FiltrePanel(
            filtres: [
              const FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher (nom, téléphone)…'),
              FiltreConfig(
                  cle: 'spe',
                  kind: FiltreKind.dropdown,
                  label: 'Spécialité',
                  options: [
                    for (final s in specialites) (s, s),
                  ]),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: liste.isEmpty
              ? const Center(
                  child: Text('Aucun fournisseur (filtre sans résultat)',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: liste.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = liste[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFF1E0),
                      child: Text(f.nom.isNotEmpty ? f.nom[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                    ),
                    title: Text(f.nom,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [f.specialite, f.telephone].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _form(context, store, f)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline, size: 19,
                              color: Colors.redAccent),
                          onPressed: () => store.supprimerFournisseur(f.id)),
                    ]),
                  ),
                );
              },
            ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store, null),
        icon: const Icon(Icons.add),
        label: const Text('Fournisseur'),
      ),
    );
  }

  Future<void> _exporter(BuildContext context, Store store,
      List<Fournisseur> liste, String format) async {
    const entetes = [
      'Nom', 'Spécialité', 'Téléphone', 'Email', 'Adresse', 'Notes'
    ];
    final lignes = [
      for (final f in liste)
        [
          f.nom,
          f.specialite,
          f.telephone,
          f.email,
          f.adresse,
          f.notes,
        ],
    ];
    final nom = 'fournisseurs_${liste.length}';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Fournisseurs',
              sousTitre: '${liste.length} fournisseur(s)',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Fournisseurs', entetes, lignes);
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

  void _form(BuildContext context, Store store, Fournisseur? existant) {
    final nom = TextEditingController(text: existant?.nom ?? '');
    final tel = TextEditingController(text: existant?.telephone ?? '');
    final mail = TextEditingController(text: existant?.email ?? '');
    final adr = TextEditingController(text: existant?.adresse ?? '');
    final spe = TextEditingController(text: existant?.specialite ?? '');
    final notes = TextEditingController(text: existant?.notes ?? '');
    final key = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              TextFormField(controller: nom, decoration: const InputDecoration(
                  labelText: 'Nom / entreprise', prefixIcon: Icon(Icons.business_outlined)),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis' : null),
              const SizedBox(height: 12),
              TextFormField(controller: tel, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => V.telephone(v)),
              const SizedBox(height: 12),
              TextFormField(controller: mail, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => V.emailOpt(v)),
              const SizedBox(height: 12),
              TextFormField(controller: adr, decoration: const InputDecoration(
                  labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: spe, decoration: const InputDecoration(
                  labelText: 'Spécialité (ce qu\'il fournit)',
                  prefixIcon: Icon(Icons.category_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: notes, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  final f = Fournisseur(
                    id: existant?.id ?? 'fr_${DateTime.now().millisecondsSinceEpoch}',
                    nom: nom.text.trim(), telephone: tel.text.trim(),
                    email: mail.text.trim(), adresse: adr.text.trim(),
                    specialite: spe.text.trim(), notes: notes.text.trim(),
                  );
                  String? e;
                  if (existant == null) {
                    e = await store.ajouterFournisseur(f);
                  } else {
                    await store.majFournisseur(f);
                  }
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
