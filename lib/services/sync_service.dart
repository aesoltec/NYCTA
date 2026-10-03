import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_service.dart';

/// Verbe a employer pour rejouer une entree de la file.
///
/// Le routage est extrait de `_pousser` dans une fonction PURE pour
/// etre testable sans client Supabase : c'est la decision qui compte,
/// car un mauvais verbe donne une erreur serveur trompeuse
/// (23502 sur une colonne absente du payload).
enum SyncOperation {
  /// `INSERT ... ON CONFLICT DO UPDATE` : la ligne peut ne pas exister.
  upsert,

  /// `UPDATE ... WHERE id = ?` : la ligne doit deja exister, le payload
  /// peut etre partiel (archivage, correction d'un champ).
  patch,

  /// `DELETE ... WHERE id = ?`.
  delete,
}

/// Extension conventionnelle des noms de table dans la file de sync,
/// alignee sur la colonne `table` : suffixe `__delete` (suppression) et
/// `__update` (mise a jour partielle).
class SyncTable {
  static const suffixeDelete = '__delete';
  static const suffixeUpdate = '__update';
}

/// Suffixe de suppression, conserve ici pour compatibilite de lecture.
const _suffixeDelete = '__delete';
/// Suffixe de mise a jour partielle.
const _suffixeUpdate = '__update';

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
///
/// VERBE, PAS QUE LE NOM DE LA TABLE : `upsert` est un
/// `INSERT ... ON CONFLICT DO UPDATE`. Un payload PARTIEL
/// (`{'id', 'actif': false}` pour un archivage) passe sans erreur tant que
/// la ligne existe, mais déclenche `23502 NOT NULL` dès qu'elle
/// n'existe pas encore — cas normal d'un produit créé hors-ligne —
/// puis se bloque définitivement après [_maxEssais] essais. Les mises à
/// jour partielles doivent donc porter le suffixe [SyncTable.suffixeUpdate].
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

  /// File d'entrees injectee pour les TESTS D'AFFICHAGE uniquement.
  ///
  /// `SynchronisationScreen` affiche des messages d'erreur serveur dont
  /// la longueur n'est pas maitrisee : c'est l'ecran le plus expose a un
  /// debordement (constate sur l'appareil : 140 px avec plusieurs
  /// erreurs). Tester exigeait de peupler la file, impossible via un
  /// singleton a Box privee.
  ///
  /// `null` = file reelle. Comportement de production inchange.
  @visibleForTesting
  static List<Map>? entreesPourTest;

  /// Notifie les ecouteurs apres une injection (la liste doit se
  /// reconstruire pour refleter les entrees injectees).
  @visibleForTesting
  static void notifierPourTest() => _instance.notifyListeners();

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
    await reparerEntreesLegacy();
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
  int get enAttente =>
      detailFile.where((e) => e['en_erreur'] != true).length;

  /// Opérations bloquées après [_maxEssais] échecs — jamais retentées tant
  /// que [reessayerTout] n'est pas appelé. Avant ce correctif, une entrée
  /// marquée en_erreur restait bloquée pour toujours, y compris après
  /// correction du problème côté serveur (ex. politique RLS ajustée) :
  /// `synchroniser()` l'ignore explicitement (`if (... en_erreur == true) continue`).
  int get enErreur =>
      detailFile.where((e) => e['en_erreur'] == true).length;

  /// Détail des opérations en attente/bloquées, pour un écran de diagnostic.
  /// Chaque entrée : table, payload, essais, dernière erreur capturée.
  List<Map> get detailFile {
    final injectees = entreesPourTest;
    if (injectees != null) return injectees;
    return _box == null ? [] : _box!.values.toList();
  }

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
  /// Suppressions : table se terminant par `__delete` → delete par id.
  /// Autres tables (produits, partenaires, charges, tarifs…) : upsert sur
  /// l'id pour rejouer les créations/modifications saisies hors-ligne.
  ///
  /// COLONNE ABSENTE (`PGRST204`) : PostgREST rejette toute la requête si le
  /// payload contient une colonne inconnue du schéma. Retenter à
  /// l'identique échouerait [_maxEssais] fois puis bloquerait l'opération
  /// définitivement — la donnée saisie hors-ligne serait PERDUE. On
  /// réessaie donc une fois sans les colonnes optionnelles, en cohérence
  /// avec le repli déjà fait par `CloudRepository.upsertProduit`.
  /// Colonnes UUID **nullables** par table mise en file : une chaine vide
  /// y est un `22P02` garanti (`invalid input syntax for type uuid: ""`),
  /// donc une entree bloquee DEFINITIVEMENT et une donnee perdue.
  ///
  /// Volontairement restreint aux colonnes dont le modele Dart utilise
  /// `''` pour « aucune reference » (cf. `MouvementStock.refId`,
  /// documente « '' si manuel »). Une colonne obligatoireRecevant `''`
  /// n'est PAS listee : la couper silencieusement detruirait l'information
  /// au lieu de la faire echouer visiblement.
  ///
  /// Source : `database/supabase_schema.sql`. Le test
  /// `sync_service_verbes_test.dart` relit ce fichier et verifie
  /// qu'aucune entree de cette table ne designe une colonne NOT NULL.
  static const colonnesUuidOptionnelles = <String, Set<String>>{
    'mouvements_stock': {'ref_id', 'created_by'},
  };

  /// Un payload {id, actif} (ou {id} seul) ne peut pas correspondre a une
  /// CREATION : il manquerait les colonnes NOT NULL de toute table metier
  /// (libelle, montant, boutique_id...). C'est donc un patch herite des
  /// versions qui n'avaient pas de routage par verbe.
  static bool estPatchLegacy(Map payload) {
    if (!payload.containsKey('id')) return false;
    return payload.keys.every((k) => k == 'id' || k == 'actif');
  }

  /// Re-route les entrees bloquees avant le correctif du verbe.
  ///
  /// Sans cela, une entree `{id, actif: false}` deja marquee `en_erreur`
  /// sur l'appareil echouerait encore a chaque `reessayerTout()`, et
  /// l'utilisateur n'aurait aucun moyen de debloquer sa file depuis
  /// l'ecran de diagnostic.
  ///
  /// Ne touche QUE le nom de table : le payload, l'horodatage et
  /// l'historique d'essais restent intacts.
  Future<int> reparerEntreesLegacy() async {
    if (_box == null) return 0;
    var repares = 0;
    for (final cle in _box!.keys.toList()) {
      final e = _box!.get(cle);
      if (e == null) continue;
      final table = e['table'];
      if (table is! String) continue;
      if (operationPour(table) != SyncOperation.upsert) continue;
      final payload = e['payload'];
      if (payload is! Map) continue;

      // Repare 1 : payload PARTIEL rejoue en upsert (INSERT sans
      // boutique_id -> 23502).
      if (estPatchLegacy(payload)) {
        e['table'] = '$table$SyncTable.suffixeUpdate';
        e['en_erreur'] = false;
        e['essais'] = 0;
        await _box!.put(cle, e);
        repares++;
        continue;
      }

      // Repare 2 : chaine VIDE dans une colonne uuid nullable
      // (-> 22P02). La table seule suffit a identifier les colonnes.
      final uuid = colonnesUuidOptionnelles[table];
      if (uuid == null) continue;
      var vide = false;
      for (final colonne in uuid) {
        if (payload[colonne] == '') {
          payload[colonne] = null;
          vide = true;
        }
      }
      if (!vide) continue;
      e['en_erreur'] = false;
      e['essais'] = 0;
      await _box!.put(cle, e);
      repares++;
    }
    if (repares > 0) {
      debugPrint('SyncService : $repares entree(s) partielle(s) re-routee(s) '
          'vers une mise a jour partielle (au lieu d\'un upsert qui aurait '
          'viole boutique_id NOT NULL).');
    }
    return repares;
  }

  /// Verbe a employer pour [table], en fonction du suffixe.
  ///
  /// Fonction PURE : c'est elle, et non le SQL, qui decide si une entree
  /// peut creer une ligne ou seulement la modifier. Un `upsert` sur un
  /// payload partiel est la cause du blocage `23502 boutique_id`.
  static SyncOperation operationPour(String table) {
    if (table.endsWith(_suffixeDelete)) return SyncOperation.delete;
    if (table.endsWith(_suffixeUpdate)) return SyncOperation.patch;
    return SyncOperation.upsert;
  }

  /// Nom de table reel, suffixe de route retire.
  static String tableReelle(String table) => (operationPour(table) ==
          SyncOperation.upsert)
      ? table
      : table.substring(0, table.length - _suffixeDelete.length);

  Future<String?> _pousser(Map entree) async {
    try {
      final table = entree['table'] as String;
      final payload = Map<String, dynamic>.from(entree['payload'] as Map);
      final client = SupabaseService.client!;
      switch (operationPour(table)) {
        case SyncOperation.delete:
          final id = payload['id']?.toString() ?? '';
          await client.from(tableReelle(table)).delete().eq('id', id);

        case SyncOperation.patch:
          // `patch` : la ligne doit deja exister en base. `id` sert de
          // filtre et ne doit pas figurer dans le corps de l'UPDATE.
          final id = payload.remove('id')?.toString() ?? '';
          if (id.isEmpty) return 'entree sans identifiant';
          final touchees = await client
              .from(tableReelle(table))
              .update(payload)
              .eq('id', id)
              .select();
          if (touchees.isEmpty) {
            // 0 ligne mise a jour : la ligne n'existe pas en base. On ne
            // peut PAS la creer depuis un payload partiel (NOT NULL), et
            // on ne doit pas inventer de donnee metier. L'entree est donc
            // consommee, mais la trace reste visible dans la console.
            debugPrint('SyncService : mise a jour sans effet sur '
                '${tableReelle(table)}/$id — la ligne n existe pas en base '
                '(creation hors-ligne non encore synchronisee).');
          }

        case SyncOperation.upsert:
          try {
            await client.from(table).upsert(payload, onConflict: 'id');
          } catch (e) {
            if (!estColonneAbsente(e)) rethrow;
            final leger = sansColonnesOptionnelles(payload);
            if (leger.length == payload.length) rethrow; // rien a retirer
            debugPrint('SyncService : ${entree['table']} — colonne absente '
                'en base, nouvelle tentative sans '
                '${payload.length - leger.length} champ(s) optionnel(s). '
                'Executer database/SUPABASE_A_EXECUTER.sql pour la creer.');
            await client.from(table).upsert(leger, onConflict: 'id');
          }
      }
      return null;
    } catch (e) {
      return e.toString(); // retry au prochain cycle, erreur conservee
    }
  }

  /// Vrai si l'erreur PostgREST est « colonne inexistante » (PGRST204) ou
  /// « colonne non trouvee » (42703) : la requête ne peut pas aboutir tant
  /// que la migration n'est pas appliquée, donc un nouvel essai à
  /// l'identique est inutile.
  @visibleForTesting
  static bool estColonneAbsente(Object e) {
    final t = e.toString();
    return t.contains('PGRST204') ||
        t.contains('42703') ||
        t.contains('Could not find the') ||
        (t.contains('column') && t.contains('does not exist'));
  }

  /// Retire du payload les champs optionnels récemment ajoutés, afin de
  /// ne pas bloquer une synchronisation sur une migration en attente.
  /// Liste volontairement restreinte : retirer une colonne métier
  /// silencieusement masquerait une vraie perte d'information.
  @visibleForTesting
  static const colonnesOptionnelles = <String>[
    'date_ajout', // refonte UX R1 — badge « Nouveau »
  ];

  @visibleForTesting
  static Map<String, dynamic> sansColonnesOptionnelles(
          Map<String, dynamic> payload) =>
      Map<String, dynamic>.from(payload)
        ..removeWhere((k, _) => colonnesOptionnelles.contains(k));

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
