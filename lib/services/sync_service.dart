import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_service.dart';

/// Synchronisation offline-first (phase P7).
///
/// Principe terrain : une vente saisie SANS réseau n'est JAMAIS perdue.
/// 1. La transaction est écrite localement (Store) ET mise en file Hive.
/// 2. Dès que le réseau revient, la file est poussée vers Supabase.
/// 3. En cas d'échec (serveur occupé), on réessaie au prochain cycle.
///
/// Anticipation : la file contient un champ `essais` — après N échecs,
/// l'entrée est marquée `en_erreur` pour investigation (jamais supprimée
/// silencieusement : une donnée financière ne se perd pas).
class SyncService extends ChangeNotifier {
  // ChangeNotifier : avant ce correctif, une opération bloquée (ex. RLS
  // refusant l'insertion) restait invisible — aucun écran ne lisait
  // enAttente/en_erreur. L'UI (badge AppShell, écran de diagnostic) peut
  // maintenant se reconstruire quand la file change.
  // Singleton : main.dart initialise la box Hive une fois via `init()` ;
  // tous les appels `SyncService()` ailleurs (Store) doivent réutiliser
  // cette même instance, sinon `_box` y reste `null` et mettreEnFile()
  // ne fait jamais rien (aucune erreur visible — silencieux).
  static final SyncService _instance = SyncService._interne();
  factory SyncService() => _instance;
  SyncService._interne();

  static const _boxName = 'file_sync';
  static const _maxEssais = 8;

