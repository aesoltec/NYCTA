import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/ecriture.dart';
import '../../models/enums.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../widgets/soft_card.dart';

/// Comptabilité SYSCOHADA simplifiée (mission §3.3/§4) : journal immuable,
/// balance par compte, compte de résultat. Lecture réservée aux rôles
/// financiers (voirRapports) ; écritures générées par l'app uniquement.
class ComptaScreen extends StatelessWidget {
  const ComptaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comptabilité'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Journal', icon: Icon(Icons.book_outlined)),
            Tab(text: 'Balance', icon: Icon(Icons.balance_outlined)),
            Tab(text: 'Résultat', icon: Icon(Icons.pie_chart_outline)),
          ]),
        ),
        body: const TabBarView(children: [
          _Journal(),
          _Balance(),
          _Resultat(),
        ]),
      ),
    );
  }
}

class _Journal extends StatefulWidget {
  const _Journal();
  @override
  State<_Journal> createState() => _JournalState();
}

class _JournalState extends State<_Journal> {
  String _journal = 'tous';
  String _recherche = '';

  static const _journaux = [
    ('tous', 'Tous'),
    ('VT', 'Ventes'),
    ('AC', 'Achats'),
    ('BQ', 'Banque/Caisse'),
    ('OD', 'Opérations diverses'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var lignes = store.ecrituresBoutique.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (_journal != 'tous') {
      lignes = lignes.where((e) => e.journal == _journal).toList();
    }
    final rech = _recherche.trim().toLowerCase();
    if (rech.isNotEmpty) {
      lignes = lignes
          .where((e) =>
              e.libelle.toLowerCase().contains(rech) ||
              e.compte.contains(rech))
          .toList();
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(
              hintText: 'Rechercher (libellé, compte)…',
              prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _recherche = v),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _journaux.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(_journaux[i].$2),
            selected: _journal == _journaux[i].$1,
            onSelected: (_) =>
                setState(() => _journal = _journaux[i].$1),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: lignes.isEmpty
            ? const EmptyView(
                icon: Icons.book_outlined,
                message: 'Aucune écriture',
                hint:
                    'Les ventes, achats, paiements et charges génèrent le journal automatiquement')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: lignes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = lignes[i];
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
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e.journal,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D47A1))),
                      ),
                      title: Text(e.libelle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      subtitle: Text(
                        '${e.compte} · ${PlanComptable.libelle(e.compte)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (e.debit > 0)
                            MoneyText(e.debit,
                                style: const TextStyle(fontSize: 13)),
                          if (e.credit > 0)
                            MoneyText(e.credit,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3E9D8F))),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _Balance extends StatelessWidget {
  const _Balance();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final entrees = store.balance.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final totalD = entrees
        .where((e) => e.value > 0)
        .fold(0.0, (s, e) => s + e.value);
    final totalC = entrees
        .where((e) => e.value < 0)
        .fold(0.0, (s, e) => s - e.value);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SoftCard(
          child: Row(children: [
            Expanded(
                child: _Chiffre(
                    label: 'Total débits',
                    valeur: totalD,
                    couleur: const Color(0xFF0D47A1))),
            Expanded(
                child: _Chiffre(
                    label: 'Total crédits',
                    valeur: totalC,
                    couleur: const Color(0xFF3E9D8F))),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Équilibre',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                    Text(
                        (totalD - totalC).abs() < 0.01
                            ? '✅ Équilibrée'
                            : '❌ Écart',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: (totalD - totalC).abs() < 0.01
                                ? const Color(0xFF3E9D8F)
                                : const Color(0xFFC62828))),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (entrees.isEmpty)
          const EmptyView(
              icon: Icons.balance_outlined,
              message: 'Balance vide',
              hint: 'Les écritures du journal alimentent la balance'),
        for (final e in entrees)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: ListTile(
              dense: true,
              title: Text(
                  '${e.key} · ${PlanComptable.libelle(e.key)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              trailing: MoneyText(e.value.abs(),
                  style: TextStyle(
                      fontSize: 13,
                      color: e.value >= 0
                          ? const Color(0xFF0D47A1)
                          : const Color(0xFF3E9D8F))),
            ),
          ),
      ],
    );
  }
}

class _Resultat extends StatelessWidget {
  const _Resultat();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    var produits = 0.0, charges = 0.0;
    final lignesP = <MapEntry<String, double>>[];
    final lignesC = <MapEntry<String, double>>[];
    for (final e in store.balance.entries) {
      if (e.key.startsWith('7')) {
        produits += -e.value;
        lignesP.add(MapEntry(e.key, -e.value));
      } else if (e.key.startsWith('6')) {
        charges += e.value;
        lignesC.add(MapEntry(e.key, e.value));
      }
    }
    final resultat = produits - charges;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SoftCard(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D47A1),
              const Color(0xFF0D47A1).withValues(alpha: 0.75)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Résultat de l\'exercice',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                MoneyText(resultat,
                    style: TextStyle(
                        color: resultat >= 0
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFF87171),
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                Text(
                    'Produits − Charges (comptes 7 − comptes 6)',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
              ]),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(children: [
            _LigneRes(
                label: 'Produits (classe 7)',
                valeur: produits,
                couleur: const Color(0xFF3E9D8F)),
            for (final l in lignesP)
              _LigneRes(
                  label: '  ${l.key} · ${PlanComptable.libelle(l.key)}',
                  valeur: l.value,
                  mineur: true),
            const Divider(height: 20),
            _LigneRes(
                label: 'Charges (classe 6)',
                valeur: charges,
                couleur: const Color(0xFFC62828)),
            for (final l in lignesC)
              _LigneRes(
                  label: '  ${l.key} · ${PlanComptable.libelle(l.key)}',
                  valeur: l.value,
                  mineur: true),
          ]),
        ),
      ],
    );
  }
}

class _Chiffre extends StatelessWidget {
  final String label;
  final double valeur;
  final Color couleur;
  const _Chiffre(
      {required this.label, required this.valeur, required this.couleur});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          MoneyText(valeur,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: couleur)),
        ],
      );
}

class _LigneRes extends StatelessWidget {
  final String label;
  final double valeur;
  final Color? couleur;
  final bool mineur;
  const _LigneRes(
      {required this.label,
      required this.valeur,
      this.couleur,
      this.mineur = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: mineur ? 12 : 13.5,
                      fontWeight:
                          mineur ? FontWeight.w400 : FontWeight.w800,
                      color: mineur ? Colors.grey.shade700 : null))),
          MoneyText(valeur,
              style: TextStyle(
                  fontSize: mineur ? 12.5 : 14,
                  fontWeight: FontWeight.w700,
                  color: couleur)),
        ]),
      );
}
