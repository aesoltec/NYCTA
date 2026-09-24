import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'core/env.dart';
import 'core/theme.dart';
import 'data/store.dart';
import 'models/app_user.dart';
import 'screens/login/login_screen.dart'; // CloudLoader inclus
import 'services/local_persistence.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // CRITIQUE : initialise les données de locale fr_FR — sans cela,
  // NumberFormat('#,##0', 'fr_FR') lève une exception au 1er montant.
  await initializeDateFormatting('fr_FR', null);
  Intl.defaultLocale = 'fr_FR';
  // En cas d'erreur de rendu : placeholder gris discret au lieu de l'écran rouge.
  ErrorWidget.builder = (details) => Container(
        color: const Color(0xFFF4F6FA),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('Contenu indisponible',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
  await Env.load(); // charge .env (valeurs de secours si absent)
  await SupabaseService.init(); // cloud si SUPABASE_URL renseigné, sinon local
  await LocalPersistence.init(); // persistance locale de l'état (mode démo)
  await SyncService().init(); // file offline-first + auto-sync réseau
  await NotificationService.init();
  runApp(const PmeApp());
}

class PmeApp extends StatelessWidget {
  const PmeApp({super.key});
  static bool _notificationsVerifiees = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Store(const AppUser(id: 'u_admin', nom: 'Patron')),
      child: MaterialApp(
        title: 'NYCTA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Localisation FR : sans ces délégués, showDatePicker avec
        // locale fr-FR ne peut pas résoudre ses chaînes et affiche une
        // page blanche sur certaines plateformes (bug Phase 1).
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // ============ GARDE ANTI-OVERFLOW GLOBALE ============
        // La police système (accessibilité) est bornée à 115 % : c'est la
        // cause n°1 de layoutOverflow sur les apps en production.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          // Après le 1er rendu : vérification des alertes (stock, budgets,
          // clôture, sauvegarde) sur le Store du Provider — une seule fois.
          if (!_notificationsVerifiees) {
            _notificationsVerifiees = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                NotificationService.verifier(context.read<Store>());
              } catch (_) {/* notifications non bloquantes */}
            });
          }
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler
                  .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: child!,
          );
        },
        home: SupabaseService.utilisateur != null
            ? const CloudLoader() // session valide → chargement cloud direct
            : const LoginScreen(),
      ),
    );
  }
}
