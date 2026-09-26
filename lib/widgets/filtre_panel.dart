import 'package:flutter/material.dart';
import 'date_picker_field.dart';

/// Types de filtres supportés par [FiltrePanel].
enum FiltreKind {
  /// Champ de recherche libre (valeur : String).
  recherche,
  /// Choix unique horizontal (valeur : String? — `null` = « Tous » si
  /// l'option `('', 'Tous')` est fournie).
  chips,
  /// Liste déroulante (valeur : String?).
  dropdown,
  /// Plage de dates Début/Fin (valeurs : `debut`, `fin` → DateTime?).
  dates,
  /// Intervalle de montants Min/Max (valeurs : `min`, `max` → String brut,
  /// le parse FR est à la charge de l'appelant).
  minMax,
}

/// Un filtre du panneau : `cle` = clé dans la map de valeurs (sauf
/// [FiltreKind.dates] → `debut`/`fin` et [FiltreKind.minMax] → `min`/`max`,
/// préfixés par `cle` si `cle` est non vide : `${cle}_debut`…).
class FiltreConfig {
  final String cle;
  final FiltreKind kind;
  final String label;
  final List<(String, String)> options;
  const FiltreConfig({
    required this.cle,
    required this.kind,
    required this.label,
    this.options = const [],
  });
}

/// Panneau de filtres UNIFIÉ (MISSION 25bis) : recherche, chips, dropdown,
/// dates, min/max — responsive (2 lignes en étroit < 560px).
/// Émet la map complète à chaque changement via [onFiltreChange].
class FiltrePanel extends StatefulWidget {
  final List<FiltreConfig> filtres;
  final Map<String, dynamic> valeurs;
  final ValueChanged<Map<String, dynamic>> onFiltreChange;
  const FiltrePanel({
    super.key,
    required this.filtres,
    this.valeurs = const {},
    required this.onFiltreChange,
  });

  @override
  State<FiltrePanel> createState() => _FiltrePanelState();
}

class _FiltrePanelState extends State<FiltrePanel> {
  late Map<String, dynamic> _v;
  final _min = TextEditingController();
  final _max = TextEditingController();

  String _k(FiltreConfig c, String suffix) =>
      c.cle.isEmpty ? suffix : '${c.cle}_$suffix';

  @override
  void initState() {
    super.initState();
    _v = Map<String, dynamic>.from(widget.valeurs);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _emettre() => widget.onFiltreChange(Map<String, dynamic>.from(_v));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in widget.filtres) ...[
          _construire(f),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _construire(FiltreConfig f) {
    switch (f.kind) {
      case FiltreKind.recherche:
        return TextField(
          decoration: InputDecoration(
            hintText: f.label,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
          ),
          onChanged: (v) {
            _v[f.cle] = v;
            _emettre();
          },
        );
      case FiltreKind.chips:
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final o in f.options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(o.$2),
                    selected: (_v[f.cle] as String?) == o.$1,
                    onSelected: (_) {
                      setState(() => _v[f.cle] = o.$1);
                      _emettre();
                    },
                  ),
                ),
            ],
          ),
        );
      case FiltreKind.dropdown:
        return DropdownButtonFormField<String>(
          value: _v[f.cle] as String?,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: f.label,
              prefixIcon: const Icon(Icons.filter_alt_outlined)),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('Toutes')),
            for (final o in f.options)
              DropdownMenuItem(value: o.$1, child: Text(o.$2)),
          ],
          onChanged: (v) {
            setState(() => _v[f.cle] = v);
            _emettre();
          },
        );
      case FiltreKind.dates:
        final kD = _k(f, 'debut');
        final kF = _k(f, 'fin');
        Widget champDebut() => DatePickerField(
              valeur: _v[kD] as DateTime?,
              label: 'Début',
              onChanged: (d) {
                setState(() => _v[kD] = d);
                _emettre();
              },
            );
        Widget champFin() => DatePickerField(
              valeur: _v[kF] as DateTime?,
              label: 'Fin',
              onChanged: (d) {
                setState(() => _v[kF] = d);
                _emettre();
              },
            );
        // Écrans étroits (< 560px) : empilés, jamais côte à côte.
        return LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth < 560) {
            return Column(children: [
              champDebut(),
              const SizedBox(height: 8),
              champFin(),
            ]);
          }
          return Row(children: [
            Expanded(child: champDebut()),
            const SizedBox(width: 10),
            Expanded(child: champFin()),
          ]);
        });
      case FiltreKind.minMax:
        final kMin = _k(f, 'min');
        final kMax = _k(f, 'max');
        return Row(children: [
          Expanded(
            child: TextFormField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: const InputDecoration(labelText: 'Min'),
              onChanged: (v) {
                _v[kMin] = v;
                _emettre();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _max,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: const InputDecoration(labelText: 'Max'),
              onChanged: (v) {
                _v[kMax] = v;
                _emettre();
              },
            ),
          ),
        ]);
    }
  }
}
