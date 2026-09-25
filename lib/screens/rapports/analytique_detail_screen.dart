import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';

/// Détail d'une période analytique : opérations filtrées, recherchées,
/// triées (mission 3, §3.1/3.2).
class AnalytiqueDetailScreen extends StatefulWidget {
  final bool depenses;
  final String titre;
  final DateTime debut;
  final DateTime fin;
  const AnalytiqueDetailScreen({
    super.key,
    required this.depenses,
    required this.titre,
    required this.debut,
    required this.fin,
  });

  @override
  State<AnalytiqueDetailScreen> createState() => _AnalytiqueDetailScreenState();
}

class _AnalytiqueDetailScreenState extends State<AnalytiqueDetailScreen> {
  String? _type; // TypeTransaction.name ou catégorie de charge
  String _recherche = '';
  final _min = TextEditingController();
  final _max = TextEditingController();
  String? _boutiqueId; // null = toutes les boutiques accessibles
  int _tri = 0; // 0 date ↓, 1 date ↑, 2 montant ↓, 3 montant ↑
  DateTime? _debut;
  DateTime? _fin;

  @override
  void initState() {
    super.initState();
    _debut = widget.debut;
    _fin = widget.fin;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final boutiques = store.boutiquesAccessibles;
    final min = double.tryParse(
            _min.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ??
        0;
    final max = double.tryParse(
            _max.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ??
        double.infinity;
    final rech = _recherche.trim().toLowerCase();

    List<_Ligne> lignes;
    if (widget.depenses) {
      lignes = [
        for (final c in store.depenses)
          if (_dansPlage(c.date) &&
              (_boutiqueId == null || c.boutiqueId == _boutiqueId) &&
              (_type == null || c.categorie == _type) &&
              c.montant >= min &&
              c.montant <= max &&
              (rech.isEmpty ||
                  c.libelle.toLowerCase().contains(rech) ||
                  c.categorie.toLowerCase().contains(rech)))
            _Ligne(
                date: c.date,
                titre: c.libelle,
                sousTitre: c.categorie,
                montant: c.montant),
      ];
    } else {
      lignes = [
        for (final t in store.transactions)
          if (_dansPlage(t.date) &&
              (_boutiqueId == null || t.boutiqueId == _boutiqueId) &&
              (_type == null || t.type.name == _type) &&
              t.montant >= min &&
              t.montant <= max &&
              (rech.isEmpty ||
                  (t.clientNom ?? '').toLowerCase().contains(rech) ||
                  _libelleType(t.type).toLowerCase().contains(rech)))
            _Ligne(
                date: t.date,
                titre: t.clientNom?.isNotEmpty == true
                    ? t.clientNom!
                    : _libelleType(t.type),
                sousTitre: _libelleType(t.type),
                montant: t.montant),
      ];
    }
    lignes.sort((a, b) => switch (_tri) {
          1 => a.date.compareTo(b.date),
          2 => b.montant.compareTo(a.montant),
          3 => a.montant.compareTo(b.montant),
          _ => b.date.compareTo(a.date),
        });
    final total = lignes.fold(0.0, (s, l) => s + l.montant);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        actions: [
          IconButton(
            tooltip: 'Exporter en CSV (Excel)',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: lignes.isEmpty
                ? null
                : () => _exporterCsv(context, lignes, total),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FiltreChip(
                label: widget.depenses ? 'Catégorie' : 'Type',
                valeur: _type,
                options: widget.depenses
                    ? store.catsCharge
                    : [
                        for (final t in TypeTransaction.values) t.name
                      ],
                libelle: (v) => widget.depenses
                    ? v
                    : _libelleType(TypeTransaction.values.byName(v)),
                onChoisir: (v) => setState(() => _type = v),
              ),
              const SizedBox(width: 8),
              _FiltreChip(
                label: 'Boutique',
                valeur: _boutiqueId,
                options: [for (final b in boutiques) b.id],
                libelle: (v) => boutiques
                    .where((b) => b.id == v)
                    .firstOrNull
                    ?.nom ??
                    v,
                onChoisir: (v) => setState(() => _boutiqueId = v),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(switch (_tri) {
                  1 => 'Date ↑',
                  2 => 'Montant ↓',
                  3 => 'Montant ↑',
                  _ => 'Date ↓',
                }),
                selected: true,
                onSelected: (_) =>
                    setState(() => _tri = (_tri + 1) % 4),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(
              child: TextFormField(
                controller: _min,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Min'),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  return V.prix(v, label: 'Min');
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _max,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Max'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DatePickerField(
                valeur: _debut,
                label: 'Début',
                onChanged: (d) => setState(() => _debut = d),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DatePickerField(
                valeur: _fin,
                label: 'Fin',
                onChanged: (d) => setState(() => _fin = d),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Text('${lignes.length} opération(s)',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            MoneyText(total,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: lignes.isEmpty
              ? const EmptyView(
                  icon: Icons.search_off_outlined,
                  message: 'Aucun résultat',
                  hint: 'Élargissez les filtres')
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: lignes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final l = lignes[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 8,
                              offset: Offset(0, 3))
                        ],
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(l.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                        subtitle: Text(
                          '${l.date.day.toString().padLeft(2, '0')}/${l.date.month.toString().padLeft(2, '0')}/${l.date.year} · ${l.sousTitre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),
                        trailing: MoneyText(l.montant,
                            style:
                                const TextStyle(fontSize: 13)),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  bool _dansPlage(DateTime d) {
    final debut = _debut, fin = _fin;
    if (debut != null && d.isBefore(debut)) return false;
    if (fin != null && d.isAfter(fin)) return false;
    return true;
  }

  /// Export CSV (Excel, séparateur `;`, BOM UTF-8) de la vue filtrée.
  Future<void> _exporterCsv(
      BuildContext context, List<_Ligne> lignes, double total) async {
    final tampon = StringBuffer()
      ..writeln('﻿Date;Libellé;Détail;Montant')
      ..writeln('Période;${widget.titre};;');
    for (final l in lignes) {
      final date =
          '${l.date.day.toString().padLeft(2, '0')}/${l.date.month.toString().padLeft(2, '0')}/${l.date.year}';
      tampon.writeln(
          '$date;${_csv(l.titre)};${_csv(l.sousTitre)};${l.montant.toStringAsFixed(0)}');
    }
    tampon.writeln('TOTAL;;;${total.toStringAsFixed(0)}');
    try {
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/analytique_${DateTime.now().millisecondsSinceEpoch}.csv');
      await f.writeAsString(tampon.toString(), flush: true);
      await SharePlus.instance
          .share(ShareParams(files: [XFile(f.path)], text: widget.titre));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Export impossible')));
      }
    }
  }

  static String _csv(String s) => '"${s.replaceAll('"', '""')}"';

  String _libelleType(TypeTransaction t) =>
      C.infosTypes[t]?.$1 ?? t.name;
}

class _Ligne {
  final DateTime date;
  final String titre;
  final String sousTitre;
  final double montant;
  const _Ligne(
      {required this.date,
      required this.titre,
      required this.sousTitre,
      required this.montant});
}

class _FiltreChip extends StatelessWidget {
  final String label;
  final String? valeur;
  final List<String> options;
  final String Function(String) libelle;
  final ValueChanged<String?> onChoisir;
  const _FiltreChip({
    required this.label,
    required this.valeur,
    required this.options,
    required this.libelle,
    required this.onChoisir,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(valeur == null ? label : libelle(valeur!)),
        selected: valeur != null,
        onSelected: (_) async {
          final choix = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => ListView(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                ListTile(
                  title: const Text('Tous'),
                  trailing: valeur == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(ctx, null),
                ),
                for (final o in options)
                  ListTile(
                    title: Text(libelle(o),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: valeur == o
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, o),
                  ),
              ],
            ),
          );
          onChoisir(choix);
        },
      );
}
