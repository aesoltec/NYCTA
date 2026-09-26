import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/boutique.dart';
import '../../models/enums.dart';
import '../../widgets/filtre_panel.dart';

/// Administration des boutiques : créer, modifier (dont affectation des
/// utilisateurs et statut siège), fermer. Plus jamais de SQL manuel.
/// Recherche (nom, adresse) + filtres statut (actives/fermées) et siège.
class BoutiquesScreen extends StatefulWidget {
  const BoutiquesScreen({super.key});

  @override
  State<BoutiquesScreen> createState() => _BoutiquesScreenState();
}

class _BoutiquesScreenState extends State<BoutiquesScreen> {
  // Filtres via FiltrePanel : statut (chips) + siège (chips) + recherche.
  // 'siege' : 'tous' | 'siege' | 'annexes' (String, pas bool — le panel
  // ne porte que des String?).
  Map<String, dynamic> _filtres = const {
    'statut': 'actives',
    'siege': 'tous',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var liste = store.boutiques.toList();
    final statut = (_filtres['statut'] as String?) ?? 'actives';
    if (statut == 'actives') {
      liste = liste.where((b) => b.actif).toList();
    } else if (statut == 'fermees') {
      liste = liste.where((b) => !b.actif).toList();
    }
    final siege = (_filtres['siege'] as String?) ?? 'tous';
    if (siege == 'siege') {
      liste = liste.where((b) => b.siege).toList();
    } else if (siege == 'annexes') {
      liste = liste.where((b) => !b.siege).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      // Le modèle Boutique ne porte que nom + adresse : pas de
      // ville/responsable/code à filtrer (non inventés).
      liste = liste
          .where((b) =>
              b.nom.toLowerCase().contains(rech) ||
              b.adresse.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Boutiques')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FiltrePanel(
            filtres: const [
              FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher (nom, adresse)…'),
              FiltreConfig(
                  cle: 'statut',
                  kind: FiltreKind.chips,
                  label: 'Statut',
                  options: [
                    ('actives', 'Actives'),
                    ('fermees', 'Fermées'),
                    ('toutes', 'Toutes'),
                  ]),
              FiltreConfig(
                  cle: 'siege',
                  kind: FiltreKind.chips,
                  label: 'Siège',
                  options: [
                    ('tous', 'Siège + annexes'),
                    ('siege', 'Siège'),
                    ('annexes', 'Annexes'),
                  ]),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: liste.isEmpty
              ? Center(
                  child: Text(
                    'Aucune boutique (filtre sans résultat)',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: [
                    for (final b in liste)
                      _CarteBoutique(
                        boutique: b,
                        onModifier: b.actif
                            ? () => _form(context, store, b)
                            : null,
                      ),
                  ],
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store, null),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Boutique'),
      ),
    );
  }

  void _form(BuildContext context, Store store, Boutique? existant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        // ctx (celui du builder), pas context (l'écran appelant) : sinon le
        // padding est figé à la valeur au moment de l'ouverture (clavier
        // fermé) et ne se met jamais à jour quand le clavier apparaît.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormBoutique(store: store, existant: existant),
      ),
    );
  }
}

