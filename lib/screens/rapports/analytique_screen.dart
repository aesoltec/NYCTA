import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/analytique.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';
import 'analytique_detail_screen.dart';

import '../../services/export_service.dart';

/// Analytique CA & dépenses (mission 3, §3.1/3.2) : 7 derniers jours,
/// mois de l'année, années — indicateurs, comparaison période précédente,
/// détail filtrable au tap.
class AnalytiqueScreen extends StatelessWidget {
  /// Onglet initial : 0 = CA, 1 = Dépenses (tuile dashboard).
  final int ongletInitial;
  const AnalytiqueScreen({super.key, this.ongletInitial = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: ongletInitial.clamp(0, 1),
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

  /// Série courante (même calcul que le build — export CSV/Excel/PDF).
  List<AgregatPeriode> _serieCourante(Store store, int annee) {
    switch (_periode) {
      case 1:
        return widget.depenses
            ? store.depensesParMois(annee)
            : store.caParMois(annee);
      case 2:
        return widget.depenses
            ? store.depensesParAnnee()
            : store.caParAnnee();
      default:
        return widget.depenses
            ? store.depenses7Jours()
            : store.ca7Jours();
    }
  }

  String get _nomPeriode => switch (_periode) {
        1 => 'mois_${_annee ?? DateTime.now().year}',
        2 => 'annees',
        _ => '7jours',
      };

  Future<void> _exporter(
      BuildContext context, Store store, String format) async {
    final serie = _serieCourante(store, _annee ?? DateTime.now().year);
    const entetes = [
      'Période', 'Montant', 'Opérations', 'Panier moyen', 'Marge', 'Devise'
    ];
    final lignes = [
      for (final e in serie)
        [
          e.label,
          e.montant,
          e.nb,
          e.panierMoyen,
          e.marge,
          store.profile.devise,
        ],
    ];
    final quoi = widget.depenses ? 'depenses' : 'ca';
    final nom = 'analytique_${quoi}_$_nomPeriode';
    final titre =
        'Analytique ${widget.depenses ? 'dépenses' : 'CA'} — $_nomPeriode';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: titre,
              sousTitre:
                  'Total : ${serie.fold(0.0, (s, e) => s + e.montant).toStringAsFixed(0)} ${store.profile.devise}',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Analytique', entetes, lignes);
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
        Row(children: [
          Expanded(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('7 jours')),
                ButtonSegment(value: 1, label: Text('Mois')),
                ButtonSegment(value: 2, label: Text('Années')),
              ],
              selected: {_periode},
              onSelectionChanged: (s) =>
                  setState(() => _periode = s.first),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Exporter la série',
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
        ]),
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
            if (_periode == 2 && _cagr(serie) != null) ...[
              const SizedBox(height: 8),
              _Comparaison(
                  variation: _cagr(serie)!,
                  prefixe: 'CAGR annuel : '),
            ],
            if (_periode == 1 &&
                cagrMensuelAnnualise(serie) != null) ...[
              const SizedBox(height: 8),
              _Comparaison(
                  variation: cagrMensuelAnnualise(serie)!,
                  prefixe: 'CAGR annualisé : '),
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

  /// Croissance annuelle moyenne (CAGR) sur la série d'années :
  /// (dernier/premier)^(1/nombre d'intervalles) − 1. Null si incalculable.
  double? _cagr(List<AgregatPeriode> serie) {
    final utils =
        serie.where((e) => e.montant > 0).toList();
    if (utils.length < 2) return null;
    final premier = utils.first.montant;
    final dernier = utils.last.montant;
    final intervalles =
        utils.last.debut.year - utils.first.debut.year;
    if (premier <= 0 || intervalles <= 0) return null;
    final ratio = dernier / premier;
    if (ratio <= 0) return null;
    return (pow(ratio, 1 / intervalles) - 1) * 100;
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
  final String prefixe;
  const _Comparaison({required this.variation, this.prefixe = ''});

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
        '$prefixe${positive ? '+' : ''}${variation.toStringAsFixed(1)} %${prefixe.isEmpty ? ' vs période précédente' : ''}',
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
