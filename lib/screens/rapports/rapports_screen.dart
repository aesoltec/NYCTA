import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/type_chip.dart';

/// Rapports : synthèse globale, par activité, par boutique, frais MoMo.
class RapportsScreen extends StatelessWidget {
  const RapportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final caParType = store.caParType;
    final total = caParType.values.fold(0.0, (a, b) => a + b);
    final fraisMoMo = store.fraisMoMoMois;

    // Poussé via Navigator.push(MaterialPageRoute(builder: (_) => destination))
    // depuis le menu « Plus », sans Scaffold englobant : cet écran DOIT
    // fournir le sien, sinon aucune surface n'est peinte derrière lui et le
    // fond apparaît noir/sombre à la place du thème clair de l'app.
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      backgroundColor: const Color(0xFFD5F0F0),
      body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CA total (mois)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              MoneyText(total, style: const TextStyle(fontSize: 18)),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Marge (mois)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              MoneyText(store.margeMois, style: const TextStyle(fontSize: 18)),
            ]),
          )),
        ]),
        const SizedBox(height: 16),
        Text('Par activité', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in caParType.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: TypeChip(e.key)),
                  const SizedBox(width: 10),
                  MoneyText(e.value, style: const TextStyle(fontSize: 14)),
                ]),
              ),
            if (caParType.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Pas de données ce mois-ci',
                    style: TextStyle(color: Colors.grey)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Frais Mobile Money gagnés (mois)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in fraisMoMo.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  MoneyText(e.value, style: const TextStyle(fontSize: 14, color: Color(0xFF3E9D8F))),
                ]),
              ),
            if (fraisMoMo.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Aucune transaction Mobile Money ce mois-ci',
                    style: TextStyle(color: Colors.grey)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('CA par jour (30 derniers jours)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(children: [
            for (final e in store.caParJour.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 52,
                    child: Text(e.key,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (e.value /
                                (store.caParJour.values.fold(0.0, (a, b) => a > b ? a : b) == 0
                                    ? 1
                                    : store.caParJour.values.fold(0.0, (a, b) => a > b ? a : b)))
                            .clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: const Color(0xFFEDF0F5),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF3D6FB4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: MoneyText(e.value, style: const TextStyle(fontSize: 11.5)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Toutes les boutiques', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final b in store.boutiques)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.storefront_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.nom,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                MoneyText(
                  store.transactions
                      .where((t) => t.boutiqueId == b.id && C.moisKey(t.date) == store.moisCourant)
                      .fold(0.0, (s, t) => s + t.montant),
                  style: const TextStyle(fontSize: 14),
                ),
              ]),
            ),
          ),
      ],
      ),
    );
  }
}