/// Carte boutique : badge SIÈGE / FERMÉE, solde, actions si active.
/// Les fermées sont en lecture seule (pas de réouverture — historique).
class _CarteBoutique extends StatelessWidget {
  final Boutique boutique;
  final VoidCallback? onModifier;
  const _CarteBoutique({required this.boutique, this.onModifier});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final b = boutique;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
              b.siege ? Icons.storefront : Icons.store_outlined,
              color: const Color(0xFF3D6FB4),
              size: 20),
        ),
        title: Row(children: [
          Flexible(
            child: Text(b.nom,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (b.siege) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F6F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('SIÈGE',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3E9D8F))),
            ),
          ],
          if (!b.actif) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF9E9E9E)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('FERMÉE',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF616161))),
            ),
          ],
        ]),
        subtitle: Text(
          '${b.adresse.isEmpty ? '—' : b.adresse} · ${store.soldeCaisse(b.id).toStringAsFixed(0)} ${store.profile.devise}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: b.actif
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon:
                        const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onModifier),
                IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Colors.redAccent),
                    onPressed: () async {
                      final erreur =
                          await store.fermerBoutique(b.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text(erreur ??
                                    '✅ Boutique fermée (historique conservé)')));
                      }
                    }),
              ])
            : (store.role == Role.admin || store.role == Role.gerant)
                ? IconButton(
                    icon: const Icon(Icons.restore_page_outlined,
                        size: 20, color: Color(0xFF3E9D8F)),
                    tooltip: 'Réouvrir cette boutique',
                    onPressed: () => _rouvrir(context, store, b),
                  )
                : null,
      ),
    );
  }
}

/// Réouverture avec confirmation (point 22bis) : admin/gérant seuls
/// (le bouton n'est rendu que pour ces rôles — garde locale en plus).
Future<void> _rouvrir(BuildContext context, Store store, Boutique b) async {
  final confirme = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.restore_page_outlined,
          color: Color(0xFF3E9D8F)),
      title: Text('Réouvrir « ${b.nom} » ?'),
      content: const Text(
          'La boutique redeviendra active et sélectionnable. '
          'Son historique (ventes, documents) est conservé.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réouvrir')),
      ],
    ),
  );
  if (confirme != true || !context.mounted) return;
  final erreur = await store.rouvrirBoutique(b.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(erreur ?? '✅ Boutique rouverte')));
  }
}

class _FormBoutique extends StatefulWidget {
  final Store store;
  final Boutique? existant;
  const _FormBoutique({required this.store, this.existant});

  @override
  State<_FormBoutique> createState() => _FormBoutiqueState();
}

class _FormBoutiqueState extends State<_FormBoutique> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom, _adresse;
  late bool _siege;
  late Set<String> _userIds;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.existant?.nom ?? '');
    _adresse = TextEditingController(text: widget.existant?.adresse ?? '');
    _siege = widget.existant?.siege ?? false;
    _userIds = {
      for (final u in widget.store.users
          .where((u) => u.accedeA(widget.existant?.id ?? '')))
        u.id,
    };
    if (_userIds.isEmpty && widget.store.users.isNotEmpty) {
      _userIds = {widget.store.users.first.id}; // créateur par défaut
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(widget.existant == null ? 'Nouvelle boutique' : 'Modifier la boutique',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(
                  labelText: 'Nom', prefixIcon: Icon(Icons.store_outlined)),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nom requis (2 caractères min.)' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresse,
              decoration: const InputDecoration(
                  labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            SwitchListTile(
              title: const Text('Boutique siège'),
              subtitle: const Text('Il ne peut y en avoir qu\'une — les autres seront démises.'),
              value: _siege,
              onChanged: (v) => setState(() => _siege = v),
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Utilisateurs ayant accès',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final u in store.users)
                FilterChip(
                  selected: _userIds.contains(u.id),
                  label: Text('${u.nom} · ${u.role.label}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onSelected: (sel) => setState(() {
                    sel ? _userIds.add(u.id) : _userIds.remove(u.id);
                  }),
                ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: Text(widget.existant == null ? 'Créer la boutique' : 'Enregistrer'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final b = Boutique(
                    id: widget.existant?.id ??
                        'bt_${DateTime.now().millisecondsSinceEpoch}',
                    nom: _nom.text.trim(),
                    adresse: _adresse.text.trim(),
                    siege: _siege,
                  );
                  final erreur = widget.existant == null
                      ? await store.ajouterBoutique(b, _userIds.toList())
                      : await store.majBoutique(b, _userIds.toList());
                  if (context.mounted) {
                    if (erreur != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
                    } else {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
