import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  const EmptyView({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        // Scroll plutôt qu'overflow : quand la zone disponible rétrécit
        // (gros TextScaler + en-tête de filtres haut), le contenu défile
        // au lieu de lever « RenderFlex overflowed ».
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
