import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../models/transaction.dart';
import '../../services/export_service.dart';
import '../../widgets/filtre_panel.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';

/// Statistiques & graphiques — la vue « pilotage » du dirigeant :
/// évolution du CA sur la période filtrée (courbe), répartition par
/// activité (camembert + histogramme), indicateurs clés.
/// Filtres (point 32) : type d'activité + période Début/Fin
/// (défaut : 30 derniers jours) — calculs locaux depuis les ventes.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();

  /// Ventes filtrées (même logique que l'écran — testable).
  static List<Tx> ventesFiltrees(
      List<Tx> toutes, String type, DateTime debut, DateTime fin) {
    return toutes.where((t) {
      if (type != 'tous' && t.type.name != type) return false;
      if (t.date.isBefore(debut)) return false;
      final finJour = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
      if (t.date.isAfter(finJour)) return false;
      return true;
    }).toList();
  }

  /// Série temporelle : seaux de [pasJours] jours de [debut] à [fin].
  /// Libellé 'jj/mm' du premier jour du seau. Testable (point 32).
  static List<MapEntry<String, double>> serie(
      List<Tx> ventes, DateTime debut, DateTime fin, int pasJours) {
    final j0 = DateTime(debut.year, debut.month, debut.day);
    final j1 = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
    final seaux = <MapEntry<String, double>>[];
    var curseur = j0;
    while (!curseur.isAfter(j1)) {
      final suivant = curseur.add(Duration(days: pasJours));
      var total = 0.0;
      for (final t in ventes) {
        if (!t.date.isBefore(curseur) && t.date.isBefore(suivant)) {
          total += t.montant;
        }
      }
      seaux.add(MapEntry(
          '${curseur.day.toString().padLeft(2, '0')}/${curseur.month.toString().padLeft(2, '0')}',
          total));
      curseur = suivant;
    }
    return seaux;
  }
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _filtres = const {'type': 'tous'};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final maintenant = DateTime.now();
    final debut = (_filtres['debut'] as DateTime?) ??
        DateTime(maintenant.year, maintenant.month, maintenant.day)
            .subtract(const Duration(days: 29));
    final fin = (_filtres['fin'] as DateTime?) ?? maintenant;
    final type = (_filtres['type'] as String?) ?? 'tous';
    final ventes = StatsScreen.ventesFiltrees(
        store.txBoutique, type, debut, fin);

    // Découpage : jour (≤ 62 j), semaine (≤ 370 j), mois au-delà.
    final span = fin.difference(debut).inDays;
    final pasJours = span <= 62 ? 1 : (span <= 370 ? 7 : 30);
    final entrees = StatsScreen.serie(ventes, debut, fin, pasJours);
    final maxCa = entrees.fold(
        0.0, (a, e) => e.value > a ? e.value : a);
    final caTotal = entrees.fold(0.0, (a, e) => a + e.value);
    final nbJours = (span + 1).clamp(1, 100000);
    final moyenne = caTotal / nbJours;
    final meilleur = entrees.isEmpty
        ? null
        : entrees.reduce((a, b) => a.value >= b.value ? a : b);
    final parType = <TypeTransaction, double>{};
    for (final t in ventes) {
      parType[t.type] = (parType[t.type] ?? 0) + t.montant;
    }
    final typesEntrees = parType.entries.toList();
    final totalPeriode =
        typesEntrees.fold(0.0, (s, e) => s + e.value);
    final margePeriode =
        ventes.fold(0.0, (s, t) => s + (t.montant - t.cout));

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques & graphiques'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter la vue filtrée',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporterStats(
                context, store, entrees, typesEntrees, totalPeriode,
                _libellePeriode(debut, fin), f),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FiltrePanel(
            filtres: [
              FiltreConfig(
                  cle: 'type',
                  kind: FiltreKind.chips,
                  label: 'Activité',
                  options: [
                    ('tous', 'Toutes'),
                    for (final t in TypeTransaction.values)
                      (t.name, C.infosTypes[t]!.$1),
                  ]),
              const FiltreConfig(
                  cle: '', kind: FiltreKind.dates, label: ''),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
        ),
        Text('Sans dates : 30 derniers jours · ${ventes.length} opération(s)',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        // ---------- Indicateurs clés ----------
        Row(children: [
          Expanded(child: _Indicateur(
              label: 'CA moyen / jour', valeur: MoneyText(moyenne, style: const TextStyle(fontSize: 15)))),
          const SizedBox(width: 10),
          Expanded(child: _Indicateur(
              label: 'Meilleur jour',
              valeur: Text(meilleur == null ? '—' : meilleur.key,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              sousTexte: meilleur == null ? '' : C.money(meilleur.value, store.profile.devise))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Indicateur(
              label: 'Opérations (période)',
              valeur: Text('${ventes.length}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              sousTexte: 'CA ${C.money(totalPeriode, store.profile.devise)}')),
          const SizedBox(width: 10),
          Expanded(child: _Indicateur(
              label: 'Marge (période)',
              valeur: MoneyText(margePeriode, style: const TextStyle(fontSize: 15, color: Color(0xFF3E9D8F))),
              sousTexte: '${totalPeriode == 0 ? 0 : (margePeriode / totalPeriode * 100).round()} % du CA')),
        ]),
        const SizedBox(height: 20),

        // ---------- Courbe : CA sur la période ----------
        Text('Évolution du CA — ${_libellePeriode(debut, fin)}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: SizedBox(
            height: 220,
            child: entrees.every((e) => e.value == 0)
                ? const Center(child: Text('Pas de données sur la période',
                    style: TextStyle(color: Colors.grey)))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= entrees.length || i % 5 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(entrees[i].key,
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey.shade600)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => [
                            for (final s in spots)
                              if (s.x.toInt() >= 0 && s.x.toInt() < entrees.length)
                                LineTooltipItem(
                                  '${entrees[s.x.toInt()].key}\n${C.money(s.y, store.profile.devise)}',
                                  const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                          ],
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: const Color(0xFF3D6FB4),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF3D6FB4).withValues(alpha: 0.12),
                          ),
                          spots: [
                            for (var i = 0; i < entrees.length; i++)
                              FlSpot(i.toDouble(), entrees[i].value),
                          ],
                        ),
                      ],
                      minY: 0,
                      maxY: maxCa * 1.15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // ---------- Camembert : répartition par activité ----------
        Text('Répartition par activité (période)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: typesEntrees.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Pas de ventes sur la période',
                      style: TextStyle(color: Colors.grey)),
                )
              : Row(children: [
                  Expanded(
                    flex: 3,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 34,
                          sectionsSpace: 2,
                          sections: [
                            for (final e in typesEntrees)
                              PieChartSectionData(
                                value: e.value,
                                color: C.infosTypes[e.key]!.$3,
                                radius: 52,
                                title: e.value / totalPeriode > 0.08
                                    ? '${(e.value / totalPeriode * 100).round()}%'
                                    : '',
                                titleStyle: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in typesEntrees)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                    color: C.infosTypes[e.key]!.$3,
                                    borderRadius: BorderRadius.circular(3)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(C.infosTypes[e.key]!.$1,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5)),
                              ),
                              Text(
                                '${(e.value / totalPeriode * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ]),
        ),
        const SizedBox(height: 20),

        // ---------- Histogramme : CA par activité ----------
        Text('CA par activité (période)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: SizedBox(
            height: 200,
            child: typesEntrees.isEmpty
                ? const Center(child: Text('Pas de données',
                    style: TextStyle(color: Colors.grey)))
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= typesEntrees.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(C.infosTypes[typesEntrees[i].key]!.$1,
                                    style: TextStyle(
                                        fontSize: 9.5, color: Colors.grey.shade600)),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < typesEntrees.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: typesEntrees[i].value,
                              color: C.infosTypes[typesEntrees[i].key]!.$3,
                              width: 26,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ]),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // ---------- Statistiques partenaires hotspot ----------
        if (store.partenaires.isNotEmpty) ...[
          Text('Partenaires hotspot — ventes du mois',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(children: [
              for (final p in store.partenaires)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(
                      child: Text(p.nom,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('${(p.taux * 100).round()} %',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    const SizedBox(width: 10),
                    MoneyText(store.ventesPartenaireMois(p.id, store.moisCourant),
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
            ]),
          ),
        ],
      ],
      ),
    );
  }
}

String _libellePeriode(DateTime debut, DateTime fin) =>
    'du ${debut.day.toString().padLeft(2, '0')}/${debut.month.toString().padLeft(2, '0')} '
    'au ${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}/${fin.year}';

Future<void> _exporterStats(
    BuildContext context,
    Store store,
    List<MapEntry<String, double>> serie,
    List<MapEntry<TypeTransaction, double>> parType,
    double total,
    String periode,
    String format) async {
  const entetes = ['Rubrique', 'Détail', 'Montant', 'Devise'];
  final lignes = <List<dynamic>>[
    for (final e in serie) ['Jour', e.key, e.value, store.profile.devise],
    for (final e in parType)
      [
        'Activité',
        C.infosTypes[e.key]!.$1,
        e.value,
        store.profile.devise
      ],
    ['Total période', periode, total, store.profile.devise],
  ];
  const nom = 'statistiques';
  try {
    switch (format) {
      case 'pdf':
        await ExportService.partagerPdf(nom,
            titre: 'Statistiques — ${store.boutiqueCourante.nom}',
            sousTitre: periode,
            entetes: entetes,
            lignes: lignes);
      case 'xlsx':
        await ExportService.partagerExcel(
            nom, 'Stats', entetes, lignes);
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

class _Indicateur extends StatelessWidget {
  final String label;
  final Widget valeur;
  final String sousTexte;
  const _Indicateur({required this.label, required this.valeur, this.sousTexte = ''});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        valeur,
        if (sousTexte.isNotEmpty)
          Text(sousTexte,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}
