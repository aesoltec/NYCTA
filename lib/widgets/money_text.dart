import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../data/store.dart';

/// Montant qui ne déborde JAMAIS : FittedBox + devise dynamique
/// (celle configurée dans l'écran Configuration).
class MoneyText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  const MoneyText(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<Store>().profile.devise;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        C.money(value, devise),
        maxLines: 1,
        softWrap: false,
        style: style ?? const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
