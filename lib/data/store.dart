import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/achat.dart';
import '../models/app_user.dart';
import '../models/ecriture.dart';
import '../models/mouvement_stock.dart';
import '../models/boutique.dart';
import '../models/charge.dart';
import '../models/client.dart';
import '../models/company_profile.dart';
import '../models/evenement.dart';
import '../services/document_service.dart';
import '../models/feedback.dart';
import '../models/fournisseur.dart';
import '../models/message.dart';
import '../models/partage.dart';
import '../models/partenaire.dart';
import '../models/produit.dart';
import '../models/tarif.dart';
import '../models/transaction.dart';
import '../services/cloud_repository.dart';
import '../services/local_persistence.dart';
import 'notifiers/analytique_notifier.dart';
import 'notifiers/boutique_notifier.dart';
import 'notifiers/categorie_notifier.dart';
import 'notifiers/charge_notifier.dart';
import 'notifiers/client_notifier.dart';
import 'notifiers/collab_notifier.dart';
import 'notifiers/compta_notifier.dart';
import 'notifiers/document_notifier.dart';
import 'notifiers/fournisseur_notifier.dart';
import 'notifiers/partenaire_notifier.dart';
import 'notifiers/produit_notifier.dart';
import 'notifiers/profile_notifier.dart';
import 'notifiers/session_notifier.dart';
import 'notifiers/stock_mouvement_notifier.dart';
import 'notifiers/achat_notifier.dart';
import 'notifiers/transaction_notifier.dart';
import 'normalisation.dart';
import 'store_sync.dart';
import 'demo/demo_seed.dart';
import 'notifiers/wiring.dart';
import 'persistence/cloud_loader.dart';
import 'persistence/serializer.dart';
import 'persistence/snapshot_applier.dart';

import 'facade/facade_ventes.dart';

// Les façades sont des `extension on Store` : pour que l'API complète
// (classe + extensions) soit visible partout, on les ré-exporte
// d'ici. Un seul `import 'data/store.dart'` suffit donc à l'application.
export 'facade/facade_achats.dart';
export 'facade/facade_catalogue.dart';
export 'facade/facade_collab.dart';
export 'facade/facade_compta_docs.dart';
export 'facade/facade_fichiers.dart';
export 'facade/facade_session.dart';
export 'facade/facade_stock.dart';
export 'facade/facade_transverse.dart';
export 'facade/facade_ventes.dart';

/// Cœur de l'application : façade d'état global. Toute la logique métier
/// vit dans les 16 Notifiers, les 5 Services purs (`services/`) et la
/// persistance (`persistence/`, `store_sync.dart`) ; l'API publique
/// complète est ré-exportée d'ici (façades `facade/`).
///
/// Réserve 40octies : `genererId`, `fileUpsert`, `numeroDocument` publics
/// par NÉCESSITÉ d'extraction (une bibliothèque séparée ne voit pas les
/// membres privés), pas par choix d'API. `late final _bundle` est sûr
/// (assigné en 1re instruction) ; un `late` simple = crash (bug 6bis).
class Store extends ChangeNotifier {
  late final NotifierBundle _bundle;
  SessionNotifier get session => _bundle.session;
  BoutiqueNotifier get boutique => _bundle.boutique;
  ProfileNotifier get profil => _bundle.profil;
  CategorieNotifier get categories => _bundle.categories;
  CollabNotifier get collab => _bundle.collab;
  ClientNotifier get client => _bundle.client;
  FournisseurNotifier get fournisseur => _bundle.fournisseur;
  PartenaireNotifier get partenaire => _bundle.partenaire;
  ChargeNotifier get charge => _bundle.charge;
  StockMouvementNotifier get stockMouvements => _bundle.stockMouvements;
  ProduitNotifier get produit => _bundle.produit;
  TransactionNotifier get transaction => _bundle.transaction;
  AchatNotifier get achat => _bundle.achat;
  DocumentNotifier get document => _bundle.document;
  ComptaNotifier get compta => _bundle.compta;
  AnalytiqueNotifier get analytique => _bundle.analytique;

