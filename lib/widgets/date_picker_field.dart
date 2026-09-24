import 'package:flutter/material.dart';

/// Sélecteur de date robuste et universel (Phase 1).
///
/// Garanties :
/// - `initialDate` toujours clampée dans `[firstDate, lastDate]` (un
///   `initialDate` hors plage fait refuser le picker natif).
/// - Fonctionne avec la locale de l'app (délégués FR déclarés dans
///   `main.dart`) ; `locale` explicite en repli.
/// - Échec du picker natif (exception) → saisie manuelle JJ/MM/AAAA.
/// - Bouton clavier permanent : saisie manuelle toujours disponible.
/// - Validation calendaire réelle (30/02/2024 refusé, 29/02/2024 accepté).
String formatDateSaisie(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Borne une date dans l'intervalle (inclusive).
DateTime clamperDate(DateTime valeur, DateTime first, DateTime last) {
  if (valeur.isBefore(first)) return first;
  if (valeur.isAfter(last)) return last;
  return valeur;
}

/// Parse strict JJ/MM/AAAA avec validation calendaire réelle.
/// Retourne null si format ou date invalide.
DateTime? parseDateSaisie(String saisie) {
  final m =
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(saisie.trim());
  if (m == null) return null;
  final j = int.parse(m.group(1)!);
  final mois = int.parse(m.group(2)!);
  final an = int.parse(m.group(3)!);
  if (an < 1900 || an > 2200) return null;
  if (mois < 1 || mois > 12) return null;
  final maxJ = DateTime(an, mois + 1, 0).day;
  if (j < 1 || j > maxJ) return null;
  return DateTime(an, mois, j);
}

/// Validateur de champ : null si OK, sinon message d'erreur en français.
String? validerDateSaisie(String? saisie,
    {required DateTime firstDate, required DateTime lastDate}) {
  final s = (saisie ?? '').trim();
  if (s.isEmpty) return 'Date requise (JJ/MM/AAAA)';
  final d = parseDateSaisie(s);
  if (d == null) return 'Date invalide (JJ/MM/AAAA, ex : 05/09/2026)';
  if (d.isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day))) {
    return 'Date trop ancienne (min : ${formatDateSaisie(firstDate)})';
  }
  if (d.isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day))) {
    return 'Date trop éloignée (max : ${formatDateSaisie(lastDate)})';
  }
  return null;
}

/// Dialogue de saisie manuelle JJ/MM/AAAA. Retourne la date ou null.
Future<DateTime?> saisirDateManuelle(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initiale,
}) async {
  final ctrl = TextEditingController(
      text: initiale == null ? '' : formatDateSaisie(initiale));
  final key = GlobalKey<FormState>();
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: const Text('Saisir la date'),
      content: Form(
        key: key,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'Date (JJ/MM/AAAA)',
            helperText:
                'Entre ${formatDateSaisie(firstDate)} et ${formatDateSaisie(lastDate)}',
            prefixIcon: const Icon(Icons.edit_calendar_outlined),
          ),
          validator: (v) => validerDateSaisie(v,
              firstDate: firstDate, lastDate: lastDate),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!key.currentState!.validate()) return;
            Navigator.pop(ctx, parseDateSaisie(ctrl.text));
          },
          child: const Text('Valider'),
        ),
      ],
    ),
  );
}

/// Ouvre le picker natif de façon robuste : clamp + locale + repli manuel
/// en cas d'exception. Retourne null si l'utilisateur annule.
Future<DateTime?> choisirDateRobuste(
  BuildContext context, {
  required DateTime valeur,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final initial = clamperDate(valeur, firstDate, lastDate);
  try {
    return await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('fr', 'FR'),
    );
  } catch (_) {
    // Picker natif indisponible (thème/locale incomplets sur la
    // plateforme) : la saisie n'est jamais bloquée.
    if (!context.mounted) return null;
    return saisirDateManuelle(context,
        firstDate: firstDate, lastDate: lastDate, initiale: initial);
  }
}

/// Champ de sélection de date : affichage + calendrier + saisie manuelle.
///
/// `valeur == null` affiche [texteVide] ; [effacable] ajoute une croix pour
/// réinitialiser à null (ex : rappel optionnel d'une note).
class DatePickerField extends StatelessWidget {
  final DateTime? valeur;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final String texteVide;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool effacable;
  const DatePickerField({
    super.key,
    required this.valeur,
    required this.onChanged,
    this.label = 'Date',
    this.texteVide = 'Choisir une date',
    this.firstDate,
    this.lastDate,
    this.effacable = false,
  });

  static DateTime get _defautDebut => DateTime(2000, 1, 1);
  static DateTime get _defautFin => DateTime(2100, 12, 31);

  @override
  Widget build(BuildContext context) {
    final debut = firstDate ?? _defautDebut;
    final fin = lastDate ?? _defautFin;
    final v = valeur;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final choix = await choisirDateRobuste(context,
            valeur: v ?? DateTime.now(), firstDate: debut, lastDate: fin);
        if (choix != null) onChanged(choix);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (v != null && effacable)
              IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onChanged(null),
              ),
            IconButton(
              tooltip: 'Saisir au clavier (JJ/MM/AAAA)',
              icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
              onPressed: () async {
                final choix = await saisirDateManuelle(context,
                    firstDate: debut, lastDate: fin, initiale: v);
                if (choix != null) onChanged(choix);
              },
            ),
          ]),
        ),
        child: Text(
          v == null ? texteVide : formatDateSaisie(v),
          style: TextStyle(
              fontSize: 15,
              fontWeight: v == null ? FontWeight.normal : FontWeight.w600,
              color: v == null ? Colors.grey.shade500 : null),
        ),
      ),
    );
  }
}
