import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/app_user.dart';
import '../../core/env.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../services/cloud_repository.dart';
import '../../services/supabase_service.dart';

/// Gestion des utilisateurs : créer des comptes, affecter un rôle
/// (admin, gérant, comptable, caissier, vendeur, stagiaire) et les
/// boutiques accessibles. Réservé à la permission gererUtilisateurs.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          for (final u in store.users)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: u.role == Role.admin
                      ? const Color(0xFFE8F0FB)
                      : const Color(0xFFE9F6F4),
                  child: Text(u.nom.isNotEmpty ? u.nom[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: u.role == Role.admin
                              ? const Color(0xFF3D6FB4)
                              : const Color(0xFF3E9D8F))),
                ),
                title: Text(u.nom,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${u.role.label} · ${u.boutiqueIds.length} boutique(s)',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _formUtilisateur(context, store, u),
                  ),
                  if (u.role != Role.admin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20,
                          color: Colors.redAccent),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Supprimer ${u.nom} ?'),
                            content: const Text('Ce compte n\'aura plus accès à l\'application.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler')),
                              FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Supprimer')),
                            ],
                          ),
                        );
                        if (ok == true) await store.supprimerUtilisateur(u.id);
                      },
                    ),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formUtilisateur(context, store, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Utilisateur'),
      ),
    );
  }

  void _formUtilisateur(BuildContext context, Store store, AppUser? existant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormUtilisateur(store: store, existant: existant),
      ),
    );
  }
}

class _FormUtilisateur extends StatefulWidget {
  final Store store;
  final AppUser? existant;
  const _FormUtilisateur({required this.store, this.existant});

  @override
  State<_FormUtilisateur> createState() => _FormUtilisateurState();
}

class _FormUtilisateurState extends State<_FormUtilisateur> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom, _email, _mdp;
  late Role _role;
  late Set<String> _boutiqueIds;
  String? _partenaireId;
  bool _envoiLienEnCours = false;
  bool get _cloud => Env.supabaseConfigured;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.existant?.nom ?? '');
    _email = TextEditingController();
    _mdp = TextEditingController();
    _role = widget.existant?.role ?? Role.vendeur;
    _boutiqueIds = {...?widget.existant?.boutiqueIds};
    _partenaireId = widget.existant?.partenaireId;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(widget.existant == null ? 'Nouvel utilisateur' : 'Modifier l\'utilisateur',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Nom requis (2 caractères min.)' : null,
            ),
            const SizedBox(height: 14),
            if (_cloud && widget.existant == null) ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email du compte',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => V.email(v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mdp,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => (v == null || v.length < 6)
                    ? '6 caractères min.' : null,
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<Role>(
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Rôle', prefixIcon: Icon(Icons.badge_outlined)),
              items: [
                for (final r in Role.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (r) => setState(() => _role = r!),
            ),
            // Sans ce lien, l'espace partenaire (login role=partenaire) ne
            // peut pas savoir à quelle fiche Partenaire (taux, ventes) ce
            // compte correspond — users.partenaire_id resterait null.
            if (_role == Role.partenaire) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _partenaireId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Partenaire lié',
                    prefixIcon: Icon(Icons.handshake_outlined)),
                items: [
                  for (final p in store.partenaires)
                    DropdownMenuItem(value: p.id, child: Text(p.nom)),
                ],
                validator: (v) => v == null ? 'Requis pour ce rôle' : null,
                onChanged: (v) => setState(() => _partenaireId = v),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Boutiques accessibles',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final b in store.boutiques)
                FilterChip(
                  selected: _boutiqueIds.contains(b.id),
                  label: Text(b.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onSelected: (sel) => setState(() {
                    sel ? _boutiqueIds.add(b.id) : _boutiqueIds.remove(b.id);
                  }),
                ),
            ]),
            const SizedBox(height: 20),
            // Mot de passe d'un compte EXISTANT (mission §2.5) : la clé
            // anon ne permet pas de le changer directement — Supabase
            // envoie un lien de réinitialisation à l'email du compte.
            if (_cloud && widget.existant != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mot de passe du compte',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email du compte',
                            prefixIcon: Icon(Icons.email_outlined),
                            helperText:
                                'Lien de réinitialisation envoyé à cet email'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: _envoiLienEnCours
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 18),
                          label: Text(_envoiLienEnCours
                              ? 'Envoi…'
                              : 'Envoyer le lien de réinitialisation'),
                          onPressed: _envoiLienEnCours
                              ? null
                              : () async {
                                  final erreur = V.email(_email.text);
                                  if (erreur != null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                            content: Text('⚠️ $erreur')));
                                    return;
                                  }
                                  setState(
                                      () => _envoiLienEnCours = true);
                                  final echec = await SupabaseService
                                      .reinitialiserMotDePasse(
                                          _email.text);
                                  if (!context.mounted) return;
                                  setState(() =>
                                      _envoiLienEnCours = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(echec == null
                                              ? '✅ Lien envoyé à ${_email.text.trim()}'
                                              : '❌ $echec')));
                                },
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: Text(widget.existant == null ? 'Créer le compte' : 'Enregistrer'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_boutiqueIds.isEmpty && _role != Role.admin) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('⚠️ Sélectionnez au moins une boutique')));
                    return;
                  }
                  if (widget.existant == null) {
                    var id = 'u_${DateTime.now().millisecondsSinceEpoch}';
                    if (_cloud) {
                      // Production : inscription Auth Supabase + rôle + boutiques.
                      // On récupère le VRAI uid Supabase : garder l'id local
                      // temporaire ferait perdre l'utilisateur de la liste au
                      // prochain rechargement (rien en base ne correspond).
                      final (erreur, uid) = await CloudRepository.creerUtilisateur(
                        email: _email.text.trim(),
                        motDePasse: _mdp.text,
                        nom: _nom.text.trim(), role: _role,
                        boutiqueIds: _boutiqueIds.toList(),
                        partenaireId: _partenaireId,
                      );
                      if (!context.mounted) return;
                      if (erreur != null || uid == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ ${erreur ?? 'Échec de la création'}')));
                        return;
                      }
                      id = uid;
                    }
                    await store.ajouterUtilisateur(AppUser(
                      id: id, nom: _nom.text.trim(), role: _role,
                      boutiqueIds: _boutiqueIds.toList(),
                      partenaireId: _partenaireId,
                    ));
                  } else {
                    final u = AppUser(
                      id: widget.existant!.id,
                      nom: _nom.text.trim(),
                      role: _role,
                      boutiqueIds: _boutiqueIds.toList(),
                      partenaireId: _partenaireId,
                    );
                    await store.majUtilisateur(u);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
