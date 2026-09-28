import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/achat.dart';
import '../models/analytique.dart';
import '../models/app_user.dart';
import '../models/ecriture.dart';
import '../models/mouvement_stock.dart';
import '../models/boutique.dart';
import '../models/charge.dart';
import '../models/client.dart';
import '../models/company_profile.dart';
import '../models/document.dart';
import '../models/evenement.dart';
import '../models/feedback.dart';
import '../models/fournisseur.dart';
import '../models/message.dart';
import '../models/enums.dart';
import '../models/partage.dart';
import '../models/partenaire.dart';
import '../models/produit.dart';
import '../models/tarif.dart';
import '../models/transaction.dart';
import '../services/cloud_repository.dart';
import '../services/document_service.dart';
import '../services/local_persistence.dart';
import '../services/media_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
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
import 'services/analytique_service.dart';
import 'services/caisse_service.dart';
import 'services/partage_service.dart';
import 'services/stock_service.dart';

/// Cœur de l'application : état global + calculs métier.
/// Persistance : l'état complet est sauvegardé localement (Hive) à chaque
/// mutation — les données et les photos survivent aux redémarrages en mode
/// démo. Avec Supabase configuré, la synchro cloud reprend le relais.
class Store extends ChangeNotifier {
  // ---------- Notifiers câblés (Phase 5) ----------
  late final SessionNotifier session;
  late final BoutiqueNotifier boutique;
  late final ProfileNotifier profil;
  late final CategorieNotifier categories;
  late final CollabNotifier collab;
  late final ClientNotifier client;
  late final FournisseurNotifier fournisseur;
  late final PartenaireNotifier partenaire;
  late final ChargeNotifier charge;
  late final StockMouvementNotifier stockMouvements;
  late final ProduitNotifier produit;
  late final TransactionNotifier transaction;
  late final AchatNotifier achat;
  late final DocumentNotifier document;
  late final ComptaNotifier compta;
  late final AnalytiqueNotifier analytique;

  Store(AppUser user) {
    session = SessionNotifier(user, users: users);
    boutique = BoutiqueNotifier(
        session: session, genererId: _nid, boutiques: boutiques);
    profil = ProfileNotifier();
    categories = CategorieNotifier(
        produits: produits, depenses: depenses);
    collab = CollabNotifier(
        session: session,
        genererId: _nid,
        fileUpsert: _fileUpsert,
        messages: messages,
        evenements: evenements,
        notesPerso: notesPerso,
        feedbacks: feedbacks);
    client = ClientNotifier(genererId: _nid, clients: clients);
    fournisseur = FournisseurNotifier(
        genererId: _nid, fournisseurs: fournisseurs);
    partenaire = PartenaireNotifier(
        genererId: _nid,
        transactions: transactions,
        partages: partages,
        fileUpsert: _fileUpsert,
        partenaires: partenaires);
    charge = ChargeNotifier(
        genererId: _nid,
        profile: profil,
        fileUpsert: _fileUpsert,
        depenses: depenses,
        comptabiliser: (c) => compta.comptabiliserCharge(c),
        contrePasser: (ref, motif) => compta.contrePasser(ref, motif));
    stockMouvements = StockMouvementNotifier(
        session: session,
        genererId: _nid,
        produits: produits,
        fileUpsert: _fileUpsert,
        mouvements: mouvements);
    produit = ProduitNotifier(
        session: session,
        genererId: _nid,
        produits: produits,
        catalogue: catalogue,
        transactions: transactions,
        mouvements: mouvements,
        fileUpsert: _fileUpsert,
        ajouterVente: _ajouterVenteProduit,
        journaliserMouvement: (
            {required String produitId,
            required String produitNom,
            required String type,
            required int quantite,
            required int stockApres,
            required String boutiqueId,
            String motif = '',
            String refId = '',
            DateTime? date}) =>
            stockMouvements.journaliser(
                produitId: produitId,
                produitNom: produitNom,
                type: type,
                quantite: quantite,
                stockApres: stockApres,
                boutiqueId: boutiqueId,
                motif: motif,
                refId: refId,
                date: date));
    transaction = TransactionNotifier(
        session: session,
        genererId: _nid,
        transactions: transactions,
        produits: produits,
        fileUpsert: _fileUpsert,
        comptabiliserVente: (tx) =>
            compta.comptabiliserVente(tx, profil.profile.tva),
        contrePasser: (ref, motif) => compta.contrePasser(ref, motif),
        posterEncaissement: (tx) =>
            compta.comptabiliserEncaissement(tx));
    achat = AchatNotifier(
        session: session,
        genererId: _nid,
        numeroDocument: numeroDocument,
        achats: achats,
        produits: produits,
        catalogue: catalogue,
        depenses: depenses,
        mouvements: mouvements,
        fileUpsert: _fileUpsert,
        upsertProduitLocal: (p) async {
          await CloudRepository.upsertProduit(p);
          await _fileUpsert('produits', _payloadProduit(p));
        },
        syncCatalogue: _syncCatalogueDepuisProduit,
        journaliser: (
            {required String produitId,
            required String produitNom,
            required String type,
            required int quantite,
            required int stockApres,
            required String boutiqueId,
            String motif = '',
            String refId = '',
            DateTime? date}) =>
            stockMouvements.journaliser(
                produitId: produitId,
                produitNom: produitNom,
                type: type,
                quantite: quantite,
                stockApres: stockApres,
                boutiqueId: boutiqueId,
                motif: motif,
                refId: refId,
                date: date),
        ajouterChargeDepense: (c) async {
          // Le Notifier a DÉJÀ inséré dans la liste partagée : ici,
          // persistance seule (cloud + file), sinon double-insert.
          await CloudRepository.upsertCharge(c);
          await _fileUpsert('charges', {
            'id': c.id,
            'boutique_id': c.boutiqueId,
            'categorie': c.categorie,
            'libelle': c.libelle,
            'montant': c.montant,
            'date_charge': c.date.toIso8601String(),
            'recurrente': c.recurrente,
          });
        },
        comptabiliserReception: (a) =>
            compta.comptabiliserReception(a),
        comptabiliserPaiement: (a, montant, mode) =>
            compta.comptabiliserPaiementAchat(a, montant, mode),
        contrePasser: (ref, motif) =>
            compta.contrePasser(ref, motif));
    document = DocumentNotifier(
        session: session,
        numeroDocument: numeroDocument,
        deduireStock: (lignes) => produit.deduireStockPourLignes([
              for (final l in lignes)
                {'libelle': l.libelle, 'quantite': l.quantite}
            ]),
        documentsEmis: documentsEmis);
    compta = ComptaNotifier(
        genererId: _nid, ecritures: ecritures, fileUpsert: _fileUpsert);
    analytique = AnalytiqueNotifier(
        transactions: transactions, depenses: depenses);
    for (final n in <ChangeNotifier>[
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
    ]) {
      n.addListener(_relayer);
    }
    if (CloudRepository.actif) {
      // ===== PRODUCTION : aucune donnée démo — tout vient de Supabase
      // via chargerDuCloud() après authentification. La génération des
      // charges récurrentes se fait à LA FIN de chargerDuCloud() : ici,
      // avant tout chargement, `depenses` est encore vide et l'appel ne
      // ferait donc jamais rien — c'est ce qui rendait la fonctionnalité
      // inopérante en production.
      profil.profile = const CompanyProfile();
      return;
    }
    // ===== MODE DÉMO (sans Supabase) : données fictives + persistance locale.
    _seedDemo();
    _boutiqueId = boutiques.first.id;
    final sauvegarde = LocalPersistence.load();
    if (sauvegarde != null) {
      try {
        _chargerEtat(Map<String, dynamic>.from(sauvegarde));
      } catch (_) {/* sauvegarde corrompue : on garde la démo */}
    }
    // Ici, `depenses` est déjà peuplé (démo ou sauvegarde locale restaurée) :
    // contrairement à la branche cloud, l'appel est donc utile dès ce point.
    genererChargesRecurrentesSiNouveauMois();
    _syncBoutiqueId();
  }

  /// Relai : toute mutation d'un Notifier rebuild l'UI ET persiste
  /// (via le timer 600 ms de `notifyListeners` ci-dessous).
  void _relayer() => notifyListeners();

  /// Pont vente-produit (évite la référence croisée produit→transaction
  /// au moment de la construction : `transaction` n'existe pas encore
  /// quand `produit` est créé).
  Future<String> _ajouterVenteProduit({
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    DateTime? date,
    Map<String, dynamic> details = const {},
  }) =>
      transaction.ajouterTransaction(
        type: type,
        montant: montant,
        cout: cout,
        clientNom: clientNom,
        date: date,
        details: details,
      );

  /// Propage la boutique courante aux Notifiers qui filtrent par boutique.
  void _syncBoutiqueId() {
    boutique.boutiqueId = _boutiqueId;
    transaction.boutiqueId = _boutiqueId;
    charge.boutiqueId = _boutiqueId;
    produit.boutiqueId = _boutiqueId;
    achat.boutiqueId = _boutiqueId;
    document.boutiqueId = _boutiqueId;
    compta.boutiqueId = _boutiqueId;
    analytique.boutiqueId = _boutiqueId;
    client.boutiqueId = _boutiqueId;
  }

  /// Identifiant du partenaire lié au compte connecté (rôle partenaire).
  /// Délégué à `session` (façade Phase 5).
  String? get monPartenaireId => session.monPartenaireId;
  set monPartenaireId(String? v) => session.monPartenaireId = v;

  /// Utilisateur connecté — délégué à `session` (façade Phase 5).
  /// Le getter/setter préservent toutes les lectures/écritures existantes
  /// (`store.user.nom`, `user = ...` dans le chargement).
  AppUser get user => session.user;
  set user(AppUser u) => session.user = u;

  /// Vrai si la connexion Supabase Auth a réussi mais qu'aucune ligne
  /// correspondante n'existe dans public.users (compte non provisionné —
  /// étape 5 du guide de déploiement jamais faite, ou faite pour un autre
  /// email). Dans ce cas, `user` retombe sur un rôle minimal avec le VRAI
  /// uuid Supabase (voir chargerDuCloud) : sans ce garde-fou, l'app gardait
  /// silencieusement l'identité locale factice 'u_admin' (permissions
  /// admin illusoires côté client) alors que le serveur refuse tout —
  /// c'est ce qui produisait les erreurs RLS/UUID invisibles jusqu'ici.
  bool get profilCloudManquant => session.profilCloudManquant;
  set profilCloudManquant(bool v) => session.profilCloudManquant = v;

