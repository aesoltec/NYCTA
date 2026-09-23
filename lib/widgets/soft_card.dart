import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Carte pro : fond blanc, fine bordure, ombre feutrée, coins 20.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final Gradient? gradient;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: gradient == null
            ? Border.all(color: AppTheme.bordure)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}
