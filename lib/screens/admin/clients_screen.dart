import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/client.dart';

/// Fichier clients de la boutique courante : créer, modifier.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final clients = store.clientsBoutique;
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: clients.isEmpty
          ? const Center(child: Text('Aucun client enregistré',
              style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: clients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8F0FB),
                    child: Text(clients[i].nom.isNotEmpty ? clients[i].nom[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: Color(0xFF3D6FB4))),
                  ),
                  title: Text(clients[i].nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [clients[i].telephone, clients[i].adresse]
                        .where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _form(context, store, clients[i])),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Client'),
      ),
    );
  }

  void _form(BuildContext context, Store store, Client? existant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormClient(store: store, existant: existant),
      ),
    );
  }
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
  late final TextEditingController _nom, _tel, _adresse;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.existant?.nom ?? '');
    _tel = TextEditingController(text: widget.existant?.telephone ?? '');
    _adresse = TextEditingController(text: widget.existant?.adresse ?? '');
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
              controller: _adresse,
              decoration: const InputDecoration(
                  labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
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
                    adresse: _adresse.text.trim(),
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