  /// Vrai quand l'app a démarré sur le snapshot local faute de réseau
/// (voir CloudLoader) : bandeau « hors-ligne » dans AppShell + bouton
/// Reconnecter. Les saisies/modifs/suppressions restent possibles :
/// elles partent en file SyncService et sont rejouées au retour réseau.
  bool get demarrageHorsLigne => session.demarrageHorsLigne;
  set demarrageHorsLigne(bool v) => session.demarrageHorsLigne = v;

  /// Chargement initial production : remplit l'app depuis Supabase.
  Future<bool> chargerDuCloud() async {
    final data = await CloudRepository.chargerTout();
    if (data == null) return false;
    final p = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
    profile = CompanyProfile(
      nomEntreprise: p['nom_entreprise']?.toString() ?? 'Mon Entreprise',
      devise: p['devise']?.toString() ?? 'FCFA',
      telephone: p['telephone']?.toString() ?? '',
      telephone2: p['telephone2']?.toString() ?? '',
      email: p['email']?.toString() ?? '',
      adresse: p['adresse']?.toString() ?? '',
      rccm: p['rccm']?.toString() ?? '',
      ifu: p['ifu']?.toString() ?? '',
      autreRefFiscale: p['autre_ref_fiscale']?.toString() ?? '',
      banque: p['banque']?.toString() ?? '',
      coordonneesBancaires: p['coordonnees_bancaires']?.toString() ?? '',
      messagePied: p['message_pied']?.toString() ?? '',
      tva: (p['tva'] as num?)?.toDouble() ?? 0,
      logoPath: MediaService.normaliserChemin(p['logo_path']?.toString(),
          entite: 'company', id: 'logo'),
      cachetPath: MediaService.normaliserChemin(p['cachet_path']?.toString(),
          entite: 'company', id: 'cachet'),
      signaturePath: MediaService.normaliserChemin(
          p['signature_path']?.toString(),
          entite: 'company',
          id: 'signature'),
      moisChargesGenerees: p['mois_charges_generees']?.toString(),
    );
    boutiques
      ..clear()
      ..addAll([
        for (final b in (data['boutiques'] as List))
          Boutique(id: b['id'].toString(), nom: b['nom'].toString(),
              adresse: b['adresse']?.toString() ?? '',
              siege: b['siege'] == true),
      ]);
    produits
      ..clear()
      ..addAll([
        for (final r in (data['produits'] as List))
          Produit(
            id: r['id'].toString(), boutiqueId: r['boutique_id'].toString(),
            libelle: r['libelle'].toString(),
            categorie: r['categorie'].toString(),
            prixAchat: (r['prix_achat'] as num?)?.toDouble() ?? 0,
            prixVente: (r['prix_vente'] as num?)?.toDouble() ?? 0,
            stock: (r['quantite_stock'] as num?)?.toInt() ?? 0,
            seuil: (r['seuil_alerte'] as num?)?.toInt() ?? 3,
            dateAjout: DateTime.tryParse(
                r['date_ajout']?.toString() ?? ''),
            imagePath: MediaService.normaliserChemin(
                r['image_path']?.toString(),
                entite: 'produit',
                id: r['id'].toString()),
            images: [
              for (final u in (r['images'] as List? ?? const []))
                MediaService.normaliserChemin(u.toString(),
                    entite: 'produit',
                    id: r['id'].toString()) ??
                    u.toString(),
            ],
          ),
      ]);
    partenaires
      ..clear()
      ..addAll([
        for (final r in (data['partenaires'] as List))
          Partenaire(
            id: r['id'].toString(), nom: r['nom'].toString(),
            telephone: r['telephone']?.toString() ?? '',
            localisation: r['localisation']?.toString() ?? '',
            taux: (r['taux_partage'] as num?)?.toDouble() ?? 0.60,
          ),
      ]);
    transactions
      ..clear()
      ..addAll([
        for (final r in (data['transactions'] as List))
          Tx(
            id: r['id'].toString(), boutiqueId: r['boutique_id'].toString(),
            employeId: r['employe_id']?.toString() ?? user.id,
            type: CloudTx.type(r['type']),
            montant: (r['montant'] as num?)?.toDouble() ?? 0,
            cout: (r['cout'] as num?)?.toDouble() ?? 0,
            statut: StatutPaiement.values
                .byName(r['statut']?.toString() ?? 'paye'),
            clientNom: r['client_nom']?.toString(),
            partenaireId: r['partenaire_id']?.toString(),
            details: Map<String, dynamic>.from(r['details'] as Map? ?? {}),
            date: DateTime.tryParse(r['date_transaction']?.toString() ?? '')
                ?? DateTime.now(),
          ),
      ]);
    depenses
      ..clear()
      ..addAll([
        for (final r in (data['charges'] as List))
          Charge(
            id: r['id'].toString(), boutiqueId: r['boutique_id'].toString(),
            categorie: r['categorie'].toString(),
            libelle: r['libelle'].toString(),
            montant: (r['montant'] as num?)?.toDouble() ?? 0,
            date: DateTime.tryParse(r['date_charge']?.toString() ?? '')
                ?? DateTime.now(),
            recurrente: r['recurrente'] == true,
          ),
      ]);
    profile = profile.copyWith(
      budgetsMensuels: {
        for (final r in (data['budgets'] as List))
          r['categorie'].toString(): (r['montant'] as num?)?.toDouble() ?? 0,
      },
      fondsRoulement: {
        for (final r in (data['fonds'] as List))
          r['boutique_id'].toString(): (r['montant'] as num?)?.toDouble() ?? 0,
      },
    );
    // Rôle et boutiques de l'utilisateur connecté. `id: user.id` était le
    // bug racine des erreurs "invalid input syntax for type uuid: u_admin" :
    // ça reprenait l'ancien id LOCAL (le compte 'u_admin' par défaut posé
    // dans main.dart) au lieu du vrai uuid Supabase Auth renvoyé par
    // mon_profil — chaque vente enregistrait donc 'u_admin' comme
    // employe_id, une chaîne qui n'est jamais un uuid valide, rejetée par
    // Postgres (22P02) dès la synchro.
    final mp = data['mon_profil'] as Map?;
    final uidReel = SupabaseService.client?.auth.currentUser?.id;
    if (mp != null) {
      profilCloudManquant = false;
      user = AppUser(
        id: mp['id'].toString(), nom: mp['nom']?.toString() ?? user.nom,
        role: Role.values.byName(mp['role']?.toString() ?? 'vendeur'),
        boutiqueIds: [
          for (final b in (data['mes_boutiques'] as List))
            b['boutique_id'].toString(),
        ],
        partenaireId: mp['partenaire_id']?.toString(),
      );
      monPartenaireId = mp['partenaire_id']?.toString();
    } else if (uidReel != null) {
      // Authentifié côté Supabase Auth, mais aucune ligne public.users
      // correspondante (compte non provisionné — voir Étape 5 du guide de
      // déploiement). On garde le VRAI uuid (jamais 'u_admin') pour que les
      // écritures échouent proprement côté RLS plutôt que d'envoyer un id
      // invalide, et on redescend sur le rôle le plus bas plutôt que de
      // laisser croire à un accès admin que le serveur refusera de toute
      // façon.
      profilCloudManquant = true;
      user = AppUser(id: uidReel, nom: user.nom, role: Role.stagiaire);
    }
    // Tous les comptes (écran Utilisateurs) — sans ce chargement, la liste
    // repartait vide à chaque redémarrage et l'admin ne pouvait plus gérer
    // les comptes créés lors de sessions précédentes.
    final userBoutiquesParUser = <String, List<String>>{};
    for (final ub in (data['user_boutiques'] as List? ?? const [])) {
      userBoutiquesParUser
          .putIfAbsent(ub['user_id'].toString(), () => [])
          .add(ub['boutique_id'].toString());
    }
    users
      ..clear()
      ..addAll([
        for (final r in (data['users'] as List? ?? const []))
          AppUser(
            id: r['id'].toString(), nom: r['nom']?.toString() ?? '',
            role: Role.values.byName(r['role']?.toString() ?? 'vendeur'),
            boutiqueIds: userBoutiquesParUser[r['id'].toString()] ?? const [],
            partenaireId: r['partenaire_id']?.toString(),
          ),
      ]);
    // Catégories dynamiques (cloud prioritaire sur les valeurs par défaut)
    final cats = data['categories'] as List? ?? const [];
    final cp = [for (final r in cats.where((r) => r['type'] == 'produit')) r['nom'].toString()];
    final cc = [for (final r in cats.where((r) => r['type'] == 'charge')) r['nom'].toString()];
    if (cp.isNotEmpty) {
      catsProduit..clear()..addAll(cp);
    }
    if (cc.isNotEmpty) {
      catsCharge..clear()..addAll(cc);
    }
    final omm = [for (final r in cats.where((r) => r['type'] == 'operateur_momo')) r['nom'].toString()];
    final oc = [for (final r in cats.where((r) => r['type'] == 'operateur_credit')) r['nom'].toString()];
    final dp = [for (final r in cats.where((r) => r['type'] == 'domaine_prestation')) r['nom'].toString()];
    final df = [for (final r in cats.where((r) => r['type'] == 'duree_forfait')) r['nom'].toString()];
    if (omm.isNotEmpty) {
      opsMobileMoney..clear()..addAll(omm);
    }
    if (oc.isNotEmpty) {
      opsCredit..clear()..addAll(oc);
    }
    if (dp.isNotEmpty) {
      domainesPresta..clear()..addAll(dp);
    }
    if (df.isNotEmpty) {
      dureesForfaitListe..clear()..addAll(df);
    }
    // Fichier clients
    clients
      ..clear()
      ..addAll([
        for (final r in (data['clients'] as List? ?? []))
          Client(
            id: r['id'].toString(), boutiqueId: r['boutique_id'].toString(),
            nom: r['nom'].toString(),
            telephone: r['telephone']?.toString() ?? '',
            email: r['email']?.toString() ?? '',
            adresse: r['adresse']?.toString() ?? '',
            rccm: r['rccm']?.toString() ?? '',
            ifu: r['ifu']?.toString() ?? '',
            rib: r['rib']?.toString() ?? '',
            logoPath: MediaService.normaliserChemin(
                r['logo_path']?.toString(),
                entite: 'client',
                id: r['id'].toString()),
          ),
      ]);
    fournisseurs
      ..clear()
      ..addAll([
        for (final r in (data['fournisseurs'] as List? ?? []))
          Fournisseur(
            id: r['id'].toString(), nom: r['nom'].toString(),
            telephone: r['telephone']?.toString() ?? '',
            email: r['email']?.toString() ?? '',
            adresse: r['adresse']?.toString() ?? '',
            specialite: r['specialite']?.toString() ?? '',
            notes: r['notes']?.toString() ?? '',
          ),
      ]);
    messages
      ..clear()
      ..addAll([
        for (final r in (data['messages'] as List? ?? []))
          Message(
            id: r['id'].toString(),
            expediteurId: r['expediteur_id'].toString(),
            expediteurNom: r['expediteur_nom']?.toString() ?? '',
            destinataireId: r['destinataire_id']?.toString(),
            sujet: r['sujet']?.toString() ?? '',
            contenu: r['contenu']?.toString() ?? '',
            date: DateTime.tryParse(r['created_at']?.toString() ?? '')
                ?? DateTime.now(),
            lu: r['lu'] == true,
          ),
      ]);
    evenements
      ..clear()
      ..addAll([
        for (final r in (data['evenements'] as List? ?? []))
          Evenement(
            id: r['id'].toString(), titre: r['titre'].toString(),
            date: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
            heure: r['heure']?.toString() ?? '',
            lieu: r['lieu']?.toString() ?? '',
            description: r['description']?.toString() ?? '',
            createurId: r['createur_id']?.toString() ?? '',
          ),
      ]);
    notesPerso
      ..clear()
      ..addAll([
        for (final r in (data['notes'] as List? ?? []))
          Note(
            id: r['id'].toString(), titre: r['titre'].toString(),
            contenu: r['contenu']?.toString() ?? '',
            date: DateTime.tryParse(r['created_at']?.toString() ?? '')
                ?? DateTime.now(),
            rappelLe: DateTime.tryParse(r['rappel_le']?.toString() ?? ''),
            createurId: r['createur_id']?.toString() ?? '',
          ),
      ]);
    feedbacks
      ..clear()
      ..addAll([
        for (final r in (data['feedbacks'] as List? ?? []))
          Feedback(
            id: r['id'].toString(), auteurId: r['auteur_id'].toString(),
            auteurNom: r['auteur_nom']?.toString() ?? '',
            boutiqueId: r['boutique_id']?.toString() ?? '',
            type: TypeFeedback.values
                .byName(r['type']?.toString() ?? 'suggestion'),
            priorite: PrioriteFeedback.values
                .byName(r['priorite']?.toString() ?? 'normale'),
            titre: r['titre']?.toString() ?? '',
            contenu: r['contenu']?.toString() ?? '',
            statut: StatutFeedback.values
                .byName(r['statut']?.toString() ?? 'nouveau'),
            date: DateTime.tryParse(r['created_at']?.toString() ?? '')
                ?? DateTime.now(),
          ),
      ]);
    catalogue
      ..clear()
      ..addAll([
        for (final r in (data['catalogue'] as List? ?? []))
          Tarif(
            id: r['id'].toString(), libelle: r['libelle'].toString(),
            categorie: r['categorie']?.toString() ?? 'Général',
            prix: (r['prix'] as num?)?.toDouble() ?? 0,
            description: r['description']?.toString() ?? '',
            actif: r['actif'] != false,
            dateAjout: DateTime.tryParse(
                r['date_ajout']?.toString() ?? ''),
            images: [
              for (final u in (r['images'] as List? ?? const []))
                MediaService.normaliserChemin(u.toString(),
                    entite: 'article',
                    id: r['id'].toString()) ??
                    u.toString(),
            ],
          ),
      ]);
    // Achats fournisseurs (Phase 2) — lignes stockées en JSONB.
    achats
      ..clear()
      ..addAll([
        for (final r in (data['achats'] as List? ?? []))
          Achat(
            id: r['id'].toString(),
            numero: r['numero']?.toString() ?? '',
            boutiqueId: r['boutique_id']?.toString() ?? '',
            fournisseurId: r['fournisseur_id']?.toString() ?? '',
            fournisseurNom: r['fournisseur_nom']?.toString() ?? '',
            lignes: [
              for (final l in (r['lignes'] as List? ?? const []))
                LigneAchat.fromJson(Map<String, dynamic>.from(l as Map)),
            ],
            date: DateTime.tryParse(r['date_achat']?.toString() ?? '') ??
                DateTime.now(),
            statut: r['statut']?.toString() ?? Achat.statutEnAttente,
            modePaiement: r['mode_paiement']?.toString() ?? 'especes',
            referenceFacture: r['reference_facture']?.toString(),
            notes: r['notes']?.toString(),
            motifAnnulation: r['motif_annulation']?.toString(),
            montantPaye: (r['montant_paye'] as num?)?.toDouble() ?? 0,
            createdBy: r['created_by']?.toString() ?? '',
            createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
      ]);
    // Mouvements de stock (mission 1 §1.3).
    mouvements
      ..clear()
      ..addAll([
        for (final r in (data['mouvements'] as List? ?? []))
          MouvementStock(
            id: r['id'].toString(),
            boutiqueId: r['boutique_id']?.toString() ?? '',
            produitId: r['produit_id']?.toString() ?? '',
            produitNom: r['produit_nom']?.toString() ?? '',
            type: r['type']?.toString() ?? MouvementStock.ajustement,
            quantite: (r['quantite'] as num?)?.toInt() ?? 0,
            stockApres: (r['stock_apres'] as num?)?.toInt() ?? 0,
            motif: r['motif']?.toString() ?? '',
            refId: r['ref_id']?.toString() ?? '',
            date: DateTime.tryParse(
                    r['date_mouvement']?.toString() ?? '') ??
                DateTime.now(),
            createdBy: r['created_by']?.toString() ?? '',
          ),
      ]);
    // Écritures comptables (mission §3.3).
    ecritures
      ..clear()
      ..addAll([
        for (final r in (data['ecritures'] as List? ?? []))
          Ecriture(
            id: r['id'].toString(),
            journal: r['journal']?.toString() ?? 'OD',
            date: DateTime.tryParse(
                    r['date_ecriture']?.toString() ?? '') ??
                DateTime.now(),
            compte: r['compte']?.toString() ?? '',
            libelle: r['libelle']?.toString() ?? '',
            debit: (r['debit'] as num?)?.toDouble() ?? 0,
            credit: (r['credit'] as num?)?.toDouble() ?? 0,
            refId: r['ref_id']?.toString() ?? '',
            boutiqueId: r['boutique_id']?.toString() ?? '',
            createdBy: r['created_by']?.toString() ?? '',
            pointee: r['pointee'] == true,
          ),
      ]);
    // Historique des documents (cloud → reconstruction complète)
    final docRows = data['documents'] as List? ?? [];
    documentsEmis.clear();
    if (docRows.isNotEmpty) {
      final lignesParDoc = await CloudRepository.chargerDocuments(docRows);
      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      documentsEmis.addAll([
        for (final r in docRows)
          DocumentBati(
            id: r['id'].toString(),
            type: typeDocumentDepuisDb(r['type'].toString()),
            numero: r['numero'].toString(),
            date: fmt(DateTime.tryParse(r['date_doc']?.toString() ?? '')
                ?? DateTime.now()),
            client: r['client_nom']?.toString() ?? '',
            lignes: [
              for (final l in lignesParDoc[r['id'].toString()] ?? const [])
                LigneDoc(
                  libelle: l['libelle'].toString(),
                  quantite: (l['quantite'] as num?)?.toInt() ?? 1,
                  prixUnitaire: (l['prix_unitaire'] as num?)?.toDouble() ?? 0,
                ),
            ],
            totalHT: (r['total_ht'] as num?)?.toDouble() ?? 0,
            tva: (r['tva'] as num?)?.toDouble() ?? 0,
            totalTTC: (r['total_ttc'] as num?)?.toDouble() ?? 0,
            devise: profile.devise,
            statut: r['statut']?.toString() ?? 'emis',
            signatureClientPath:
                await _signatureLocaleDepuisCloud(
                    r['signature_client_path']?.toString()),
          ),
      ]);
    }
    if (boutiques.isNotEmpty) {
      _boutiqueId = boutiques
          .firstWhere((b) => user.accedeA(b.id) || user.role == Role.admin,
              orElse: () => boutiques.first)
          .id;
    }
    notifyListeners();
    // `depenses` est maintenant peuplé : c'est ici, et seulement ici en
    // production, que la génération des charges récurrentes du mois a un
    // effet réel (voir le constructeur, où l'appel équivalent était fait
    // trop tôt — sur une liste encore vide — et ne faisait donc jamais rien).
    await genererChargesRecurrentesSiNouveauMois();
    // Images distantes (URLs http issues des buckets) : re-téléchargement
    // vers le stockage local, SANS bloquer le démarrage (plan A2 §Action 4).
    unawaited(_reparerImagesDistantes());
    return true;
  }

  /// Passe réparatrice (plan A2 §Action 4) : tout chemin http trouvé dans
  /// les galeries/logos est re-téléchargé (compressé, nom unique) et
  /// remplacé par le chemin local. Jamais d'exception, jamais de blocage :
  /// chaque entrée est isolée en try/catch, et l'état est persisté + notifié
  /// uniquement si au moins un chemin a changé.
  bool _reparationImagesEnCours = false;
  Future<void> _reparerImagesDistantes() async {
    if (_reparationImagesEnCours) return;
    _reparationImagesEnCours = true;
    var change = false;
    try {
      for (var i = 0; i < produits.length; i++) {
        final p = produits[i];
        final imgs = <String>[];
        for (final u in p.images) {
          final local = await MediaService.assurerLocal(u,
              entite: 'produit', id: p.id);
          imgs.add(local ?? u);
          if (local != null && local != u) change = true;
        }
        final principal = await MediaService.assurerLocal(p.imagePath,
            entite: 'produit', id: p.id);
        if (principal != p.imagePath ||
            !_memeListe(imgs, p.images)) {
          produits[i] = p.copyWith(
              imagePath: principal ?? p.imagePath, images: imgs);
          change = true;
        }
      }
      for (var i = 0; i < catalogue.length; i++) {
        final t = catalogue[i];
        final imgs = <String>[];
        for (final u in t.images) {
          final local = await MediaService.assurerLocal(u,
              entite: 'article', id: t.id);
          imgs.add(local ?? u);
          if (local != null && local != u) change = true;
        }
        if (!_memeListe(imgs, t.images)) {
          catalogue[i] = t.copyWith(images: imgs);
          change = true;
        }
      }
      for (var i = 0; i < clients.length; i++) {
        final c = clients[i];
        final logo = await MediaService.assurerLocal(c.logoPath,
            entite: 'client', id: c.id);
        if (logo != c.logoPath && logo != null) {
          clients[i] = Client(
              id: c.id, boutiqueId: c.boutiqueId, nom: c.nom,
              telephone: c.telephone, email: c.email, adresse: c.adresse,
              rccm: c.rccm, ifu: c.ifu, rib: c.rib, logoPath: logo);
          change = true;
        }
      }
      final logo = await MediaService.assurerLocal(profile.logoPath,
          entite: 'company', id: 'logo');
      final cachet = await MediaService.assurerLocal(profile.cachetPath,
          entite: 'company', id: 'cachet');
      final signature = await MediaService.assurerLocal(
          profile.signaturePath,
          entite: 'company',
          id: 'signature');
      if (logo != profile.logoPath ||
          cachet != profile.cachetPath ||
          signature != profile.signaturePath) {
        profile = profile.copyWith(
          logoPath: logo ?? profile.logoPath,
          cachetPath: cachet ?? profile.cachetPath,
          signaturePath: signature ?? profile.signaturePath,
        );
        change = true;
      }
    } catch (_) {
      // Réparation opportuniste : un échec ne bloque jamais l'app.
    } finally {
      _reparationImagesEnCours = false;
    }
    if (change) {
      _persist();
      notifyListeners();
    }
  }

  static bool _memeListe(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  /// Secours hors-ligne : recharge le dernier snapshot local
  /// (sauvegardé à chaque mutation via _persist) quand Supabase est
  /// injoignable au démarrage. L'identité de session est CONSERVÉE
  /// (jamais écrasée par le snapshot) pour que les écritures en file
  /// gardent le bon employe_id au rejeu. Retourne false si aucun
  /// snapshot exploitable (boutiques vides → rien à afficher).
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
    demarrageHorsLigne = true;
    notifyListeners();
    return true;
  }

  /// Tentative de retour en ligne depuis le bandeau hors-ligne :
  /// recharge le cloud et n'efface le mode que si ça réussit.
  Future<bool> reconnecter() async {
    final ok = await chargerDuCloud();
    if (ok) {
      demarrageHorsLigne = false;
      notifyListeners();
    }
    return ok;
  }

  /// Pull-to-refresh (mission §2.8) : recharge depuis Supabase si le
  /// cloud est configuré (jamais le cache local seul), sinon simple
  /// reconstruction. Utilisé par les RefreshIndicator des listes.
  Future<void> rafraichir() async {
    if (CloudRepository.actif) {
      await chargerDuCloud();
    } else {
      notifyListeners();
    }
  }

  // ---------- Données ----------
  late String _boutiqueId;
  String get boutiqueId => _boutiqueId;
  final boutiques = <Boutique>[];
  final transactions = <Tx>[];
  final produits = <Produit>[];
  final partenaires = <Partenaire>[];
  final partages = <Partage>[];
  final depenses = <Charge>[];
  final users = <AppUser>[];                 // gestion des utilisateurs (P-admin)
  final clients = <Client>[];                // fichier clients
  final fournisseurs = <Fournisseur>[];      // fichier fournisseurs
  final messages = <Message>[];              // messagerie interne
  final evenements = <Evenement>[];          // réunions & événements
  final notesPerso = <Note>[];               // notes & rappels
  final feedbacks = <Feedback>[];            // suggestions & signalements
  final catalogue = <Tarif>[];               // tarifs & catalogue (hors stock)
  final documentsEmis = <DocumentBati>[];
  final achats = <Achat>[];                // achats fournisseurs (Phase 2)
  final mouvements = <MouvementStock>[];   // historique des stocks (mission 1)
  final ecritures = <Ecriture>[];          // journal comptable (mission §3.3)
  CompanyProfile get profile => profil.profile;
  set profile(CompanyProfile p) => profil.profile = p;
  int _seq = 0;
  Timer? _persistTimer;
  String _nid() => CloudRepository.actif
      ? CloudRepository.uuid()
      : 'id_${++_seq}_${DateTime.now().millisecondsSinceEpoch}';

  void changerBoutique(String id) {
    final avant = _boutiqueId;
    boutique.changerBoutique(id);
    _boutiqueId = boutique.boutiqueId;
    if (_boutiqueId != avant) _syncBoutiqueId();
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
    // Sans cela, le timer de persistance différée survivait à l'arbre de
    // widgets (fuite mémoire + smoke test rouge : "A Timer is still
    // pending even after the widget tree was disposed").
    _persistTimer?.cancel();
    super.dispose();
  }

  // ---------- Utilisateurs (gestion, délégué à `session`) ----------
  Role get role => session.role;
  bool peut(Permission p) => session.peut(p);

  void changerRole(Role r) => session.changerRole(r);

  Future<void> ajouterUtilisateur(AppUser u) =>
      session.ajouterUtilisateur(u);

  Future<void> majUtilisateur(AppUser u) =>
      session.majUtilisateur(u);

  Future<void> supprimerUtilisateur(String id) =>
      session.supprimerUtilisateur(id);

  // ---------- Catégories (délégué à `categories`, Phase 5) ----------
  List<String> get catsProduit => categories.catsProduit;
  List<String> get catsCharge => categories.catsCharge;
  List<String> get opsMobileMoney => categories.opsMobileMoney;
  List<String> get opsCredit => categories.opsCredit;
  List<String> get domainesPresta => categories.domainesPresta;
  List<String> get dureesForfaitListe => categories.dureesForfaitListe;

  Future<String?> ajouterCategorie(String nom,
          {required bool produit}) =>
      categories.ajouterCategorie(nom, produit: produit);

  Future<String?> renommerCategorie(String ancien, String nouveau,
          {required bool produit}) =>
      categories.renommerCategorie(ancien, nouveau, produit: produit);

  Future<String?> supprimerCategorie(String nom,
          {required bool produit}) =>
      categories.supprimerCategorie(nom, produit: produit);

  Future<String?> ajouterValeurListe(String type, String nom) =>
      categories.ajouterValeurListe(type, nom);

  Future<String?> renommerValeurListe(
          String type, String ancien, String nouveau) =>
      categories.renommerValeurListe(type, ancien, nouveau);

  Future<String?> supprimerValeurListe(String type, String nom) =>
      categories.supprimerValeurListe(type, nom);

  // ---------- Clients (délégué à `client`, Phase 5) ----------
  List<Client> get clientsBoutique => client.clientsBoutique;

  Future<String?> ajouterClient(Client c) =>
      client.ajouterClient(c);

  Future<void> majClient(Client c) => client.majClient(c);

  /// Noms des clients avec impayé en cours (filtre « Avec crédit »).
  /// Façade : aucun Notifier ne porte ce calcul transverse.
  Set<String> get clientsAvecCredit => {
        for (final t in transactions)
          if (t.statut != StatutPaiement.paye &&
              (t.clientNom ?? '').trim().isNotEmpty)
            t.clientNom!.trim(),
      };

  // ---------- Fournisseurs (délégué à `fournisseur`, Phase 5) ----------
  Future<String?> ajouterFournisseur(Fournisseur f) =>
      fournisseur.ajouterFournisseur(f);

  Future<void> majFournisseur(Fournisseur f) =>
      fournisseur.majFournisseur(f);

  Future<void> supprimerFournisseur(String id) =>
      fournisseur.supprimerFournisseur(id);

  // ---------- Messagerie / Événements / Notes (délégué à `collab`) ----------
  List<Message> get messagesVisibles => collab.messagesVisibles;

  int get messagesNonLus => collab.messagesNonLus;

  Future<void> envoyerMessage({
    required String sujet,
    required String contenu,
    String? destinataireId,
  }) =>
      collab.envoyerMessage(
          sujet: sujet,
          contenu: contenu,
          destinataireId: destinataireId);

  Future<void> marquerMessageLu(String id) =>
      collab.marquerMessageLu(id);

  Future<void> marquerTousMessagesLus() =>
      collab.marquerTousMessagesLus();

  Future<String?> majMessage(Message maj) => collab.majMessage(maj);

  Future<void> supprimerMessage(String id) =>
      collab.supprimerMessage(id);

  List<Evenement> get evenementsAVenir => collab.evenementsAVenir;

  Future<void> ajouterEvenement(Evenement e) =>
      collab.ajouterEvenement(e);

  Future<void> majEvenement(Evenement e) => collab.majEvenement(e);

  Future<void> supprimerEvenement(String id) =>
      collab.supprimerEvenement(id);

  Future<void> ajouterNote(Note n) => collab.ajouterNote(n);

  Future<void> majNote(Note n) => collab.majNote(n);

  Future<void> supprimerNote(String id) => collab.supprimerNote(id);

  // ---------- Tarifs & catalogue ----------
  List<Tarif> get tarifsActifs => catalogue.where((t) => t.actif).toList();

  Future<String?> ajouterTarif(Tarif t) async {
    final e = V.texte(t.libelle, 2, 'Libellé');
    if (e != null) return e;
    if (t.prix <= 0) return 'Le prix doit être > 0';
    if (catalogue.any((x) =>
        x.actif && memeCategorie(x.libelle, t.libelle.trim()))) {
      return 'Un article du même nom existe déjà';
    }
    final tarif = Tarif(
      id: _nid(), libelle: t.libelle, categorie: t.categorie,
      prix: t.prix, description: t.description, actif: t.actif,
      images: t.images,
      dateAjout: t.dateAjout ?? DateTime.now(),
    );
    catalogue.add(tarif);
    notifyListeners();
    await CloudRepository.upsertTarif(tarif);
    await _fileUpsert('tarifs', _payloadTarif(tarif));
    return null;
  }

  Future<String?> majTarif(Tarif t) async {
    final i = catalogue.indexWhere((x) => x.id == t.id);
    if (i < 0) return 'Article introuvable';
    if (t.prix <= 0) return 'Le prix doit être > 0';
    // Date d'ajout d'origine conservée (badge Nouveau stable en modif).
    catalogue[i] =
        t.dateAjout == null && catalogue[i].dateAjout != null
            ? t.copyWith(dateAjout: catalogue[i].dateAjout)
            : t;
    notifyListeners();
    await CloudRepository.upsertTarif(t);
    await _fileUpsert('tarifs', _payloadTarif(t));
    return null;
  }

  Future<void> supprimerTarif(String id) async {
    final i = catalogue.indexWhere((t) => t.id == id);
    if (i >= 0) {
      catalogue[i] = catalogue[i].copyWith(actif: false);
      notifyListeners();
      await CloudRepository.upsertTarif(catalogue[i]);
      await _fileUpsert('tarifs', _payloadTarif(catalogue[i]));
    }
  }

  // ---------- Suggestions (délégué à `collab`, Phase 5) ----------
  int get nouveauxFeedbacks => collab.nouveauxFeedbacks;

  Future<String?> ajouterFeedback(Feedback f) =>
      collab.ajouterFeedback(f);

  Future<void> changerStatutFeedback(
          String id, StatutFeedback statut) =>
      collab.changerStatutFeedback(id, statut);

  Future<String?> majFeedback(Feedback maj) =>
      collab.majFeedback(maj);

  Future<void> supprimerFeedback(String id) =>
      collab.supprimerFeedback(id);

  // ---------- Boutiques (délégué à `boutique`, Phase 5) ----------
  List<Boutique> get boutiquesActives => boutique.boutiquesActives;

  List<Boutique> get boutiquesAccessibles =>
      boutique.boutiquesAccessibles;

  Boutique get boutiqueCourante => boutique.boutiqueCourante;

  Future<String?> ajouterBoutique(Boutique b, List<String> userIds) =>
      boutique.ajouterBoutique(b, userIds);

  Future<String?> majBoutique(Boutique b, List<String> userIds) =>
      boutique.majBoutique(b, userIds);

  Future<String?> fermerBoutique(String id) =>
      boutique.fermerBoutique(id);

  Future<String?> rouvrirBoutique(String id) =>
      boutique.rouvrirBoutique(id);

  // ---------- Configuration entreprise (délégué à `profil`) ----------
  Future<void> updateProfile(CompanyProfile p) =>
      profil.updateProfile(p);

  // ---------- Transactions ----------
  Map<String, dynamic> _payloadTx(Tx tx) => {
        'id': tx.id,
        'boutique_id': tx.boutiqueId,
        'employe_id': tx.employeId,
        'type': CloudTx.dbValue(tx.type),
        'montant': tx.montant,
        'cout': tx.cout,
        'statut': tx.statut.name,
        'client_nom': tx.clientNom,
        'partenaire_id': tx.partenaireId,
        'details': tx.details,
        'date_transaction': tx.date.toIso8601String(),
      };

  Future<String> ajouterTransaction({
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    String? partenaireId,
    Map<String, dynamic> details = const {},
    DateTime? date,
    StatutPaiement statut = StatutPaiement.paye,
  }) =>
      transaction.ajouterTransaction(
        type: type,
        montant: montant,
        cout: cout,
        clientNom: clientNom,
        partenaireId: partenaireId,
        details: details,
        date: date,
        statut: statut,
      );

  Future<String?> majTransaction(Tx maj) =>
      transaction.majTransaction(maj);

  Future<void> supprimerTransaction(String id) =>
      transaction.supprimerTransaction(id);

  /// Encaissement d'une vente à crédit (délégué à `transaction`).
  Future<String?> encaisserVente(String id) =>
      transaction.encaisserVente(id);

  /// Créances clients : ventes non soldées (délégué à `transaction`).
  List<Tx> get creances => transaction.creances;

  double get totalCreances => transaction.totalCreances;

  /// Balance âgée : encours impayé par tranche (délégué, Phase 5).
  Map<String, double> get balanceAgee =>
      AnalytiqueService.balanceAgee(creances, DateTime.now());

  /// TVA par mois (délégué à `AnalytiqueService`, Phase 5).
  Map<int, (double, double)> tvaParMois(int annee) =>
      AnalytiqueService.tvaParMois(ecrituresBoutique, annee);

  // ---------- Tableau de bord ----------
  List<Tx> get txBoutique => transaction.txBoutique;

  List<Tx> get txJour => AnalytiqueService.duJour(
      transactions, _boutiqueId, DateTime.now());

  double get caJour =>
      AnalytiqueService.caJour(transactions, _boutiqueId, DateTime.now());

  double get margeJour => AnalytiqueService.margeJour(
      transactions, _boutiqueId, DateTime.now());

  String get moisCourant => C.moisKey(DateTime.now());

  List<Tx> get txMois =>
      AnalytiqueService.duMois(transactions, _boutiqueId, moisCourant);

  double get caMois =>
      AnalytiqueService.caMois(transactions, _boutiqueId, moisCourant);

  double get margeMois =>
      AnalytiqueService.margeMois(transactions, _boutiqueId, moisCourant);

  Map<TypeTransaction, double> get caParType =>
      AnalytiqueService.caParType(txMois);

  Map<String, double> get caParJour => AnalytiqueService.caParJour(
      transaction.txBoutique, DateTime.now());

  Map<String, double> get fraisMoMoMois =>
      AnalytiqueService.fraisMoMo(txMois);


  // ---------- Charges (délégué à `charge`, Phase 5) ----------
  Future<void> ajouterCharge(Charge c) => charge.ajouterCharge(c);

  List<Charge> get depensesBoutique => charge.depensesBoutique;

  Future<String?> majCharge(Charge maj) => charge.majCharge(maj);

  Future<void> supprimerCharge(String id) =>
      charge.supprimerCharge(id);

  List<Charge> get depensesMois =>
      charge.depensesMois(moisCourant);

  double get totalDepensesMois =>
      charge.totalDepensesMois(moisCourant);

  double depensesCategorieMois(String categorie) =>
      charge.depensesCategorieMois(categorie, moisCourant);

  Map<String, (double, double)> get suiviBudgets =>
      charge.suiviBudgets(moisCourant);

  Future<void> genererChargesRecurrentesSiNouveauMois() =>
      charge.genererChargesRecurrentesSiNouveauMois(moisCourant);

  // ---------- Trésorerie (délégué à `profil` + `CaisseService`) ----------
  double get fondsRoulementCourant =>
      profil.profile.fondsRoulement[_boutiqueId] ?? 0;

  Future<void> definirFondsRoulement(
          String boutiqueId, double montant) =>
      profil.definirFonds(boutiqueId, montant);

  double soldeCaisse(String boutiqueId) => CaisseService.solde(
      transactions: transactions,
      depenses: depenses,
      boutiqueId: boutiqueId,
      fondsRoulement:
          profil.profile.fondsRoulement[boutiqueId] ?? 0);

  double get soldeCaisseCourant => soldeCaisse(_boutiqueId);

  // ---------- Comptabilité SYSCOHADA simplifiée (mission §3.3/§4) ----------
  /// Journal immuable : écritures auto-générées, corrections par
  /// contre-écriture uniquement (jamais de update/delete).
  // ---------- Comptabilité (délégué à `compta`, Phase 5) ----------
  // Journal immuable : écritures auto-générées, corrections par
  // contre-écriture uniquement (jamais de update/delete).
  List<Ecriture> get ecrituresBoutique => compta.ecrituresBoutique;

  Future<void> pointerEcriture(String id, bool pointee) =>
      compta.pointerEcriture(id, pointee);

  List<Ecriture> get ecrituresARapprocher => compta.ecrituresARapprocher;

  Map<String, double> get balance => compta.balance;

  double get resultatExercice => compta.resultatExercice;

  // ---------- Documents ----------
  /// [date] = date d'émission réelle (formulaire) : affichée sur le
  /// document, conservée dans l'historique local ET dans la base cloud
  /// (date_doc) pour que le rechargement ne la remette pas à aujourd'hui.
  /// Validation manager : un document créé par un vendeur naît `brouillon`
  /// (à valider par admin/gérant/comptable) ; les rôles financiers
  /// émettent directement en `emis`.
  /// Retourne l'identifiant cloud (pour rattacher la signature client).
  // ---------- Documents (délégué à `document`, Phase 5) ----------
  Future<String?> enregistrerDocument(DocumentBati d,
          {DateTime? date}) =>
      document.enregistrerDocument(d, date: date);

  Future<String?> validerDocument(String numero) =>
      document.validerDocument(numero);

  Future<String?> payerDocument(String numero) =>
      document.payerDocument(numero);

  Future<String?> annulerDocument(String numero, String motif) =>
      document.annulerDocument(numero, motif);

  Future<void> joindreSignatureClient(
          String numero, String cheminLocal) =>
      document.joindreSignatureClient(numero, cheminLocal);

  /// Re-télécharge une signature client (chemin storage → fichier
  /// temporaire local) pour l'aperçu et la régénération PDF après
  /// rechargement. Retourne null si absente ou inaccessible — l'original
  /// reste visible sur l'appareil émetteur.
  Future<String?> _signatureLocaleDepuisCloud(String? chemin) async {
    if (chemin == null || chemin.isEmpty) return null;
    if (!CloudRepository.actif) return null;
    return CloudRepository.telechargerSignature(chemin);
  }

  Future<DocumentBati> transformerDevisEnFacture(DocumentBati devis) =>
      document.transformerDevisEnFacture(devis);

  Future<String> numeroDocument(String prefixe) async {
    if (CloudRepository.actif) {
      final numero = await CloudRepository.prochainNumero(prefixe);
      if (numero != null) return numero;
    }
    final (numero, nouveauProfile) = profile.prochainNumero(prefixe);
    profile = nouveauProfile;
    notifyListeners();
    return numero;
  }

  // ---------- Stock ----------
  // ---------- Produits (délégué à `produit`, Phase 5) ----------
  List<Produit> get produitsBoutique => produit.produitsBoutique;

  List<Produit> get alertesStock => produit.alertesStock;

  Future<String?> ajouterProduit(Produit p) =>
      produit.ajouterProduit(p);

  Future<String?> majProduit(Produit p) => produit.majProduit(p);

  Future<void> archiverProduit(String id) =>
      produit.archiverProduit(id);

  Future<String?> supprimerProduit(String id,
          {bool forcerArchive = false}) =>
      produit.supprimerProduit(id, forcerArchive: forcerArchive);

  Future<List<String>> deduireStockPourLignes(List<LigneDoc> lignes,
          {String refId = '', DateTime? date}) =>
      produit.deduireStockPourLignes(
          [for (final l in lignes) {'libelle': l.libelle, 'quantite': l.quantite}],
          refId: refId,
          date: date);

  Future<void> vendreProduit(Produit p, int quantite,
          {String? clientNom, DateTime? date}) =>
      produit.vendreProduit(p, quantite,
          clientNom: clientNom, date: date);

  /// Tout produit du stock est automatiquement présent au catalogue
  /// (même libellé, prix = prix de vente) : la vente sans stock et les
  /// documents peuvent le réutiliser sans double saisie.
  Future<void> _syncCatalogueDepuisProduit(Produit p) async {
    final i = catalogue.indexWhere(
        (t) => t.actif && _memeLibelle(t.libelle, p.libelle));
    if (i >= 0) {
      if (catalogue[i].prix != p.prixVente ||
          catalogue[i].categorie != p.categorie) {
        catalogue[i] = catalogue[i].copyWith(
            prix: p.prixVente, categorie: p.categorie);
        notifyListeners();
        await CloudRepository.upsertTarif(catalogue[i]);
        await _fileUpsert('tarifs', _payloadTarif(catalogue[i]));
      }
      return;
    }
    final t = Tarif(
      id: _nid(), libelle: p.libelle.trim(), categorie: p.categorie,
      prix: p.prixVente, description: 'Depuis le stock', actif: true,
      dateAjout: DateTime.now(),
    );
    catalogue.add(t);
    notifyListeners();
    await CloudRepository.upsertTarif(t);
    await _fileUpsert('tarifs', _payloadTarif(t));
  }

  Map<String, dynamic> _payloadTarif(Tarif t) => {
        'id': t.id, 'libelle': t.libelle, 'categorie': t.categorie,
        'prix': t.prix, 'description': t.description, 'actif': t.actif,
        'images': t.images,
        'date_ajout': t.dateAjout?.toIso8601String(),
      };

  // ---------- Mouvements (délégué à `stockMouvements`, Phase 5) ----------
  List<MouvementStock> get mouvementsBoutique =>
      stockMouvements.mouvementsBoutique(_boutiqueId);

  List<MouvementStock> mouvementsProduit(String produitId) =>
      stockMouvements.mouvementsProduit(produitId);

  /// Valorisation du stock (quantité × coût d'achat courant).
  double get valeurStock =>
      StockService.valorisation(produit.produitsBoutique);

  Future<void> _journaliser({
    required String produitId,
    required String produitNom,
    required String type,
    required int quantite,
    required int stockApres,
    String motif = '',
    String refId = '',
    DateTime? date,
  }) =>
      stockMouvements.journaliser(
        produitId: produitId,
        produitNom: produitNom,
        type: type,
        quantite: quantite,
        stockApres: stockApres,
        boutiqueId: _boutiqueId,
        motif: motif,
        refId: refId,
        date: date,
      );

  Future<void> _fileUpsert(
      String table, Map<String, dynamic> payload) async {
    if (!CloudRepository.actif) return;
    await SyncService().mettreEnFile(payload, table: table);
  }

  Map<String, dynamic> _payloadProduit(Produit p) => {
        'id': p.id,
        'boutique_id': p.boutiqueId,
        'libelle': p.libelle,
        'categorie': p.categorie,
        'prix_achat': p.prixAchat,
        'prix_vente': p.prixVente,
        'quantite_stock': p.stock,
        'seuil_alerte': p.seuil,
        'date_ajout': p.dateAjout?.toIso8601String(),
        'actif': true,
      };

  bool _memeLibelle(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Normalisation anti-doublon (point 35) : casse + accents.
  /// Conservée ici car `tarifs_screen.dart` l'utilise via `Store.*`
  /// (la Phase 5 délèguera tout le module tarifs).
  static String sansAccents(String s) =>
      Normalisation.sansAccents(s);

  static bool memeCategorie(String a, String b) =>
      Normalisation.memeCategorie(a, b);

  /// Ajustement manuel (délégué à `stockMouvements`, Phase 5).
  Future<String?> ajusterStock(String produitId, int nouveauStock,
          String motif) =>
      stockMouvements.ajusterStock(
          produitId, nouveauStock, motif, _boutiqueId);

  // ---------- Analytique CA & dépenses (mission 3, §3.1/3.2) ----------
  /// Jours calendaires couvrant [fin] et les [jours]-1 jours précédents.
  // ---------- Analytique (délégué à `analytique`, Phase 5) ----------
  List<AgregatPeriode> ca7Jours({DateTime? fin}) =>
      analytique.ca7Jours(fin: fin);

  List<AgregatPeriode> depenses7Jours({DateTime? fin}) =>
      analytique.depenses7Jours(fin: fin);

  List<AgregatPeriode> caParMois(int annee) =>
      analytique.caParMois(annee);

  List<AgregatPeriode> depensesParMois(int annee) =>
      analytique.depensesParMois(annee);

  List<AgregatPeriode> caParAnnee() => analytique.caParAnnee();

  List<AgregatPeriode> depensesParAnnee() =>
      analytique.depensesParAnnee();

  List<int> anneesDonnees() => analytique.anneesDonnees();

  // ---------- Partenaires (délégué à `partenaire`, Phase 5) ----------
  Future<String?> ajouterPartenaire(Partenaire p) =>
      partenaire.ajouterPartenaire(p);

  Future<String?> majPartenaire(Partenaire p) =>
      partenaire.majPartenaire(p);

  Future<void> desactiverPartenaire(String id) =>
      partenaire.desactiverPartenaire(id);

  Future<String?> supprimerPartenaire(String id) =>
      partenaire.supprimerPartenaire(id);

  // ---------- Partenaires : clôture (délégué, Phase 5) ----------
  double ventesPartenaireMois(String partenaireId, String mois) =>
      PartageService.totalVentes(
          transactions, partenaireId, mois);

  bool partageExiste(String partenaireId, String mois) =>
      partenaire.partageExiste(partenaireId, mois);

  Future<Partage> cloturerMois(String partenaireId, String mois) =>
      partenaire.cloturerMois(partenaireId, mois, _boutiqueId);

  List<Partage> partagesDe(String partenaireId) =>
      partenaire.partagesDe(partenaireId);

  // ---------- Achats (délégué à `achat`, Phase 5) ----------
  List<Achat> get achatsBoutique => achat.achatsBoutique;

  List<Achat> get achatsEnAttente => achat.achatsEnAttente;

  double get totalAchatsMois => achat.totalAchatsMois(moisCourant);

  double get duFournisseurs => achat.duFournisseurs;

  Future<String?> creerAchat(Achat brouillon) =>
      achat.creerAchat(brouillon);

  Future<String?> majAchat(Achat maj) => achat.majAchat(maj);

  Future<String?> validerAchat(String id) => achat.validerAchat(id);

  Future<String?> recevoirAchat(String id) => achat.recevoirAchat(id);

  Future<String?> payerAchat(String id, double montant,
          {String? mode}) =>
      achat.payerAchat(id, montant, mode: mode);

  Future<String?> annulerAchat(String id, String motif) =>
      achat.annulerAchat(id, motif);

  // ---------- Sérialisation (persistance locale) ----------
  Map<String, dynamic> toJson() => {
        'version': 1,
        'boutique_id_courante': _boutiqueId,
        'profil': {
          'nom_entreprise': profile.nomEntreprise, 'devise': profile.devise,
          'telephone': profile.telephone, 'telephone2': profile.telephone2,
          'email': profile.email, 'adresse': profile.adresse,
          'rccm': profile.rccm, 'ifu': profile.ifu,
          'autre_ref_fiscale': profile.autreRefFiscale,
          'banque': profile.banque,
          'coordonnees_bancaires': profile.coordonneesBancaires,
          'message_pied': profile.messagePied, 'tva': profile.tva,
          'logo_path': profile.logoPath, 'cachet_path': profile.cachetPath,
          'signature_path': profile.signaturePath,
          'fonds_roulement': profile.fondsRoulement,
          'budgets': profile.budgetsMensuels,
          'compteurs': profile.compteursDocs,
          'mois_charges_generees': profile.moisChargesGenerees,
        },
        'utilisateur': {
          'id': user.id, 'nom': user.nom, 'role': user.role.name,
          'boutique_ids': user.boutiqueIds,
        },
        'utilisateurs': [
          for (final u in users)
            {'id': u.id, 'nom': u.nom, 'role': u.role.name, 'boutique_ids': u.boutiqueIds},
        ],
        'boutiques': [
          for (final b in boutiques)
            {'id': b.id, 'nom': b.nom, 'adresse': b.adresse,
             'siege': b.siege, 'actif': b.actif},
        ],
        'categories': {
          'produits': catsProduit,
          'charges': catsCharge,
          'operateurs_mobile_money': opsMobileMoney,
          'operateurs_credit': opsCredit,
          'domaines_prestation': domainesPresta,
          'durees_forfait': dureesForfaitListe,
        },
        'clients': [
          for (final c in clients)
            {'id': c.id, 'boutique_id': c.boutiqueId, 'nom': c.nom,
             'telephone': c.telephone, 'email': c.email,
             'adresse': c.adresse, 'rccm': c.rccm, 'ifu': c.ifu,
             'rib': c.rib, 'logo_path': c.logoPath},
        ],
        'fournisseurs': [
          for (final f in fournisseurs)
            {'id': f.id, 'nom': f.nom, 'telephone': f.telephone,
             'email': f.email, 'adresse': f.adresse,
             'specialite': f.specialite, 'notes': f.notes},
        ],
        'messages': [
          for (final m in messages)
            {'id': m.id, 'expediteur_id': m.expediteurId,
             'expediteur_nom': m.expediteurNom,
             'destinataire_id': m.destinataireId,
             'sujet': m.sujet, 'contenu': m.contenu,
             'date': m.date.toIso8601String(), 'lu': m.lu},
        ],
        'evenements': [
          for (final e in evenements)
            {'id': e.id, 'titre': e.titre, 'date': e.date.toIso8601String(),
             'heure': e.heure, 'lieu': e.lieu, 'description': e.description,
             'createur_id': e.createurId},
        ],
        'catalogue': [
          for (final t in catalogue)
            {'id': t.id, 'libelle': t.libelle, 'categorie': t.categorie,
             'prix': t.prix, 'description': t.description, 'actif': t.actif,
             'images': t.images,
             'date_ajout': t.dateAjout?.toIso8601String()},
        ],
        'feedbacks': [
          for (final f in feedbacks)
            {'id': f.id, 'auteur_id': f.auteurId, 'auteur_nom': f.auteurNom,
             'boutique_id': f.boutiqueId, 'type': f.type.name,
             'priorite': f.priorite.name, 'titre': f.titre,
             'contenu': f.contenu, 'statut': f.statut.name,
             'date': f.date.toIso8601String()},
        ],
        'notes': [
          for (final n in notesPerso)
            {'id': n.id, 'titre': n.titre, 'contenu': n.contenu,
             'date': n.date.toIso8601String(),
             'rappel_le': n.rappelLe?.toIso8601String(),
             'createur_id': n.createurId},
        ],
        'produits': [
          for (final p in produits)
            {'id': p.id, 'boutique_id': p.boutiqueId, 'libelle': p.libelle,
             'categorie': p.categorie, 'prix_achat': p.prixAchat,
             'prix_vente': p.prixVente, 'stock': p.stock, 'seuil': p.seuil,
             'image_path': p.imagePath, 'images': p.images,
             'date_ajout': p.dateAjout?.toIso8601String()},
        ],
        'partenaires': [
          for (final p in partenaires)
            {'id': p.id, 'nom': p.nom, 'telephone': p.telephone,
             'localisation': p.localisation, 'taux': p.taux},
        ],
        'transactions': [
          for (final t in transactions)
            {'id': t.id, 'boutique_id': t.boutiqueId, 'type': t.type.name,
             'montant': t.montant, 'cout': t.cout, 'statut': t.statut.name,
             'client_nom': t.clientNom, 'partenaire_id': t.partenaireId,
             'details': t.details, 'date': t.date.toIso8601String()},
        ],
        'charges': [
          for (final c in depenses)
            {'id': c.id, 'boutique_id': c.boutiqueId, 'categorie': c.categorie,
             'libelle': c.libelle, 'montant': c.montant,
             'date': c.date.toIso8601String(), 'recurrente': c.recurrente},
        ],
        'partages': [
          for (final p in partages)
            {'partenaire_id': p.partenaireId, 'mois': p.mois,
             'total_ventes': p.totalVentes, 'taux': p.taux,
             'part_partenaire': p.partPartenaire,
             'part_entreprise': p.partEntreprise},
        ],
        'achats': [for (final a in achats) a.toJson()],
        'mouvements': [for (final m in mouvements) m.toJson()],
        'ecritures': [for (final e in ecritures) e.toJson()],
      };

  /// Rechargement d'un snapshot (boot démo, test de non-régression
  /// images). Exposée aux tests uniquement.
  @visibleForTesting
  void restaurerEtatPourTest(Map<String, dynamic> data) =>
      _chargerEtat(data);

  void _chargerEtat(Map<String, dynamic> data) {
    final p = Map<String, dynamic>.from(data['profil'] as Map? ?? {});
    profile = CompanyProfile(
      nomEntreprise: p['nom_entreprise']?.toString() ?? 'Mon Entreprise',
      devise: p['devise']?.toString() ?? 'FCFA',
      telephone: p['telephone']?.toString() ?? '',
      telephone2: p['telephone2']?.toString() ?? '',
      email: p['email']?.toString() ?? '',
      adresse: p['adresse']?.toString() ?? '',
      rccm: p['rccm']?.toString() ?? '',
      ifu: p['ifu']?.toString() ?? '',
      autreRefFiscale: p['autre_ref_fiscale']?.toString() ?? '',
      banque: p['banque']?.toString() ?? '',
      coordonneesBancaires: p['coordonnees_bancaires']?.toString() ?? '',
      messagePied: p['message_pied']?.toString() ?? '',
      tva: (p['tva'] as num?)?.toDouble() ?? 0,
      logoPath: MediaService.normaliserChemin(p['logo_path']?.toString(),
          entite: 'company', id: 'logo'),
      cachetPath: MediaService.normaliserChemin(p['cachet_path']?.toString(),
          entite: 'company', id: 'cachet'),
      signaturePath: MediaService.normaliserChemin(
          p['signature_path']?.toString(),
          entite: 'company',
          id: 'signature'),
      fondsRoulement: {
        for (final e in (p['fonds_roulement'] as Map? ?? {}).entries)
          e.key.toString(): (e.value as num).toDouble(),
      },
      budgetsMensuels: {
        for (final e in (p['budgets'] as Map? ?? {}).entries)
          e.key.toString(): (e.value as num).toDouble(),
      },
      compteursDocs: {
        for (final e in (p['compteurs'] as Map? ?? {}).entries)
          e.key.toString(): (e.value as num).toInt(),
      },
      moisChargesGenerees: p['mois_charges_generees']?.toString(),
    );
    user = AppUser(
      id: data['utilisateur']?['id']?.toString() ?? user.id,
      nom: data['utilisateur']?['nom']?.toString() ?? user.nom,
      role: Role.values.byName(data['utilisateur']?['role']?.toString() ?? 'admin'),
      boutiqueIds: List<String>.from(
          data['utilisateur']?['boutique_ids'] as List? ?? const []),
    );
    users
      ..clear()
      ..addAll([
        for (final u in (data['utilisateurs'] as List? ?? []))
          AppUser(
            id: u['id'].toString(), nom: u['nom'].toString(),
            role: Role.values.byName(u['role'].toString()),
            boutiqueIds: List<String>.from(u['boutique_ids'] as List? ?? const []),
          ),
      ]);
    boutiques
      ..clear()
      ..addAll([
        for (final b in (data['boutiques'] as List? ?? []))
          Boutique(id: b['id'].toString(), nom: b['nom'].toString(),
              adresse: b['adresse']?.toString() ?? '',
              siege: b['siege'] == true, actif: b['actif'] != false),
      ]);
    final cats = Map<String, dynamic>.from(data['categories'] as Map? ?? {});
    if (cats['produits'] is List) {
      catsProduit
        ..clear()
        ..addAll([for (final c in cats['produits'] as List) c.toString()]);
    }
    if (cats['charges'] is List) {
      catsCharge
        ..clear()
        ..addAll([for (final c in cats['charges'] as List) c.toString()]);
    }
    if (cats['operateurs_mobile_money'] is List) {
      opsMobileMoney
        ..clear()
        ..addAll([for (final c in cats['operateurs_mobile_money'] as List) c.toString()]);
    }
    if (cats['operateurs_credit'] is List) {
      opsCredit
        ..clear()
        ..addAll([for (final c in cats['operateurs_credit'] as List) c.toString()]);
    }
    if (cats['domaines_prestation'] is List) {
      domainesPresta
        ..clear()
        ..addAll([for (final c in cats['domaines_prestation'] as List) c.toString()]);
    }
    if (cats['durees_forfait'] is List) {
      dureesForfaitListe
        ..clear()
        ..addAll([for (final c in cats['durees_forfait'] as List) c.toString()]);
    }
    clients
      ..clear()
      ..addAll([
        for (final c in (data['clients'] as List? ?? []))
          Client(
            id: c['id'].toString(), boutiqueId: c['boutique_id'].toString(),
            nom: c['nom'].toString(),
            telephone: c['telephone']?.toString() ?? '',
            email: c['email']?.toString() ?? '',
            adresse: c['adresse']?.toString() ?? '',
            rccm: c['rccm']?.toString() ?? '',
            ifu: c['ifu']?.toString() ?? '',
            rib: c['rib']?.toString() ?? '',
            logoPath: MediaService.normaliserChemin(
                c['logo_path']?.toString(),
                entite: 'client',
                id: c['id'].toString()),
          ),
      ]);
    fournisseurs
      ..clear()
      ..addAll([
        for (final f in (data['fournisseurs'] as List? ?? []))
          Fournisseur(
            id: f['id'].toString(), nom: f['nom'].toString(),
            telephone: f['telephone']?.toString() ?? '',
            email: f['email']?.toString() ?? '',
            adresse: f['adresse']?.toString() ?? '',
            specialite: f['specialite']?.toString() ?? '',
            notes: f['notes']?.toString() ?? '',
          ),
      ]);
    messages
      ..clear()
      ..addAll([
        for (final m in (data['messages'] as List? ?? []))
          Message(
            id: m['id'].toString(),
            expediteurId: m['expediteur_id'].toString(),
            expediteurNom: m['expediteur_nom']?.toString() ?? '',
            destinataireId: m['destinataire_id']?.toString(),
            sujet: m['sujet']?.toString() ?? '',
            contenu: m['contenu']?.toString() ?? '',
            date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
            lu: m['lu'] == true,
          ),
      ]);
    evenements
      ..clear()
      ..addAll([
        for (final e in (data['evenements'] as List? ?? []))
          Evenement(
            id: e['id'].toString(), titre: e['titre'].toString(),
            date: DateTime.tryParse(e['date']?.toString() ?? '') ?? DateTime.now(),
            heure: e['heure']?.toString() ?? '',
            lieu: e['lieu']?.toString() ?? '',
            description: e['description']?.toString() ?? '',
            createurId: e['createur_id']?.toString() ?? '',
          ),
      ]);
    catalogue
      ..clear()
      ..addAll([
        for (final t in (data['catalogue'] as List? ?? []))
          Tarif(
            id: t['id'].toString(), libelle: t['libelle'].toString(),
            categorie: t['categorie']?.toString() ?? 'Général',
            prix: (t['prix'] as num?)?.toDouble() ?? 0,
            description: t['description']?.toString() ?? '',
            actif: t['actif'] != false,
            dateAjout: DateTime.tryParse(
                t['date_ajout']?.toString() ?? ''),
            images: [
              for (final u in (t['images'] as List? ?? const []))
                MediaService.normaliserChemin(u.toString(),
                    entite: 'article',
                    id: t['id'].toString()) ??
                    u.toString(),
            ],
          ),
      ]);
    feedbacks
      ..clear()
      ..addAll([
        for (final f in (data['feedbacks'] as List? ?? []))
          Feedback(
            id: f['id'].toString(), auteurId: f['auteur_id'].toString(),
            auteurNom: f['auteur_nom']?.toString() ?? '',
            boutiqueId: f['boutique_id']?.toString() ?? '',
            type: TypeFeedback.values.byName(f['type']?.toString() ?? 'suggestion'),
            priorite: PrioriteFeedback.values
                .byName(f['priorite']?.toString() ?? 'normale'),
            titre: f['titre']?.toString() ?? '',
            contenu: f['contenu']?.toString() ?? '',
            statut: StatutFeedback.values
                .byName(f['statut']?.toString() ?? 'nouveau'),
            date: DateTime.tryParse(f['date']?.toString() ?? '') ?? DateTime.now(),
          ),
      ]);
    notesPerso
      ..clear()
      ..addAll([
        for (final n in (data['notes'] as List? ?? []))
          Note(
            id: n['id'].toString(), titre: n['titre'].toString(),
            contenu: n['contenu']?.toString() ?? '',
            date: DateTime.tryParse(n['date']?.toString() ?? '') ?? DateTime.now(),
            rappelLe: DateTime.tryParse(n['rappel_le']?.toString() ?? ''),
            createurId: n['createur_id']?.toString() ?? '',
          ),
      ]);
    produits
      ..clear()
      ..addAll([
        for (final p in (data['produits'] as List? ?? []))
          Produit(
            id: p['id'].toString(), boutiqueId: p['boutique_id'].toString(),
            libelle: p['libelle'].toString(), categorie: p['categorie'].toString(),
            prixAchat: (p['prix_achat'] as num?)?.toDouble() ?? 0,
            prixVente: (p['prix_vente'] as num?)?.toDouble() ?? 0,
            stock: (p['stock'] as num?)?.toInt() ?? 0,
            seuil: (p['seuil'] as num?)?.toInt() ?? 3,
            dateAjout: DateTime.tryParse(
                p['date_ajout']?.toString() ?? ''),
            imagePath: MediaService.normaliserChemin(
                p['image_path']?.toString(),
                entite: 'produit',
                id: p['id'].toString()),
            images: [
              for (final u in (p['images'] as List? ?? const []))
                MediaService.normaliserChemin(u.toString(),
                    entite: 'produit',
                    id: p['id'].toString()) ??
                    u.toString(),
            ],
          ),
      ]);
    partenaires
      ..clear()
      ..addAll([
        for (final p in (data['partenaires'] as List? ?? []))
          Partenaire(
            id: p['id'].toString(), nom: p['nom'].toString(),
            telephone: p['telephone']?.toString() ?? '',
            localisation: p['localisation']?.toString() ?? '',
            taux: (p['taux'] as num?)?.toDouble() ?? 0.60,
          ),
      ]);
    transactions
      ..clear()
      ..addAll([
        for (final t in (data['transactions'] as List? ?? []))
          Tx(
            id: t['id'].toString(), boutiqueId: t['boutique_id'].toString(),
            employeId: user.id,
            type: TypeTransaction.values.byName(t['type'].toString()),
            montant: (t['montant'] as num?)?.toDouble() ?? 0,
            cout: (t['cout'] as num?)?.toDouble() ?? 0,
            statut: StatutPaiement.values.byName(t['statut']?.toString() ?? 'paye'),
            clientNom: t['client_nom']?.toString(),
            partenaireId: t['partenaire_id']?.toString(),
            details: Map<String, dynamic>.from(t['details'] as Map? ?? {}),
            date: DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now(),
          ),
      ]);
    depenses
      ..clear()
      ..addAll([
        for (final c in (data['charges'] as List? ?? []))
          Charge(
            id: c['id'].toString(), boutiqueId: c['boutique_id'].toString(),
            categorie: c['categorie'].toString(), libelle: c['libelle'].toString(),
            montant: (c['montant'] as num?)?.toDouble() ?? 0,
            date: DateTime.tryParse(c['date']?.toString() ?? '') ?? DateTime.now(),
            recurrente: c['recurrente'] == true,
          ),
      ]);
    partages
      ..clear()
      ..addAll([
        for (final p in (data['partages'] as List? ?? []))
          Partage.calculer(
            id: _nid(), partenaireId: p['partenaire_id'].toString(),
            mois: p['mois'].toString(),
            totalVentes: (p['total_ventes'] as num?)?.toDouble() ?? 0,
            taux: (p['taux'] as num?)?.toDouble() ?? 0.60,
          ),
      ]);
    achats
      ..clear()
      ..addAll([
        for (final a in (data['achats'] as List? ?? []))
          Achat.fromJson(Map<String, dynamic>.from(a as Map)),
      ]);
    mouvements
      ..clear()
      ..addAll([
        for (final m in (data['mouvements'] as List? ?? []))
          MouvementStock.fromJson(Map<String, dynamic>.from(m as Map)),
      ]);
    ecritures
      ..clear()
      ..addAll([
        for (final e in (data['ecritures'] as List? ?? []))
          Ecriture.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);
    final bt = data['boutique_id_courante']?.toString();
    if (bt != null && boutiques.any((b) => b.id == bt)) {
      _boutiqueId = bt;
    } else if (boutiques.isNotEmpty) {
      _boutiqueId = boutiques.first.id;
    }
  }

  /// Restauration depuis un fichier de sauvegarde JSON (BackupService).
  Future<void> restaurerSauvegarde(Map<String, dynamic> data) async {
    _chargerEtat({
      'version': 1,
      'boutique_id_courante': data['boutique_id_courante'],
      'profil': {
        ...?data['profil'] as Map?,
        'logo_path': null, 'cachet_path': null, 'signature_path': null,
      },
      'utilisateur': {
        'id': user.id, 'nom': user.nom, 'role': user.role.name,
        'boutique_ids': user.boutiqueIds,
      },
      'boutiques': data['boutiques'] ?? const [],
      'produits': data['produits'] ?? const [],
      'partenaires': data['partenaires'] ?? const [],
      'transactions': data['transactions'] ?? const [],
      'charges': data['charges'] ?? const [],
      'partages': data['partages'] ?? const [],
      'achats': data['achats'] ?? const [],
      'mouvements': data['mouvements'] ?? const [],
      'ecritures': data['ecritures'] ?? const [],
    });
  }

  // ---------- Données de démo ----------
  void _seedDemo() {
    boutiques.addAll([
      const Boutique(id: 'bt_siege', nom: 'Siège — Hotspot & Services', adresse: 'Centre-ville', siege: true),
      const Boutique(id: 'bt_marche', nom: 'Boutique Marché', adresse: 'Grand marché'),
    ]);
    users.add(const AppUser(id: 'u_admin', nom: 'Patron', role: Role.admin));
    profile = CompanyProfile(
      nomEntreprise: 'SARL TECH-SERVICES & CO',
      devise: 'FCFA',
      telephone: '+225 07 07 07 07 07',
      email: 'contact@techservices.ci',
      adresse: 'Abidjan, Cocody — Rue des Jardins',
      rccm: 'CI-ABJ-2023-B-12345',
      ifu: 'IFU-123456789A',
      messagePied: 'Merci de votre confiance — Paiement sous 8 jours.',
      fondsRoulement: {'bt_siege': 500000, 'bt_marche': 300000},
      budgetsMensuels: {'Loyer': 150000, 'Salaires': 400000, 'Électricité & Eau': 60000},
    );
    partenaires.addAll([
      const Partenaire(id: 'pt_1', nom: 'Kouassi Jean', telephone: '07 08 09 10 11', localisation: 'Quieré', taux: 0.60),
      const Partenaire(id: 'pt_2', nom: 'Traoré Awa', telephone: '05 06 07 08 09', localisation: 'Gare routière', taux: 0.55),
    ]);
    produits.addAll([
      Produit(id: 'pr_1', boutiqueId: 'bt_siege', libelle: 'Câble RJ45 (305m)', categorie: 'Télécom & Réseau', prixAchat: 18000, prixVente: 25000, stock: 4, seuil: 3, dateAjout: DateTime.now().subtract(const Duration(days: 2))),
      Produit(id: 'pr_2', boutiqueId: 'bt_siege', libelle: 'Disjoncteur 32A', categorie: 'Électricité', prixAchat: 2500, prixVente: 4000, stock: 25, seuil: 5, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_3', boutiqueId: 'bt_siege', libelle: 'Écran 24 pouces', categorie: 'Accessoire PC', prixAchat: 45000, prixVente: 60000, stock: 2, seuil: 2, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_4', boutiqueId: 'bt_siege', libelle: 'Chargeur type-C 25W', categorie: 'Accessoire téléphone', prixAchat: 3000, prixVente: 5500, stock: 40, seuil: 8, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_5', boutiqueId: 'bt_marche', libelle: 'Caméra IP Hikvision', categorie: 'Télécom & Réseau', prixAchat: 22000, prixVente: 32000, stock: 6, seuil: 2, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
    ]);
    depenses.addAll([
      Charge(id: _nid(), boutiqueId: 'bt_siege', categorie: 'Loyer', libelle: 'Loyer local siège', montant: 150000, date: DateTime.now().subtract(const Duration(days: 8))),
      Charge(id: _nid(), boutiqueId: 'bt_siege', categorie: 'Électricité & Eau', libelle: 'Facture CIE', montant: 45000, date: DateTime.now().subtract(const Duration(days: 4))),
      Charge(id: _nid(), boutiqueId: 'bt_siege', categorie: 'Fournisseurs', libelle: 'Achat câbles et connectiques', montant: 75000, date: DateTime.now().subtract(const Duration(days: 2))),
    ]);

    final now = DateTime.now();
    Tx make(TypeTransaction type, double m, double c, String bt,
            {String? client, String? pt, Map<String, dynamic> d = const {}, int jour = 0, int heure = 10}) =>
        Tx(
          id: _nid(), boutiqueId: bt, employeId: user.id, type: type,
          montant: m, cout: c, clientNom: client, partenaireId: pt,
          details: d, date: now.subtract(Duration(days: jour, hours: now.hour - heure)),
        );

    transactions.addAll([
      make(TypeTransaction.prestationService, 25000, 3000, 'bt_siege', client: 'M. Koné', d: {'domaine': 'Vidéosurveillance', 'description': 'Installation 4 caméras'}, jour: 0, heure: 9),
      make(TypeTransaction.mobileMoney, 50000, 0, 'bt_siege', d: {'operateur': 'Orange Money', 'frais': 400, 'operation': 'Dépôt'}, jour: 0, heure: 10),
      make(TypeTransaction.mobileMoney, 30000, 0, 'bt_siege', d: {'operateur': 'Moov Money', 'frais': 250, 'operation': 'Retrait'}, jour: 0, heure: 11),
      make(TypeTransaction.creditCommunication, 2000, 1960, 'bt_siege', d: {'operateur': 'Orange'}, jour: 0, heure: 12),
      make(TypeTransaction.forfaitHotspot, 1000, 0, 'bt_siege', d: {'duree': '1 heure'}, jour: 0, heure: 13),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 jour'}, jour: 0, heure: 14),
      make(TypeTransaction.prestationService, 15000, 2000, 'bt_siege', client: 'Mme Bamba', d: {'domaine': 'Informatique', 'description': 'Formatage + installation'}, jour: 1),
      make(TypeTransaction.forfaitHotspot, 5000, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 semaine'}, jour: 1),
      make(TypeTransaction.forfaitHotspot, 10000, 0, 'bt_siege', pt: 'pt_2', d: {'duree': '1 mois'}, jour: 1),
      make(TypeTransaction.creditCommunication, 5000, 4900, 'bt_siege', d: {'operateur': 'Moov'}, jour: 1),
      make(TypeTransaction.venteMateriel, 64000, 44000, 'bt_marche', client: 'Entreprise Sahel', d: {'lignes': [{'libelle': 'Caméra IP Hikvision', 'quantite': 2}]}, jour: 3),
      make(TypeTransaction.prestationService, 40000, 5000, 'bt_marche', client: 'Pharmacie du Nord', d: {'domaine': 'Électricité', 'description': 'Mise aux normes tableau'}, jour: 5),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_2', d: {'duree': '1 jour'}, jour: 2),
      make(TypeTransaction.mobileMoney, 100000, 0, 'bt_siege', d: {'operateur': 'Telecel Money', 'frais': 800, 'operation': 'Transfert'}, jour: 2),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 jour'}, jour: 4),
      make(TypeTransaction.forfaitHotspot, 1000, 0, 'bt_siege', d: {'duree': '1 heure'}, jour: 4),
    ]);
  }
}
