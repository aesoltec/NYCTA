import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/wiring.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';

/// Charge de test (catégorie « Loyer » → 6xx / 571).
Charge _charge() => Charge(
      id: 'c1',
      boutiqueId: 'b1',
      categorie: 'Loyer',
      libelle: 'Loyer test',
      montant: 1000,
      date: DateTime(2026, 9, 1),
    );

/// Phase 6bis — `NotifierWiring` : construction du faisceau à partir d'un
/// Store réel (les listes sont partagées par référence).
NotifierBundle _faisceau(Store store) =>
    NotifierWiring.construire(EntreesWiring(
      store: store,
      user: store.user,
      users: store.users,
      boutiques: store.boutiques,
      transactions: store.transactions,
      produits: store.produits,
      partenaires: store.partenaires,
      partages: store.partages,
      depenses: store.depenses,
      clients: store.clients,
      fournisseurs: store.fournisseurs,
      messages: store.messages,
      evenements: store.evenements,
      notesPerso: store.notesPerso,
      feedbacks: store.feedbacks,
      catalogue: store.catalogue,
      documentsEmis: store.documentsEmis,
      achats: store.achats,
      mouvements: store.mouvements,
      ecritures: store.ecritures,
      genererId: store.genererId,
      fileUpsert: store.fileUpsert,
      numeroDocument: store.numeroDocument,
    ));

void main() {
  group('NotifierWiring.construire', () {
    test('construit les 16 Notifiers', () {
      final b = _faisceau(Store(
          const AppUser(id: 'u', nom: 'T', role: Role.admin)));
      expect(b.tous.length, 16);
    });

    test('partage les listes du Store par référence', () {
      final store =
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final b = _faisceau(store);
      expect(identical(b.produit.produits, store.produits), isTrue);
      expect(identical(b.charge.depenses, store.depenses), isTrue);
      expect(identical(b.compta.ecritures, store.ecritures), isTrue);
      expect(identical(b.analytique.transactions, store.transactions),
          isTrue);
      expect(identical(b.achat.depenses, store.depenses), isTrue);
    });

    test('compta câblée : une charge poste 2 écritures équilibrées',
        () async {
      final store =
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final b = _faisceau(store);
      b.charge.boutiqueId = 'b1';
      b.compta.boutiqueId = 'b1';
      await b.charge.ajouterCharge(_charge());
      expect(store.ecritures.length, 2);
      final d = store.ecritures.fold(0.0, (s, e) => s + e.debit);
      final c = store.ecritures.fold(0.0, (s, e) => s + e.credit);
      expect(d, closeTo(c, 0.01));
      expect(store.ecritures.every((e) => e.refId.isNotEmpty), isTrue);
    });

    test('session initiale + permissions', () {
      final store =
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final b = _faisceau(store);
      expect(b.session.user.id, 'u');
      expect(b.session.peut(Permission.vendre), isTrue);
    });

    test('catégories : valeurs par défaut en mode démo', () {
      final store =
          Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));
      final b = _faisceau(store);
      expect(b.categories.catsProduit, isNotEmpty);
      expect(b.categories.catsCharge, isNotEmpty);
    });
  });
}
