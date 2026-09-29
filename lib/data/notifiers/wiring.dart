import 'package:flutter/foundation.dart';
import '../../models/achat.dart';
import '../../models/app_user.dart';
import '../../models/boutique.dart';
import '../../models/charge.dart';
import '../../models/client.dart';
import '../../models/document.dart';
import '../../services/document_service.dart';
import '../../models/ecriture.dart';
import '../../models/evenement.dart';
import '../../models/feedback.dart';
import '../../models/fournisseur.dart';
import '../../models/message.dart';
import '../../models/mouvement_stock.dart';
import '../../models/partage.dart';
import '../../models/partenaire.dart';
import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart';
import '../store.dart';
import '../store_sync.dart';
import 'achat_notifier.dart';
import 'analytique_notifier.dart';
import 'boutique_notifier.dart';
import 'categorie_notifier.dart';
import 'charge_notifier.dart';
import 'client_notifier.dart';
import 'collab_notifier.dart';
import 'compta_notifier.dart';
import 'document_notifier.dart';
import 'fournisseur_notifier.dart';
import 'partenaire_notifier.dart';
import 'produit_notifier.dart';
import 'profile_notifier.dart';
import 'session_notifier.dart';
import 'stock_mouvement_notifier.dart';
import 'transaction_notifier.dart';

/// Mouchard de mouvement stock (produits + achats partagent le même).
typedef JournaliserStock = Future<void> Function({
  required String produitId,
  required String produitNom,
  required String type,
  required int quantite,
  required int stockApres,
  required String boutiqueId,
  String motif,
  String refId,
  DateTime? date,
});

/// Vente atomique depuis le stock (retourne l'id Tx).
typedef AjouterVente = Future<String> Function({
  required TypeTransaction type,
  required double montant,
  double cout,
  String? clientNom,
  DateTime? date,
  Map<String, dynamic> details,
});

/// Faisceau des 16 Notifiers (Phase 6) : construit en une fois par
/// [NotifierWiring.construire], exposé au Store via getters.
class NotifierBundle {
  final SessionNotifier session;
  final BoutiqueNotifier boutique;
  final ProfileNotifier profil;
  final CategorieNotifier categories;
  final CollabNotifier collab;
  final ClientNotifier client;
  final FournisseurNotifier fournisseur;
  final PartenaireNotifier partenaire;
  final ChargeNotifier charge;
  final StockMouvementNotifier stockMouvements;
  final ProduitNotifier produit;
  final TransactionNotifier transaction;
  final AchatNotifier achat;
  final DocumentNotifier document;
  final ComptaNotifier compta;
  final AnalytiqueNotifier analytique;

  const NotifierBundle({
    required this.session,
    required this.boutique,
    required this.profil,
    required this.categories,
    required this.collab,
    required this.client,
    required this.fournisseur,
    required this.partenaire,
    required this.charge,
    required this.stockMouvements,
    required this.produit,
    required this.transaction,
    required this.achat,
    required this.document,
    required this.compta,
    required this.analytique,
  });

  /// Les 16, pour le relai `notifyListeners` du Store.
  List<ChangeNotifier> get tous => [
        session,
        boutique,
        profil,
        categories,
        collab,
        client,
        fournisseur,
        partenaire,
        charge,
        stockMouvements,
        produit,
        transaction,
        achat,
        document,
        compta,
        analytique,
      ];
}

/// Entrées du wiring : listes PARTAGÉES (mêmes objets que le Store),
/// identité initiale, et callbacks vers les privés du Store.
/// Les références croisées (compta/produit/profil) passent par des
/// accesseurs paresseux — aucun `LateError` à la construction.
class EntreesWiring {
  final AppUser user;
  final List<AppUser> users;
  final List<Boutique> boutiques;
  final List<Tx> transactions;
  final List<Produit> produits;
  final List<Partenaire> partenaires;
  final List<Partage> partages;
  final List<Charge> depenses;
  final List<Client> clients;
  final List<Fournisseur> fournisseurs;
  final List<Message> messages;
  final List<Evenement> evenements;
  final List<Note> notesPerso;
  final List<Feedback> feedbacks;
  final List<Tarif> catalogue;
  final List<DocumentBati> documentsEmis;
  final List<Achat> achats;
  final List<MouvementStock> mouvements;
  final List<Ecriture> ecritures;

  final String Function() genererId;
  final Future<void> Function(String table, Map<String, dynamic> payload)
      fileUpsert;
  final Future<String> Function(String prefixe) numeroDocument;
  final Store store;

  /// Vente atomique depuis le stock (pont vers le Notifier transactions).
  Future<String> ajouterVente({
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    DateTime? date,
    Map<String, dynamic> details = const {},
  }) =>
      store.transaction.ajouterTransaction(
        type: type,
        montant: montant,
        cout: cout,
        clientNom: clientNom,
        date: date,
        details: details,
      );

  /// Persiste un produit en local + cloud puis en file.
  Future<void> upsertProduitLocal(Produit p) async {
    await CloudRepository.upsertProduit(p);
    await StoreSync.fileUpsert(
        store, 'produits', StoreSync.payloadProduit(p));
  }

  /// Persiste une dépense (contrat : l'insertion en liste est déjà faite
  /// par le Notifier — cf. point 30, sinon double caisse).
  Future<void> ajouterChargeDepense(Charge c) => StoreSync.fileUpsert(
      store, 'charges', StoreSync.payloadCharge(c));

  /// Décrémente le stock pour chaque ligne documentaire.
  Future<List<String>> deduireStock(List<LigneDoc> lignes) =>
      store.produit.deduireStockPourLignes([
        for (final l in lignes)
          {'libelle': l.libelle, 'quantite': l.quantite}
      ]);

