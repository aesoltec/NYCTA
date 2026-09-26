import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../transaction/nouvelle_transaction_screen.dart';

/// Journal des transactions : filtres par activité + recherche client.
/// Chaque ligne propose Modifier / Supprimer (appui long ou menu ⋮) :
/// forfait, crédit, mobile money, prestation, matériel — toutes les ventes
/// saisies restent corrigeables après coup.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  TypeTransaction? _filtre;
  String? _sousCategorie;
  DateTime? _debut;
  DateTime? _fin;
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    // Option A (anti-fraude) : modifier = admin/gérant/comptable,
    // supprimer = admin/gérant. Vendeur/caissier/partenaire = création
    // seule (boutons masqués, en miroir des policies RLS).
    final role = store.role;
    final peutModifier = role == Role.admin ||
        role == Role.gerant ||
        role == Role.comptable;
    final peutSupprimer =
        role == Role.admin || role == Role.gerant;
    var txs = store.txBoutique;
    if (_filtre != null) txs = txs.where((t) => t.type == _filtre).toList();
    if (_sousCategorie != null) {
      txs = txs.where((t) {
        final d = t.details;
        return switch (t.type) {
          TypeTransaction.mobileMoney =>
            (d['operateur']?.toString() ?? '') == _sousCategorie,
          TypeTransaction.creditCommunication =>
            (d['operateur']?.toString() ?? '') == _sousCategorie,
          TypeTransaction.prestationService =>
            (d['domaine']?.toString() ?? '') == _sousCategorie,
          TypeTransaction.forfaitHotspot =>
            (d['duree']?.toString() ?? '') == _sousCategorie,
          TypeTransaction.venteMateriel => true,
        };
      }).toList();
    }
    if (_debut != null) {
      txs = txs.where((t) => !t.date.isBefore(_debut!)).toList();
    }
    if (_fin != null) {
      final finJour =
          DateTime(_fin!.year, _fin!.month, _fin!.day, 23, 59, 59);
      txs = txs.where((t) => !t.date.isAfter(finJour)).toList();
    }
    if (_recherche.isNotEmpty) {
      txs = txs
          .where((t) =>
              (t.clientNom ?? '').toLowerCase().contains(_recherche.toLowerCase()))
          .toList();
    }
    return Scaffold(
      // Scaffold propre : cet écran est affiché à la fois comme onglet
      // (corps sous le Scaffold d'AppShell) et comme route poussée depuis
      // le menu « Plus » — sans Scaffold propre, TextField/ListTile n'ont
      // aucun ancêtre Material en mode route (assertion debug).
      appBar: AppBar(
        title: const Text('Journal des ventes'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter la vue filtrée',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, f, txs),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'pdf', child: Text('PDF (partage)')),
              PopupMenuItem(
                  value: 'xlsx', child: Text('Excel (.xlsx)')),
              PopupMenuItem(
                  value: 'csv', child: Text('CSV (Excel)')),
            ],
          ),
        ],
      ),
      body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un client…',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            // Clôture de journée : rapport PDF du jour, partageable WhatsApp
            suffixIcon: IconButton(
              tooltip: 'Rapport du jour (PDF)',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => PdfService.partagerRapportJournalier(
                transactions: context.read<Store>().txJour,
                boutiqueNom: context.read<Store>().boutiqueCourante.nom,
                devise: context.read<Store>().profile.devise,
              ),
            ),
          ),
          onChanged: (v) => setState(() => _recherche = v),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            _FiltreChip(
              label: 'Tout · ${store.txBoutique.length}',
              actif: _filtre == null,
              onTap: () => setState(() {
                _filtre = null;
                _sousCategorie = null;
              }),
            ),
            for (final t in TypeTransaction.values)
              _FiltreChip(
                label: C.infosTypes[t]!.$1,
                actif: _filtre == t,
                onTap: () => setState(() {
                  _filtre = t;
                  _sousCategorie = null;
                }),
              ),
          ],
        ),
      ),
      if (_optionsSousCategorie(store).isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: DropdownButtonFormField<String>(
            value: _sousCategorie,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Sous-catégorie',
                prefixIcon: Icon(Icons.filter_alt_outlined)),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Toutes')),
              for (final o in _optionsSousCategorie(store))
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => setState(() => _sousCategorie = v),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          Expanded(
            child: DatePickerField(
              valeur: _debut,
              label: 'Début (optionnel)',
              onChanged: (d) => setState(() => _debut = d),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DatePickerField(
              valeur: _fin,
              label: 'Fin (optionnel)',
              onChanged: (d) => setState(() => _fin = d),
            ),
          ),
          if (_debut != null || _fin != null)
            IconButton(
              tooltip: 'Effacer les dates',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _debut = null;
                _fin = null;
              }),
            ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: store.rafraichir,
          child: txs.isEmpty
              ? ListView(children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: EmptyView(
                        icon: Icons.receipt_long_outlined,
                        message: 'Aucune transaction',
                        hint:
                            'Les ventes que vous enregistrez apparaîtront ici'),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: txs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LigneTx(
                    tx: txs[i],
                    peutModifier: peutModifier,
                    peutSupprimer: peutSupprimer,
                    onModifier: () => _modifier(context, txs[i]),
                    onSupprimer: () =>
                        _confirmerSuppression(context, txs[i]),
                    onEncaisser: () => _encaisser(context, txs[i]),
                  ),
                ),
          ),
        ),
      ]),
    );
  }

  /// Sous-catégories dépendant du type filtré (opérateur, domaine…).
  /// Vente matériel : pas de sous-catégorie (lignes libres).
  List<String> _optionsSousCategorie(Store store) => switch (_filtre) {
        TypeTransaction.mobileMoney => store.opsMobileMoney,
        TypeTransaction.creditCommunication => store.opsCredit,
        TypeTransaction.prestationService => store.domainesPresta,
        TypeTransaction.forfaitHotspot => store.dureesForfaitListe,
        _ => const [],
      };

  /// Lignes d'export de la vue filtrée (mêmes colonnes partout).
  List<List<dynamic>> _lignesExport(
      List<Tx> txs, String devise, Store store) => [
        for (final t in txs)
          [
            t.date,
            C.infosTypes[t.type]!.$1,
            t.clientNom ?? '',
            _detailExport(t),
            t.montant,
            t.cout,
            t.marge,
            devise,
            store.boutiqueCourante.nom,
          ],
      ];

  static String _detailExport(Tx t) {
    final d = t.details;
    final base = switch (t.type) {
      TypeTransaction.prestationService =>
        '${d['domaine'] ?? ''}${d['description'] != null ? ' — ${d['description']}' : ''}',
      TypeTransaction.mobileMoney =>
        '${d['operateur'] ?? ''} ${d['operation'] ?? ''}',
      TypeTransaction.creditCommunication => '${d['operateur'] ?? ''}',
      TypeTransaction.forfaitHotspot => '${d['duree'] ?? ''}',
      TypeTransaction.venteMateriel =>
        (d['lignes'] as List?)?.map((l) => '${l['quantite']}× ${l['libelle']}').join(', ') ?? '',
    };
    return '$base${suffixesVente(t)}';
  }

  Future<void> _exporter(
      BuildContext context, String format, List<Tx> txs) async {
    final store = context.read<Store>();
    const entetes = [
      'Date', 'Activité', 'Client', 'Détail', 'Montant', 'Coût',
      'Marge', 'Devise', 'Boutique'
    ];
    final lignes = _lignesExport(txs, store.profile.devise, store);
    final nom =
        'journal_${store.moisCourant}_${txs.length}ops';
    final titre = 'Journal des ventes — ${store.boutiqueCourante.nom}';
    try {
      switch (format) {
        case 'pdf':
          // pdfTableau garantit un tableau non vide : corrige le bug du
          // cadre PDF vide quand la période filtrée ne contient rien.
          await ExportService.partagerPdf(nom,
              titre: titre,
              sousTitre:
                  '${txs.length} opération(s) · Total : ${txs.fold(0.0, (s, t) => s + t.montant).toStringAsFixed(0)} ${store.profile.devise}',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Journal', entetes, lignes);
        default:
          await ExportService.partagerCsv(nom, entetes, lignes);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Export impossible')));
      }
    }
  }

  void _modifier(BuildContext context, Tx tx) {    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          NouvelleTransactionScreen(type: tx.type, transaction: tx),
    ));
  }

  Future<void> _encaisser(BuildContext context, Tx tx) async {
    final store = context.read<Store>();
    final erreur = await store.encaisserVente(tx.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(erreur == null
            ? '✅ Encaissé'
            : '⚠️ $erreur')));
  }

  Future<void> _confirmerSuppression(BuildContext context, Tx tx) async {
    final store = context.read<Store>();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 32),
        title: const Text('Supprimer cette vente ?'),
        content: Text(
          '${C.infosTypes[tx.type]!.$1} — ${C.money(tx.montant, store.profile.devise)}'
          '${tx.clientNom != null ? '\nClient : ${tx.clientNom}' : ''}'
          '${tx.type == TypeTransaction.venteMateriel ? '\n\nLe stock des produits liés sera restauré.' : ''}'
          '\n\nCette action est définitive.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    await store.supprimerTransaction(tx.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Vente supprimée')),
      );
    }
  }
}

