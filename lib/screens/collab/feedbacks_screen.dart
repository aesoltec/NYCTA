import 'package:flutter/material.dart' hide Feedback;
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/feedback.dart';

/// Boîte à idées & signalements : recommandations, suggestions, propositions,
/// signalements de panne et avis — avec priorité et suivi de traitement
/// (nouveau → en cours → traité, réservé admin/gérant).
class FeedbacksScreen extends StatelessWidget {
  const FeedbacksScreen({super.key});

  static const _couleursTypes = <TypeFeedback, Color>{
    TypeFeedback.recommandation: Color(0xFF3E9D8F),
    TypeFeedback.suggestion: Color(0xFF3D6FB4),
    TypeFeedback.proposition: Color(0xFF7E57C2),
    TypeFeedback.panne: Color(0xFFD97706),
    TypeFeedback.avis: Color(0xFF607D8B),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutTraiter = store.peut(Permission.gererPartenaires) ||
        store.peut(Permission.configurer) ||
        store.role == Role.admin || store.role == Role.gerant;
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions & signalements')),
      body: store.feedbacks.isEmpty
          ? const Center(child: Text('Aucune contribution — soyez le premier !',
              style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: store.feedbacks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final f = store.feedbacks[i];
                final couleur = _couleursTypes[f.type]!;
                // Modifier/supprimer : auteur + admin/gérant (miroir RLS).
                final estAuteur = f.auteurId == store.user.id;
                final peutGerer = estAuteur ||
                    store.role == Role.admin ||
                    store.role == Role.gerant;
                return Container(
                  decoration: BoxDecoration(
                    color: f.statut == StatutFeedback.nouveau
                        ? const Color(0xFFF6F9FE)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: ListTile(
                    onTap: () =>
                        _lire(context, store, f, couleur, peutGerer),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(f.type.icone, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Row(children: [
                      if (f.statut == StatutFeedback.nouveau)
                        Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                                color: Color(0xFF3D6FB4), shape: BoxShape.circle)),
                      Expanded(
                        child: Text(f.titre,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: f.statut == StatutFeedback.nouveau
                                    ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14)),
                      ),
                      if (f.priorite == PrioriteFeedback.haute)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('🔴', style: TextStyle(fontSize: 12)),
                        ),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.type.label} · par ${f.auteurNom} · '
                            '${f.date.day}/${f.date.month}/${f.date.year}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: couleur,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(f.contenu,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                        ]),
                    trailing: (peutTraiter || peutGerer)
                        ? PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 20,
                                color: f.statut == StatutFeedback.traite
                                    ? const Color(0xFF3E9D8F) : Colors.grey),
                            tooltip: f.statut.label,
                            onSelected: (v) {
                              if (v == 'modifier') {
                                _form(context, store, f);
                              } else if (v == 'supprimer') {
                                _confirmerSuppression(context, store, f);
                              } else if (v.startsWith('statut:')) {
                                store.changerStatutFeedback(
                                  f.id,
                                  StatutFeedback.values.byName(
                                      v.substring(7)),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              if (peutGerer)
                                const PopupMenuItem(
                                  value: 'modifier',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Modifier'),
                                  ]),
                                ),
                              if (peutGerer)
                                const PopupMenuItem(
                                  value: 'supprimer',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline,
                                        size: 18, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Supprimer',
                                        style: TextStyle(
                                            color: Colors.redAccent)),
                                  ]),
                                ),
                              if (peutGerer && peutTraiter)
                                const PopupMenuDivider(),
                              if (peutTraiter)
                                for (final s in StatutFeedback.values)
                                  PopupMenuItem(
                                    value: 'statut:${s.name}',
                                    child: Row(children: [
                                      Icon(
                                        f.statut == s
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 16,
                                        color: f.statut == s
                                            ? couleur
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(s.label),
                                    ]),
                                  ),
                            ],
                          )
                        : Text(f.statut.label,
                            style: TextStyle(fontSize: 10.5,
                                color: f.statut == StatutFeedback.traite
                                    ? const Color(0xFF3E9D8F) : Colors.grey.shade600)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, store),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Contribuer'),
      ),
    );
  }

  void _form(BuildContext context, Store store, [Feedback? existant]) {
    final titre = TextEditingController(text: existant?.titre ?? '');
    final contenu = TextEditingController(text: existant?.contenu ?? '');
    var type = existant?.type ?? TypeFeedback.suggestion;
    var priorite = existant?.priorite ?? PrioriteFeedback.normale;
    final key = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null
                ? 'Votre contribution'
                : 'Modifier la contribution',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Recommandation, suggestion, proposition, signalement '
                'de panne ou avis — transmis au gérant.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final t in TypeFeedback.values)
                  ChoiceChip(
                    selected: type == t,
                    label: Text('${t.icone} ${t.label}',
                        style: const TextStyle(fontSize: 12)),
                    onSelected: (_) => setSheetState(() => type = t),
                  ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<PrioriteFeedback>(
                initialValue: priorite,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: [
                  for (final p in PrioriteFeedback.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setSheetState(() => priorite = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: titre,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (v) => V.texte(v, 3, 'Titre')),
              const SizedBox(height: 12),
              TextFormField(controller: contenu, maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Description détaillée'),
                  validator: (v) => V.texte(v, 5, 'Description')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                icon: Icon(existant == null ? Icons.send : Icons.save_outlined),
                label: Text(existant == null
                    ? 'Envoyer au gérant'
                    : 'Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  if (existant == null) {
                    final erreur = await store.ajouterFeedback(Feedback(
                      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
                      auteurId: store.user.id, auteurNom: store.user.nom,
                      boutiqueId: store.boutiqueId,
                      type: type, priorite: priorite,
                      titre: titre.text.trim(), contenu: contenu.text.trim(),
                      date: DateTime.now(),
                    ));
                    if (ctx.mounted) {
                      if (erreur != null) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
                      } else {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Merci ! Transmis au gérant.')));
                      }
                    }
                  } else {
                    final erreur = await store.majFeedback(existant.copyWith(
                      type: type, priorite: priorite,
                      titre: titre.text.trim(),
                      contenu: contenu.text.trim(),
                    ));
                    if (ctx.mounted) {
                      if (erreur != null) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
                      } else {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('✅ Contribution modifiée')));
                      }
                    }
                  }
                },
              )),
            ])),
          ]),
      )),
    );
  }

  void _lire(BuildContext context, Store store, Feedback f,
      Color couleur, bool peutGerer) {
    showModalBottomSheet(
      context: context, useSafeArea: true, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(f.type.icone,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(f.titre,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              '${f.type.label} · ${f.priorite.label} · ${f.statut.label} · '
              'par ${f.auteurNom} · '
              '${f.date.day}/${f.date.month}/${f.date.year}',
              style: TextStyle(
                  fontSize: 12, color: couleur,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(f.contenu,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            if (peutGerer) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _form(context, store, f);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmerSuppression(
      BuildContext context, Store store, Feedback f) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 32),
        title: const Text('Supprimer cette contribution ?'),
        content: Text('« ${f.titre} »\n\nCette action est définitive.'),
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
    await store.supprimerFeedback(f.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Contribution supprimée')),
      );
    }
  }
}
