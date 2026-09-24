import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../widgets/money_text.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/type_chip.dart';
import '../transaction/nouvelle_transaction_screen.dart';
import '../achat/achat_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final caParType = store.caParType;
    final totalMois = caParType.values.fold(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- Bandeau héro : dégradé encre, CA du jour + marge ----
        SoftCard(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(store.boutiqueCourante.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(store.moisCourant,
                      style: const TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              const Text("Chiffre d'affaires du jour",
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              MoneyText(store.caJour,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.trending_up_rounded,
                    size: 15, color: Color(0xFF6EE7B7)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Marge : ${C.money(store.margeJour)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _Kpi(
              icone: Icons.calendar_month_outlined,
              couleur: const Color(0xFF0F172A),
              label: 'CA du mois',
              valeur: store.caMois,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Kpi(
              icone: Icons.savings_outlined,
              couleur: const Color(0xFF0E9F6E),
              label: 'Marge du mois',
              valeur: store.margeMois,
            ),
          ),
        ]),
        const SizedBox(height: 22),
        // Courbe d'évolution du CA — 30 derniers jours (même donnée que
        // l'écran Statistiques, vue compacte pour l'accueil).
        const SectionHeader(titre: 'Évolution du CA', compteur: '30 j'),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
          child: SizedBox(
            height: 160,
            child: Builder(builder: (context) {
              final courbe = store.caParJour;
              final entrees = courbe.entries.toList();
              final maxCa =
                  courbe.values.fold(0.0, (a, b) => a > b ? a : b);
              if (entrees.every((e) => e.value == 0)) {
                return const Center(
                    child: Text('Pas de données', style: TextStyle(color: Colors.grey)));
              }
              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFF0F3F8), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i % 10 != 0 || i >= entrees.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(entrees[i].key,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 12,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            C.money(s.y),
                            const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
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
                  maxY: maxCa * 1.2,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 22),
        // ---- Achats fournisseurs (Phase 2) : total mois, en attente,
        //      reste dû, suggestion si stock bas ----
        if (store.peut(Permission.gererAchats) ||
            store.role == Role.vendeur ||
            store.role == Role.caissier)
          const _TuileAchats(),
        if (store.peut(Permission.gererAchats) ||
            store.role == Role.vendeur ||
            store.role == Role.caissier)
          const SizedBox(height: 22),
        SectionHeader(
            titre: 'Nouvelle opération',
            compteur: '${TypeTransaction.values.length}'),
        // ---- Grille activités : LayoutBuilder → jamais de débordement,
        //      libellés courts avec ellipsis dans les cartes ----
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 560 ? 3 : 2;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final type in TypeTransaction.values)
                _ModuleTile(
                  type: type,
                  enabled: store.peut(Permission.vendre),
                  onTap: () async {
                    if (!store.peut(Permission.vendre)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('🔒 Réservé aux rôles de vente (caissier, vendeur…)'),
                          duration: Duration(seconds: 2)));
                      return;
                    }
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NouvelleTransactionScreen(type: type),
                    ));
                  },
                ),
            ],
          );
        }),
        const SizedBox(height: 22),
        SectionHeader(
            titre: 'Répartition du mois',
            compteur: totalMois > 0 ? C.money(totalMois) : null),
        if (caParType.isEmpty)
          const SoftCard(
              child: Text('Aucune vente ce mois-ci.',
                  style: TextStyle(color: Colors.grey)))
        else
          SoftCard(
            child: Column(
              children: [
                for (final e in caParType.entries)
                  _BarreActivite(type: e.key, montant: e.value,
                      total: totalMois),
              ],
            ),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String label;
  final double valeur;
  const _Kpi(
      {required this.icone,
      required this.couleur,
      required this.label,
      required this.valeur});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icone, color: couleur, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.grey.shade600)),
            ),
          ]),
          const SizedBox(height: 8),
          MoneyText(valeur,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TuileAchats extends StatelessWidget {
  const _TuileAchats();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final enAttente = store.achatsEnAttente.length;
    final alertes = store.alertesStock.length;
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AchatListScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFEF6C00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 20, color: Color(0xFFEF6C00)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Achats fournisseurs',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _MiniAchat(
                  label: 'Mois',
                  valeur: MoneyText(store.totalAchatsMois,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800))),
            ),
            Expanded(
              child: _MiniAchat(
                  label: 'En attente',
                  valeur: Text('$enAttente',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: enAttente > 0
                              ? const Color(0xFFEF6C00)
                              : Colors.grey.shade600))),
            ),
            Expanded(
              child: _MiniAchat(
                  label: 'Dû fournisseurs',
                  valeur: MoneyText(store.duFournisseurs,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828)))),
            ),
          ]),
          if (alertes > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                  '⚠️ $alertes produit(s) en stock bas — pensez à réapprovisionner',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAchat extends StatelessWidget {
  final String label;
  final Widget valeur;
  const _MiniAchat({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          valeur,
        ],
      );
}

class _ModuleTile extends StatelessWidget {
  final TypeTransaction type;
  final VoidCallback onTap;
  final bool enabled;
  const _ModuleTile({required this.type, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color0) = C.infosTypes[type]!;
    final color = enabled ? color0 : Colors.grey.shade400;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _BarreActivite extends StatelessWidget {
  final TypeTransaction type;
  final double montant, total;
  const _BarreActivite(
      {required this.type, required this.montant, required this.total});

  @override
  Widget build(BuildContext context) {
    final (label, _, color) = C.infosTypes[type]!;
    final ratio = total == 0 ? 0.0 : (montant / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 92, child: TypeChip(type)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFEDF0F5),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: MoneyText(montant,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