/// Suffixes remise + mode de paiement (point 24) : partagés entre
/// l'affichage journal et l'export pour une stricte cohérence.
/// Vide pour les ventes antérieures (clés absentes).
String suffixesVente(Tx t) {
  final d = t.details;
  final remise = (d['remise'] as num?)?.toDouble() ?? 0;
  final mode = d['modePaiement']?.toString();
  var s = '';
  if (remise > 0) {
    final brut = (d['montantBrut'] as num?)?.toDouble();
    s += brut != null
        ? ' · remise ${remise.toStringAsFixed(0)} (brut ${brut.toStringAsFixed(0)})'
        : ' · remise ${remise.toStringAsFixed(0)}';
  }
  if (mode != null && mode.isNotEmpty) {
    s +=
        ' · ${NouvelleTransactionScreen.libelleMode(mode)}';
  }
  return s;
}

class _FiltreChip extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;
  const _FiltreChip(
      {required this.label, required this.actif, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final chipColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: actif,
        onSelected: (_) => onTap(),
        label: Text(label,
            maxLines: 1,
            style: TextStyle(
                fontSize: 12.5,
                color: actif ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700)),
        selectedColor: chipColor,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(
            color: actif ? chipColor : const Color(0xFFE0E4EA)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _LigneTx extends StatelessWidget {
  final Tx tx;
  final bool peutModifier;
  final bool peutSupprimer;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;
  final VoidCallback onEncaisser;
  const _LigneTx(
      {required this.tx,
      required this.peutModifier,
      required this.peutSupprimer,
      required this.onModifier,
      required this.onSupprimer,
      required this.onEncaisser});

  @override
  Widget build(BuildContext context) {
    final d = tx.details;
    final (_, icone, couleur) = C.infosTypes[tx.type]!;
    final brut = switch (tx.type) {
      TypeTransaction.prestationService =>
        '${d['domaine'] ?? ''}${d['description'] != null ? ' — ${d['description']}' : ''}',
      TypeTransaction.mobileMoney =>
        '${d['operateur'] ?? ''} · ${d['operation'] ?? ''} · Frais ${C.money((d['frais'] as num?) ?? 0)}',
      TypeTransaction.creditCommunication => '${d['operateur'] ?? ''}',
      TypeTransaction.forfaitHotspot =>
        '${d['duree'] ?? ''}${tx.partenaireId != null ? ' · via partenaire' : ''}',
      TypeTransaction.venteMateriel =>
        (d['lignes'] as List?)?.map((l) => l['libelle']).join(', ') ?? '',
    };
    final detail = brut.isEmpty
        ? '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')} à ${tx.date.hour.toString().padLeft(2, '0')}h${tx.date.minute.toString().padLeft(2, '0')}'
        : '$brut${suffixesVente(tx)}';

    final carte = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF1)),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icone, color: couleur, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.clientNom ?? C.infosTypes[tx.type]!.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5, color: Colors.grey.shade600),
              ),
              if (tx.statut != StatutPaiement.paye)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('IMPAYÉ — à relancer',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828))),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MoneyText(tx.montant,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        if (peutModifier || peutSupprimer) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'Modifier / Supprimer',
            onSelected: (v) {
              if (v == 'modifier') onModifier();
              if (v == 'supprimer') onSupprimer();
              if (v == 'encaisser') onEncaisser();
            },
            itemBuilder: (_) => [
              if (peutModifier)
                const PopupMenuItem(
                  value: 'modifier',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ]),
                ),
              if (peutModifier && tx.statut != StatutPaiement.paye)
                const PopupMenuItem(
                  value: 'encaisser',
                  child: Row(children: [
                    Icon(Icons.payments_outlined,
                        size: 18, color: Color(0xFF3E9D8F)),
                    SizedBox(width: 8),
                    Text('Encaisser',
                        style: TextStyle(color: Color(0xFF3E9D8F))),
                  ]),
                ),
              if (peutSupprimer)
                const PopupMenuItem(
                  value: 'supprimer',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: Colors.redAccent)),
                  ]),
                ),
            ],
          ),
        ],
      ]),
    );

    if (!peutModifier && !peutSupprimer) return carte;
    // Tap = modifier (si autorisé) ; appui long = menu d'actions.
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: peutModifier ? onModifier : null,
      onLongPress: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (peutModifier)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier cette vente'),
                onTap: () {
                  Navigator.pop(ctx);
                  onModifier();
                },
              ),
            if (peutSupprimer)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text('Supprimer cette vente',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  onSupprimer();
                },
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      child: carte,
    );
  }
}
