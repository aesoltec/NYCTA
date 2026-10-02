import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou typographique PDF.
///
/// Les polices integrees de `package:pdf` (Helvetica, Times) ne couvrent
/// que le Latin-1 (U+0000..U+00FF). Tout caractere au-dela est
/// SILENCIEUSEMENT PERDU du PDF genere.
///
/// Preuve relevee sur l'appareil pendant une generation reelle :
///   `Unable to find a font to draw "-" (U+2014) try to provide a
///    TextStyle.fontFallback`
///
/// Consequence : le tiret cadratin des libelles de signature sortait
/// avec un trou. Les accents / euro / degre sont Latin-1 : ils
/// s'impriment normalement.
void main() {
  /// `pdf_service.dart` est le constructeur de TOUS les documents
  /// (facture, BL, ticket, signatures) : son contenu entier est dans le
  /// perimetre.
  ///
  /// Pour les ecrans, seul le TEXTE DESSINE compte : une interface
  /// Flutter utilise Roboto (Unicode complet), mais des qu'on passe par
  /// `pw.` on retombe sur Helvetica/Times (Latin-1). D'ou le filtre
  /// `ligne contenant 'pw.'` -- un `Text('Rechercher\u2026')` ou une
  /// `SnackBar('\u26a0')` sont parfaitement valides a l'ecran.
  const perimetre = <String, bool>{
    'lib/services/pdf_service.dart': true, // fichier entier
    'lib/services/export_service.dart': false,
    'lib/screens/rapports/analytique_detail_screen.dart': false,
  };

  /// Retire commentaires et chaines des couleurs : on ne teste que le
  /// texte reellement dessine.
  String sansCommentaires(String source) => source
      .split('\n')
      .where((l) {
        final t = l.trim();
        return !t.startsWith('//');
      })
      .join('\n');

  /// « -(U+2014) » : lisible dans un rapport d'echec.
  String etiquette(String c) {
    final code = c.codeUnitAt(0)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    return '$c(U+$code)';
  }

  test('aucun caractere hors Latin-1 dans le texte imprime en PDF', () {
    final coupables = <String>[];

    for (final entree in perimetre.entries) {
      final chemin = entree.key;
      final toutLeFichier = entree.value;
      final lignes = sansCommentaires(File(chemin).readAsStringSync())
          .split('\n');
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (!toutLeFichier && !l.contains('pw.')) continue;
        final horsLatin1 = <String>{
          for (final c in l.split(''))
            if (c.trim().isNotEmpty && c.codeUnitAt(0) > 0xFF) c
        };
        if (horsLatin1.isEmpty) continue;
        final detail = horsLatin1.map(etiquette).join(' ');
        coupables.add('$chemin:${i + 1} $detail');      }
    }

    expect(coupables, isEmpty,
        reason: 'caractere(s) hors Latin-1 : absent(s) du PDF genere, '
            'silencieusement. Utiliser un tiret ASCII `-` plutot que le '
            'tiret cadratin.\n${coupables.join('\n')}');
  });

  test('les accents restent presents (Latin-1, ils doivent s\'imprimer)', () {
    final source = File('lib/services/pdf_service.dart').readAsStringSync();
    // une回归 : on ne "corrige" pas au point de supprimer les accents
    expect(source, contains('é'));
    expect(source, contains('à'));
  });
}
