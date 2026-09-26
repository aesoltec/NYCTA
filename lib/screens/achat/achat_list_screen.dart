import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../models/achat.dart';
import '../../models/enums.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../services/export_service.dart';
import 'achat_detail_screen.dart';
import 'achat_form_screen.dart';

/// Liste des achats : filtres statut + recherche, tuile dashboard et menu.
class AchatListScreen extends StatefulWidget {
  const AchatListScreen({super.key});
  @override
  State<AchatListScreen> createState() => _AchatListScreenState();
}

class _AchatListScreenState extends State<AchatListScreen> {
  String _filtreStatut = 'tous';
  String _recherche = '';

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
    if (_filtreStatut != 'tous') {
      liste = liste.where((a) => a.statut == _filtreStatut).toList();
    }
    final rech = _recherche.trim().toLowerCase();
    if (rech.isNotEmpty) {
      liste = liste
          .where((a) =>
              a.numero.toLowerCase().contains(rech) ||
              a.fournisseurNom.toLowerCase().contains(rech))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats fournisseurs'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter la vue filtrée',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (f) => _exporter(context, store, liste, f),
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
            decoration: const InputDecoration(
                hintText: 'Rechercher (n°, fournisseur)…',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _recherche = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _statuts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_statuts[i].$2),
              selected: _filtreStatut == _statuts[i].$1,
              onSelected: (_) =>
                  setState(() => _filtreStatut = _statuts[i].$1),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: liste.isEmpty
              ? const EmptyView(
                  icon: Icons.shopping_cart_outlined,
                  message: 'Aucun achat',
                  hint: 'Demandes, bons de commande et réceptions fournisseurs')
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, peutCreer ? 90 : 24),
                  itemCount: liste.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _LigneAchat(achat: liste[i]),
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

  /// Lignes d'export de la vue filtrée (mêmes colonnes partout).
  static List<List<dynamic>> _lignesExport(
      List<Achat> liste, String devise) => [
        for (final a in liste)
          [
            a.date,
            a.numero,
            a.fournisseurNom,
            _LigneAchat.libelle(a.statut),
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
      List<Achat> liste, String format) async {
    const entetes = [
      'Date', 'Numéro', 'Fournisseur', 'Statut', 'Nb lignes', 'Détail',
      'Montant TTC', 'Payé', 'Reste dû', 'Paiement', 'Devise'
    ];
    final lignes = _lignesExport(liste, store.profile.devise);
    final total = liste.fold(0.0, (s, a) => s + a.montantTTC);
    final du = liste.fold(0.0, (s, a) => s + a.montantRestant);
    final nom = 'achats_${store.moisCourant}_${liste.length}ops';
    try {
      switch (format) {
        case 'pdf':
          await ExportService.partagerPdf(nom,
              titre: 'Achats — ${store.boutiqueCourante.nom}',
              sousTitre:
                  '${liste.length} achat(s) · Total : ${total.toStringAsFixed(0)} ${store.profile.devise} · Dû : ${du.toStringAsFixed(0)} ${store.profile.devise}',
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

class _LigneAchat extends StatelessWidget {
  final Achat achat;
  const _LigneAchat({required this.achat});

  static const _couleurs = {
    Achat.statutDemande: Color(0xFF7E57C2),
    Achat.statutEnAttente: Color(0xFFEF6C00),
    Achat.statutValide: Color(0xFF3D6FB4),
    Achat.statutRecu: Color(0xFF3E9D8F),
    Achat.statutAnnule: Color(0xFF9E9E9E),
  };

  static const _libelles = {
    Achat.statutDemande: 'DEMANDE',
    Achat.statutEnAttente: 'EN ATTENTE',
    Achat.statutValide: 'VALIDÉ',
    Achat.statutRecu: 'REÇU',
    Achat.statutAnnule: 'ANNULÉ',
  };

  static String libelle(String statut) =>
      _libelles[statut] ?? statut.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurs[achat.statut] ?? Colors.grey;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.shopping_cart_outlined,
              size: 18, color: couleur),
        ),
        title: Text('${achat.numero} · ${achat.fournisseurNom}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${_libelles[achat.statut]}${achat.montantRestant > 0.001 && achat.statut != Achat.statutAnnule ? ' · dû : ${achat.montantRestant.toStringAsFixed(0)}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12, color: couleur, fontWeight: FontWeight.w700),
        ),
        trailing: MoneyText(achat.montantTTC,
            style: const TextStyle(fontSize: 14)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AchatDetailScreen(achatId: achat.id))),
      ),
    );
  }
}
