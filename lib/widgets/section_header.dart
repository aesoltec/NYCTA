import 'package:flutter/material.dart';

/// En-tête de section : titre + compteur/action optionnels.
/// Unifie la hiérarchie visuelle des écrans (dashboard, journal, stock…).
class SectionHeader extends StatelessWidget {
  final String titre;
  final String? compteur;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({
    super.key,
    required this.titre,
    this.compteur,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (compteur != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(compteur!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
              ),
            ],
          ]),
        ),
        if (actionLabel != null)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ]),
    );
  }
}
