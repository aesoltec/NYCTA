import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/screens/shell/app_shell.dart';

/// FUITE CONFIRMEE, corrigee ici.
///
/// La barre de navigation du bas etait une liste `const` de 5
/// destinations, sans aucun filtrage par droits. Un VENDEUR pouvait donc
/// ouvrir « Depenses » (charges de l'entreprise) et « Achats »
/// (fournisseurs, montants), alors que le menu « Plus » les lui cachait
/// correctement. Deux entrees, deux traitements : c'est exactement
/// l'ecart que MATRICE_PERMISSIONS.md qualifie de bug.
void main() {
  Store _store(Role role) =>
      Store(AppUser(id: 'u', nom: 'Test', role: role));

  group('barre de navigation filtree par les droits', () {
    test('le VENDEUR n a pas l onglet Depenses', () {
      final onglets = AppShell.ongletsAutorises(_store(Role.vendeur));
      expect(onglets, isNot(contains('Dépenses')),
          reason: 'un vendeur n a aucun droit gererDepenses ; il ne doit '
              'pas voir les charges de l entreprise');
      expect(onglets, isNot(contains('Achats')));
    });

    test('le VENDEUR voit le stock (il vend)', () {
      expect(AppShell.ongletsAutorises(_store(Role.vendeur)),
          contains('Stock'));
    });

    test('le CAISSIER n a ni Depenses ni Achats, mais voit le stock', () {
      final onglets = AppShell.ongletsAutorises(_store(Role.caissier));
      expect(onglets, contains('Stock'));
      expect(onglets, isNot(contains('Dépenses')));
      expect(onglets, isNot(contains('Achats')));
    });

    test('le STAGIAIRE ne voit que Accueil et Plus', () {
      expect(AppShell.ongletsAutorises(_store(Role.stagiaire)),
          ['Accueil', 'Plus']);
    });

    test('l ADMIN voit tout', () {
      final onglets = AppShell.ongletsAutorises(_store(Role.admin));
      expect(onglets, containsAll(['Accueil', 'Achats', 'Stock', 'Dépenses', 'Plus']));
    });

    test('le GERANT et le COMPTABLE voient Depenses', () {
      expect(AppShell.ongletsAutorises(_store(Role.gerant)),
          contains('Dépenses'));
      expect(AppShell.ongletsAutorises(_store(Role.comptable)),
          contains('Dépenses'));
    });

    test('Accueil et Plus restent accessibles a tous', () {
      for (final r in Role.values) {
        final onglets = AppShell.ongletsAutorises(_store(r));
        expect(onglets, contains('Accueil'), reason: '$r');
        expect(onglets, contains('Plus'), reason: '$r');
      }
    });

    test('aucun role ne recoit un onglet qu il n a pas le droit de voir', () {
      // Table de verite : onglet -> droit requis
      const requis = {
        'Achats': Permission.gererAchats,
        'Stock': Permission.voirStock,
        'Dépenses': Permission.gererDepenses,
      };
      for (final r in Role.values) {
        final onglets = AppShell.ongletsAutorises(_store(r));
        requis.forEach((onglet, droit) {
          if (onglets.contains(onglet)) {
            expect(rolePermissions[r], contains(droit),
                reason: '$r voit $onglet sans $droit');
          }
        });
      }
    });
  });
}
