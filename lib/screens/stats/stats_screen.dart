import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';

/// Statistiques & graphiques — la vue « pilotage » du dirigeant :
/// évolution du CA sur 30 jours (courbe), répartition par activité
/// (camembert + histogramme), indicateurs clés (moyenne, meilleur jour,
/// marge, nombre d'opérations).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final caParJour = store.caParJour; // Map<'jj/mm', double> — 30 derniers jours
    final entrees = caParJour.entries.toList();
    final maxCa = caParJour.values.fold(0.0, (a, b) => a > b ? a : b);
    final caTotal = caParJour.values.fold(0.0, (a, b) => a + b);
    final moyenne = caTotal / (caParJour.values.where((v) => v > 0).isEmpty ? 1 : 30);
    final meilleur = entrees.isEmpty
        ? null
        : entrees.reduce((a, b) => a.value >= b.value ? a : b);
    final caParType = store.caParType;
    // Calculés UNE fois par build (évite les folds répétés dans les
    // boucles de graphiques à chaque frame).
    final typesEntrees = caParType.entries.toList();
    final totalMois =
        typesEntrees.fold(0.0, (s, e) => s + e.value);

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques & graphiques')),
      backgroundColor: const Color(0xFFD5F0F0),
      body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
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
              label: 'Opérations du mois',
              valeur: Text('${store.txMois.length}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              sousTexte: 'CA ${C.money(store.caMois, store.profile.devise)}')),
          const SizedBox(width: 10),
          Expanded(child: _Indicateur(
              label: 'Marge du mois',
              valeur: MoneyText(store.margeMois, style: const TextStyle(fontSize: 15, color: Color(0xFF3E9D8F))),
              sousTexte: '${store.caMois == 0 ? 0 : (store.margeMois / store.caMois * 100).round()} % du CA')),
        ]),
        const SizedBox(height: 20),

        // ---------- Courbe : CA sur 30 jours ----------
        Text('Évolution du CA — 30 jours',
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
        Text('Répartition par activité (mois)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: caParType.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Pas de ventes ce mois-ci',
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
                                title: e.value / totalMois > 0.08
                                    ? '${(e.value / totalMois * 100).round()}%'
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
                                '${(e.value / totalMois * 100).round()}%',
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
        Text('CA par activité (mois)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: SizedBox(
            height: 200,
            child: caParType.isEmpty
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
