import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/env.dart';
import '../../data/store.dart';
import '../../services/supabase_service.dart';
import '../login/login_screen.dart';
import '../../models/enums.dart';
import '../admin/boutiques_screen.dart';
import '../achat/achat_list_screen.dart';
import '../admin/categories_screen.dart';
import '../admin/listes_dynamiques_screen.dart';
import '../admin/clients_screen.dart';
import '../collab/evenements_screen.dart';
import '../collab/feedbacks_screen.dart';
import '../collab/fournisseurs_screen.dart';
import '../collab/messagerie_screen.dart';
import '../collab/notes_screen.dart';
import '../config/config_screen.dart';
import '../config/synchronisation_screen.dart';
import '../documents/documents_history_screen.dart';
import '../documents/documents_screen.dart';
import '../backup/backup_screen.dart';
import '../compta/compta_screen.dart';
import '../partenaires/partenaires_screen.dart';
import '../relances/relances_screen.dart';
import '../rapports/analytique_screen.dart';
import '../rapports/rapports_screen.dart';
import '../stats/stats_screen.dart';
import '../tarifs/tarifs_screen.dart';
import '../tresorerie/tresorerie_screen.dart';
import '../users/users_screen.dart';

/// Hub "Plus" : accès aux modules secondaires, filtrés par le rôle connecté.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: Color(0xFF6EE7B7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Menu',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${store.boutiqueCourante.nom} · ${store.role.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                  ]),
            ),
          ]),
        ),
        if (store.peut(Permission.gererPartenaires) || store.peut(Permission.cloturerMois))
          _Tuille(
            icone: Icons.handshake_outlined,
            couleur: const Color(0xFF3D6FB4),
            titre: 'Partenaires hotspot',
            sousTitre: '${store.partenaires.length} partenaire(s) · clôture mensuelle',
            destination: const PartenairesScreen(),
          ),
        if (store.peut(Permission.voirCaisse))
          _Tuille(
            icone: Icons.account_balance_wallet_outlined,
            couleur: const Color(0xFF3E9D8F),
            titre: 'Trésorerie',
            sousTitre: 'Fonds de roulement, soldes de caisse, budgets',
            destination: const TresorerieScreen(),
          ),
        if (store.peut(Permission.voirRapports))
          _Tuille(
            icone: Icons.insights_outlined,
            couleur: const Color(0xFF7E57C2),
            titre: 'Rapports',
            sousTitre: 'Par activité, opérateurs, boutiques',
            destination: const RapportsScreen(),
          ),
        if (store.peut(Permission.voirRapports))
          _Tuille(
            icone: Icons.query_stats_outlined,
            couleur: const Color(0xFF00838F),
            titre: 'Analytique CA & dépenses',
            sousTitre: '7 jours, mois, années — comparaisons, détail filtrable',
            destination: const AnalytiqueScreen(),
          ),
        if (store.peut(Permission.voirRapports))
          _Tuille(
            icone: Icons.account_balance_outlined,
            couleur: const Color(0xFF0D47A1),
            titre: 'Comptabilité',
            sousTitre: 'Journal immuable, balance, compte de résultat',
            destination: const ComptaScreen(),
          ),
        if (store.peut(Permission.voirRapports))
          _Tuille(
            icone: Icons.bar_chart_rounded,
            couleur: const Color(0xFF5C6BC0),
            titre: 'Statistiques & graphiques',
            sousTitre: 'Courbe CA 30 jours, camembert activités, partenaires',
            destination: const StatsScreen(),
          ),
        if (store.role != Role.partenaire)
          _Tuille(
            icone: Icons.sell_outlined,
            couleur: const Color(0xFF2E7D32),
            titre: 'Tarifs & catalogue',
            sousTitre: '${store.tarifsActifs.length} article(s) — préremplit '
                'factures et devis',
            destination: const TarifsScreen(),
          ),
        if (store.peut(Permission.gererDocuments) ||
            store.role == Role.vendeur)
          _Tuille(
            icone: Icons.description_outlined,
            couleur: const Color(0xFFEF6C00),
            titre: 'Documents commerciaux',
            sousTitre: 'Factures, devis proforma, bons de commande, tickets',
            destination: const DocumentsScreen(),
          ),
        if (store.peut(Permission.gererDocuments) ||
            store.role == Role.vendeur)
          _Tuille(
            icone: Icons.folder_outlined,
            couleur: const Color(0xFF455A64),
            titre: 'Historique des documents',
            sousTitre: '${store.documentsEmis.length} document(s) émis — factures, devis, bons, tickets',
            destination: const DocumentsHistoryScreen(),
          ),
        if (store.peut(Permission.gererUtilisateurs) || store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.storefront_outlined,
            couleur: const Color(0xFF37474F),
            titre: 'Boutiques',
            sousTitre: '${store.boutiquesActives.length} boutique(s) · création, accès, siège',
            destination: const BoutiquesScreen(),
          ),
        if (store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.label_outline,
            couleur: const Color(0xFF00838F),
            titre: 'Catégories',
            sousTitre: '${store.catsProduit.length} produit(s) · ${store.catsCharge.length} charge(s) — dynamiques',
            destination: const CategoriesScreen(),
          ),
        if (store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.tune_rounded,
            couleur: const Color(0xFF00838F),
            titre: 'Listes du formulaire de vente',
            sousTitre: 'Opérateurs Mobile Money/Crédit, domaines, durées forfait',
            destination: const ListesDynamiquesScreen(),
          ),
        if (store.peut(Permission.gererAchats) ||
            store.role == Role.vendeur ||
            store.role == Role.caissier)
          _Tuille(
            icone: Icons.shopping_cart_outlined,
            couleur: const Color(0xFFEF6C00),
            titre: 'Achats fournisseurs',
            sousTitre: store.achatsEnAttente.isNotEmpty
                ? '${store.achatsEnAttente.length} en attente · dû : ${store.duFournisseurs.toStringAsFixed(0)}'
                : 'Demandes, commandes, réceptions, dettes',
            destination: const AchatListScreen(),
          ),
        if (store.peut(Permission.gererDepenses) || store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.local_shipping_outlined,
            couleur: const Color(0xFFBF360C),
            titre: 'Fournisseurs',
            sousTitre: '${store.fournisseurs.length} fournisseur(s)',
            destination: const FournisseursScreen(),
          ),
        if (store.peut(Permission.vendre))
          _Tuille(
            icone: Icons.notification_important_outlined,
            couleur: const Color(0xFFC62828),
            titre: 'Relances clients',
            sousTitre: store.creances.isEmpty
                ? 'Aucun impayé'
                : '${store.creances.length} impayé(s) · ${store.totalCreances.toStringAsFixed(0)} à recouvrer',
            destination: const RelancesScreen(),
          ),
        if (store.peut(Permission.vendre))
          _Tuille(
            icone: Icons.people_outline,
            couleur: const Color(0xFF6A1B9A),
            titre: 'Clients',
            sousTitre: '${store.clientsBoutique.length} client(s) de cette boutique',
            destination: const ClientsScreen(),
          ),
        if (store.peut(Permission.gererUtilisateurs))
          _Tuille(
            icone: Icons.group_outlined,
            couleur: const Color(0xFF6D4C41),
            titre: 'Utilisateurs',
            sousTitre: '${store.users.length} compte(s) · rôles et boutiques',
            destination: const UsersScreen(),
          ),
        if (store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.sync_problem_outlined,
            couleur: const Color(0xFFC62828),
            titre: 'Synchronisation',
            sousTitre: 'Ventes/opérations en attente ou bloquées — pourquoi et comment relancer',
            destination: const SynchronisationScreen(),
          ),
        if (store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.cloud_outlined,
            couleur: const Color(0xFF0277BD),
            titre: 'Sauvegardes & exports',
            sousTitre: 'Excel (CSV), sauvegarde complète, restauration',
            destination: const BackupScreen(),
          ),
        // ----- Collaboration -----
        if (store.role != Role.partenaire)
          _Tuille(
            icone: Icons.forum_outlined,
            couleur: const Color(0xFF00695C),
            titre: 'Messagerie interne',
            sousTitre: store.messagesNonLus > 0
                ? '${store.messagesNonLus} message(s) non lu(s)'
                : 'Messages à un utilisateur ou à tous',
            destination: const MessagerieScreen(),
          ),
        if (store.role != Role.partenaire)
          _Tuille(
            icone: store.nouveauxFeedbacks > 0
                ? Icons.mark_chat_unread_outlined
                : Icons.chat_bubble_outline,
            couleur: const Color(0xFFC62828),
            titre: 'Suggestions & signalements',
            sousTitre: store.nouveauxFeedbacks > 0
                ? '${store.nouveauxFeedbacks} contribution(s) à traiter'
                : 'Recommandations, idées, pannes, avis',
            destination: const FeedbacksScreen(),
          ),
        if (store.role != Role.partenaire)
          _Tuille(
            icone: Icons.event_outlined,
            couleur: const Color(0xFF4527A0),
            titre: 'Réunions & événements',
            sousTitre: store.evenementsAVenir.isEmpty
                ? 'Planifier'
                : '${store.evenementsAVenir.length} événement(s) à venir',
            destination: const EvenementsScreen(),
          ),
        if (store.role != Role.partenaire)
          _Tuille(
            icone: Icons.sticky_note_2_outlined,
            couleur: const Color(0xFF827717),
            titre: 'Notes & rappels',
            sousTitre: '${store.notesPerso.length} note(s)',
            destination: const NotesScreen(),
          ),
        if (store.peut(Permission.configurer))
          _Tuille(
            icone: Icons.settings_outlined,
            couleur: Colors.grey.shade700,
            titre: 'Configuration',
            sousTitre: 'Identité, RCCM, IFU, devise, image de marque, budgets…',
            destination: const ConfigScreen(),
          ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text('Connecté : ${store.user.nom}'),
            subtitle: Text('Rôle : ${store.role.label}'),
            trailing: Env.supabaseConfigured
                ? IconButton(
                    tooltip: 'Se déconnecter',
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: () async {
                      await SupabaseService.client?.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      }
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _Tuille extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre, sousTitre;
  final Widget destination;
  const _Tuille({
    required this.icone, required this.couleur,
    required this.titre, required this.sousTitre, required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icone, color: couleur),
        ),
        title: Text(titre,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sousTitre,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => destination)),
      ),
    );
  }
}
