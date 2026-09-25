import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../data/store.dart';
import '../../models/partenaire.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';

/// Partenaires hotspot : liste + clôture mensuelle du partage.
class PartenairesScreen extends StatelessWidget {
  const PartenairesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final mois = C.moisKey(DateTime.now());

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    if (store.partenaires.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partenaires hotspot')),
        backgroundColor: const Color(0xFFD5F0F0),
        body: const EmptyView(
            icon: Icons.handshake_outlined,
            message: 'Aucun partenaire',
            hint: 'Ajoutez vos partenaires hotspot pour suivre leurs ventes'),
        floatingActionButton: store.peut(Permission.gererPartenaires)
            ? FloatingActionButton.extended(
                onPressed: () => _formPartenaire(context, store, null),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Partenaire'),
              )
            : null,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Partenaires hotspot')),
      backgroundColor: const Color(0xFFD5F0F0),
      body: RefreshIndicator(
        onRefresh: store.rafraichir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            for (final p in store.partenaires.where((p) => p.actif))
              _CartePartenaire(partenaire: p, mois: mois),
            if (store.partenaires.any((p) => !p.actif))
              ExpansionTile(
                title: Text(
                    'Inactifs (${store.partenaires.where((p) => !p.actif).length})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
                  for (final p in store.partenaires.where((p) => !p.actif))
                    _CartePartenaire(partenaire: p, mois: mois),
                ],
              ),
          ],
        ),
      ),
      floatingActionButton: store.peut(Permission.gererPartenaires)
          ? FloatingActionButton.extended(
              onPressed: () => _formPartenaire(context, store, null),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Partenaire'),
            )
          : null,
    );
  }

  static void _formPartenaire(
      BuildContext context, Store store, Partenaire? existant) {
    final nom = TextEditingController(text: existant?.nom ?? '');
    final tel = TextEditingController(text: existant?.telephone ?? '');
    final loc = TextEditingController(text: existant?.localisation ?? '');
    final taux = TextEditingController(
        text: existant == null ? '60' : '${(existant.taux * 100).round()}');
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(existant == null ? 'Nouveau partenaire' : 'Modifier le partenaire',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: Column(children: [
                TextFormField(
                  controller: nom,
                  decoration: const InputDecoration(
                      labelText: 'Nom', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nom requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => V.telephone(v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: loc,
                  decoration: const InputDecoration(
                      labelText: 'Localisation / quartier',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: taux,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Sa part (%)',
                      helperText: 'Ex : 60 → il garde 60 %, l\'entreprise 40 %'),
                  validator: (v) => V.pourcent(v, label: 'Sa part'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    child: const Text('Enregistrer'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final p = Partenaire(
                        id: existant?.id ?? 'nouveau',
                        nom: nom.text.trim(),
                        telephone: tel.text.trim(),
                        localisation: loc.text.trim(),
                        taux: double.parse(taux.text
                                .trim()
                                .replaceAll(' ', '')
                                .replaceAll(',', '.')) /
                            100,
                        actif: existant?.actif ?? true,
                      );
                      final String? erreur;
                      if (existant == null) {
                        erreur = await store.ajouterPartenaire(p);
                      } else {
                        erreur = await store.majPartenaire(p);
                      }
                      if (!ctx.mounted) return;
                      if (erreur != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('⚠️ $erreur')));
                        return;
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(existant == null
                              ? '✅ Partenaire ajouté'
                              : '✅ Modifications enregistrées')));
                    },
                  ),
                ),
                if (existant != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 19, color: Colors.redAccent),
                      label: const Text('Supprimer ce partenaire',
                          style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        confirmerSuppression(context, store, existant);
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static void confirmerDesactivation(BuildContext context, Store store, Partenaire p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Désactiver ${p.nom} ?'),
        content: const Text('Ses ventes passées sont conservées ; il ne pourra '
            'plus vendre de forfaits.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // BUG CORRIGÉ : l'ancienne version appelait ajouterPartenaire()
              // (nouvel id régénéré) et DUPLIQUAIT la fiche au lieu de la
              // désactiver. On passe par la désactivation dédiée.
              await store.desactiverPartenaire(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
  }

  /// Suppression définitive (refusée avec motif si historique existant —
  /// désactivation proposée à la place). Accessible depuis la fiche
  /// d'édition et l'icône de chaque carte.
  static void confirmerSuppression(BuildContext context, Store store, Partenaire p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${p.nom} ?'),
        content: const Text('Suppression définitive uniquement si ce '
            'partenaire n\'a ni ventes ni clôtures.\n'
            'Sinon, désactivez-le pour conserver l\'historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final erreur = await store.supprimerPartenaire(p.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (erreur != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('⚠️ $erreur')));
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('« ${p.nom} » supprimé')));
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _CartePartenaire extends StatelessWidget {
  final Partenaire partenaire;
  final String mois;
  const _CartePartenaire({required this.partenaire, required this.mois});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final ventesMois = store.ventesPartenaireMois(partenaire.id, mois);
    final dejaCloture = store.partageExiste(partenaire.id, mois);
    final historique = store.partagesDe(partenaire.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => PartenairesScreen._formPartenaire(context, store, partenaire),
          borderRadius: BorderRadius.circular(12),
          child: Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8F0FB),
            child: Text(partenaire.nom.characters.first,
                style: const TextStyle(
                    color: Color(0xFF3D6FB4), fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(partenaire.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${partenaire.localisation} · ${(partenaire.taux * 100).round()} % pour lui',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ]),
          ),
          if (store.peut(Permission.gererPartenaires)) ...[
            if (partenaire.actif)
              IconButton(
                tooltip: 'Désactiver',
                icon: const Icon(Icons.person_off_outlined, size: 18, color: Colors.redAccent),
                onPressed: () => PartenairesScreen.confirmerDesactivation(context, store, partenaire),
              )
            else
              IconButton(
                tooltip: 'Réactiver',
                icon: const Icon(Icons.person_add_alt_outlined, size: 18, color: Color(0xFF3E9D8F)),
                onPressed: () async {
                  final erreur =
                      await store.majPartenaire(partenaire.copyWith(actif: true));
                  if (erreur != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⚠️ $erreur')));
                  }
                },
              ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              onPressed: () => PartenairesScreen.confirmerSuppression(context, store, partenaire),
            ),
          ],
        ]),
        ),
        const Divider(height: 24),
        Row(children: [
          Expanded(
            child: _MiniStat(
                label: 'Ventes $mois', valeur: MoneyText(ventesMois, style: const TextStyle(fontSize: 15))),
          ),
          Expanded(
            child: _MiniStat(
                label: 'Sa part',
                valeur: MoneyText(ventesMois * partenaire.taux,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF3E9D8F)))),
          ),
          Expanded(
            child: _MiniStat(
                label: 'Votre part',
                valeur: MoneyText(ventesMois * (1 - partenaire.taux),
                    style: const TextStyle(fontSize: 15))),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (!store.peut(Permission.cloturerMois) || dejaCloture || ventesMois == 0)
                ? null
                : () async {
                    final pg = await store.cloturerMois(partenaire.id, mois);
                    if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Partage clôturé ✅'),
                          content: Text(
                              'Total ventes : ${C.money(pg.totalVentes)}\n\n'
                              'Part ${partenaire.nom} : ${C.money(pg.partPartenaire)}\n'
                              'Part entreprise : ${C.money(pg.partEntreprise)}'),
                          actions: [
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK')),
                          ],
                        ),
                      );
                    }
                  },
            icon: Icon(dejaCloture ? Icons.check_circle : Icons.lock_clock_outlined),
            label: Text(dejaCloture ? 'Mois clôturé' : 'Clôturer le mois $mois'),
          ),
        ),
        if (historique.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Historique des partages',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            children: [
              for (final pg in historique.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(pg.mois,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${C.money(pg.partPartenaire)} / ${C.money(pg.partEntreprise)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final Widget valeur;
  const _MiniStat({required this.label, required this.valeur});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          valeur,
        ],
      );
}
