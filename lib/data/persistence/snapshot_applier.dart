import '../store.dart';
import 'serializer.dart';

/// Application d'un [StoreSnapshot] aux listes du [Store] (Phase 6bis).
///
/// Extraite de `Store._appliquerSnapshot` : la fusion est décrit ici en
/// une seule fois. Règle d'origine conservée — les listes de catégories
/// ne sont remplacées que si le snapshot en apporte (cloud prioritaire
/// sur les valeurs par défaut, jamais d'écrasement par du vide).
class SnapshotApplier {
  const SnapshotApplier._();

  /// [inclureDocuments] : les documents ne viennent QUE du cloud (le
  /// format local ne les persiste pas) — false pour un snapshot local.
  /// [choisirBoutique] : true pour un chargement cloud (élit la boutique
  /// accessible du profil connecté).
  static void appliquer(
    Store store,
    StoreSnapshot s, {
    bool inclureDocuments = true,
    bool choisirBoutique = false,
  }) {
    store.profile = s.profile;
    store.user = s.user;
    store.monPartenaireId = s.monPartenaireId;
    store.profilCloudManquant = s.profilCloudManquant;
    _r(store.users, s.users);
    _r(store.boutiques, s.boutiques);
    _r(store.transactions, s.transactions);
    _r(store.produits, s.produits);
    _r(store.partenaires, s.partenaires);
    _r(store.partages, s.partages);
    _r(store.depenses, s.depenses);
    _r(store.clients, s.clients);
    _r(store.fournisseurs, s.fournisseurs);
    _r(store.messages, s.messages);
    _r(store.evenements, s.evenements);
    _r(store.notesPerso, s.notesPerso);
    _r(store.feedbacks, s.feedbacks);
    _r(store.catalogue, s.catalogue);
    if (inclureDocuments) _r(store.documentsEmis, s.documentsEmis);
    _r(store.achats, s.achats);
    _r(store.mouvements, s.mouvements);
    _r(store.ecritures, s.ecritures);
    if (s.catsProduit.isNotEmpty) {
      store.catsProduit
        ..clear()
        ..addAll(s.catsProduit);
    }
    if (s.catsCharge.isNotEmpty) {
      store.catsCharge
        ..clear()
        ..addAll(s.catsCharge);
    }
    if (s.opsMobileMoney.isNotEmpty) {
      store.opsMobileMoney
        ..clear()
        ..addAll(s.opsMobileMoney);
    }
    if (s.opsCredit.isNotEmpty) {
      store.opsCredit
        ..clear()
        ..addAll(s.opsCredit);
    }
    if (s.domainesPresta.isNotEmpty) {
      store.domainesPresta
        ..clear()
        ..addAll(s.domainesPresta);
    }
    if (s.dureesForfaitListe.isNotEmpty) {
      store.dureesForfaitListe
        ..clear()
        ..addAll(s.dureesForfaitListe);
    }
    if (choisirBoutique && store.boutiques.isNotEmpty) {
      // On élit parmi les boutiques RÉELLEMENT accessibles, sinon
      // `definirBoutiqueCourante` refuse et la courante reste neutre.
      final accessibles = store.boutiques
          .where((b) => s.user.accedeA(b.id))
          .toList();
      final pool =
          accessibles.isNotEmpty ? accessibles : store.boutiques;
      final bt = s.boutiqueId;
      store.definirBoutiqueCourante(
          (bt.isNotEmpty && pool.any((b) => b.id == bt))
              ? bt
              : pool.first.id);
    }
  }

  /// Restauration d'une sauvegarde cloud (BackupService) : on repart du
  /// même schéma local, en conservant l'identité de session et en
  /// effaçant les chemins de média (re-téléchargés ensuite).
  static void restaurerSauvegarde(Store store, Map<String, dynamic> data) {
    appliquer(
      store,
      StoreSerializer.fromJson({
        'version': 1,
        'boutique_id_courante': data['boutique_id_courante'],
        'profil': {
          ...?data['profil'] as Map?,
          'logo_path': null,
          'cachet_path': null,
          'signature_path': null,
        },
        'utilisateur': {
          'id': store.user.id,
          'nom': store.user.nom,
          'role': store.user.role.name,
          'boutique_ids': store.user.boutiqueIds,
        },
        'boutiques': data['boutiques'] ?? const <Object>[],
        'produits': data['produits'] ?? const <Object>[],
        'partenaires': data['partenaires'] ?? const <Object>[],
        'transactions': data['transactions'] ?? const <Object>[],
        'charges': data['charges'] ?? const <Object>[],
        'partages': data['partages'] ?? const <Object>[],
        'achats': data['achats'] ?? const <Object>[],
        'mouvements': data['mouvements'] ?? const <Object>[],
        'ecritures': data['ecritures'] ?? const <Object>[],
      }, genererId: store.genererId),
      inclureDocuments: false,
    );
  }

  static void _r<T>(List<T> cible, List<T> source) {
    cible
      ..clear()
      ..addAll(source);
  }
}
