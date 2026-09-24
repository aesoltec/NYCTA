import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/evenement.dart';
import '../../widgets/date_picker_field.dart';

/// Notes personnelles avec rappel optionnel (notification le jour J).
/// Chacun crée/modifie/supprime ses propres notes (cf. policy RLS
/// "ecriture notes" : createur_id = auth.uid()) ; admin/gérant peuvent
/// en plus gérer celles des autres.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final notes = store.notesPerso.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Notes & rappels')),
      body: notes.isEmpty
          ? const Center(child: Text('Aucune note',
              style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notes[i];
                final peutGerer = n.createurId == store.user.id ||
                    store.role == Role.admin || store.role == Role.gerant;
                return Container(
                  decoration: BoxDecoration(
                    color: n.rappelAujourdhui ? const Color(0xFFFFF9E6) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: ListTile(
                    onTap: () => _lire(context, store, n, peutGerer),
                    leading: Icon(Icons.sticky_note_2_outlined,
                        color: n.rappelAujourdhui
                            ? const Color(0xFFB26A00) : const Color(0xFF3D6FB4)),                    title: Text(n.titre,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.contenu,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                          if (n.rappelLe != null)
                            Text('⏰ Rappel le ${n.rappelLe!.day}/${n.rappelLe!.month}/${n.rappelLe!.year}',
                                style: TextStyle(fontSize: 11,
                                    color: n.rappelAujourdhui
                                        ? const Color(0xFFB26A00) : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                        ]),
                    trailing: peutGerer
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                                onPressed: () => _form(context, store, n)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, size: 19,
                                    color: Colors.redAccent),
                                onPressed: () => store.supprimerNote(n.id)),
                          ])
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store, null),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Note'),
      ),
    );
  }

  void _lire(BuildContext context, Store store, Note n, bool peutGerer) {
    showModalBottomSheet(
      context: context, useSafeArea: true, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.titre, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Créée le ${n.date.day}/${n.date.month}/${n.date.year}'
              '${n.rappelLe != null ? ' · ⏰ Rappel le ${n.rappelLe!.day}/${n.rappelLe!.month}/${n.rappelLe!.year}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(n.contenu.isEmpty ? '—' : n.contenu,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            if (peutGerer) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _form(context, store, n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    label: const Text('Supprimer',
                        style: TextStyle(color: Colors.redAccent)),
                    onPressed: () async {
                      final confirme = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('Supprimer cette note ?'),
                          content: Text('« ${n.titre} »'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('Annuler')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirme == true && ctx.mounted) {
                        await store.supprimerNote(n.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _form(BuildContext context, Store store, Note? existant) {
    final titre = TextEditingController(text: existant?.titre ?? '');
    final contenu = TextEditingController(text: existant?.contenu ?? '');
    DateTime? rappel = existant?.rappelLe;
    final key = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Nouvelle note' : 'Modifier la note',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              TextFormField(controller: titre, decoration: const InputDecoration(
                  labelText: 'Titre'),
                  validator: (v) => V.texte(v, 2, 'Titre')),
              const SizedBox(height: 12),
              TextFormField(controller: contenu, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Contenu')),
              const SizedBox(height: 12),
              DatePickerField(
                valeur: rappel,
                label: 'Rappel (optionnel)',
                texteVide: 'Aucun rappel',
                firstDate:
                    DateTime.now().subtract(const Duration(days: 30)),
                lastDate:
                    DateTime.now().add(const Duration(days: 365 * 3)),
                effacable: true,
                onChanged: (d) => setSheetState(() => rappel = d),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  final n = Note(
                    id: existant?.id ?? 'nt_${DateTime.now().millisecondsSinceEpoch}',
                    titre: titre.text.trim(), contenu: contenu.text.trim(),
                    date: existant?.date ?? DateTime.now(), rappelLe: rappel,
                    createurId: existant?.createurId ?? '',
                  );
                  if (existant == null) {
                    await store.ajouterNote(n);
                  } else {
                    await store.majNote(n);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              )),
            ])),
          ]),
      )),
    );
  }
}
