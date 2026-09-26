import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/type_chip.dart';

import '../../services/export_service.dart';

/// Rapports : synthèse globale, par activité, par boutique, frais MoMo.
class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final caParType = store.caParType;
    final total = caParType.values.fold(0.0, (a, b) => a + b);
    final fraisMoMo = store.fraisMoMoMois;

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    final boutiques = store.boutiques
        .where((b) =>
            _recherche.trim().isEmpty ||
            b.nom
                .toLowerCase()
                .contains(_recherche.trim().toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter le rapport',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, store, f),
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
      backgroundColor: const Color(0xFFD5F0F0),
      body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CA total (mois)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              MoneyText(total, style: const TextStyle(fontSize: 18)),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Marge (mois)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              MoneyText(store.margeMois, style: const TextStyle(fontSize: 18)),
            ]),
          )),
        ]),
        const SizedBox(height: 16),
        Text('Par activité', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in caParType.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: TypeChip(e.key)),
                  const SizedBox(width: 10),
                  MoneyText(e.value, style: const TextStyle(fontSize: 14)),
                ]),
              ),
            if (caParType.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Pas de données ce mois-ci',
                    style: TextStyle(color: Colors.grey)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Frais Mobile Money gagnés (mois)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in fraisMoMo.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  MoneyText(e.value, style: const TextStyle(fontSize: 14, color: Color(0xFF3E9D8F))),
                ]),
              ),
            if (fraisMoMo.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Aucune transaction Mobile Money ce mois-ci',
                    style: TextStyle(color: Colors.grey)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('CA par jour (30 derniers jours)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in store.caParJour.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 52,
                    child: Text(e.key,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (e.value /
                                (store.caParJour.values.fold(0.0, (a, b) => a > b ? a : b) == 0
                                    ? 1
                                    : store.caParJour.values.fold(0.0, (a, b) => a > b ? a : b)))
                            .clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: const Color(0xFFEDF0F5),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF3D6FB4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: MoneyText(e.value, style: const TextStyle(fontSize: 11.5)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Filtrer les boutiques…',
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
          ),
          onChanged: (v) => setState(() => _recherche = v),
        ),
        const SizedBox(height: 16),
        Text('Toutes les boutiques', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final b in boutiques)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.storefront_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                MoneyText(
                  store.transactions
                      .where((t) => t.boutiqueId == b.id && C.moisKey(t.date) == store.moisCourant)
                      .fold(0.0, (s, t) => s + t.montant),
                  style: const TextStyle(fontSize: 14),
                ),
              ]),
            ),
          ),
      ],
      ),
    );
  }

  Future<void> _exporter(
      BuildContext context, Store store, String format) async {
    const entetes = [
      'Section', 'Rubrique', 'Montant', 'Devise'
    ];
    final caParType = store.caParType;
    final total = caParType.values.fold(0.0, (a, b) => a + b);
    final lignes = <List<dynamic>>[
      ['CA total (mois)', '', total, store.profile.devise],
      ['Marge (mois)', '', store.margeMois, store.profile.devise],
      for (final e in caParType.entries)
        ['Par activité', e.key.name, e.value, store.profile.devise],
      for (final e in store.fraisMoMoMois.entries)
        ['Frais MoMo', e.key, e.value, store.profile.devise],
      for (final e in store.caParJour.entries)
        ['CA par jour', e.key, e.value, store.profile.devise],
    ];
    final nom = 'rapport_${store.moisCourant}';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Rapport — ${store.moisCourant}',
              sousTitre: store.boutiqueCourante.nom,
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Rapport', entetes, lignes);
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
