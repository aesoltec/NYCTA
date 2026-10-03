import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/sync_service.dart';

/// Régression bloquante observée SUR L'APPAREIL :
/// `SyncService : opération bloquée définitivement (produits) —
/// null value in column "boutique_id" of relation "produits" violates
/// not-null constraint (23502)`.
///
/// Cause : les payloadS PARTIELS d'archivage passaient par `upsert`, qui
/// est un `INSERT ... ON CONFLICT DO UPDATE`. Dès que la ligne
/// n'existe pas en base — cas normal d'un produit créé hors-ligne —
/// le serveur essaie d'insérer `{id, actif: false}` et viole
/// `boutique_id NOT NULL`. Après 8 essais, l'entrée était bloquée
/// définitivement et l'archive / l'ajustement de stock n'atteignait
/// jamais le cloud.
void main() {
  group('routage du verbe', () {
    test('table nue → upsert (création ou modification complète)', () {
      expect(SyncService.operationPour('produits'), SyncOperation.upsert);
      expect(SyncService.tableReelle('produits'), 'produits');
    });

    test('__update → patch', () {
      expect(
          SyncService.operationPour('produits__update'), SyncOperation.patch);
      expect(SyncService.tableReelle('produits__update'), 'produits');
      expect(
          SyncService.operationPour('partenaires__update'), SyncOperation.patch);
    });

    test('__delete → delete', () {
      expect(
          SyncService.operationPour('transactions__delete'), SyncOperation.delete);
      expect(SyncService.tableReelle('transactions__delete'), 'transactions');
    });

    test('la table réelle ne perd pas le suffixe des noms composés', () {
      expect(SyncService.tableReelle('produits__update'), 'produits');
      expect(SyncService.tableReelle('catalogue__update'), 'catalogue');
    });
  });

  group('détection d\'un payload partiel', () {
    test('{id, actif} est un patch', () {
      expect(SyncService.estPatchLegacy({'id': 'p1', 'actif': false}), isTrue);
    });

    test('{id} seul est un patch', () {
      expect(SyncService.estPatchLegacy({'id': 'p1'}), isTrue);
    });

    test('un payload complet n\'est PAS un patch', () {
      expect(
          SyncService.estPatchLegacy({
            'id': 'p1',
            'libelle': 'Câble',
            'prix_achat': 1000,
          }),
          isFalse);
    });

    test('sans identifiant, jamais un patch', () {
      expect(SyncService.estPatchLegacy({'actif': false}), isFalse);
    });
  });

  group('garde-fou structurel des appelants', () {
    /// Lit `lib/` et verifie qu'aucun appel `fileUpsert` n'envoie un
    /// payload partiel sur une table SANS suffixe de route.
    ///
    /// C'est la protection contre le retour du bug : la regle est dans
    /// le code, mais les appelants sont multiples et disperses.
    List<File> sources() {
      final racine = Directory.current.path;
      return Directory('$racine${Platform.pathSeparator}lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('aucun fileUpsert avec payload partiel sur table nue', () {
      const partielles = {'id', 'actif'};
      final coupables = <String>[];

      for (final f in sources()) {
        final lignes = f.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          if (!l.contains('fileUpsert')) continue;
          // fenetre de 4 lignes : l'appel peut etre multi-lignes
          final bloc =
              lignes.sublist(i, (i + 5).clamp(0, lignes.length)).join('\n');
          final table = RegExp(r"""call\(\s*'([a-z_]+)'""").firstMatch(bloc);
          if (table == null) continue;
          final nom = table.group(1)!;
          if (nom.contains('__')) continue; // deja route
          if (!RegExp(r"""\{[^}]*'id'\s*:""").hasMatch(bloc)) continue;
          // toutes les cles du payload sont-elles partielles ?
          final cles = RegExp(r"'([a-z_]+)'\s*:")
              .allMatches(bloc.split('{').last)
              .map((m) => m.group(1)!)
              .where((c) => c != 'table')
              .toSet();
          if (cles.isNotEmpty && cles.every(partielles.contains)) {
            coupables.add(
                '${f.path.replaceAll(Platform.pathSeparator, '/')}:${i + 1}');
          }
        }
      }

      expect(coupables, isEmpty,
          reason: 'payload PARTIEL envoye sur une table sans suffixe '
              '__update : l\'upsert tentera un INSERT sans boutique_id '
              '(23502). Utiliser table__update.\n${coupables.join('\n')}');
    });

    test('le retour de l\'archivage produit est bien un __update', () {
      final source = File('lib/data/notifiers/produit_notifier.dart')
          .readAsStringSync();
      expect(source, contains("'produits__update'"));
      expect(source, isNot(contains("call('produits', {'id': id")));
    });

    test('l\'ajustement de stock envoie un payload COMPLET', () {
      final source =
          File('lib/data/notifiers/stock_mouvement_notifier.dart')
              .readAsStringSync();
      expect(source, contains('StoreSync.payloadProduit(maj)'),
          reason: '`{\'id\'}` seul ne peut pas cr\u00e9er de ligne');
    });
  });

  group('colonnes uuid optionnelles (22P02)', () {
    /// Relit le schema et rend, par table, ses colonnes uuid NOT NULL.
    Map<String, Set<String>> uuidNotNull() {
      final source = File('database/supabase_schema.sql').readAsStringSync();
      final resultat = <String, Set<String>>{};
      final tables = RegExp(
              r'create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\);',
              dotAll: true)
          .allMatches(source);
      for (final t in tables) {
        final nom = t.group(1)!;
        final notNull = <String>{};
        for (final ligne in t.group(2)!.split('\n')) {
          final propre = ligne.split('--').first.trim();
          final m = RegExp(r'^(\w+)\s+uuid\b').firstMatch(propre);
          if (m == null) continue;
          final reste = propre.substring(m.end);
          // `uuid` suivi de `not null` = obligatoire
          if (RegExp(r'\bnot\s+null\b').hasMatch(reste)) notNull.add(m.group(1)!);
        }
        if (notNull.isNotEmpty) resultat[nom] = notNull;
      }
      return resultat;
    }

    test('aucune colonne listee n est uuid NOT NULL dans le schema', () {
      final notNull = uuidNotNull();
      final coupables = <String>[];
      SyncService.colonnesUuidOptionnelles.forEach((table, colonnes) {
        for (final c in colonnes) {
          if ((notNull[table] ?? const <String>{}).contains(c)) {
            coupables.add('$table.$c');
          }
        }
      });
      expect(coupables, isEmpty,
          reason: 'une colonne NOT NULL ne peut pas valoir null : la '
              'reparation la rebloquerait et masquerait une vraie erreur '
              'de donnee.\n${coupables.join(', ')}');
    });

    test('chaque table listee existe dans le schema', () {
      final source = File('database/supabase_schema.sql').readAsStringSync();
      final tables = RegExp(r'create table (?:if not exists )?public\.(\w+)')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      for (final table in SyncService.colonnesUuidOptionnelles.keys) {
        expect(tables, contains(table),
            reason: '$table n existe plus dans le schema');
      }
    });

    test('mouvements_stock.ref_id et created_by sont des uuid NULLABLE', () {
      final source = File('database/supabase_schema.sql').readAsStringSync();
      final notNull = uuidNotNull()['mouvements_stock'] ?? const <String>{};
      // nullable -> absentes de la table des NOT NULL
      expect(notNull, isNot(contains('ref_id')));
      expect(notNull, isNot(contains('created_by')));
      // et bien des uuid
      expect(source, contains('ref_id'));
      expect(source, contains('created_by'));
    });
  });

}