  Store(AppUser user) {
    _bundle = NotifierWiring.construire(EntreesWiring(
      store: this,
      user: user,
      users: users,
      boutiques: boutiques,
      transactions: transactions,
      produits: produits,
      partenaires: partenaires,
      partages: partages,
      depenses: depenses,
      clients: clients,
      fournisseurs: fournisseurs,
      messages: messages,
      evenements: evenements,
      notesPerso: notesPerso,
      feedbacks: feedbacks,
      catalogue: catalogue,
      documentsEmis: documentsEmis,
      achats: achats,
      mouvements: mouvements,
      ecritures: ecritures,
      genererId: genererId,
      fileUpsert: fileUpsert,
      numeroDocument: numeroDocument,
    ));
    for (final n in _bundle.tous) {
      n.addListener(notifier);
    }
    // PRODUCTION : aucune donnée démo (tout vient de Supabase via
    // chargerDuCloud). DÉMO : jeu de données fictif + persistance locale.
    if (CloudRepository.actif) {
      profil.profile = const CompanyProfile();
      return;
    }
    DemoSeed.appliquer(
      boutiques: boutiques,
      users: users,
      setProfile: (p) => profile = p,
      partenaires: partenaires,
      produits: produits,
      depenses: depenses,
      transactions: transactions,
      genererId: genererId,
      employeId: user.id,
    );
    _boutiqueId = boutiques.first.id;
    final sauvegarde = LocalPersistence.load();
    if (sauvegarde != null) {
      try {
        _chargerEtat(Map<String, dynamic>.from(sauvegarde));
      } catch (_) {/* sauvegarde corrompue : on garde la démo */}
    }
    genererChargesRecurrentesSiNouveauMois(); // `depenses` est peuplé
    _syncBoutiqueId();
  }

  /// Boutique courante projetée sur les Notifiers qui filtrent.
  void _syncBoutiqueId() =>
      StoreSync.synchroniserBoutique(this, _boutiqueId);

  /// Relai : une mutation de Notifier rebuild l'UI et persiste (600 ms).
  void notifier() => notifyListeners();

  /// File hors-ligne (no-op sans cloud). Public par extraction — 40octies.
  Future<void> fileUpsert(String table, Map<String, dynamic> payload) =>
      StoreSync.fileUpsert(this, table, payload);

  /// Numérotation atomique (RPC cloud, sinon compteur du profil).
  Future<String> numeroDocument(String prefixe) =>
      StoreSync.numeroDocument(this, prefixe);

  /// Partenaire lié au compte connecté (rôle partenaire) — `session`.
  String? get monPartenaireId => session.monPartenaireId;
  set monPartenaireId(String? v) => session.monPartenaireId = v;

  /// Utilisateur connecté — délégué à `session`.
  AppUser get user => session.user;
  set user(AppUser u) => session.user = u;

  /// Auth OK mais aucune ligne `public.users` : identité factice remplacée
  /// par le VRAI uuid (sinon permissions client illusoires).
  bool get profilCloudManquant => session.profilCloudManquant;
  set profilCloudManquant(bool v) => session.profilCloudManquant = v;

  /// Démarrage sur snapshot local (bandeau « hors-ligne » + Reconnecter).
  bool get demarrageHorsLigne => session.demarrageHorsLigne;
  set demarrageHorsLigne(bool v) => session.demarrageHorsLigne = v;

  /// Chargement production : remplit l'app depuis Supabase.
  Future<bool> chargerDuCloud() async {
    final snapshot = await CloudLoader.chargerTout(
      sessionUser: user,
      sessionPartenaireId: monPartenaireId,
      sessionProfilManquant: profilCloudManquant,
      genererId: genererId,
    );
    if (snapshot == null) return false;
    _appliquerSnapshot(snapshot, choisirBoutique: true);
    notifyListeners();
    // `depenses` est peuplé : ici, et seulement ici en production, la
    // génération des charges récurrentes a un effet réel.
    await genererChargesRecurrentesSiNouveauMois();
    unawaited(_reparerImagesDistantes()); // images distantes, non bloquant
    return true;
  }

  /// Passe réparatrice (plan A2 §4) : chemins http re-téléchargés en
  /// local. Jamais bloquante ; persiste + notifie si un chemin change.
  Future<void> _reparerImagesDistantes() => CloudLoader.reparerImages(
      produits, catalogue, clients, () => profile, (p) => profile = p,
      _persist, notifyListeners);

  /// Secours hors-ligne : dernier snapshot local quand Supabase est
  /// injoignable. Identité de session CONSERVÉE pour que les écritures en
  /// file gardent le bon employe_id au rejeu.
  Future<bool> chargerSnapshotLocal() async {
    final sauvegarde = LocalPersistence.load();
    if (sauvegarde == null) return false;
    final sessionUser = user;
    final sessionPartenaire = monPartenaireId;
    final profilManquant = profilCloudManquant;
    try {
      _chargerEtat(Map<String, dynamic>.from(sauvegarde));
    } catch (_) {
      return false;
    }
    if (boutiques.isEmpty) return false;
    user = sessionUser;
    monPartenaireId = sessionPartenaire;
    profilCloudManquant = profilManquant;
    // L'identité restaurée décide de la boutique courante (le format local
    // n'en stocke pas) : sans cet appel, l'app démarrerait hors-ligne avec
    // une boutique neutre et des listes toutes vides.
    StoreSync.elireBoutiqueAccessible(this);
    demarrageHorsLigne = true;
    notifyListeners();
    return true;
  }

