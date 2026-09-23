import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/env.dart';
import '../../data/store.dart';
import '../../services/sync_service.dart';
import '../config/synchronisation_screen.dart';
import '../charges/charges_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../journal/journal_screen.dart';
import '../menu/menu_screen.dart';
import '../stock/stock_screen.dart';
import '../config/config_screen.dart';
import '../../models/enums.dart';
import '../partenaire/partner_home_screen.dart';

/// Coquille : NavigationBar 5 onglets + sélecteur multi-boutiques.
/// Les modules secondaires (Partenaires, Trésorerie, Rapports,
/// Documents, Configuration) sont dans l'onglet « Plus ».
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    JournalScreen(),
    StockScreen(),
    ChargesScreen(),
    MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    // P8 : le rôle Partenaire reçoit UNIQUEMENT son espace dédié —
    // aucun accès à la caisse, au stock ou à la configuration de la PME.
    if (store.role == Role.partenaire) {
      return const PartnerShell();
    }
    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          onSelected: store.changerBoutique,
          itemBuilder: (_) => [
            for (final b in store.boutiquesAccessibles)
              PopupMenuItem(
                value: b.id,
                child: Row(children: [
                  Icon(
                    b.id == store.boutiqueId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: b.id == store.boutiqueId
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(b.nom,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(store.boutiqueCourante.nom,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
        actions: [
          // Avant ce correctif, une vente refusée par le serveur (RLS,
          // boutique non affectée…) disparaissait après redémarrage sans
          // AUCUN signal dans l'UI. Ce badge rend le blocage visible et
          // mène à l'écran de diagnostic (lib/screens/config/synchronisation_screen.dart).
          if (Env.supabaseConfigured)
            ListenableBuilder(
              listenable: SyncService(),
              builder: (context, _) {
                final sync = SyncService();
                if (sync.enAttente == 0 && sync.enErreur == 0) {
                  return const SizedBox.shrink();
                }
                final bloque = sync.enErreur > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  child: Tooltip(
                    message: bloque
                        ? '${sync.enErreur} opération(s) bloquée(s) — non '
                          'enregistrée(s) sur le serveur. Touchez pour voir pourquoi.'
                        : '${sync.enAttente} opération(s) en cours de synchronisation.',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SynchronisationScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bloque ? const Color(0xFFFFEBEE) : const Color(0xFFE3EEFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: bloque ? const Color(0xFFFFAAA5) : const Color(0xFFAFC9EC)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(bloque ? Icons.error_outline : Icons.cloud_sync_outlined,
                              size: 14,
                              color: bloque ? const Color(0xFFC62828) : const Color(0xFF3D6FB4)),
                          const SizedBox(width: 4),
                          Text('${bloque ? sync.enErreur : sync.enAttente}',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: bloque ? const Color(0xFFC62828) : const Color(0xFF3D6FB4))),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Indicateur d'état : visible immédiatement si le cloud n'est
          // pas configuré (données locales uniquement).
          if (!Env.supabaseConfigured)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Tooltip(
                message: 'Mode démonstration — données sur cet appareil. '
                    'Renseignez SUPABASE_URL dans le fichier .env pour le cloud.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD699)),
                  ),
                  child: const Center(
                    child: Text('DÉMO',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Color(0xFFB26A00))),
                  ),
                ),
              ),
            ),
          if (store.peut(Permission.configurer))
            IconButton(
              tooltip: 'Configuration',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConfigScreen())),
            ),
          if (store.alertesStock.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Badge(
                  label: Text('${store.alertesStock.length}'),
                  child: const Icon(Icons.notifications_none),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.money_off_outlined),
              selectedIcon: Icon(Icons.money_off_rounded), label: 'Dépenses'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded), label: 'Plus'),
        ],
      ),
    );
  }
}
