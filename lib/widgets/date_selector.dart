import 'package:flutter/material.dart';

/// Sélecteur de date de saisie réutilisé par tous les formulaires
/// (ventes, dépenses, documents, vente stock, espace partenaire).
///
/// Principe terrain : on doit pouvoir saisir aujourd'hui une opération
/// d'hier ou d'une date passée. Par défaut, seules aujourd'hui et les
/// dates passées sont proposées ([autoriserFutur] = false).
String formatDateCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ChampDate extends StatelessWidget {
  final DateTime valeur;
  final ValueChanged<DateTime> onChanged;
  final String label;
  final bool autoriserFutur;
  const ChampDate({
    super.key,
    required this.valeur,
    required this.onChanged,
    this.label = 'Date',
    this.autoriserFutur = false,
  });

  bool get _estAujourdhui {
    final m = DateTime.now();
    return valeur.year == m.year &&
        valeur.month == m.month &&
        valeur.day == m.day;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final auj = DateTime.now();
        final choix = await showDatePicker(
          context: context,
          initialDate: valeur.isAfter(auj) && !autoriserFutur ? auj : valeur,
          firstDate: DateTime(2020, 1, 1),
          lastDate: autoriserFutur
              ? DateTime(auj.year + 2, 12, 31)
              : DateTime(auj.year, auj.month, auj.day),
          locale: const Locale('fr', 'FR'),
        );
        if (choix != null) onChanged(choix);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: _estAujourdhui
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Chip(
                    label: Text("Aujourd'hui",
                        style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
        ),
        child: Text(
          formatDateCourt(valeur),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
