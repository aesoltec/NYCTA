import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/message.dart';

/// Messagerie interne : envoyer à un utilisateur précis ou à TOUS.
/// Badge des non-lus sur la tuile du menu.
class MessagerieScreen extends StatelessWidget {
  const MessagerieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final msgs = store.messagesVisibles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie interne'),
        actions: [
          if (store.messagesNonLus > 0)
            IconButton(
              tooltip: 'Tout marquer comme lu',
              icon: const Icon(Icons.done_all),
              onPressed: () => store.marquerTousMessagesLus(),
            ),
        ],
      ),
      body: msgs.isEmpty
          ? const Center(child: Text('Aucun message',
              style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: msgs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LigneMessage(message: msgs[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nouveau(context, store),
        icon: const Icon(Icons.send_outlined),
        label: const Text('Nouveau'),
      ),
    );
  }

  static void _nouveau(BuildContext context, Store store,
      [Message? existant]) {
    final sujet = TextEditingController(text: existant?.sujet ?? '');
    final contenu = TextEditingController(text: existant?.contenu ?? '');
    String? destinataireId = existant?.destinataireId; // null = tous
    final key = GlobalKey<FormState>();
    final destinataires = store.users.where((u) => u.id != store.user.id).toList();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Nouveau message' : 'Modifier le message',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              DropdownButtonFormField<String?>(
                initialValue: destinataires.any((u) => u.id == destinataireId)
                    ? destinataireId
                    : null,
                decoration: const InputDecoration(labelText: 'Destinataire',
                    prefixIcon: Icon(Icons.person_outline)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('🌍 Tous les utilisateurs')),
                  for (final u in destinataires)
                    DropdownMenuItem<String?>(
                        value: u.id, child: Text('${u.nom} · ${u.role.label}')),
                ],
                onChanged: (v) => setSheetState(() => destinataireId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: sujet,
                  autofocus: existant != null,
                  decoration: const InputDecoration(
                  labelText: 'Sujet'),
                  validator: (v) => V.texte(v, 3, 'Sujet')),
              const SizedBox(height: 12),
              TextFormField(controller: contenu, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: (v) => V.texte(v, 3, 'Message')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                icon: Icon(existant == null ? Icons.send : Icons.save_outlined),
                label: Text(existant == null ? 'Envoyer' : 'Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  if (existant == null) {
                    await store.envoyerMessage(
                        sujet: sujet.text, contenu: contenu.text,
                        destinataireId: destinataireId);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Message envoyé')));
                    }
                  } else {
                    final erreur = await store.majMessage(existant.copyWith(
                      sujet: sujet.text.trim(),
                      contenu: contenu.text.trim(),
                    ));
                    if (!ctx.mounted) return;
                    if (erreur != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('⚠️ $erreur')));
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('✅ Message modifié')));
                    }
                  }
                },
              )),
            ])),
          ]),
      )),
    );
  }
}

class _LigneMessage extends StatelessWidget {
  final Message message;
  const _LigneMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final estMoi = message.expediteurId == store.user.id;
    // Modifier/supprimer : auteur + admin/gérant (miroir RLS).
    final role = store.role;
    final peutGerer = estMoi ||
        role == Role.admin ||
        role == Role.gerant;
    final nonLu = !message.lu && !estMoi;
    return Container(
      decoration: BoxDecoration(
        color: nonLu ? const Color(0xFFE8F0FB) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF1)),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F0FB),
          child: Text(message.expediteurNom.isNotEmpty ? message.expediteurNom[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3D6FB4))),
        ),
        title: Row(children: [
          if (nonLu)
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(color: Color(0xFF3D6FB4), shape: BoxShape.circle)),
          Expanded(
            child: Text(message.sujet,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: nonLu ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14)),
          ),
        ]),
        subtitle: Text(
          '${estMoi ? '→ ' : ''}${message.expediteurNom}'
          '${message.destinataireId == null ? ' (à tous)' : ''} — '
          '${message.contenu}',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${message.date.day}/${message.date.month} ${message.date.hour}h${message.date.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (peutGerer)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Modifier / Supprimer',
              onSelected: (v) {
                if (v == 'modifier') {
                  MessagerieScreen._nouveau(context, store, message);
                }
                if (v == 'supprimer') _confirmerSuppression(context, store);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'modifier',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'supprimer',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: Colors.redAccent)),
                  ]),
                ),
              ],
            ),
        ]),
        onTap: () async {
          await store.marquerMessageLu(message.id);
          if (!context.mounted) return;
          await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: Text(message.sujet,
                style: const TextStyle(fontSize: 16)),
            content: SingleChildScrollView(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('De : ${message.expediteurNom}'
                    '${message.destinataireId == null ? ' (à tous)' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 10),
                Text(message.contenu),
              ],
            )),
            actions: [FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
          ));
        },
      ),
    );
  }

  Future<void> _confirmerSuppression(
      BuildContext context, Store store) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 32),
        title: const Text('Supprimer ce message ?'),
        content: Text('« ${message.sujet} »\n\nCette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    await store.supprimerMessage(message.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Message supprimé')),
      );
    }
  }
}
