import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/achat.dart';
import '../../models/enums.dart';
import '../../widgets/empty_view.dart';
import '../../services/export_service.dart';
import '../../widgets/filtre_panel.dart';
import 'achat_detail_screen.dart';
import 'achat_form_screen.dart';
import 'widgets/achat_card.dart';

/// Liste des achats : filtres statut + recherche, tuile dashboard et menu.
class AchatListScreen extends StatefulWidget {
  const AchatListScreen({super.key});
  @override
  State<AchatListScreen> createState() => _AchatListScreenState();
}

class _AchatListScreenState extends State<AchatListScreen> {
  // Refonte UX : cartes commande (liste par défaut) + bascule grille.
  // Filtres via FiltrePanel : statut + recherche + période + fournisseur
  // + montant min-max + tri. Catégorie/sous-catégorie non applicables
  // (lignes libres sans référentiel — non inventé).
  var _grille = false;
  Map<String, dynamic> _filtres = const {'statut': 'tous', 'tri': 'date_desc'};

  static const _statuts = [
    ('tous', 'Tous'),
    (Achat.statutDemande, 'Demandes'),
    (Achat.statutEnAttente, 'En attente'),
    (Achat.statutValide, 'Validés'),
    (Achat.statutRecu, 'Reçus'),
    (Achat.statutAnnule, 'Annulés'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final role = store.role;
    // Vendeur/caissier : création de demandes uniquement (pas de gererAchats).
    final peutCreer = store.peut(Permission.gererAchats) ||
        role == Role.vendeur ||
        role == Role.caissier;
    var liste = store.achatsBoutique
      ..sort((a, b) => b.date.compareTo(a.date));
    final statut = (_filtres['statut'] as String?) ?? 'tous';
    if (statut != 'tous') {
      liste = liste.where((a) => a.statut == statut).toList();
    }
    final rech = ((_filtres['q'] as String?) ?? '').trim().toLowerCase();
    if (rech.isNotEmpty) {
      liste = liste
          .where((a) =>
              a.numero.toLowerCase().contains(rech) ||
              a.fournisseurNom.toLowerCase().contains(rech))
          .toList();
    }
    // Point 25 + plan A5 : période (intervalles prédéfinis ou
    // dates personnalisées) + filtre fournisseur.
    // Catégorie/sous-catégorie : non applicables (lignes d'achat libres,
    // sans référentiel catégorie — non inventé).
    final fournisseurs = {
      for (final a in store.achatsBoutique)
        if (a.fournisseurNom.trim().isNotEmpty)
          a.fournisseurNom.trim(),
    }.toList()
      ..sort();
    final fourn = (_filtres['fourn'] as String?) ?? '';
    if (fourn.isNotEmpty) {
      liste = liste.where((a) => a.fournisseurNom == fourn).toList();
    }
    final periode = (_filtres['periode'] as String?) ?? 'tout';
    final maintenant = DateTime.now();
    DateTime? debut;
    DateTime? fin;
    switch (periode) {
      case '7j':
        debut = maintenant.subtract(const Duration(days: 6));
        fin = null;
      case '30j':
        debut = maintenant.subtract(const Duration(days: 29));
        fin = null;
      case 'mois':
        debut = DateTime(maintenant.year, maintenant.month);
        fin = null;
      case 'annee':
        debut = DateTime(maintenant.year);
        fin = null;
      case 'custom':
        debut = _filtres['debut'] as DateTime?;
        fin = _filtres['fin'] as DateTime?;
      default:
        debut = null;
        fin = null;
    }
    final d0 = debut;
    if (d0 != null) {
      liste = liste.where((a) => !a.date.isBefore(d0)).toList();
    }
    final f0 = fin;
    if (f0 != null) {
      final finJour = DateTime(f0.year, f0.month, f0.day, 23, 59, 59);
      liste = liste.where((a) => !a.date.isAfter(finJour)).toList();
    }
    final min =
        double.tryParse((_filtres['montant_min'] as String?) ?? '');
    final max =
        double.tryParse((_filtres['montant_max'] as String?) ?? '');
    if (min != null) {
      liste = liste.where((a) => a.montantTTC >= min).toList();
    }
    if (max != null) {
      liste = liste.where((a) => a.montantTTC <= max).toList();
    }
    switch ((_filtres['tri'] as String?) ?? 'date_desc') {
      case 'date_asc':
        liste.sort((a, b) => a.date.compareTo(b.date));
      case 'montant_desc':
        liste.sort((a, b) => a.montantTTC.compareTo(b.montantTTC));
      case 'montant_asc':
        liste.sort((a, b) => b.montantTTC.compareTo(a.montantTTC));
      case 'statut':
        liste.sort((a, b) => a.statut.compareTo(b.statut));
      default:
        liste.sort((a, b) => b.date.compareTo(a.date));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats fournisseurs'),
        actions: [
          IconButton(
            tooltip: _grille ? 'Vue liste' : 'Vue grille',
            icon: Icon(_grille
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined),
            onPressed: () => setState(() => _grille = !_grille),
          ),
          PopupMenuButton<String>(
            tooltip: 'Exporter (vue filtrée ou tout)',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) {
              // 'tout:pdf' → tous les achats ; sinon la vue filtrée.
              final tout = f.startsWith('tout:');
              final format = tout ? f.substring(5) : f;
              final source = tout
                  ? (store.achatsBoutique
                    ..sort((a, b) => b.date.compareTo(a.date)))
                  : liste;
              _exporter(context, store, source, format, tout: tout);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  enabled: false,
                  child: Text('Vue filtrée (${liste.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700))),
              const PopupMenuItem(
                  value: 'pdf', child: Text('PDF (partage)')),
              const PopupMenuItem(
                  value: 'xlsx', child: Text('Excel (.xlsx)')),
              const PopupMenuItem(
                  value: 'csv', child: Text('CSV (Excel)')),
              PopupMenuItem(
                  enabled: false,
                  child: Text('Tous (${store.achatsBoutique.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700))),
              const PopupMenuItem(
                  value: 'tout:pdf', child: Text('Tout en PDF')),
              const PopupMenuItem(
                  value: 'tout:xlsx',
                  child: Text('Tout en Excel')),
              const PopupMenuItem(
                  value: 'tout:csv', child: Text('Tout en CSV')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FiltrePanel(
            filtres: [
              const FiltreConfig(
                  cle: 'q',
                  kind: FiltreKind.recherche,
                  label: 'Rechercher (n°, fournisseur)…'),
              FiltreConfig(
                  cle: 'statut',
                  kind: FiltreKind.chips,
                  label: 'Statut',
                  options: _statuts),
              const FiltreConfig(
                  cle: 'periode',
                  kind: FiltreKind.chips,
                  label: 'Période',
                  options: [
                    ('tout', 'Tout'),
                    ('7j', '7 jours'),
                    ('30j', '30 jours'),
                    ('mois', 'Mois'),
                    ('annee', 'Année'),
                    ('custom', 'Personnalisé'),
                  ]),
              FiltreConfig(
                  cle: 'fourn',
                  kind: FiltreKind.dropdown,
                  label: 'Fournisseur',
                  options: [
                    for (final f in fournisseurs) (f, f),
                  ]),
              const FiltreConfig(
                  cle: 'montant',
                  kind: FiltreKind.minMax,
                  label: 'Montant TTC (min-max)'),
              const FiltreConfig(
                  cle: 'tri',
                  kind: FiltreKind.dropdown,
                  label: 'Tri',
                  options: [
                    ('date_desc', 'Date ↓'),
                    ('date_asc', 'Date ↑'),
                    ('montant_desc', 'Montant ↓'),
                    ('montant_asc', 'Montant ↑'),
                    ('statut', 'Statut'),
                  ]),
              const FiltreConfig(
                  cle: '', kind: FiltreKind.dates, label: ''),
            ],
            valeurs: _filtres,
            onFiltreChange: (m) => setState(() => _filtres = m),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.rafraichir,
            child: liste.isEmpty
                ? ListView(children: const [
                    EmptyView(
                        icon: Icons.shopping_cart_outlined,
                        message: 'Aucun achat',
                        hint:
                            'Demandes, bons de commande et réceptions fournisseurs'),
                  ])
                : _grille
                    ? GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                            16, 8, 16, peutCreer ? 90 : 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 380,
                        ),
                        itemCount: liste.length,
                        itemBuilder: (_, i) => _carte(
                            context, store, liste[i]),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            16, 8, 16, peutCreer ? 90 : 24),
                        itemCount: liste.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _carte(
                            context, store, liste[i]),
                      ),
          ),
        ),
      ]),
      floatingActionButton: peutCreer
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AchatFormScreen())),
              icon: const Icon(Icons.add),
              label: Text(role == Role.vendeur || role == Role.caissier
                  ? 'Demande'
                  : 'Achat'),
            )
          : null,
    );
  }

  /// Carte commande + actions rapides (voir, payer, annuler, exporter).
  Widget _carte(BuildContext context, Store store, Achat a) {
    final gere = store.peut(Permission.gererAchats);
    return AchatCard(
      achat: a,
      onVoir: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AchatDetailScreen(achatId: a.id))),
      onPayer: gere && a.peutPayer
          ? () => _payerRapide(context, store, a)
          : null,
      onAnnuler: gere && a.peutAnnuler
          ? () => _annulerRapide(context, store, a)
          : null,
      onExporter: () => _exporter(context, store, [a], 'pdf'),
    );
  }

  Future<void> _payerRapide(
      BuildContext context, Store store, Achat a) async {
    final ctrl =
        TextEditingController(text: a.montantRestant.toStringAsFixed(0));
    final montant = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Paiement fournisseur'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText:
                  'Montant (dû : ${a.montantRestant.toStringAsFixed(0)})'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, V.prixValue(ctrl.text)),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (montant == null || montant <= 0 || !context.mounted) return;
    final erreur = await store.payerAchat(a.id, montant);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erreur == null
              ? '✅ Paiement enregistré'
              : '⚠️ $erreur')));
    }
  }

  Future<void> _annulerRapide(
      BuildContext context, Store store, Achat a) async {
    final ctrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Annuler cet achat ?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Motif (obligatoire)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx,
                ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Annuler l\'achat'),
          ),
        ],
      ),
    );
    if (motif == null || !context.mounted) return;
    final erreur = await store.annulerAchat(a.id, motif);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              erreur == null ? 'Achat annulé' : '⚠️ $erreur')));
    }
  }

  /// Lignes d'export de la vue filtrée (mêmes colonnes partout).
  static List<List<dynamic>> _lignesExport(
      List<Achat> liste, String devise) => [
        for (final a in liste)
          [
            a.date,
            a.numero,
            a.fournisseurNom,
            AchatCard.libelleStatut(a.statut),
            a.lignes.length,
            a.lignes
                .map((l) =>
                    '${l.quantite.toStringAsFixed(l.quantite.truncateToDouble() == l.quantite ? 0 : 2)}× ${l.produitNom}')
                .join(', '),
            a.montantTTC,
            a.montantPaye,
            a.montantRestant,
            a.modePaiement,
            devise,
          ],
      ];

  Future<void> _exporter(BuildContext context, Store store,
      List<Achat> liste, String format, {bool tout = false}) async {
    const entetes = [
      'Date', 'Numéro', 'Fournisseur', 'Statut', 'Nb lignes', 'Détail',
      'Montant TTC', 'Payé', 'Reste dû', 'Paiement', 'Devise'
    ];
    final lignes = _lignesExport(liste, store.profile.devise);
    final total = liste.fold(0.0, (s, a) => s + a.montantTTC);
    final du = liste.fold(0.0, (s, a) => s + a.montantRestant);
    final nom =
        'achats_${tout ? 'tous' : store.moisCourant}_${liste.length}ops';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Achats — ${store.boutiqueCourante.nom}',
              sousTitre:
                  '${tout ? 'Tous les achats' : 'Vue filtrée'} · ${liste.length} achat(s) · Total : ${total.toStringAsFixed(0)} ${store.profile.devise} · Dû : ${du.toStringAsFixed(0)} ${store.profile.devise}',
              entetes: entetes,
              lignes: lignes);
        case 'xlsx':
          await ExportService.partagerExcel(
              nom, 'Achats', entetes, lignes);
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
}