  final _connectivity = Connectivity();
  StreamSubscription? _sub;
  Box<Map>? _box;
  bool _synchronisationEnCours = false;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
    // Dès que le réseau revient (wifi, 4G…), on pousse la file.
    _sub = _connectivity.onConnectivityChanged.listen((resultats) {
      final connecte = resultats.any((r) => r != ConnectivityResult.none);
      if (connecte) unawaited(synchroniser());
    });
    // Tentative immédiate au démarrage (si déjà en ligne).
    await synchroniser();
  }

  bool get estEnLigneSupabase => SupabaseService.client != null;

  /// Met une opération en file d'attente de synchronisation.
  Future<void> mettreEnFile(Map<String, dynamic> payload,
      {String table = 'transactions'}) async {
    if (_box == null || !estEnLigneSupabase) return; // mode 100 % local : rien à faire
    await _box!.add({
      'table': table,
      'payload': payload,
      'cree_le': DateTime.now().toIso8601String(),
      'essais': 0,
      'en_erreur': false,
      'derniere_erreur': null,
    });
    notifyListeners();
    await synchroniser();
  }

  /// Nombre d'opérations en attente (pas encore en erreur définitive).
  int get enAttente => _box == null
      ? 0
      : _box!.values.where((e) => e['en_erreur'] != true).length;

  /// Opérations bloquées après [_maxEssais] échecs — jamais retentées tant
  /// que [reessayerTout] n'est pas appelé. Avant ce correctif, une entrée
  /// marquée en_erreur restait bloquée pour toujours, y compris après
  /// correction du problème côté serveur (ex. politique RLS ajustée) :
  /// `synchroniser()` l'ignore explicitement (`if (... en_erreur == true) continue`).
  int get enErreur => _box == null
      ? 0
      : _box!.values.where((e) => e['en_erreur'] == true).length;

  /// Détail des opérations en attente/bloquées, pour un écran de diagnostic.
  /// Chaque entrée : table, payload, essais, dernière erreur capturée.
  List<Map> get detailFile => _box == null ? [] : _box!.values.toList();

  /// Remet en circulation toutes les opérations bloquées (en_erreur) et
  /// relance immédiatement une synchronisation. À utiliser après avoir
  /// corrigé la cause du blocage côté serveur (ex. affectation boutique,
  /// politique RLS).
  Future<void> reessayerTout() async {
    if (_box == null) return;
    for (final cle in _box!.keys.toList()) {
      final e = _box!.get(cle);
      if (e == null) continue;
      e['en_erreur'] = false;
      e['essais'] = 0;
      await _box!.put(cle, e);
    }
    notifyListeners();
    await synchroniser();
  }

  /// Supprime définitivement les opérations bloquées (en_erreur), sans les
  /// retenter. À utiliser pour purger des entrées obsolètes (ex. capturées
  /// avant un correctif de bug — un ancien identifiant invalide ou une
  /// mauvaise politique RLS déjà résolue autrement) qui ne réussiront
  /// jamais et n'ont plus de raison d'être retentées. Contrairement à
  /// [reessayerTout], celles encore en attente (jamais bloquées) ne sont
  /// pas touchées : seules les entrées déjà marquées en_erreur disparaissent.
  Future<void> viderErreurs() async {
    if (_box == null) return;
    for (final cle in _box!.keys.toList()) {
      final e = _box!.get(cle);
      if (e != null && e['en_erreur'] == true) {
        await _box!.delete(cle);
      }
    }
    notifyListeners();
  }

  /// Pousse la file vers Supabase. Retourne le nombre d'opérations réussies.
  Future<int> synchroniser() async {
    if (_box == null || !estEnLigneSupabase || _synchronisationEnCours) return 0;
    _synchronisationEnCours = true;
    var reussies = 0;
    try {
      final cles = _box!.keys.cast<dynamic>().toList();
      for (final cle in cles) {
        final entree = _box!.get(cle);
        if (entree == null || entree['en_erreur'] == true) continue;
        final erreur = await _pousser(entree);
        if (erreur == null) {
          await _box!.delete(cle);
          reussies++;
        } else {
          final essais = (entree['essais'] as int? ?? 0) + 1;
          entree['essais'] = essais;
          entree['derniere_erreur'] = erreur;
          if (essais >= _maxEssais) {
            entree['en_erreur'] = true;
            // Ne jamais avaler cette erreur en silence : sans ce message,
            // une vente refusée par la base (ex. politique RLS, boutique
            // non affectée à l'utilisateur) disparaissait sans aucune trace
            // après redémarrage — ni dans l'UI, ni dans la console.
            debugPrint('❌ SyncService : opération bloquée définitivement '
                '(${entree['table']}) — $erreur');
          }
          await _box!.put(cle, entree);
        }
      }
    } finally {
      _synchronisationEnCours = false;
    }
    notifyListeners();
    return reussies;
  }

  /// Pousse une entrée vers Supabase. Retourne `null` si réussi, sinon le
  /// message d'erreur (au lieu d'avaler l'exception comme avant ce correctif).
  /// Transactions : upsert sur l'id (création + correction partagent le même
  /// identifiant client — voir Store.ajouterTransaction qui envoie son id).
  /// Suppressions : table se terminant par '__delete' → delete par id.
  /// Autres tables (produits, partenaires, charges, tarifs…) : upsert sur
  /// l'id pour rejouer les créations/modifications saisies hors-ligne.
  Future<String?> _pousser(Map entree) async {
    try {
      final table = entree['table'] as String;
      final payload = Map<String, dynamic>.from(entree['payload'] as Map);
      final client = SupabaseService.client!;
      if (table.endsWith('__delete')) {
        final vraieTable = table.substring(0, table.length - 8);
        final id = payload['id']?.toString() ?? '';
        await client.from(vraieTable).delete().eq('id', id);
      } else if (table == 'transactions') {
        await client.from(table).upsert(payload, onConflict: 'id');
      } else {
        await client.from(table).upsert(payload, onConflict: 'id');
      }
      return null;
    } catch (e) {
      return e.toString(); // retry au prochain cycle, erreur conservée
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    super.dispose();
  }
}

/// Helper : lance une future fire-and-forget en capturant TOUTE erreur
/// (f.ignore() marque la future comme volontairement non attendue et
/// empêche les "unhandled exception" — contrairement à un no-op).
void unawaited(Future<void> f) => f.ignore();
