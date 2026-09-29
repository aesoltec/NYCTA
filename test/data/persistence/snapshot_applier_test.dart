import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/boutique_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/data/persistence/serializer.dart';
import 'package:pme_gestion_pro/data/persistence/snapshot_applier.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/data/store_sync.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/boutique.dart';
import 'package:pme_gestion_pro/models/enums.dart';

/// Snapshot cloud minimal : 2 boutiques.
/// Reproduit le crash du premier chargement réel en production
/// (`LateInitializationError: Field '_boutiqueId' has not been
/// initialized`) : le Store sort du constructeur SANS boutique courante
/// (mode cloud) puis `chargerDuCloud` en élit une.
StoreSnapshot _snapshotCloud({
  String? boutiqueId,
  AppUser? user,
  List<Boutique>? boutiques,
}) =>
    StoreSnapshot(
      user: user ??
          const AppUser(id: 'u1', nom: 'Vendeur', role: Role.gerant,
              boutiqueIds: ['b2']),
      boutiqueId: boutiqueId ?? '',
      boutiques: boutiques ??
          const [
            Boutique(id: 'b1', nom: 'Siege'),
            Boutique(id: 'b2', nom: 'Annexe'),
          ],
    );

Store _store() => Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

SessionNotifier _session() =>
    SessionNotifier(const AppUser(id: 'u', nom: 'T', role: Role.admin));

