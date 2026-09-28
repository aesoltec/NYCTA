import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/client.dart';

import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/client.dart';
import '../../services/export_service.dart';
import '../../services/media_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/filtre_panel.dart';

/// Fichier clients de la boutique courante : créer, modifier.
/// Recherche (nom, téléphone, adresse) + filtre Pro/Particulier + exports.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  Map<String, dynamic> _filtres = const {
    'categorie': 'tous',
    'credit': 'tous',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var clients = store.clientsBoutique;
    final cat = (_filtres['categorie'] as String?) ?? 'tous';
    if (cat == 'pros') {
      clients = clients.where((c) => c.estPro).toList();
    } else if (cat == 'particuliers') {
      clients = clients.where((c) => !c.estPro).toList();
    }
    // Filtre crédit (plan A14) : impayé en cours rattaché au nom.
    final credit = (_filtres['credit'] as String?) ?? 'tous';
    if (credit != 'tous') {
      final avec = store.clientsAvecCredit;
      clients = clients
          .where((c) => credit == 'oui'
              ? avec.contains(c.nom.trim())
              : !avec.contains(c.nom.trim()))
          .toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      clients = clients
          .where((c) =>
              c.nom.toLowerCase().contains(rech) ||
              c.telephone.toLowerCase().contains(rech) ||
              c.adresse.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter la vue filtrée',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, store, clients, f),
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
            filtres: const [
              FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher (nom, téléphone, adresse)…'),
              FiltreConfig(
                  cle: 'categorie',
                  kind: FiltreKind.chips,
                  label: 'Catégorie',
                  options: [
                    ('tous', 'Tous'),
                    ('pros', 'Professionnels'),
                    ('particuliers', 'Particuliers'),
                  ]),
              FiltreConfig(
                  cle: 'credit',
                  kind: FiltreKind.chips,
                  label: 'Crédit',
                  options: [
                    ('tous', 'Tous'),
                    ('oui', 'Avec crédit'),
                    ('non', 'Sans crédit'),
                  ]),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: clients.isEmpty
              ? const Center(
                  child: Text('Aucun client (filtre sans résultat)',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _CarteClient(client: clients[i]),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Client'),
      ),
    );
  }

  void _form(BuildContext context, Store store, Client? existant) =>
      ouvrirFormClient(context, store, existant);

  Future<void> _exporter(BuildContext context, Store store,
      List<Client> clients, String format) async {
    const entetes = [
      'Nom', 'Téléphone', 'Email', 'Adresse', 'RCCM', 'IFU', 'RIB',
      'Catégorie'
    ];
    final lignes = [
      for (final c in clients)
        [
          c.nom,
          c.telephone,
          c.email,
          c.adresse,
          c.rccm,
          c.ifu,
          c.rib,
          c.estPro ? 'Professionnel' : 'Particulier',
        ],
    ];
    final nom = 'clients_${clients.length}';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Clients — ${store.boutiqueCourante.nom}',
              sousTitre: '${clients.length} client(s)',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Clients', entetes, lignes);
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

/// Carte client : logo (ou initiale), coordonnées, badge PRO, édition.
class _CarteClient extends StatelessWidget {
  final Client client;
  const _CarteClient({required this.client});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final c = client;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: ListTile(
        leading: MediaService.existe(c.logoPath)
            ? AppImage(c.logoPath,
                size: 44, borderRadius: BorderRadius.circular(22))
            : CircleAvatar(
                backgroundColor: const Color(0xFFE8F0FB),
                child: Text(
                    c.nom.isNotEmpty ? c.nom[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3D6FB4))),
              ),
        title: Row(children: [
          Flexible(
            child: Text(c.nom,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (c.estPro) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F6F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PRO',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3E9D8F))),
            ),
          ],
        ]),
        subtitle: Text(
          [c.telephone, c.email, c.adresse]
              .where((s) => s.isNotEmpty)
              .join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () =>
                ouvrirFormClient(context, store, c)),
      ),
    );
  }
}

/// Accès formulaire : [_form] est statique (appelable depuis la carte).
void ouvrirFormClient(
    BuildContext context, Store store, Client? existant) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _FormClient(store: store, existant: existant),
    ),
  );
}

class _FormClient extends StatefulWidget {
  final Store store;
  final Client? existant;
  const _FormClient({required this.store, this.existant});

  @override
  State<_FormClient> createState() => _FormClientState();
}

class _FormClientState extends State<_FormClient> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom, _tel, _email, _adresse, _rccm,
      _ifu, _rib;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _nom = TextEditingController(text: e?.nom ?? '');
    _tel = TextEditingController(text: e?.telephone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _adresse = TextEditingController(text: e?.adresse ?? '');
    _rccm = TextEditingController(text: e?.rccm ?? '');
    _ifu = TextEditingController(text: e?.ifu ?? '');
    _rib = TextEditingController(text: e?.rib ?? '');
    _logoPath = e?.logoPath;
  }

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _email.dispose();
    _adresse.dispose();
    _rccm.dispose();
    _ifu.dispose();
    _rib.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(widget.existant == null ? 'Nouveau client' : 'Modifier le client',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(
                  labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nom requis (2 caractères min.)' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => V.telephone(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email (optionnel)',
                  prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => V.emailOpt(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresse,
              decoration: const InputDecoration(
                  labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rccm,
              decoration: const InputDecoration(
                  labelText: 'RCCM (optionnel — professionnel)',
                  prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ifu,
              decoration: const InputDecoration(
                  labelText: 'IFU (optionnel — professionnel)',
                  prefixIcon:
                      Icon(Icons.numbers_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rib,
              decoration: const InputDecoration(
                  labelText: 'RIB / coordonnées bancaires (optionnel)',
                  prefixIcon:
                      Icon(Icons.account_balance_outlined)),
            ),
            const SizedBox(height: 12),
            // Logo (optionnel) : galerie ou photo, upload bucket « media ».
            Row(children: [
              AppImage(_logoPath,
                  size: 56, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined,
                        size: 18),
                    label: const Text('Logo'),
                    onPressed: () async {
                      final p = await MediaService.pickImage();
                      if (p != null) {
                        setState(() => _logoPath = p);
                      }
                    },
                  ),
                  if ((_logoPath ?? '').isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Retirer'),
                      onPressed: () =>
                          setState(() => _logoPath = null),
                    ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final c = Client(
                    id: widget.existant?.id ??
                        'cl_${DateTime.now().millisecondsSinceEpoch}',
                    boutiqueId: store.boutiqueId,
                    nom: _nom.text.trim(),
                    telephone: _tel.text.trim(),
                    email: _email.text.trim(),
                    adresse: _adresse.text.trim(),
                    rccm: _rccm.text.trim(),
                    ifu: _ifu.text.trim(),
                    rib: _rib.text.trim(),
                    logoPath: (_logoPath ?? '').isEmpty
                        ? null
                        : _logoPath,
                  );
                  final String? erreur;
                  if (widget.existant == null) {
                    erreur = await store.ajouterClient(c);
                  } else {
                    await store.majClient(c);
                    erreur = null;
                  }
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
