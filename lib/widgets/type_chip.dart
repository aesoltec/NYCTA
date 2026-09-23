import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/transaction.dart';

/// Pastille d'activité : icône colorée + libellé, sûre en petit espace.
class TypeChip extends StatelessWidget {
  final TypeTransaction type;
  const TypeChip(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = C.infosTypes[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
