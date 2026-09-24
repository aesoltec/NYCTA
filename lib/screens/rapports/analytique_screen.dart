import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/analytique.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';
import 'analytique_detail_screen.dart';

/// Analytique CA & dépenses (mission 3, §3.1/3.2) : 7 derniers jours,
/// mois de l'année, années — indicateurs, comparaison période précédente,
/// détail filtrable au tap.
class AnalytiqueScreen extends StatelessWidget {
  const AnalytiqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytique'),
          bottom: const TabBar(tabs: [
            Tab(text: "Chiffre d'affaires", icon: Icon(Icons.trending_up)),
            Tab(text: 'Dépenses', icon: Icon(Icons.trending_down)),
          ]),
        ),
        body: const TabBarView(children: [
          _Panneau(depenses: false),
          _Panneau(depenses: true),
        ]),
      ),
    );
  }
}

class _Panneau extends StatefulWidget {
  final bool depenses;
  const _Panneau({required this.depenses});

  @override
  State<_Panneau> createState() => _PanneauState();
}

class _PanneauState extends State<_Panneau> {
  int _periode = 0; // 0 = 7 jours, 1 = mois, 2 = années
  int? _annee;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final annees = store.anneesDonnees();
    final anneeCourante = DateTime.now().year;
    _annee ??= annees.contains(anneeCourante)
        ? anneeCourante
        : (annees.isNotEmpty ? annees.last : anneeCourante);

    final List<AgregatPeriode> serie;
    final List<AgregatPeriode> precedente;
    switch (_periode) {
      case 1:
        serie = widget.depenses
            ? store.depensesParMois(_annee!)
            : store.caParMois(_annee!);
        precedente = widget.depenses
            ? store.depensesParMois(_annee! - 1)
            : store.caParMois(_annee! - 1);
      case 2:
        serie = widget.depenses
            ? store.depensesParAnnee()
            : store.caParAnnee();
        precedente = const [];
      default:
        serie = widget.depenses ? store.depenses7Jours() : store.ca7Jours();
        precedente = widget.depenses
            ? store.depenses7Jours(
                fin: DateTime.now().subtract(const Duration(days: 7)))
            : store.ca7Jours(
                fin: DateTime.now().subtract(const Duration(days: 7)));
    }
    final total = serie.fold(0.0, (s, e) => s + e.montant);
    final totalPrec = precedente.fold(0.0, (s, e) => s + e.montant);
    final nb = serie.fold(0, (s, e) => s + e.nb);
    final nonNuls = serie.where((e) => e.montant > 0).toList();
    final max = serie.fold(
        0.0, (a, e) => e.montant > a ? e.montant : a);
    final varPct = _periode == 2 ? null : variationPct(total, totalPrec);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('7 jours')),
            ButtonSegment(value: 1, label: Text('Mois')),
            ButtonSegment(value: 2, label: Text('Années')),
          ],
          selected: {_periode},
          onSelectionChanged: (s) =>
              setState(() => _periode = s.first),
        ),
        if (_periode == 1) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _annee,
            decoration:
                const InputDecoration(labelText: 'Année'),
            items: [
              for (final a in {
                ...annees,
                anneeCourante,
                _annee!
              }.toList()
                ..sort())
                DropdownMenuItem(value: a, child: Text('$a')),
            ],
            onChanged: (v) => setState(() => _annee = v!),
          ),
        ],
        const SizedBox(height: 12),
        SoftCard(
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _Indicateur(
                      label: 'Total',
                      valeur: MoneyText(total,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800)))),
              Expanded(
                  child: _Indicateur(
                      label: nb == 0
                          ? 'Opérations'
                          : 'Moyenne / op.',
                      valeur: Text(
                          nb == 0
                              ? '0'
                              : _montantCourt(total / nb, context),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)))),
            ]),
            if (varPct != null) ...[
              const SizedBox(height: 8),
              _Comparaison(variation: varPct),
            ],
            if (nonNuls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Fort : ${nonNuls.reduce((a, b) => a.montant >= b.montant ? a : b).label}'
                ' · Faible : ${nonNuls.reduce((a, b) => a.montant <= b.montant ? a : b).label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(children: [
            for (final e in serie)
              _LignePeriode(
                agregat: e,
                max: max,
                depenses: widget.depenses,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => AnalytiqueDetailScreen(
                              depenses: widget.depenses,
                              titre:
                                  '${widget.depenses ? 'Dépenses' : 'CA'} — ${e.label}',
                              debut: e.debut,
                              fin: _finPeriode(e),
                            ))),
              ),
          ]),
        ),
      ],
    );
  }

  DateTime _finPeriode(AgregatPeriode e) {
    if (_periode == 1) {
      final suivant =
          e.debut.month == 12 ? DateTime(e.debut.year + 1) : DateTime(e.debut.year, e.debut.month + 1);
      return suivant.subtract(const Duration(seconds: 1));
    }
    if (_periode == 2) {
      return DateTime(e.debut.year + 1).subtract(const Duration(seconds: 1));
    }
    return DateTime(e.debut.year, e.debut.month, e.debut.day, 23, 59, 59);
  }

  String _montantCourt(double v, BuildContext context) =>
      '${v.toStringAsFixed(0)} ${context.read<Store>().profile.devise}';
}

class _Indicateur extends StatelessWidget {
  final String label;
  final Widget valeur;
  const _Indicateur({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          valeur,
        ],
      );
}

class _Comparaison extends StatelessWidget {
  final double variation;
  const _Comparaison({required this.variation});

  @override
  Widget build(BuildContext context) {
    final positive = variation >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (positive
                ? const Color(0xFF3E9D8F)
                : const Color(0xFFC62828))
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${positive ? '+' : ''}${variation.toStringAsFixed(1)} % vs période précédente',
        style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: positive
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828)),
      ),
    );
  }
}

class _LignePeriode extends StatelessWidget {
  final AgregatPeriode agregat;
  final double max;
  final bool depenses;
  final VoidCallback onTap;
  const _LignePeriode(
      {required this.agregat,
      required this.max,
      required this.depenses,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: agregat.nb == 0 ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Text(agregat.label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: max == 0
                      ? 0
                      : (agregat.montant / max).clamp(0.0, 1.0),
                  minHeight: 14,
                  backgroundColor: const Color(0xFFEDF0F5),
                  valueColor: AlwaysStoppedAnimation(depenses
                      ? const Color(0xFFEF6C00)
                      : const Color(0xFF3D6FB4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: MoneyText(agregat.montant,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}