void main() {
  group('SnapshotApplier — choix de la boutique courante', () {
    test('ne lève pas et élit la boutique accessible (crash 6bis)', () {
      final store = _store();
      SnapshotApplier.appliquer(store, _snapshotCloud(),
          choisirBoutique: true);
      expect(store.boutiqueId, 'b2');
      expect(store.boutique.boutiqueId, 'b2');
      expect(store.boutiqueCourante.id, 'b2');
    });

    test('respecte la boutique demandée si elle est accessible', () {
      final store = _store();
      SnapshotApplier.appliquer(
          store, _snapshotCloud(boutiqueId: 'b2'), choisirBoutique: true);
      expect(store.boutiqueId, 'b2');
    });

    test('demande non accessible : élit une boutique réellement '
        'accessible, jamais un identifiant fantôme', () {
      final store = _store();
      // b1 n'est pas dans boutiqueIds du gérant : la courante ne doit
      // surtout pas rester sur l'ancienne valeur (ici `bt_siege` du
      // mode démo, boutique qui n'existe plus après application).
      SnapshotApplier.appliquer(
          store, _snapshotCloud(boutiqueId: 'b1'), choisirBoutique: true);
      expect(store.boutiqueId, 'b2');
      expect(store.boutiques.map((b) => b.id), contains(store.boutiqueId));
    });

    test('propage la boutique aux Notifiers qui filtrent', () {
      final store = _store();
      SnapshotApplier.appliquer(store, _snapshotCloud(),
          choisirBoutique: true);
      for (final n in <dynamic>[
        store.transaction,
        store.charge,
        store.produit,
        store.achat,
        store.document,
        store.compta,
        store.analytique,
        store.client,
        store.boutique,
      ]) {
        expect(n.boutiqueId as String, 'b2',
            reason: 'Notifier non synchronisé sur la boutique courante');
      }
    });

    test('compte sans accès à une boutique : courante neutre, aucun crash',
        () {
      final store = _store();
      SnapshotApplier.appliquer(
        store,
        _snapshotCloud(
            user: const AppUser(id: 'u2', nom: 'Isolé', role: Role.gerant)),
        choisirBoutique: true,
      );
      expect(store.boutiqueId, '');
      expect(store.boutiqueCourante.nom, 'Aucune boutique');
    });

    test('snapshot sans boutique : aucun throw', () {
      final store = _store();
      final s = _snapshotCloud(boutiques: const []);
      expect(() => SnapshotApplier.appliquer(store, s, choisirBoutique: true),
          returnsNormally);
    });

    test('ne touche pas aux catégories vides (cloud prioritaire)', () {
      final store = _store();
      final avant = store.catsProduit.length;
      final s = _snapshotCloud()..catsProduit = [];
      SnapshotApplier.appliquer(store, s);
      expect(store.catsProduit.length, avant);
    });
  });

  group('BoutiqueNotifier.boutiqueCourante', () {
    test('boutique neutre si aucune n\'est élue (pas de StateError)', () {
      final n = BoutiqueNotifier(
        session: _session(),
        genererId: () => 'x',
        boutiques: const [Boutique(id: 'b1', nom: 'Siege')],
        // boutiqueId laissé à '' : cas « compte sans boutique » et fenêtre
        // entre la connexion et la fin de chargerDuCloud.
      );
      expect(n.boutiqueId, '');
      expect(() => n.boutiqueCourante, returnsNormally);
      expect(n.boutiqueCourante.nom, 'Aucune boutique');
    });

    test('liste vide : boutique neutre', () {
      final n = BoutiqueNotifier(session: _session(), genererId: () => 'x');
      expect(n.boutiqueCourante.nom, 'Aucune boutique');
    });
  });

  group('StoreSync.elireBoutiqueAccessible (repli hors-ligne)', () {
    test('élit la première boutique accessible du profil restauré', () {
      final store = _store();
      store.boutiques
        ..clear()
        ..addAll(const [
          Boutique(id: 'b1', nom: 'Siege'),
          Boutique(id: 'b2', nom: 'Annexe'),
        ]);
      store.user = const AppUser(
          id: 'u1', nom: 'V', role: Role.gerant, boutiqueIds: ['b2']);
      StoreSync.elireBoutiqueAccessible(store);
      expect(store.boutiqueId, 'b2');
    });

    test('sans boutique : reste neutre', () {
      final store = _store();
      store.definirBoutiqueCourante(''); // état mode cloud : aucune courante
      store.boutiques.clear();
      StoreSync.elireBoutiqueAccessible(store);
      expect(store.boutiqueId, '');
    });

    test('compte sans accès : première du jeu (pas de boutique fantôme)',
        () {
      final store = _store();
      store.boutiques
        ..clear()
        ..addAll(const [Boutique(id: 'b1', nom: 'Siege')]);
      store.user =
          const AppUser(id: 'u2', nom: 'Isole', role: Role.gerant);
      StoreSync.elireBoutiqueAccessible(store);
      expect(store.boutiqueId, ''); // refus d'accès -> neutre, cohérent
      expect(store.boutiqueCourante.nom, 'Aucune boutique');
    });
  });

  group('Store.changerBoutique (sélecteur du menu)', () {
    test('refuse une boutique inexistante (même pour un admin)', () {
      final store = _store();
      final avant = store.boutiqueId;
      store.changerBoutique('fantome');
      expect(store.boutiqueId, avant);
    });

    test('accepte une boutique existante', () {
      final store = _store();
      store.changerBoutique(store.boutiques.last.id);
      expect(store.boutiqueId, store.boutiques.last.id);
    });
  });

  group('Garde-fou structurel (bug 6bis)', () {
    test('Store ne déclare aucun champ `late` non final', () {
      final src = File('lib/data/store.dart').readAsStringSync();
      // `late final _bundle` est sûr : assigné en 1re instruction du
      // constructeur, jamais lu avant. Un `late` simple, lui, peut être
      // lu avant affectation -> LateInitializationError (le bug 6bis).
      final lates = RegExp(r'^\s*late\s+(?!final)', multiLine: true)
          .allMatches(src)
          .map((m) =>
              src.substring(m.start, src.indexOf('\n', m.start)).trim())
          .toList();
      expect(lates, isEmpty,
          reason: 'Un `late` sur un champ d\'instance réintroduirait le '
              'crash du premier chargement cloud : $lates');
    });
  });
}
