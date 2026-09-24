import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/mouvement_stock.dart';
import '../../widgets/empty_view.dart';

/// Historique des mouvements de stock (mission 1, §1.3) : entrées,
/// sorties, ajustements, retours — avec auteur, motif et stock résultant.
class MouvementsScreen extends StatefulWidget {
  final String? produitId; // filtré sur un produit si fourni
  const MouvementsScreen({super.key, this.produitId});

  @override
  State<MouvementsScreen> createState() => _MouvementsScreenState();
}

class _MouvementsScreenState extends State<MouvementsScreen> {
  String _filtreType = 'tous';
  String _recherche = '';

  static const _types = [
    ('tous', 'Tous'),
    (MouvementStock.entree, 'Entrées'),
    (MouvementStock.sortie, 'Sorties'),
    (MouvementStock.ajustement, 'Ajustements'),
    (MouvementStock.retour, 'Retours'),
    (MouvementStock.inventaire, 'Inventaires'),
  ];

  static const _couleurs = {
    MouvementStock.entree: Color(0xFF3E9D8F),
    MouvementStock.sortie: Color(0xFFEF6C00),
    MouvementStock.ajustement: Color(0xFF7E57C2),
    MouvementStock.retour: Color(0xFF3D6FB4),
    MouvementStock.inventaire: Color(0xFF00838F),
  };

  static const _icones = {
    MouvementStock.entree: Icons.arrow_downward_rounded,
    MouvementStock.sortie: Icons.arrow_upward_rounded,
    MouvementStock.ajustement: Icons.tune_rounded,
    MouvementStock.retour: Icons.undo_rounded,
    MouvementStock.inventaire: Icons.fact_check_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var liste = widget.produitId == null
        ? store.mouvementsBoutique
        : store.mouvementsProduit(widget.produitId!);
    liste = liste.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (_filtreType != 'tous') {
      liste = liste.where((m) => m.type == _filtreType).toList();
    }
    final rech = _recherche.trim().toLowerCase();
    if (rech.isNotEmpty) {
      liste = liste
          .where((m) =>
              m.produitNom.toLowerCase().contains(rech) ||
              m.motif.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Rechercher (produit, motif)…',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_types[i].$2),
              selected: _filtreType == _types[i].$1,
              onSelected: (_) =>
                  setState(() => _filtreType = _types[i].$1),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: liste.isEmpty
              ? const EmptyView(
                  icon: Icons.swap_vert_rounded,
                  message: 'Aucun mouvement',
                  hint:
                      'Ventes, réceptions, documents et ajustements apparaissent ici')
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: liste.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = liste[i];
                    final couleur =
                        _couleurs[m.type] ?? Colors.grey;
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
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: couleur.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(12)),
                          child: Icon(_icones[m.type] ??
                              Icons.swap_horiz_rounded,
                              size: 18, color: couleur),
                        ),
                        title: Text(m.produitNom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}'
                          '${m.motif.isNotEmpty ? ' · ${m.motif}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                '${m.quantite > 0 ? '+' : ''}${m.quantite}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: couleur)),
                            Text('→ ${m.stockApres}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