  /// Journalier un mouvement de stock (Notifier mouvements).
  JournaliserStock get journaliserStock => ({
        required String produitId,
        required String produitNom,
        required String type,
        required int quantite,
        required int stockApres,
        required String boutiqueId,
        String motif = '',
        String refId = '',
        DateTime? date,
      }) =>
          StoreSync.journaliser(store,
              produitId: produitId,
              produitNom: produitNom,
              type: type,
              quantite: quantite,
              stockApres: stockApres,
              boutiqueId: boutiqueId,
              motif: motif,
              refId: refId,
              date: date);

  ComptaNotifier getCompta() => store.compta;
  ProfileNotifier getProfil() => store.profil;

  EntreesWiring({
    required this.store,
    required this.user,
    required this.users,
    required this.boutiques,
    required this.transactions,
    required this.produits,
    required this.partenaires,
    required this.partages,
    required this.depenses,
    required this.clients,
    required this.fournisseurs,
    required this.messages,
    required this.evenements,
    required this.notesPerso,
    required this.feedbacks,
    required this.catalogue,
    required this.documentsEmis,
    required this.achats,
    required this.mouvements,
    required this.ecritures,
    required this.genererId,
    required this.fileUpsert,
    required this.numeroDocument,
  });
}

/// Construction du faisceau (Phase 6) : contenu déplacé à l'identique
/// du constructeur `Store` (Phase 5). `compta` est construit AVANT
/// ses dépendants ; les callbacks le référencent via [getCompta]
/// (paresseux — construits avant tout appel).
class NotifierWiring {
  const NotifierWiring._();

  static NotifierBundle construire(EntreesWiring e) {
    final session = SessionNotifier(e.user, users: e.users);
    final boutique = BoutiqueNotifier(
        session: session,
        genererId: e.genererId,
        boutiques: e.boutiques);
    final profil = ProfileNotifier();
    final categories = CategorieNotifier(
        produits: e.produits, depenses: e.depenses);
    final collab = CollabNotifier(
        session: session,
        genererId: e.genererId,
        fileUpsert: e.fileUpsert,
        messages: e.messages,
        evenements: e.evenements,
        notesPerso: e.notesPerso,
        feedbacks: e.feedbacks);
    final client =
        ClientNotifier(genererId: e.genererId, clients: e.clients);
    final fournisseur = FournisseurNotifier(
        genererId: e.genererId, fournisseurs: e.fournisseurs);
    final partenaire = PartenaireNotifier(
        genererId: e.genererId,
        transactions: e.transactions,
        partages: e.partages,
        fileUpsert: e.fileUpsert,
        partenaires: e.partenaires);
    final compta = ComptaNotifier(
        genererId: e.genererId,
        ecritures: e.ecritures,
        fileUpsert: e.fileUpsert);
    final charge = ChargeNotifier(
        genererId: e.genererId,
        profile: profil,
        fileUpsert: e.fileUpsert,
        depenses: e.depenses,
        comptabiliser: (c) =>
            e.getCompta().comptabiliserCharge(c),
        contrePasser: (ref, motif) =>
            e.getCompta().contrePasser(ref, motif));
    final stockMouvements = StockMouvementNotifier(
        session: session,
        genererId: e.genererId,
        produits: e.produits,
        fileUpsert: e.fileUpsert,
        mouvements: e.mouvements);
    final produit = ProduitNotifier(
        session: session,
        genererId: e.genererId,
        produits: e.produits,
        catalogue: e.catalogue,
        transactions: e.transactions,
        mouvements: e.mouvements,
        fileUpsert: e.fileUpsert,
        ajouterVente: e.ajouterVente,
        journaliserMouvement: e.journaliserStock);
    final transaction = TransactionNotifier(
        session: session,
        genererId: e.genererId,
        transactions: e.transactions,
        produits: e.produits,
        fileUpsert: e.fileUpsert,
        comptabiliserVente: (tx) => e
            .getCompta()
            .comptabiliserVente(tx, e.getProfil().profile.tva),
        contrePasser: (ref, motif) =>
            e.getCompta().contrePasser(ref, motif),
        posterEncaissement: (tx) =>
            e.getCompta().comptabiliserEncaissement(tx));
    final achat = AchatNotifier(
        session: session,
        genererId: e.genererId,
        numeroDocument: e.numeroDocument,
        achats: e.achats,
        produits: e.produits,
        catalogue: e.catalogue,
        depenses: e.depenses,
        mouvements: e.mouvements,
        fileUpsert: e.fileUpsert,
        upsertProduitLocal: e.upsertProduitLocal,
        syncCatalogue: (p) =>
            StoreSync.catalogueDepuisProduit(e.store, p),
        journaliser: e.journaliserStock,
        ajouterChargeDepense: e.ajouterChargeDepense,
        comptabiliserReception: (a) =>
            e.getCompta().comptabiliserReception(a),
        comptabiliserPaiement: (a, montant, mode) => e
            .getCompta()
            .comptabiliserPaiementAchat(a, montant, mode),
        contrePasser: (ref, motif) =>
            e.getCompta().contrePasser(ref, motif));
    final document = DocumentNotifier(
        session: session,
        numeroDocument: e.numeroDocument,
        documentsEmis: e.documentsEmis);
    final analytique = AnalytiqueNotifier(
        transactions: e.transactions, depenses: e.depenses);
    return NotifierBundle(
      session: session,
      boutique: boutique,
      profil: profil,
      categories: categories,
      collab: collab,
      client: client,
      fournisseur: fournisseur,
      partenaire: partenaire,
      charge: charge,
      stockMouvements: stockMouvements,
      produit: produit,
      transaction: transaction,
      achat: achat,
      document: document,
      compta: compta,
      analytique: analytique,
    );
  }
}
