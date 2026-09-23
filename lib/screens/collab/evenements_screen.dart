import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/evenement.dart';

/// Réunions & événements : planifier, modifier, supprimer.
/// Écriture réservée à admin/gérant (cf. policy RLS "ecriture evenements") —
/// les autres rôles ont un accès lecture seule au calendrier de l'équipe.
class EvenementsScreen extends StatelessWidget {
  const EvenementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final peutGerer = store.role == Role.admin || store.role == Role.gerant;
    final aVenir = store.evenementsAVenir;
    final passes = store.evenements.where((e) => e.estPasse).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Réunions & événements')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, peutGerer ? 90 : 24),
        children: [
          if (aVenir.isEmpty && passes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucun événement planifié',
                  style: TextStyle(color: Colors.grey))),
            ),
          if (aVenir.isNotEmpty) ...[
            Text('À venir', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final e in aVenir) _CarteEvenement(evenement: e, peutGerer: peutGerer),
          ],
          if (passes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Passés', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final e in passes.take(10))
              Opacity(opacity: 0.6, child: _CarteEvenement(evenement: e, peutGerer: peutGerer)),
          ],
        ],
      ),
      floatingActionButton: peutGerer
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, store, null),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Planifier'),
            )
          : null,
    );
  }

  void _lire(BuildContext context, Store store, Evenement e,
      bool peutGerer) {
    final d = e.date;
    showModalBottomSheet(
      context: context, useSafeArea: true, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.titre, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '📅 ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
              '${e.heure.isNotEmpty ? ' à ${e.heure}' : ''}'
              '${e.lieu.isNotEmpty ? ' · 📍 ${e.lieu}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(e.description,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
            if (peutGerer) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _form(context, store, e);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _form(BuildContext context, Store store, Evenement? existant) {
    final titre = TextEditingController(text: existant?.titre ?? '');
    final heure = TextEditingController(text: existant?.heure ?? '');
    final lieu = TextEditingController(text: existant?.lieu ?? '');
    final desc = TextEditingController(text: existant?.description ?? '');
    DateTime date = existant?.date ?? DateTime.now();
    final key = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Planifier un événement' : 'Modifier l\'événement',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Form(key: key, child: Column(children: [
              TextFormField(controller: titre, decoration: const InputDecoration(
                  labelText: 'Titre', prefixIcon: Icon(Icons.title)),
                  validator: (v) => V.texte(v, 3, 'Titre')),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx, initialDate: date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (d != null) setSheetState(() => date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
                  child: Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: heure,
                  decoration: const InputDecoration(labelText: 'Heure (ex : 14h30)',
                      prefixIcon: Icon(Icons.schedule_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: lieu,
                  decoration: const InputDecoration(labelText: 'Lieu',
                      prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: desc, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / ordre du jour')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                child: const Text('Enregistrer'),
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  final e = Evenement(
                    id: existant?.id ?? 'ev_${DateTime.now().millisecondsSinceEpoch}',
                    titre: titre.text.trim(), date: date, heure: heure.text.trim(),
                    lieu: lieu.text.trim(), description: desc.text.trim(),
                    createurId: existant?.createurId ?? '',
                  );
                  if (existant == null) {
                    await store.ajouterEvenement(e);
                  } else {
                    await store.majEvenement(e);
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

class _CarteEvenement extends StatelessWidget {
  final Evenement evenement;
  final bool peutGerer;
  const _CarteEvenement({required this.evenement, required this.peutGerer});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final d = evenement.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        onTap: () =>
            EvenementsScreen()._lire(context, store, evenement, peutGerer),
        leading: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FB), borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text('${d.day}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF3D6FB4))),
            Text('${d.month}/${d.year}',
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
          ]),
        ),
        title: Text(evenement.titre,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [evenement.heure, evenement.lieu, evenement.description]
              .where((s) => s.isNotEmpty).join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: peutGerer
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 19),
                    onPressed: () => EvenementsScreen()._form(context, store, evenement)),
                IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                    onPressed: () => store.supprimerEvenement(evenement.id)),
              ])
            : null,
      ),
    );
  }
}