  /// Retour en ligne : recharge le cloud, n'efface le bandeau que si OK.
  Future<bool> reconnecter() async {
    final ok = await chargerDuCloud();
    if (ok) {
      demarrageHorsLigne = false;
      notifyListeners();
    }
    return ok;
  }

  /// Pull-to-refresh : recharge Supabase si configuré, sinon rebuild.
  Future<void> rafraichir() async {
    if (CloudRepository.actif) {
      await chargerDuCloud();
    } else {
      notifyListeners();
    }
  }

  // ---------- Données (listes PARTAGÉES avec les Notifiers) ----------
  // PAS de `late` : en mode cloud le constructeur sort AVANT toute
  // affectation. La valeur neutre `''` évite l'effondrement (bug 6bis).
  String _boutiqueId = '';
  String get boutiqueId => _boutiqueId;
  final boutiques = <Boutique>[];
  final transactions = <Tx>[];
  final produits = <Produit>[];
  final partenaires = <Partenaire>[];
  final partages = <Partage>[];
  final depenses = <Charge>[];
  final users = <AppUser>[];
  final clients = <Client>[];
  final fournisseurs = <Fournisseur>[];
  final messages = <Message>[];
  final evenements = <Evenement>[];
  final notesPerso = <Note>[];
  final feedbacks = <Feedback>[];
  final catalogue = <Tarif>[];
  final documentsEmis = <DocumentBati>[];
  final achats = <Achat>[];
  final mouvements = <MouvementStock>[];
  final ecritures = <Ecriture>[];
  CompanyProfile get profile => profil.profile;
  set profile(CompanyProfile p) => profil.profile = p;
  int _seq = 0;
  Timer? _persistTimer;

  /// Id local (uuid cloud, sinon compteur). Public par extraction — 40octies.
  String genererId() => CloudRepository.actif
      ? CloudRepository.uuid()
      : 'id_${++_seq}_${DateTime.now().millisecondsSinceEpoch}';

  /// Boutique courante élue par un chargement cloud : la boutique doit
  /// exister ET être accessible, sinon on retombe sur la valeur neutre
  /// (jamais un identifiant fantôme : en-têtes incohérents, listes vides).
  void definirBoutiqueCourante(String id) {
    _boutiqueId =
        (boutiques.any((b) => b.id == id) && user.accedeA(id)) ? id : '';
    boutique.boutiqueId = _boutiqueId;
    _syncBoutiqueId();
    notifyListeners();
  }

  /// Changement manuel (sélecteur du menu) : refus = no-op silencieux.
  void changerBoutique(String id) {
    if (!boutiques.any((b) => b.id == id) || !user.accedeA(id)) return;
    if (_boutiqueId == id) return;
    _boutiqueId = id;
    boutique.boutiqueId = id;
    _syncBoutiqueId();
    notifyListeners();
  }

  /// Chaque mutation déclenche une persistance locale différée (600 ms).
  @override
  void notifyListeners() {
    super.notifyListeners();
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 600), _persist);
  }

  void _persist() => LocalPersistence.save(toJson());

  @override
  void dispose() {
    // Sans cela, le timer de persistance survivait à l'arbre de widgets
    // (fuite mémoire + "A Timer is still pending even after ...").
    _persistTimer?.cancel();
    super.dispose();
  }

  /// Normalisation anti-doublon (point 35) : casse + accents.
  static String sansAccents(String s) => Normalisation.sansAccents(s);

  static bool memeCategorie(String a, String b) =>
      Normalisation.memeCategorie(a, b);

  /// Sérialisation locale (persistance différée à chaque mutation).
  Map<String, dynamic> toJson() =>
      StoreSerializer.toJson(StoreSerializer.capturer(this));

  /// Rechargement d'un snapshot (tests de non-régression).
  @visibleForTesting
  void restaurerEtatPourTest(Map<String, dynamic> data) =>
      _chargerEtat(data);

  void _chargerEtat(Map<String, dynamic> data) => _appliquerSnapshot(
      StoreSerializer.fromJson(data, genererId: genererId),
      inclureDocuments: false);

  /// Applique un snapshot aux listes PARTAGÉES avec les Notifiers.
  void _appliquerSnapshot(StoreSnapshot s,
          {bool inclureDocuments = true, bool choisirBoutique = false}) =>
      SnapshotApplier.appliquer(this, s,
          inclureDocuments: inclureDocuments, choisirBoutique: choisirBoutique);

  /// Restauration d'une sauvegarde cloud (BackupService).
  Future<void> restaurerSauvegarde(Map<String, dynamic> data) async =>
      SnapshotApplier.restaurerSauvegarde(this, data);
}
