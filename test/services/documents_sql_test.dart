import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le SQL livré doit etre coherent avec le code Dart.
///
/// Un test qui lit le `.sql` verifie ce que le testeur Dart ne peut pas
/// voir : si la colonne s'appelle `unite` dans le schema mais
/// `unit` dans le code, l'application ecrira silencieusement dans le
/// vide et l'utilisateur perdra ses donnees sans aucun message.
void main() {
  final sql = File('database/DML_DATES_DOCUMENTS.sql').readAsStringSync();

  group('colonnes attendues par le code', () {
    // Chaque colonne vient d'une ecriture ou d'une lecture reelle du code.
    const attendues = {
      'date_doc': 'date du document',
      'note': 'note libre / conditions',
      'adresse_livraison': 'adresse de livraison',
      'echeance': 'date d echeance',
      'delai_paiement_jours': 'delai de reglement',
      'unite': 'unite de vente par ligne',
      'reference': 'reference article par ligne',
    };

    for (final e in attendues.entries) {
      test('${e.key} (${e.value}) est creee', () {
        expect(sql, contains('ADD COLUMN ${e.key}'),
            reason: 'le code ecrit/lit «${e.key} » : sans colonne, '
                'l ecriture echoue silencieusement ou la valeur est '
                'perdue au rechargement');
      });
    }

    test('les colonnes de lignes portent NOT NULL DEFAULT', () {
      // Une colonne sans DEFAULT rend l INSERT des lignes existantes
      // invalide : l'import d'un portefeuille deja enregistre casse.
      expect(sql, matches(RegExp(r"ADD COLUMN unite text NOT NULL DEFAULT 'pcs'")));
      expect(sql,
          matches(RegExp(r"ADD COLUMN reference text NOT NULL DEFAULT ''")));
    });
  });

  group('securite du journal', () {
    test('la table du journal existe', () {
      expect(sql, contains('CREATE TABLE IF NOT EXISTS document_modifications'));
    });

    test('RLS active, avec policies SELECT et INSERT', () {
      expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('document_modifications_select'));
      expect(sql, contains('document_modifications_insert'));
    });

    test('AUCUNE policy UPDATE ni DELETE : une trace ne se corrige pas',
        () {
      // C est le point essentiel de la tracabilite : autoriser la
      // modification d une trace viderait le journal de son sens.
      expect(sql, isNot(contains('ON document_modifications\n  FOR UPDATE')));
      expect(sql,
          isNot(matches(RegExp(r'document_modifications_delete'))));
      expect(sql, isNot(matches(RegExp(r'FOR DELETE'))));
    });

    test('les policies filtrent sur boutique_id', () {
      // Sans ce filtre, un document d une boutique serait lisible par
      // les utilisateurs d une autre.
      final bloc = sql.substring(sql.indexOf('document_modifications_select'));
      expect(bloc, contains('boutique_id IN'));
    });

    test('index unique : une correction ne peut pas etre ecrite 2 fois',
        () {
      expect(sql, contains('idx_document_modifications_unique'));
    });
  });

  group('idempotence', () {
    test('toute creation de colonne est conditionnee', () {
      // Relancer le fichier ne doit pas echouer : l utilisateur peut le
      // executer plusieurs fois sans y casser sa base.
      final blocs = 'ADD COLUMN'.allMatches(sql).length;
      final gardes = 'IF NOT EXISTS (SELECT 1 FROM information_schema.columns'
              .allMatches(sql)
              .length +
          'CREATE TABLE IF NOT EXISTS'.allMatches(sql).length;
      expect(blocs, greaterThan(0));
      expect(gardes, greaterThanOrEqualTo(blocs),
          reason: 'chaque ADD COLUMN doit etre garde par un IF NOT EXISTS');
    });

    test('les policies sont recreees (DROP ... IF EXISTS avant CREATE)', () {
      expect(sql, contains('DROP POLICY IF EXISTS document_modifications_select'));
      expect(
          sql, contains('DROP POLICY IF EXISTS document_modifications_insert'));
    });
  });

  group('absence de donnees destructrices', () {
    test('aucun DROP TABLE ni TRUNCATE', () {
      expect(sql.toUpperCase(), isNot(contains('DROP TABLE')));
      expect(sql.toUpperCase(), isNot(contains('TRUNCATE')));
    });

    test('aucun UPDATE sans garde sur documents', () {
      // Les UPDATE presents ne touchent que des valeurs nulles -> ils
      // remplissent des defauts, ils n ecrasent aucune donnee saisie.
      final updates =
          RegExp(r'UPDATE\s+(\w+)', caseSensitive: false)
              .allMatches(sql)
              .map((m) => m.group(1)?.toUpperCase() ?? '')
              .where((t) => t.isNotEmpty)
              .toSet();
      for (final table in updates) {
        final pattern = 'UPDATE $table';
        final idx = sql.toUpperCase().indexOf(pattern);
        if (idx < 0) continue; // commentaire ou structure inattendue
        final bloc = sql.substring(idx, (idx + 260).clamp(0, sql.length));
        expect(bloc.toUpperCase(),
            anyOf(contains('IS NULL'), contains("= ''")),
            reason: 'UPDATE sur $table sans garde : il ecraserait des '
                'valeurs deja saisies');
      }
    });
  });
}