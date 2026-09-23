import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/store.dart';
import '../models/enums.dart';

/// Notifications locales (dans le téléphone, sans serveur) :
/// - ⚠️ stock bas
/// - 💸 budget de charge dépassé
/// - 📅 rappel clôture mensuelle des partages partenaires (à partir du 28)
/// - 💾 rappel sauvegarde hebdomadaire (le lundi)
///
/// Vérifiées à chaque ouverture de l'app — zéro configuration.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _canal = NotificationDetails(
    android: AndroidNotificationDetails(
      'pme_gestion_alerts', 'Alertes de gestion',
      channelDescription: 'Stock, budgets, clôtures et sauvegardes',
      importance: Importance.high, priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Mémoire des notifications déjà affichées (une par famille et par
  /// jour — sinon le rappel « stock bas » se réaffiche à chaque ouverture
  /// tant qu'un produit reste sous son seuil).
  static Box? _memoire;
  static const _familles = ['stock', 'budget', 'cloture', 'sauvegarde', 'evenements', 'rappels', 'feedbacks'];

  static Future<void> init() async {
    _memoire = await Hive.openBox('notifs_memoire');
    // Purge des entrées d'un autre jour (évite la croissance du stockage).
    final aujourdhui = _cleJour();
    for (final f in _familles) {
      if (_memoire?.get(f) != null && _memoire?.get(f) != aujourdhui) {
        await _memoire?.delete(f);
      }
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ : demande la permission dès la 1re ouverture
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static String _cleJour() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Affiche seulement si cette famille n'a pas déjà notifié aujourd'hui.
  static Future<void> _notifier(int id, String titre, String corps,
      {required String famille}) async {
    final memoire = _memoire;
    if (memoire != null) {
      final cle = _cleJour();
      if (memoire.get(famille) == cle) return; // déjà notifié aujourd'hui
      await memoire.put(famille, cle);
    }
    await _plugin.show(id, titre, corps, _canal);
  }

  /// Passe de vérification complète — appelée au démarrage et après
  /// chaque synchronisation. Une seule notification par famille et par
  /// ouverture (les id fixes évitent le spam).
  static Future<void> verifier(Store store) async {
    // 1. Stock bas
    final alertes = store.alertesStock;
    if (alertes.isNotEmpty) {
      await _notifier(1, '⚠️ Stock bas', famille: 'stock',
          '${alertes.length} produit(s) à réapprovisionner : '
          '${alertes.take(3).map((p) => p.libelle).join(', ')}${alertes.length > 3 ? '…' : ''}');
    }

    // 2. Budget dépassé
    final depasses = store.suiviBudgets.entries
        .where((e) => e.value.$2 > e.value.$1)
        .toList();
    if (depasses.isNotEmpty) {
      await _notifier(2, '💸 Budget dépassé', famille: 'budget',
          '${depasses.length} catégorie(s) : '
          '${depasses.take(2).map((e) => e.key).join(', ')}');
    }

    // 3. Rappel clôture mensuelle (du 28 au dernier jour du mois)
    final maintenant = DateTime.now();
    final mois = store.moisCourant;
    if (maintenant.day >= 28 && store.partenaires.isNotEmpty) {
      final nonClotures = store.partenaires
          .where((p) => !store.partageExiste(p.id, mois))
          .toList();
      if (nonClotures.isNotEmpty) {
        await _notifier(3, '📅 Clôture du mois $mois', famille: 'cloture',
            '${nonClotures.length} partenaire(s) à clôturer : '
            '${nonClotures.take(2).map((p) => p.nom).join(', ')}');
      }
    }

    // 3bis. Événements aujourd'hui
    final eventsAujourdhui = store.evenements.where((e) {
      final n = DateTime.now();
      return e.date.year == n.year && e.date.month == n.month && e.date.day == n.day;
    }).toList();
    if (eventsAujourdhui.isNotEmpty) {
      await _notifier(5, '📅 Événement aujourd\'hui',
          eventsAujourdhui.map((e) => e.titre).join(' · '),
          famille: 'evenements');
    }

    // 3ter. Rappels de notes dus aujourd'hui
    final rappels = store.notesPerso.where((n) => n.rappelAujourdhui).toList();
    if (rappels.isNotEmpty) {
      await _notifier(6, '⏰ Rappel',
          rappels.map((n) => n.titre).join(' · '), famille: 'rappels');
    }

    // 3quater. Nouvelles contributions (admin/gérant uniquement)
    if (store.role == Role.admin || store.role == Role.gerant) {
      final nouveaux = store.nouveauxFeedbacks;
      if (nouveaux > 0) {
        await _notifier(7, '💬 Suggestions & signalements',
            '$nouveaux contribution(s) en attente de traitement',
            famille: 'feedbacks');
      }
    }

    // 4. Rappel sauvegarde (le lundi)
    if (maintenant.weekday == DateTime.monday) {
      await _notifier(4, '💾 Sauvegarde hebdomadaire', famille: 'sauvegarde',
          'Pensez à exporter votre sauvegarde complète '
          '(Plus → Sauvegardes & exports)');
    }
  }
}
