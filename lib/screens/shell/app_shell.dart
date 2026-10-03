import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/env.dart';
import '../../data/store.dart';
import '../../services/sync_service.dart';
import '../config/synchronisation_screen.dart';
import '../charges/charges_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../achat/achat_list_screen.dart';
import '../menu/menu_screen.dart';
import '../stock/stock_screen.dart';
import '../config/config_screen.dart';
import '../../models/enums.dart';
import '../partenaire/partner_home_screen.dart';

/// Coquille : NavigationBar 5 onglets + sélecteur multi-boutiques.
/// Accueil, Achats, Stock, Dépenses en accès direct ; le Journal et les
/// modules secondaires sont dans l'onglet « Plus ».
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  /// LIBELLES des onglets autorises pour [store], dans l'ordre.
  ///
  /// Expose pour le test de non-regression : avant correction, la barre
  /// du bas etait une liste `const` et un VENDEUR pouvait ouvrir
  /// « Depenses » et « Achats ». Tester l'AppShell complet serait fragile
  /// (Supabase, Hive, navigation) pour une simple liste de libelles.
  @visibleForTesting
  static List<String> ongletsAutorises(Store store) =>
      _onglets(store).map((_Onglet o) => o.libelle).toList();

  /// Onglets de la barre de navigation, FILTRES par les droits du role.
  ///
  /// Avant, c'etait une liste `const` de 5 destinations : un vendeur
  /// pouvait ouvrir « Achats » et « Depenses » alors que le menu « Plus »
  /// les lui cachait. La divergence etait invisible parce que les deux
  /// entrees n'etaient pas filtrees de la meme facon.
  ///
  /// `droits` vide = onglet ouvert a tous (Accueil, Plus).
  static List<_Onglet> _onglets(Store store) => [
        const _Onglet('Accueil', DashboardScreen(), {}),
        if (store.peut(Permission.gererAchats))
          const _Onglet('Achats', AchatListScreen(), {}),
        // Lecture du catalogue : un caissier ou un vendeur doit pouvoir
        // consulter le stock pour ne pas vendre un article inexistant.
        if (store.peut(Permission.voirStock))
          const _Onglet('Stock', StockScreen(), {}),
        if (store.peut(Permission.gererDepenses))
          const _Onglet('Dépenses', ChargesScreen(), {}),
        const _Onglet('Plus', MenuScreen(), {}),
      ];

  @override
  State<AppShell> createState() => _AppShellState();
}


/// Bandeau hors-ligne : données locales, synchronisation en attente.
/// Le bouton Reconnecter recharge le cloud et efface le mode.
class _BandeauHorsLigne extends StatefulWidget {
  final Store store;
  const _BandeauHorsLigne({required this.store});

  @override
  State<_BandeauHorsLigne> createState() => _BandeauHorsLigneState();
}

class _BandeauHorsLigneState extends State<_BandeauHorsLigne> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF4E0),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined,
            size: 18, color: Color(0xFFB26A00)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Hors-ligne — données locales, synchro en attente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Color(0xFFB26A00),
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        _busy
            ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () async {
                  setState(() => _busy = true);
                  final ok = await widget.store.reconnecter();
                  if (!context.mounted) return;
                  setState(() => _busy = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? '✅ Reconnecté — données à jour'
                          : '📡 Toujours hors-ligne — réessayez plus tard')));
                },
                child: const Text('Reconnecter'),
              ),
      ]),
    );
  }
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    // Onglets autorises pour le role connecte. `index` est BORNÉ : un
    // changement de role retrecit la liste, et un index hors bornes
    // ferait lever une exception Flutter.
    final onglets = AppShell._onglets(store);
    final index = _index.clamp(0, onglets.length - 1);
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
      body: Column(children: [
        // Démarrage hors-ligne (snapshot local) : saisies/modifs/
        // suppressions possibles, file rejouée au retour réseau.
        if (store.demarrageHorsLigne) _BandeauHorsLigne(store: store),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child:
                KeyedSubtree(
                    key: ValueKey(_index),
                    child: onglets[index].page),
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final o in onglets) o.destination(),
        ],
      ),
    );
  }
}

/// Un onglet de la barre de navigation, avec son icone et ses droits.
///
/// `droits` est documente pour le lecteur : la liste d'onglets est
/// filtree par `Store.peut` et non par ce champ (qui sert de trace de
/// l'intention). Le conserver evite qu'un onglet soit ajoute sans que sa
/// condition d'acces soit ecrite au meme endroit que lui.
class _Onglet {
  final String libelle;
  final Widget page;
  final Set<Permission> droits;
  const _Onglet(this.libelle, this.page, this.droits);

  IconData get icone => switch (libelle) {
        'Accueil' => Icons.home_outlined,
        'Achats' => Icons.shopping_cart_outlined,
        'Stock' => Icons.inventory_2_outlined,
        'Dépenses' => Icons.money_off_outlined,
        _ => Icons.grid_view_outlined,
      };

  IconData get iconeActive => switch (libelle) {
        'Accueil' => Icons.home_rounded,
        'Achats' => Icons.shopping_cart_rounded,
        'Stock' => Icons.inventory_2_rounded,
        'Dépenses' => Icons.money_off_rounded,
        _ => Icons.grid_view_rounded,
      };

  NavigationDestination destination() => NavigationDestination(
        icon: Icon(icone),
        selectedIcon: Icon(iconeActive),
        label: libelle,
      );
}
