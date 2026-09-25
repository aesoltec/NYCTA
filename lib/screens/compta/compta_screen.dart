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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comptabilité'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Journal', icon: Icon(Icons.book_outlined)),
              Tab(text: 'Balance', icon: Icon(Icons.balance_outlined)),
              Tab(text: 'Résultat', icon: Icon(Icons.pie_chart_outline)),
              Tab(text: 'TVA', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Âgée', icon: Icon(Icons.hourglass_bottom_outlined)),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _Journal(),
          _Balance(),
          _Resultat(),
          _Tva(),
          _Agee(),
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
  bool _nonRapprochees = false;

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
    if (_nonRapprochees) {
      lignes = lignes.where((e) => !e.pointee).toList();
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
          itemCount: _journaux.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i >= _journaux.length) {
              return FilterChip(
                label: const Text('Non rapprochées'),
                selected: _nonRapprochees,
                onSelected: (v) =>
                    setState(() => _nonRapprochees = v),
              );
            }
            return ChoiceChip(
              label: Text(_journaux[i].$2),
              selected: _journal == _journaux[i].$1,
              onSelected: (_) =>
                  setState(() => _journal = _journaux[i].$1),
            );
          },
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    // Rapprochement bancaire : appui long → pointer /
                    // dépointer l'écriture (retrouvée sur le relevé ou non).
                    onLongPress: () =>
                        _pointer(context, e.id, e.pointee, e.libelle),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: e.pointee
                            ? Border.all(
                                color: const Color(0xFF3E9D8F), width: 1.5)
                            : null,
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
                        title: Row(children: [
                          Expanded(
                            child: Text(e.libelle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          if (e.pointee)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Color(0xFF3E9D8F)),
                            ),
                        ]),
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
                                  style:
                                      const TextStyle(fontSize: 13)),
                            if (e.credit > 0)
                              MoneyText(e.credit,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF3E9D8F))),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  /// Dialogue de rapprochement : pointe/dépointe l'écriture (rôles
  /// financiers). Ne modifie aucun montant — seul le suivi évolue.
  Future<void> _pointer(
      BuildContext context, String id, bool pointee, String libelle) async {
    final store = context.read<Store>();
    if (!store.peut(Permission.gererDepenses) &&
        !store.peut(Permission.voirCaisse)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🔒 Rapprochement réservé aux rôles financiers')));
      return;
    }
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pointee ? 'Dépointer ?' : 'Pointer comme rapprochée ?'),
        content: Text(
            '« $libelle »\n\n${pointee ? 'L\'écriture repassera en non rapprochée.' : 'Confirme que cette écriture figure sur le relevé bancaire / de caisse.'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    await store.pointerEcriture(id, !pointee);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pointee
              ? 'Écriture dépointée'
              : '✅ Écriture rapprochée')));
    }
  }
}

class _Balance extends StatelessWidget {
  const _Balance();
  @override
  Widget build(BuildContext context) {    final store = context.watch<Store>();
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

class _Tva extends StatefulWidget {
  const _Tva();
  @override
  State<_Tva> createState() => _TvaState();
}

/// TVA déclarative simplifiée : collectée (443) − déductible (445),
/// par mois sur l'année choisie, depuis le journal.
class _TvaState extends State<_Tva> {
  int? _annee;

  static const _mois = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final annees = store.anneesDonnees();
    _annee ??= annees.contains(DateTime.now().year)
        ? DateTime.now().year
        : (annees.isNotEmpty ? annees.last : DateTime.now().year);
    final serie = store.tvaParMois(_annee!);
    final totC = serie.values.fold(0.0, (s, e) => s + e.$1);
    final totD = serie.values.fold(0.0, (s, e) => s + e.$2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        DropdownButtonFormField<int>(
          value: _annee,
          decoration: const InputDecoration(labelText: 'Année'),
          items: [
            for (final a in {...annees, _annee!}.toList()..sort())
              DropdownMenuItem(value: a, child: Text('$a')),
          ],
          onChanged: (v) => setState(() => _annee = v!),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Row(children: [
            Expanded(
                child: _Chiffre(
                    label: 'Collectée (443)',
                    valeur: totC,
                    couleur: const Color(0xFF0D47A1))),
            Expanded(
                child: _Chiffre(
                    label: 'Déductible (445)',
                    valeur: totD,
                    couleur: const Color(0xFF3E9D8F))),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('À reverser',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                    MoneyText(totC - totD,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: totC - totD >= 0
                                ? const Color(0xFFC62828)
                                : const Color(0xFF3E9D8F))),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(children: [
            for (var m = 1; m <= 12; m++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(
                    width: 44,
                    child: Text(_mois[m - 1],
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700)),
                  ),
                  Expanded(
                    child: Text(
                      'C : ${serie[m]!.$1.toStringAsFixed(0)} · D : ${serie[m]!.$2.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  MoneyText(serie[m]!.$1 - serie[m]!.$2,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

/// Balance âgée clients : encours impayé par ancienneté.
class _Agee extends StatelessWidget {
  const _Agee();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final tranches = store.balanceAgee;
    final total = tranches.values.fold(0.0, (s, v) => s + v);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SoftCard(
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Encours impayé',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                    MoneyText(total,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ]),
            ),
            Text('${store.creances.length} créance(s)',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(children: [
            for (final e in tranches.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  SizedBox(
                    width: 64,
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total == 0
                            ? 0
                            : (e.value / total).clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor:
                            const Color(0xFFEDF0F5),
                        valueColor:
                            const AlwaysStoppedAnimation(
                                Color(0xFFC62828)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: MoneyText(e.value,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
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
