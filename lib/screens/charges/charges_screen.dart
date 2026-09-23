import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/charge.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';

/// Charges & dépenses de l'entreprise, avec total du mois.
class ChargesScreen extends StatelessWidget {
  const ChargesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final depenses = store.depensesBoutique;

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SoftSummary(
            label: 'Dépenses du mois (${store.moisCourant})',
            valeur: store.totalDepensesMois,
            icone: Icons.money_off_rounded,
            couleur: const Color(0xFFD97706),
          ),
        ),
        Expanded(
          child: depenses.isEmpty
              ? const EmptyView(
                  icon: Icons.money_off_outlined,
                  message: 'Aucune dépense enregistrée',
                  hint: 'Loyers, salaires, fournisseurs, taxes…')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: depenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LigneCharge(charge: depenses[i]),
                ),
        ),
      ]),
      floatingActionButton: store.peut(Permission.gererDepenses)
          ? FloatingActionButton.extended(
              onPressed: () => _formCharge(context),
              icon: const Icon(Icons.add),
              label: const Text('Dépense'),
            )
          : null,
    );
  }

  void _formCharge(BuildContext context, [Charge? charge]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormCharge(charge: charge),
      ),
    );
  }
}

class SoftSummary extends StatelessWidget {
  final String label;
  final double valeur;
  final IconData icone;
  final Color couleur;
  const SoftSummary({super.key, required this.label, required this.valeur,
      required this.icone, required this.couleur});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icone, color: couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          const SizedBox(width: 12),
          MoneyText(valeur, style: const TextStyle(fontSize: 18)),
        ]),
      );
}

class _LigneCharge extends StatelessWidget {
  final Charge charge;
  const _LigneCharge({required this.charge});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    // Option A (miroir RLS) : modifier = admin/gérant/comptable,
    // supprimer = admin/gérant uniquement.
    final role = store.role;
    final peutModifier = role == Role.admin ||
        role == Role.gerant ||
        role == Role.comptable;
    final peutSupprimer =
        role == Role.admin || role == Role.gerant;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_outlined, color: Color(0xFFD97706), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: peutModifier ? () => _modifier(context) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(charge.libelle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${charge.categorie} · ${charge.date.day}/${charge.date.month}/${charge.date.year}${charge.recurrente ? ' · 🔁' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        MoneyText(charge.montant, style: const TextStyle(fontSize: 14)),
        if (peutModifier || peutSupprimer)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'Modifier / Supprimer',
            onSelected: (v) {
              if (v == 'modifier') _modifier(context);
              if (v == 'supprimer') _confirmerSuppression(context);
            },
            itemBuilder: (_) => [
              if (peutModifier)
                const PopupMenuItem(
                  value: 'modifier',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ]),
                ),
              if (peutSupprimer)
                const PopupMenuItem(
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
    );
  }

  void _modifier(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormCharge(charge: charge),
      ),
    );
  }

  Future<void> _confirmerSuppression(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 32),
        title: const Text('Supprimer cette dépense ?'),
        content: Text(
            '« ${charge.libelle} » — ${C.money(charge.montant)}\n\nCette action est définitive.'),
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
    await context.read<Store>().supprimerCharge(charge.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Dépense supprimée')),
      );
    }
  }
}

class _FormCharge extends StatefulWidget {
  final Charge? charge; // null = création, sinon modification
  const _FormCharge({this.charge});
  @override
  State<_FormCharge> createState() => _FormChargeState();
}

class _FormChargeState extends State<_FormCharge> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelle;
  late final TextEditingController _montant;
  late String _categorie; // ajusté dans build selon la liste dynamique
  late bool _recurrente;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final c = widget.charge;
    _libelle = TextEditingController(text: c?.libelle ?? '');
    _montant = TextEditingController(
        text: c == null ? '' : c.montant.toStringAsFixed(0));
    _categorie = c?.categorie ?? '';
    _recurrente = c?.recurrente ?? false;
    _date = c?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _libelle.dispose();
    _montant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final cats = store.catsCharge;
    if (_categorie.isEmpty || !cats.contains(_categorie)) {
      _categorie = cats.isNotEmpty ? cats.first : 'Autre';
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(widget.charge == null ? 'Nouvelle dépense' : 'Modifier la dépense',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _libelle,
              autofocus: widget.charge == null,
              decoration: const InputDecoration(labelText: 'Libellé'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categorie,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [for (final c in cats)
                  DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _categorie = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montant,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Montant (${store.profile.devise})'),
              validator: (v) => V.prix(v),
            ),
            const SizedBox(height: 12),
            ChampDate(
              valeur: _date,
              label: 'Date de la dépense',
              onChanged: (d) => setState(() => _date = d),
            ),
            SwitchListTile(
              title: const Text('Charge récurrente (mensuelle)'),
              value: _recurrente,
              onChanged: (v) => setState(() => _recurrente = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                child: Text(widget.charge == null
                    ? 'Enregistrer la dépense'
                    : 'Enregistrer les modifications'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (widget.charge == null) {
                    await store.ajouterCharge(Charge(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      boutiqueId: store.boutiqueId,
                      categorie: _categorie,
                      libelle: _libelle.text.trim(),
                      montant: V.prixValue(_montant.text),
                      date: _date,
                      recurrente: _recurrente,
                    ));
                  } else {
                    final erreur = await store.majCharge(Charge(
                      id: widget.charge!.id,
                      boutiqueId: widget.charge!.boutiqueId,
                      categorie: _categorie,
                      libelle: _libelle.text.trim(),
                      montant: V.prixValue(_montant.text),
                      date: _date,
                      recurrente: _recurrente,
                    ));
                    if (erreur != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ $erreur')));
                      return;
                    }
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
