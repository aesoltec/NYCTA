import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/achat.dart';
import '../models/achat.dart';
import '../models/app_user.dart';
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
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

/// Cœur de l'application : état global + calculs métier.
/// Persistance : l'état complet est sauvegardé localement (Hive) à chaque
/// mutation — les données et les photos survivent aux redémarrages en mode
/// démo. Avec Supabase configuré, la synchro cloud reprend le relais.
class Store extends ChangeNotifier {
  AppUser user;
  Store(this.user) {
    if (CloudRepository.actif) {
      // ===== PRODUCTION : aucune donnée démo — tout vient de Supabase
      // via chargerDuCloud() après authentification. La génération des
      // charges récurrentes se fait à LA FIN de chargerDuCloud() : ici,
      // avant tout chargement, `depenses` est encore vide et l'appel ne
      // ferait donc jamais rien — c'est ce qui rendait la fonctionnalité
      // inopérante en production.
      profile = const CompanyProfile();
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
  }

  /// Identifiant du partenaire lié au compte connecté (rôle partenaire).
  String? monPartenaireId;

  /// Vrai si la connexion Supabase Auth a réussi mais qu'aucune ligne
  /// correspondante n'existe dans public.users (compte non provisionné —
  /// étape 5 du guide de déploiement jamais faite, ou faite pour un autre
  /// email). Dans ce cas, `user` retombe sur un rôle minimal avec le VRAI
  /// uuid Supabase (voir chargerDuCloud) : sans ce garde-fou, l'app gardait
  /// silencieusement l'identité locale factice 'u_admin' (permissions
  /// admin illusoires côté client) alors que le serveur refuse tout —
  /// c'est ce qui produisait les erreurs RLS/UUID invisibles jusqu'ici.
  bool profilCloudManquant = false;

  /// Vrai quand l'app a démarré sur le snapshot local faute de réseau
/// (voir CloudLoader) : bandeau « hors-ligne » dans AppShell + bouton
/// Reconnecter. Les saisies/modifs/suppressions restent possibles :
/// elles partent en file SyncService et sont rejouées au retour réseau.
  bool demarrageHorsLigne = false;

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
      logoPath: p['logo_path']?.toString(),
      cachetPath: p['cachet_path']?.toString(),
      signaturePath: p['signature_path']?.toString(),
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
            imagePath: r['image_path']?.toString(),
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
            adresse: r['adresse']?.toString() ?? '',
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
    return true;
  }

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
  /// Catégories dynamiques (éditables) — initialisées depuis les valeurs
  /// par défaut, remplacées par le cloud si présentes.
  final catsProduit = List<String>.of(C.categoriesProduit);
  final catsCharge = List<String>.of(categoriesCharge);
  /// Listes dynamiques du formulaire "Nouvelle opération" — mêmes règles
  /// que catsProduit/catsCharge : valeurs par défaut locales, remplacées
  /// par le cloud dès qu'au moins une valeur y existe pour ce type.
  final opsMobileMoney = List<String>.of(C.operateurs);
  final opsCredit = List<String>.of(C.operateursCredit);
  final domainesPresta = List<String>.of(C.domaines);
  final dureesForfaitListe = List<String>.of(C.dureesForfait);
  final documentsEmis = <DocumentBati>[];
  final achats = <Achat>[];                // achats fournisseurs (Phase 2)
  CompanyProfile profile = const CompanyProfile();
  int _seq = 0;
  Timer? _persistTimer;
  String _nid() => CloudRepository.actif
      ? CloudRepository.uuid()
      : 'id_${++_seq}_${DateTime.now().millisecondsSinceEpoch}';

  Boutique get boutiqueCourante =>
      boutiques.firstWhere((b) => b.id == _boutiqueId);

  void changerBoutique(String id) {
    // N'accepte que les boutiques auxquelles l'utilisateur a réellement
    // accès (cf. boutiquesAccessibles) — sinon les ventes saisies dans une
    // boutique hors accès s'inséraient (RLS écriture ne vérifie que le
    // rôle) mais devenaient invisibles au rechargement (RLS lecture
    // vérifie l'accès à la boutique), donnant l'impression qu'elles
    // avaient disparu.
    if (!user.accedeA(id)) return;
    _boutiqueId = id;
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

  // ---------- Utilisateurs (gestion) ----------
  Role get role => user.role;
  bool peut(Permission p) => user.peut(p);

  void changerRole(Role r) {
    user = AppUser(id: user.id, nom: user.nom, role: r, boutiqueIds: user.boutiqueIds);
    notifyListeners();
  }

  Future<void> ajouterUtilisateur(AppUser u) async {
    users.add(u);
    notifyListeners();
  }

  Future<void> majUtilisateur(AppUser u) async {
    final i = users.indexWhere((x) => x.id == u.id);
    if (i >= 0) {
      users[i] = u;
      notifyListeners();
      await CloudRepository.majUtilisateur(u);
    }
  }

  /// "Supprimer" = désactivation (l'anon key ne peut pas supprimer un
  /// compte Auth). La désactivation cloud manquait ici : le compte
  /// disparaissait de la liste locale mais restait ACTIF côté Supabase —
  /// l'utilisateur "supprimé" pouvait donc continuer à se connecter
  /// normalement malgré le message "Ce compte n'aura plus accès".
  Future<void> supprimerUtilisateur(String id) async {
    final u = users.where((x) => x.id == id).firstOrNull;
    if (u == null || u.role == Role.admin) return;
    users.removeWhere((x) => x.id == id);
    notifyListeners();
    await CloudRepository.desactiverUtilisateur(id);
  }

  // ---------- Catégories (dynamiques) ----------
  /// Ajoute une catégorie ; retourne une erreur ou null si OK.
  Future<String?> ajouterCategorie(String nom, {required bool produit}) async {
    final n = nom.trim();
    if (n.length < 2) return 'Nom trop court (2 caractères min.)';
    final liste = produit ? catsProduit : catsCharge;
    if (liste.any((c) => c.toLowerCase() == n.toLowerCase())) {
      return 'Cette catégorie existe déjà';
    }
    liste.add(n);
    notifyListeners();
    await CloudRepository.upsertCategorie(produit ? 'produit' : 'charge', n);
    return null;
  }

  Future<String?> renommerCategorie(String ancien, String nouveau,
      {required bool produit}) async {
    final liste = produit ? catsProduit : catsCharge;
    final n = nouveau.trim();
    if (n.length < 2) return 'Nom trop court';
    if (liste.any((c) => c != ancien && c.toLowerCase() == n.toLowerCase())) {
      return 'Cette catégorie existe déjà';
    }
    final i = liste.indexOf(ancien);
    if (i < 0) return 'Catégorie introuvable';
    liste[i] = n;
    // Renommage en cascade sur les fiches existantes.
    if (produit) {
      for (var j = 0; j < produits.length; j++) {
        if (produits[j].categorie == ancien) {
          final p = produits[j];
          produits[j] = Produit(
            id: p.id, boutiqueId: p.boutiqueId, libelle: p.libelle,
            categorie: n, prixAchat: p.prixAchat, prixVente: p.prixVente,
            stock: p.stock, seuil: p.seuil, imagePath: p.imagePath,
          );
        }
      }
    } else {
      for (var j = 0; j < depenses.length; j++) {
        if (depenses[j].categorie == ancien) {
          final c = depenses[j];
          depenses[j] = Charge(
            id: c.id, boutiqueId: c.boutiqueId, categorie: n,
            libelle: c.libelle, montant: c.montant, date: c.date,
            recurrente: c.recurrente,
          );
        }
      }
    }
    notifyListeners();
    await CloudRepository.upsertCategorie(produit ? 'produit' : 'charge', n);
    await CloudRepository.supprimerCategorie(
        produit ? 'produit' : 'charge', ancien);
    return null;
  }

  /// Suppression avec garde-fou : catégorie en cours d'utilisation.
  Future<String?> supprimerCategorie(String nom,
      {required bool produit}) async {
    final utilisee = produit
        ? produits.any((p) => p.categorie == nom)
        : depenses.any((c) => c.categorie == nom);
    if (utilisee) {
      return 'Catégorie utilisée par des fiches existantes — renommez-la '
          'pour préserver l\'historique.';
    }
    (produit ? catsProduit : catsCharge).remove(nom);
    notifyListeners();
    await CloudRepository.supprimerCategorie(
        produit ? 'produit' : 'charge', nom);
    return null;
  }

  // ---------- Listes dynamiques : opérateurs, domaines, durées ----------
  /// Types valides : 'operateur_momo', 'operateur_credit',
  /// 'domaine_prestation', 'duree_forfait'. Réutilise la table `categories`
  /// (même mécanisme que catsProduit/catsCharge ci-dessus).
  List<String> _listeDynamique(String type) => switch (type) {
        'operateur_momo' => opsMobileMoney,
        'operateur_credit' => opsCredit,
        'domaine_prestation' => domainesPresta,
        'duree_forfait' => dureesForfaitListe,
        _ => throw ArgumentError('Type de liste inconnu : $type'),
      };

  Future<String?> ajouterValeurListe(String type, String nom) async {
    final n = nom.trim();
    if (n.isEmpty) return 'Valeur requise';
    final liste = _listeDynamique(type);
    if (liste.any((v) => v.toLowerCase() == n.toLowerCase())) {
      return 'Cette valeur existe déjà';
    }
    liste.add(n);
    notifyListeners();
    await CloudRepository.upsertCategorie(type, n);
    return null;
  }

  Future<String?> renommerValeurListe(
      String type, String ancien, String nouveau) async {
    final liste = _listeDynamique(type);
    final n = nouveau.trim();
    if (n.isEmpty) return 'Valeur requise';
    if (liste.any((v) => v != ancien && v.toLowerCase() == n.toLowerCase())) {
      return 'Cette valeur existe déjà';
    }
    final i = liste.indexOf(ancien);
    if (i < 0) return 'Valeur introuvable';
    liste[i] = n;
    notifyListeners();
    await CloudRepository.upsertCategorie(type, n);
    await CloudRepository.supprimerCategorie(type, ancien);
    return null;
  }

  Future<String?> supprimerValeurListe(String type, String nom) async {
    _listeDynamique(type).remove(nom);
    notifyListeners();
    await CloudRepository.supprimerCategorie(type, nom);
    return null;
  }

  // ---------- Clients ----------
  List<Client> get clientsBoutique =>
      clients.where((c) => c.boutiqueId == _boutiqueId).toList();

  Future<String?> ajouterClient(Client c) async {
    if (c.nom.trim().length < 2) return 'Nom trop court';
    if (clients.any((x) =>
        x.boutiqueId == c.boutiqueId &&
        x.nom.toLowerCase() == c.nom.trim().toLowerCase())) {
      return 'Ce client existe déjà dans cette boutique';
    }
    // Id régénéré en uuid v4 : la colonne Postgres est de type uuid, un id
    // local (ex. horodatage) ferait échouer silencieusement l'écriture cloud
    // (voir _nid()) — le client semblerait ajouté puis disparaîtrait au
    // prochain chargement depuis Supabase.
    final client = Client(
      id: _nid(), boutiqueId: c.boutiqueId, nom: c.nom,
      telephone: c.telephone, adresse: c.adresse,
    );
    clients.add(client);
    notifyListeners();
    await CloudRepository.upsertClient(client);
    return null;
  }

  Future<void> majClient(Client c) async {
    final i = clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      clients[i] = c;
      notifyListeners();
      await CloudRepository.upsertClient(c);
    }
  }

  // ---------- Fournisseurs ----------
  Future<String?> ajouterFournisseur(Fournisseur f) async {
    if (f.nom.trim().length < 2) return 'Nom trop court';
    if (fournisseurs.any((x) => x.nom.toLowerCase() == f.nom.trim().toLowerCase())) {
      return 'Ce fournisseur existe déjà';
    }
    final fournisseur = Fournisseur(
      id: _nid(), nom: f.nom, telephone: f.telephone, email: f.email,
      adresse: f.adresse, specialite: f.specialite, notes: f.notes,
    );
    fournisseurs.add(fournisseur);
    notifyListeners();
    await CloudRepository.upsertFournisseur(fournisseur);
    return null;
  }

  Future<void> majFournisseur(Fournisseur f) async {
    final i = fournisseurs.indexWhere((x) => x.id == f.id);
    if (i >= 0) {
      fournisseurs[i] = f;
      notifyListeners();
      await CloudRepository.upsertFournisseur(f);
    }
  }

  Future<void> supprimerFournisseur(String id) async {
    fournisseurs.removeWhere((f) => f.id == id);
    notifyListeners();
    await CloudRepository.supprimerFournisseur(id);
  }

  // ---------- Messagerie ----------
  /// Messages visibles par l'utilisateur connecté (reçus + envoyés).
  List<Message> get messagesVisibles => messages
      .where((m) => m.mEstDestineA(user.id) || m.expediteurId == user.id)
      .toList();

  int get messagesNonLus => messages
      .where((m) => !m.lu && m.mEstDestineA(user.id) && m.expediteurId != user.id)
      .length;

  Future<void> envoyerMessage({
    required String sujet,
    required String contenu,
    String? destinataireId, // null = tous
  }) async {
    final m = Message(
      id: _nid(),
      expediteurId: user.id,
      expediteurNom: user.nom,
      destinataireId: destinataireId,
      sujet: sujet.trim(),
      contenu: contenu.trim(),
      date: DateTime.now(),
    );
    messages.insert(0, m);
    notifyListeners();
    await CloudRepository.envoyerMessage(m);
  }

  Future<void> marquerMessageLu(String id) async {
    final i = messages.indexWhere((m) => m.id == id);
    if (i >= 0 && !messages[i].lu) {
      messages[i] = messages[i].copyWith(lu: true);
      notifyListeners();
      await CloudRepository.marquerMessageLu(id);
    }
  }

  Future<void> marquerTousMessagesLus() async {
    for (var i = 0; i < messages.length; i++) {
      if (!messages[i].lu && messages[i].mEstDestineA(user.id)) {
        messages[i] = messages[i].copyWith(lu: true);
      }
    }
    notifyListeners();
    await CloudRepository.marquerTousMessagesLus();
  }

  /// Correction d'un message (auteur ou admin/gérant — l'écran masque
  /// le bouton aux autres, en miroir des policies RLS).
  Future<String?> majMessage(Message maj) async {
    final i = messages.indexWhere((m) => m.id == maj.id);
    if (i < 0) return 'Message introuvable';
    if (maj.sujet.trim().length < 3) return 'Sujet trop court';
    if (maj.contenu.trim().length < 3) return 'Message trop court';
    messages[i] = maj;
    notifyListeners();
    await CloudRepository.majMessage(maj);
    await _fileUpsert('messages', {
      'id': maj.id, 'expediteur_id': maj.expediteurId,
      'expediteur_nom': maj.expediteurNom,
      'destinataire_id': maj.destinataireId,
      'sujet': maj.sujet, 'contenu': maj.contenu,
    });
    return null;
  }

  /// Suppression d'un message (auteur ou admin/gérant).
  Future<void> supprimerMessage(String id) async {
    messages.removeWhere((m) => m.id == id);
    notifyListeners();
    await CloudRepository.supprimerMessage(id);
    if (CloudRepository.actif) {
      await SyncService().mettreEnFile({'id': id}, table: 'messages__delete');
    }
  }

  // ---------- Événements ----------
  List<Evenement> get evenementsAVenir {
    final l = evenements.where((e) => !e.estPasse).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  Future<void> ajouterEvenement(Evenement e) async {
    final evenement = Evenement(
      id: _nid(), titre: e.titre, date: e.date, heure: e.heure,
      lieu: e.lieu, description: e.description, createurId: e.createurId,
    );
    evenements.add(evenement);
    notifyListeners();
    await CloudRepository.upsertEvenement(evenement);
  }

  Future<void> majEvenement(Evenement e) async {
    final i = evenements.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      evenements[i] = e;
      notifyListeners();
      await CloudRepository.upsertEvenement(e);
    }
  }

  Future<void> supprimerEvenement(String id) async {
    evenements.removeWhere((e) => e.id == id);
    notifyListeners();
    await CloudRepository.supprimerEvenement(id);
  }

  // ---------- Notes ----------
  Future<void> ajouterNote(Note n) async {
    final note = Note(
      id: _nid(), titre: n.titre, contenu: n.contenu, date: n.date,
      rappelLe: n.rappelLe, createurId: n.createurId,
    );
    notesPerso.add(note);
    notifyListeners();
    await CloudRepository.upsertNote(note);
  }

  Future<void> majNote(Note n) async {
    final i = notesPerso.indexWhere((x) => x.id == n.id);
    if (i >= 0) {
      notesPerso[i] = n;
      notifyListeners();
      await CloudRepository.upsertNote(n);
    }
  }

  Future<void> supprimerNote(String id) async {
    notesPerso.removeWhere((n) => n.id == id);
    notifyListeners();
    await CloudRepository.supprimerNote(id);
  }

  // ---------- Tarifs & catalogue ----------
  List<Tarif> get tarifsActifs => catalogue.where((t) => t.actif).toList();

  Future<String?> ajouterTarif(Tarif t) async {
    final e = V.texte(t.libelle, 2, 'Libellé');
    if (e != null) return e;
    if (t.prix <= 0) return 'Le prix doit être > 0';
    if (catalogue.any((x) =>
        x.actif && x.libelle.toLowerCase() == t.libelle.trim().toLowerCase())) {
      return 'Un article du même nom existe déjà';
    }
    final tarif = Tarif(
      id: _nid(), libelle: t.libelle, categorie: t.categorie,
      prix: t.prix, description: t.description, actif: t.actif,
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
    catalogue[i] = t;
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

  // ---------- Suggestions & signalements ----------
  int get nouveauxFeedbacks => feedbacks
      .where((f) => f.statut == StatutFeedback.nouveau)
      .length;

  Future<String?> ajouterFeedback(Feedback f) async {
    if (f.titre.trim().length < 3) return 'Titre trop court';
    if (f.contenu.trim().length < 5) return 'Description trop courte';
    final feedback = Feedback(
      id: _nid(), auteurId: f.auteurId, auteurNom: f.auteurNom,
      boutiqueId: f.boutiqueId, type: f.type, priorite: f.priorite,
      titre: f.titre, contenu: f.contenu, statut: f.statut, date: f.date,
    );
    feedbacks.insert(0, feedback);
    notifyListeners();
    await CloudRepository.ajouterFeedback(feedback);
    return null;
  }

  Future<void> changerStatutFeedback(String id, StatutFeedback statut) async {
    final i = feedbacks.indexWhere((f) => f.id == id);
    if (i >= 0) {
      feedbacks[i] = feedbacks[i].copyWith(statut: statut);
      notifyListeners();
      await CloudRepository.majStatutFeedback(id, statut);
    }
  }

  /// Correction d'une contribution (auteur ou admin/gérant — l'écran
  /// masque le bouton aux autres, en miroir des policies RLS).
  Future<String?> majFeedback(Feedback maj) async {
    final i = feedbacks.indexWhere((f) => f.id == maj.id);
    if (i < 0) return 'Contribution introuvable';
    if (maj.titre.trim().length < 3) return 'Titre trop court';
    if (maj.contenu.trim().length < 5) return 'Description trop courte';
    feedbacks[i] = maj;
    notifyListeners();
    await CloudRepository.majFeedback(maj);
    await _fileUpsert('feedbacks', {
      'id': maj.id, 'type': maj.type.name, 'priorite': maj.priorite.name,
      'titre': maj.titre, 'contenu': maj.contenu, 'statut': maj.statut.name,
    });
    return null;
  }

  /// Suppression d'une contribution (auteur ou admin/gérant).
  Future<void> supprimerFeedback(String id) async {
    feedbacks.removeWhere((f) => f.id == id);
    notifyListeners();
    await CloudRepository.supprimerFeedback(id);
    if (CloudRepository.actif) {
      await SyncService()
          .mettreEnFile({'id': id}, table: 'feedbacks__delete');
    }
  }

  // ---------- Boutiques ----------
  List<Boutique> get boutiquesActives =>
      boutiques.where((b) => b.actif).toList();

  /// Boutiques actives que l'utilisateur courant peut effectivement choisir.
  /// Le sélecteur de boutique (barre du haut) proposait TOUTES les
  /// boutiques à tout le monde, sans vérifier l'accès (user_boutiques) —
  /// un non-admin pouvait ainsi basculer sur une boutique où il n'a pas de
  /// ligne user_boutiques, y saisir des ventes (l'écriture n'est bloquée
  /// que par rôle, pas par boutique), puis ne plus jamais les revoir : la
  /// policy RLS "transactions select" (accede_boutique()) les lui cachait
  /// silencieusement au rechargement suivant — elles semblaient disparaître.
  List<Boutique> get boutiquesAccessibles =>
      boutiquesActives.where((b) => user.accedeA(b.id)).toList();

  /// Crée une boutique et donne accès aux utilisateurs choisis.
  Future<String?> ajouterBoutique(Boutique b, List<String> userIds) async {
    if (b.nom.trim().length < 2) return 'Nom trop court';
    if (boutiques.any((x) =>
        x.actif && x.nom.toLowerCase() == b.nom.trim().toLowerCase())) {
      return 'Une boutique porte déjà ce nom';
    }
    if (b.siege) {
      // Un seul siège : on démet les autres.
      for (var i = 0; i < boutiques.length; i++) {
        if (boutiques[i].siege) boutiques[i] = boutiques[i].copyWith(siege: false);
      }
    }
    final boutique = Boutique(
      id: _nid(), nom: b.nom, adresse: b.adresse,
      siege: b.siege, actif: b.actif,
    );
    boutiques.add(boutique);
    notifyListeners();
    await CloudRepository.upsertBoutique(boutique, userIds);
    return null;
  }

  Future<String?> majBoutique(Boutique b, List<String> userIds) async {
    final i = boutiques.indexWhere((x) => x.id == b.id);
    if (i < 0) return 'Boutique introuvable';
    if (b.siege) {
      for (var j = 0; j < boutiques.length; j++) {
        if (boutiques[j].siege && boutiques[j].id != b.id) {
          boutiques[j] = boutiques[j].copyWith(siege: false);
        }
      }
    }
    boutiques[i] = b;
    notifyListeners();
    await CloudRepository.upsertBoutique(b, userIds);
    return null;
  }

  /// Désactivation (jamais de suppression dure : l'historique financier
  /// y est rattaché). La dernière boutique active est protégée.
  Future<String?> fermerBoutique(String id) async {
    if (boutiquesActives.length <= 1) {
      return 'Impossible : il doit rester au moins une boutique active.';
    }
    if (id == _boutiqueId) {
      return 'Changez d\'abord de boutique courante (menu en haut).';
    }
    final i = boutiques.indexWhere((x) => x.id == id);
    if (i < 0) return 'Boutique introuvable';
    boutiques[i] = boutiques[i].copyWith(actif: false, siege: false);
    notifyListeners();
    await CloudRepository.desactiverBoutique(id);
    return null;
  }

  // ---------- Configuration entreprise ----------
  Future<void> updateProfile(CompanyProfile p) async {
    profile = p;
    notifyListeners();
    await CloudRepository.updateProfile(p);
  }

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
    // Date de l'opération choisie dans le formulaire (saisie d'hier,
    // d'avant-hier…) — par défaut l'instant présent. C'est elle qui
    // alimente journal, rapports et synchro (date_transaction).
    DateTime? date,
  }) async {
    final tx = Tx(
      id: _nid(),
      boutiqueId: _boutiqueId,
      employeId: user.id,
      type: type,
      montant: montant,
      cout: cout,
      clientNom: clientNom,
      partenaireId: partenaireId,
      details: details,
      date: date ?? DateTime.now(),
    );
    transactions.insert(0, tx);
    notifyListeners();
    // L'id local (uuid en production) est envoyé tel quel : création et
    // correction partagent le même identifiant, ce qui rend l'upsert
    // idempotent (pas de doublon si la file rejoue l'opération).
    await CloudRepository.upsertTransaction(tx);
    if (SupabaseService.client != null) {
      await SyncService().mettreEnFile(_payloadTx(tx));
    }
    return tx.id;
  }

  /// Modification d'une vente existante (journal → Modifier).
  /// Retourne null si OK, sinon un message d'erreur.
  /// Vente matériel : seules client/date/montant/coût sont modifiables
  /// (les lignes + quantités restent gérées par l'écran Stock pour garder
  /// le stock cohérent) — l'écran d'édition applique déjà cette règle.
  Future<String?> majTransaction(Tx maj) async {
    final i = transactions.indexWhere((t) => t.id == maj.id);
    if (i < 0) return 'Vente introuvable';
    if (maj.montant <= 0) return 'Le montant doit être > 0';
    if (maj.cout < 0) return 'Le coût ne peut pas être négatif';
    transactions[i] = maj;
    notifyListeners();
    await CloudRepository.upsertTransaction(maj);
    await _fileUpsert('transactions', _payloadTx(maj));
    return null;
  }

  /// Suppression définitive d'une vente (journal → Supprimer).
  /// Vente matériel : le stock des produits liés est restauré
  /// (quantités remises en rayon) avant suppression.
  Future<void> supprimerTransaction(String id) async {
    final i = transactions.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final tx = transactions[i];
    if (tx.type == TypeTransaction.venteMateriel) {
      final lignes = (tx.details['lignes'] as List?) ?? const [];
      for (final l in lignes) {
        if (l is! Map) continue;
        final pid = l['produitId']?.toString();
        final qte = (l['quantite'] as num?)?.toInt() ?? 0;
        if (pid == null || qte <= 0) continue;
        final pi = produits.indexWhere((p) => p.id == pid);
        if (pi >= 0) {
          final restaure = produits[pi].copyWith(
              stock: produits[pi].stock + qte);
          produits[pi] = restaure;
          await CloudRepository.upsertProduit(restaure);
          await _fileUpsert('produits', _payloadProduit(restaure));
        }
      }
    }
    transactions.removeAt(i);
    notifyListeners();
    await CloudRepository.supprimerTransaction(id);
    if (CloudRepository.actif) {
      await SyncService()
          .mettreEnFile({'id': id}, table: 'transactions__delete');
    }
  }

  // ---------- Tableau de bord ----------
  bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Tx> get txBoutique =>
      transactions.where((t) => t.boutiqueId == _boutiqueId).toList();

  List<Tx> get txJour => txBoutique.where((t) => _memeJour(t.date, DateTime.now())).toList();

  double get caJour => txJour.fold(0.0, (s, t) => s + t.montant);
  double get margeJour => txJour.fold(0.0, (s, t) => s + t.marge);

  String get moisCourant => C.moisKey(DateTime.now());
  List<Tx> get txMois =>
      txBoutique.where((t) => C.moisKey(t.date) == moisCourant).toList();
  double get caMois => txMois.fold(0.0, (s, t) => s + t.montant);
  double get margeMois => txMois.fold(0.0, (s, t) => s + t.marge);

  Map<TypeTransaction, double> get caParType {
    final map = <TypeTransaction, double>{};
    for (final t in txMois) {
      map[t.type] = (map[t.type] ?? 0) + t.montant;
    }
    return map;
  }

  Map<String, double> get caParJour {
    final map = <String, double>{};
    final maintenant = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final jour = maintenant.subtract(Duration(days: i));
      map['${jour.day.toString().padLeft(2, '0')}/${jour.month.toString().padLeft(2, '0')}'] = 0;
    }
    for (final t in txBoutique) {
      final cle = '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}';
      if (map.containsKey(cle)) map[cle] = map[cle]! + t.montant;
    }
    return map;
  }

  Map<String, double> get fraisMoMoMois {
    final map = <String, double>{};
    for (final t in txMois.where((t) => t.type == TypeTransaction.mobileMoney)) {
      final op = (t.details['operateur'] ?? 'Autre').toString();
      final frais = (t.details['frais'] as num?)?.toDouble() ?? 0;
      map[op] = (map[op] ?? 0) + frais;
    }
    return map;
  }

  // ---------- Charges ----------
  Future<void> ajouterCharge(Charge c) async {
    final charge = Charge(
      id: _nid(), boutiqueId: c.boutiqueId, categorie: c.categorie,
      libelle: c.libelle, montant: c.montant, date: c.date,
      recurrente: c.recurrente,
    );
    depenses.insert(0, charge);
    notifyListeners();
    await CloudRepository.upsertCharge(charge);
    await _fileUpsert('charges', {
      'id': charge.id, 'boutique_id': charge.boutiqueId,
      'categorie': charge.categorie, 'libelle': charge.libelle,
      'montant': charge.montant,
      'date_charge': charge.date.toIso8601String(),
      'recurrente': charge.recurrente,
    });
  }

  List<Charge> get depensesBoutique =>
      depenses.where((c) => c.boutiqueId == _boutiqueId).toList();

  /// Modification d'une dépense existante (écran Charges → Modifier).
  Future<String?> majCharge(Charge maj) async {
    final i = depenses.indexWhere((c) => c.id == maj.id);
    if (i < 0) return 'Dépense introuvable';
    if (maj.libelle.trim().isEmpty) return 'Libellé requis';
    if (maj.montant <= 0) return 'Le montant doit être > 0';
    depenses[i] = maj;
    notifyListeners();
    await CloudRepository.upsertCharge(maj);
    await _fileUpsert('charges', {
      'id': maj.id, 'boutique_id': maj.boutiqueId,
      'categorie': maj.categorie, 'libelle': maj.libelle,
      'montant': maj.montant,
      'date_charge': maj.date.toIso8601String(),
      'recurrente': maj.recurrente,
    });
    return null;
  }

  /// Suppression définitive d'une dépense (écran Charges → Supprimer).
  Future<void> supprimerCharge(String id) async {
    depenses.removeWhere((c) => c.id == id);
    notifyListeners();
    await CloudRepository.supprimerCharge(id);
    if (CloudRepository.actif) {
      await SyncService().mettreEnFile({'id': id}, table: 'charges__delete');
    }
  }

  List<Charge> get depensesMois =>
      depensesBoutique.where((c) => C.moisKey(c.date) == moisCourant).toList();

  double get totalDepensesMois => depensesMois.fold(0.0, (s, c) => s + c.montant);

  double depensesCategorieMois(String categorie) => depensesMois
      .where((c) => c.categorie == categorie)
      .fold(0.0, (s, c) => s + c.montant);

  Map<String, (double, double)> get suiviBudgets {
    final map = <String, (double, double)>{};
    for (final entry in profile.budgetsMensuels.entries) {
      if (entry.value > 0) {
        map[entry.key] = (entry.value, depensesCategorieMois(entry.key));
      }
    }
    return map;
  }

  /// Charges récurrentes : recopie à chaque nouveau mois (anti-double).
  Future<void> genererChargesRecurrentesSiNouveauMois() async {
    final mois = moisCourant;
    if (profile.moisChargesGenerees == mois) return;
    // Un "modèle" = (boutique, catégorie, libellé) récurrent : on ne garde
    // que sa plus récente occurrence. Boucler sur CHAQUE ligne récurrente
    // passée aurait dupliqué de façon exponentielle d'un mois sur l'autre
    // (chaque copie générée est elle-même recurrente:true, donc reprise au
    // mois suivant en plus de l'originale).
    final parModele = <String, Charge>{};
    for (final c in depenses.where((c) => c.recurrente)) {
      final cle = '${c.boutiqueId}|${c.categorie}|${c.libelle}';
      final actuel = parModele[cle];
      if (actuel == null || c.date.isAfter(actuel.date)) parModele[cle] = c;
    }
    for (final c in parModele.values) {
      if (C.moisKey(c.date) == mois) continue;
      final charge = Charge(
        id: _nid(), boutiqueId: c.boutiqueId, categorie: c.categorie,
        libelle: c.libelle, montant: c.montant,
        date: DateTime.now(), recurrente: true,
      );
      depenses.insert(0, charge);
      await CloudRepository.upsertCharge(charge);
    }
    profile = profile.copyWith(moisChargesGenerees: mois);
    notifyListeners();
    await CloudRepository.majMoisChargesGenerees(mois);
  }

  // ---------- Trésorerie ----------
  double get fondsRoulementCourant => profile.fondsRoulement[_boutiqueId] ?? 0;

  Future<void> definirFondsRoulement(String boutiqueId, double montant) =>
      updateProfile(profile.copyWith(
        fondsRoulement: {...profile.fondsRoulement, boutiqueId: montant},
      ));

  double soldeCaisse(String boutiqueId) {
    final ca = transactions
        .where((t) => t.boutiqueId == boutiqueId && t.statut == StatutPaiement.paye)
        .fold(0.0, (s, t) => s + t.montant);
    final dep = depenses.where((c) => c.boutiqueId == boutiqueId)
        .fold(0.0, (s, c) => s + c.montant);
    return (profile.fondsRoulement[boutiqueId] ?? 0) + ca - dep;
  }

  double get soldeCaisseCourant => soldeCaisse(_boutiqueId);

  // ---------- Documents ----------
  /// [date] = date d'émission réelle (formulaire) : affichée sur le
  /// document, conservée dans l'historique local ET dans la base cloud
  /// (date_doc) pour que le rechargement ne la remette pas à aujourd'hui.
  Future<void> enregistrerDocument(DocumentBati d, {DateTime? date}) async {
    documentsEmis.insert(0, d);
    notifyListeners();
    // Copie cloud fidèle (en-tête + lignes) — ré-exploitable à volonté.
    if (CloudRepository.actif) {
      await CloudRepository.enregistrerDocument(d, _boutiqueId, date: date);
    }
  }

  Future<DocumentBati> transformerDevisEnFacture(DocumentBati devis) async {
    final facture = DocumentBati(
      type: TypeDocument.facture,
      numero: await numeroDocument('FACT'),
      date: devis.date, client: devis.client, lignes: devis.lignes,
      totalHT: devis.totalHT, tva: devis.tva,
      totalTTC: devis.totalTTC, devise: devis.devise,
    );
    documentsEmis.insert(0, facture);
    notifyListeners();
    // La facture issue du devis est une vente ferme : sortie de stock.
    await deduireStockPourLignes(facture.lignes);
    // La facture garde la date du devis (y compris après rechargement).
    if (CloudRepository.actif) {
      await CloudRepository.enregistrerDocument(
          facture, _boutiqueId,
          date: DocumentService.parseAffichage(devis.date));
    }
    return facture;
  }

  /// Numéro de document. En production, délègue à la RPC atomique
  /// `prochain_numero` (SECURITY DEFINER côté Supabase) : un compteur
  /// purement local remis à zéro à chaque redémarrage de l'app aurait généré
  /// des doublons de numéro de facture entre deux sessions ou deux appareils.
  /// Le compteur local (CompanyProfile.prochainNumero) ne sert qu'en mode
  /// démo/hors-ligne, ou en repli si le réseau est indisponible.
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
  List<Produit> get produitsBoutique =>
      produits.where((p) => p.boutiqueId == _boutiqueId).toList();

  List<Produit> get alertesStock => produitsBoutique.where((p) => p.alerte).toList();

  /// Mise en file offline-first générique : toute écriture directe
  /// (produit, partenaire, charge, tarif…) est rejouée vers Supabase au
  /// retour du réseau. Sans cela, seul ajouterTransaction() survivait au
  /// hors-ligne — les autres écritures passaient par _silencieux et
  /// étaient réellement perdues si l'appareil était hors-ligne.
  Future<void> _fileUpsert(String table, Map<String, dynamic> payload) async {
    if (!CloudRepository.actif) return;
    await SyncService().mettreEnFile(payload, table: table);
  }

  bool _memeLibelle(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Ajout produit : retourne un message d'erreur si doublon (même libellé
  /// dans la même boutique), null si OK. L'appelant n'ajoute RIEN tant que
  /// l'erreur est non-nulle — c'est ce qui empêchait les doublons lors des
  /// corrections (l'écran re-soumettait après le dialogue marge négative).
  Future<String?> ajouterProduit(Produit p) async {
    if (p.libelle.trim().length < 2) return 'Libellé requis (2 car. min.)';
    if (produits.any((x) =>
        x.boutiqueId == p.boutiqueId && _memeLibelle(x.libelle, p.libelle))) {
      return '« ${p.libelle.trim()} » existe déjà dans cette boutique — modifiez sa fiche au lieu de le recréer';
    }
    // Id régénéré en uuid v4 : la colonne Postgres est de type uuid ; un id
    // fourni par l'écran (ex. horodatage) ferait échouer silencieusement
    // l'upsert cloud (_silencieux avale l'erreur) — le produit semblerait
    // ajouté puis disparaîtrait au prochain chargement depuis Supabase.
    final produit = Produit(
      id: _nid(), boutiqueId: p.boutiqueId, libelle: p.libelle.trim(),
      categorie: p.categorie, prixAchat: p.prixAchat, prixVente: p.prixVente,
      stock: p.stock, seuil: p.seuil, imagePath: p.imagePath,
    );
    produits.add(produit);
    notifyListeners();
    await CloudRepository.upsertProduit(produit);
    await _fileUpsert('produits', _payloadProduit(produit));
    await _syncCatalogueDepuisProduit(produit);
    return null;
  }

  Map<String, dynamic> _payloadProduit(Produit p) => {
        'id': p.id, 'boutique_id': p.boutiqueId, 'libelle': p.libelle,
        'categorie': p.categorie, 'prix_achat': p.prixAchat,
        'prix_vente': p.prixVente, 'quantite_stock': p.stock,
        'seuil_alerte': p.seuil, 'actif': true,
      };

  /// Modification complète d'un produit (tap sur la fiche stock).
  /// Retourne une erreur si le nouveau libellé collide avec un AUTRE produit.
  Future<String?> majProduit(Produit p) async {
    final i = produits.indexWhere((x) => x.id == p.id);
    if (i < 0) return 'Produit introuvable';
    if (produits.any((x) =>
        x.id != p.id &&
        x.boutiqueId == p.boutiqueId &&
        _memeLibelle(x.libelle, p.libelle))) {
      return 'Un autre produit porte déjà ce nom dans cette boutique';
    }
    produits[i] = p;
    notifyListeners();
    await CloudRepository.upsertProduit(p);
    await _fileUpsert('produits', _payloadProduit(p));
    await _syncCatalogueDepuisProduit(p);
    return null;
  }

  Future<void> archiverProduit(String id) async {
    final i = produits.indexWhere((x) => x.id == id);
    if (i >= 0) {
      produits.removeAt(i);
      notifyListeners();
      await CloudRepository.archiverProduit(id);
      await _fileUpsert(
          'produits', {'id': id, 'actif': false});
    }
  }

  /// Suppression définitive avec garde-fou : si des transactions existantes
  /// référencent le produit (détail produitId), la suppression est refusée
  /// et l'archivage conseillé (l'historique financier reste cohérent).
  /// Retourne null si supprimé/archivé, sinon le motif du refus.
  Future<String?> supprimerProduit(String id, {bool forcerArchive = false}) async {
    final i = produits.indexWhere((x) => x.id == id);
    if (i < 0) return 'Produit introuvable';
    final lie = transactions.any((t) {
      final lignes = (t.details['lignes'] as List?) ?? const [];
      return lignes.any((l) =>
          l is Map && l['produitId']?.toString() == id);
    });
    if (lie && !forcerArchive) {
      return 'Ce produit a déjà été vendu — archivez-le plutôt pour garder un historique cohérent';
    }
    await archiverProduit(id);
    return null;
  }

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
    );
    catalogue.add(t);
    notifyListeners();
    await CloudRepository.upsertTarif(t);
    await _fileUpsert('tarifs', _payloadTarif(t));
  }

  Map<String, dynamic> _payloadTarif(Tarif t) => {
        'id': t.id, 'libelle': t.libelle, 'categorie': t.categorie,
        'prix': t.prix, 'description': t.description, 'actif': t.actif,
      };

  /// Décrémente le stock pour chaque ligne dont le libellé correspond à un
  /// produit de la boutique courante (facture, ticket, bordereau validé).
  /// Les lignes sans correspondance sont ignorées (service, article libre).
  /// Retourne la liste des libellés ignorés faute de stock suffisant.
  Future<List<String>> deduireStockPourLignes(List<LigneDoc> lignes) async {
    final ignores = <String>[];
    for (final l in lignes) {
      final i = produits.indexWhere((p) =>
          p.boutiqueId == _boutiqueId && _memeLibelle(p.libelle, l.libelle));
      if (i < 0) continue;
      final p = produits[i];
      if (p.stock < l.quantite) {
        ignores.add('${l.libelle} (stock ${p.stock})');
        continue;
      }
      final maj = p.copyWith(stock: p.stock - l.quantite);
      produits[i] = maj;
      await CloudRepository.upsertProduit(maj);
      await _fileUpsert('produits', _payloadProduit(maj));
    }
    if (ignores.isEmpty) {
      // notifyListeners déjà déclenché par les upserts ? non : on le fait.
    }
    notifyListeners();
    return ignores;
  }

  Future<void> vendreProduit(Produit p, int quantite,
      {String? clientNom, DateTime? date}) async {
    if (quantite > p.stock) throw StateError('Stock insuffisant');
    final idx = produits.indexWhere((x) => x.id == p.id);
    if (idx < 0) throw StateError('Produit introuvable');
    final produit = p.copyWith(stock: p.stock - quantite);
    produits[idx] = produit;
    notifyListeners();
    // Sans cet upsert, seule la transaction de vente était synchronisée :
    // le stock décrémenté restait local et revenait à son ancienne valeur
    // au prochain chargement depuis Supabase.
    await CloudRepository.upsertProduit(produit);
    await _fileUpsert('produits', _payloadProduit(produit));
    await ajouterTransaction(
      type: TypeTransaction.venteMateriel,
      montant: p.prixVente * quantite,
      cout: p.prixAchat * quantite,
      clientNom: clientNom,
      date: date,
      details: {'lignes': [
        {'produitId': p.id, 'libelle': p.libelle,
         'quantite': quantite, 'prixUnitaire': p.prixVente}
      ]},
    );
  }

  // ---------- Partenaires ----------
  /// Retourne une erreur si un partenaire du même nom existe déjà, sinon null.
  Future<String?> ajouterPartenaire(Partenaire p) async {
    if (p.nom.trim().length < 2) return 'Nom requis (2 car. min.)';
    if (partenaires.any((x) => _memeLibelle(x.nom, p.nom))) {
      return '« ${p.nom.trim()} » existe déjà — modifiez sa fiche au lieu de le recréer';
    }
    final partenaire = Partenaire(
      id: _nid(), nom: p.nom.trim(), telephone: p.telephone.trim(),
      localisation: p.localisation.trim(), taux: p.taux, actif: p.actif,
    );
    partenaires.add(partenaire);
    notifyListeners();
    await CloudRepository.upsertPartenaire(partenaire);
    await _fileUpsert('partenaires', {
      'id': partenaire.id, 'nom': partenaire.nom,
      'telephone': partenaire.telephone,
      'localisation': partenaire.localisation,
      'taux_partage': partenaire.taux, 'actif': partenaire.actif,
    });
    return null;
  }

  /// Il n'existait aucune méthode de modification : l'écran partenaires
  /// appelait ajouterPartenaire même pour "Modifier le partenaire", ce qui
  /// régénérait un nouvel id et AJOUTAIT un doublon au lieu de mettre à
  /// jour la fiche existante.
  /// Retourne une erreur si le nom collide avec un AUTRE partenaire.
  Future<String?> majPartenaire(Partenaire p) async {
    final i = partenaires.indexWhere((x) => x.id == p.id);
    if (i < 0) return 'Partenaire introuvable';
    if (partenaires.any(
        (x) => x.id != p.id && _memeLibelle(x.nom, p.nom))) {
      return 'Un autre partenaire porte déjà ce nom';
    }
    partenaires[i] = p;
    notifyListeners();
    await CloudRepository.upsertPartenaire(p);
    await _fileUpsert('partenaires', {
      'id': p.id, 'nom': p.nom, 'telephone': p.telephone,
      'localisation': p.localisation, 'taux_partage': p.taux,
      'actif': p.actif,
    });
    return null;
  }

  /// Désactivation (conserve l'historique : ventes et partages) — le chemin
  /// normal de « suppression » d'un partenaire.
  Future<void> desactiverPartenaire(String id) async {
    final i = partenaires.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final p = partenaires[i].copyWith(actif: false);
    partenaires[i] = p;
    notifyListeners();
    await CloudRepository.upsertPartenaire(p);
    await _fileUpsert('partenaires', {'id': p.id, 'actif': false});
  }

  /// Suppression définitive : refusée si le partenaire a des ventes ou des
  /// clôtures (désactivation proposée à la place) pour ne jamais orpheliner
  /// l'historique financier. Retourne null si supprimé, sinon le motif.
  Future<String?> supprimerPartenaire(String id) async {
    final i = partenaires.indexWhere((x) => x.id == id);
    if (i < 0) return 'Partenaire introuvable';
    final aVendu = transactions.any((t) => t.partenaireId == id);
    final aCloture = partages.any((p) => p.partenaireId == id);
    if (aVendu || aCloture) {
      return 'Ce partenaire a un historique (ventes/clôtures) — désactivez-le plutôt pour le conserver';
    }
    partenaires.removeAt(i);
    notifyListeners();
    await CloudRepository.supprimerPartenaire(id);
    await _fileUpsert('partenaires', {'id': id, 'actif': false});
    return null;
  }

  double ventesPartenaireMois(String partenaireId, String mois) =>
      transactions.where((t) =>
          t.partenaireId == partenaireId &&
          t.type == TypeTransaction.forfaitHotspot &&
          C.moisKey(t.date) == mois).fold(0.0, (s, t) => s + t.montant);

  bool partageExiste(String partenaireId, String mois) =>
      partages.any((p) => p.partenaireId == partenaireId && p.mois == mois);

  Future<Partage> cloturerMois(String partenaireId, String mois) async {
    final partenaire = partenaires.firstWhere((p) => p.id == partenaireId);
    if (CloudRepository.actif) {
      // Production : RPC atomique côté serveur (calcul + anti-double).
      final res = await CloudRepository.cloturer(partenaireId, _boutiqueId, mois);
      if (res == null) throw StateError('Clôture impossible (réseau ou déjà clôturé)');
      final pg = Partage.calculer(
        id: res['id'].toString(), partenaireId: partenaireId, mois: mois,
        totalVentes: (res['total_ventes'] as num).toDouble(),
        taux: (res['taux_partage'] as num).toDouble(),
      );
      partages.insert(0, pg);
      notifyListeners();
      return pg;
    }
    final total = ventesPartenaireMois(partenaireId, mois);
    final pg = Partage.calculer(
      id: _nid(), partenaireId: partenaireId, mois: mois,
      totalVentes: total, taux: partenaire.taux,
    );
    partages.insert(0, pg);
    notifyListeners();
    return pg;
  }

  List<Partage> partagesDe(String partenaireId) =>
      partages.where((p) => p.partenaireId == partenaireId).toList();

  // ---------- Achats fournisseurs (Phase 2) ----------
  /// Cycle : demande/en_attente (aucun impact) → valide (dette) →
  /// recu (stock+ CUMP) + paiements (charges Fournisseurs) ; annule
  /// avec motif, contre-écriture stock si déjà reçu. Toute action
  /// sensible est tracée (createdBy + motif).
  List<Achat> get achatsBoutique =>
      achats.where((a) => a.boutiqueId == _boutiqueId).toList();

  List<Achat> get achatsEnAttente => achatsBoutique
      .where((a) =>
          a.statut == Achat.statutDemande ||
          a.statut == Achat.statutEnAttente)
      .toList();

  double get totalAchatsMois => achatsBoutique
      .where((a) =>
          a.statut != Achat.statutAnnule &&
          C.moisKey(a.date) == moisCourant)
      .fold(0.0, (s, a) => s + a.montantTTC);

  double get duFournisseurs => achatsBoutique
      .where((a) =>
          a.statut == Achat.statutValide ||
          a.statut == Achat.statutRecu)
      .fold(0.0, (s, a) => s + a.montantRestant);

  Map<String, dynamic> _payloadAchat(Achat a) => {
        'id': a.id, 'numero': a.numero, 'boutique_id': a.boutiqueId,
        'fournisseur_id': a.fournisseurId.isEmpty ? null : a.fournisseurId,
        'fournisseur_nom': a.fournisseurNom,
        'lignes': [for (final l in a.lignes) l.toJson()],
        'date_achat': a.date.toIso8601String(), 'statut': a.statut,
        'mode_paiement': a.modePaiement,
        'reference_facture': a.referenceFacture, 'notes': a.notes,
        'motif_annulation': a.motifAnnulation,
        'montant_paye': a.montantPaye, 'created_by': a.createdBy,
      };

  /// Création : vendeur/caissier (sans gererAchats) ⇒ statut `demande`
  /// imposé, sans accès aux actions suivantes. Retourne null si OK.
  Future<String?> creerAchat(Achat brouillon) async {
    if (brouillon.fournisseurNom.trim().length < 2) {
      return 'Fournisseur requis (2 car. min.)';
    }
    if (brouillon.lignes.isEmpty) return 'Ajoutez au moins une ligne';
    for (final l in brouillon.lignes) {
      if (l.produitNom.trim().isEmpty) return 'Ligne sans libellé';
      if (l.quantite <= 0) return 'Quantité > 0 requise (${l.produitNom})';
      if (l.prixUnitaire < 0) return 'Prix invalide (${l.produitNom})';
    }
    final statut = peut(Permission.gererAchats)
        ? (brouillon.statut == Achat.statutDemande
            ? Achat.statutDemande
            : Achat.statutEnAttente)
        : Achat.statutDemande;
    final a = Achat(
      id: _nid(), numero: await numeroDocument('ACH'),
      boutiqueId: brouillon.boutiqueId,
      fournisseurId: brouillon.fournisseurId,
      fournisseurNom: brouillon.fournisseurNom.trim(),
      lignes: brouillon.lignes, date: brouillon.date, statut: statut,
      modePaiement: brouillon.modePaiement,
      referenceFacture: brouillon.referenceFacture?.trim(),
      notes: brouillon.notes?.trim(),
      createdBy: user.id, createdAt: DateTime.now(),
    );
    achats.insert(0, a);
    notifyListeners();
    await CloudRepository.upsertAchat(a);
    await _fileUpsert('achats', _payloadAchat(a));
    return null;
  }

  /// Correction d'un brouillon (demande/en_attente uniquement).
  Future<String?> majAchat(Achat maj) async {
    final i = achats.indexWhere((x) => x.id == maj.id);
    if (i < 0) return 'Achat introuvable';
    final actuel = achats[i];
    if (actuel.statut != Achat.statutDemande &&
        actuel.statut != Achat.statutEnAttente) {
      return 'Seule une demande ou un achat en attente est modifiable';
    }
    if (maj.lignes.isEmpty) return 'Ajoutez au moins une ligne';
    achats[i] = maj;
    notifyListeners();
    await CloudRepository.upsertAchat(maj);
    await _fileUpsert('achats', _payloadAchat(maj));
    return null;
  }

  /// Validation : demande/en_attente → valide (dette fournisseur).
  /// Aucun impact stock ni trésorerie à ce stade.
  Future<String?> validerAchat(String id) async {
    if (!peut(Permission.gererAchats)) return 'Réservé (admin, gérant, comptable)';
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    if (!achats[i].peutValider) return 'Statut incompatible avec la validation';
    achats[i] = achats[i].copyWith(statut: Achat.statutValide);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await _fileUpsert('achats', _payloadAchat(achats[i]));
    return null;
  }

  /// Réception : valide → recu + entrée stock (CUMP) par ligne.
  /// Ligne liée à un produit : stock += qté, prixAchat = moyenne pondérée.
  /// Ligne libre : crée la fiche produit (prixVente = prixAchat, à ajuster).
  Future<String?> recevoirAchat(String id) async {
    if (!peut(Permission.gererAchats)) return 'Réservé (admin, gérant, comptable)';
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutRecevoir) return 'Validez d\'abord cet achat';
    for (final l in a.lignes) {
      final pi = produits.indexWhere((p) =>
          p.boutiqueId == a.boutiqueId &&
          (l.produitId.isNotEmpty
              ? p.id == l.produitId
              : _memeLibelle(p.libelle, l.produitNom)));
      if (pi >= 0) {
        final p = produits[pi];
        final qte = (l.quantite).toInt();
        final nouveauStock = p.stock + qte;
        // CUMP : (stock × ancien PA + qté × nouveau PA) / nouveau stock.
        final cump = nouveauStock > 0
            ? (p.stock * p.prixAchat + l.quantite * l.prixUnitaire) /
                nouveauStock
            : l.prixUnitaire;
        final maj = p.copyWith(stock: nouveauStock, prixAchat: cump);
        produits[pi] = maj;
        await CloudRepository.upsertProduit(maj);
        await _fileUpsert('produits', _payloadProduit(maj));
      } else {
        final nouveau = Produit(
          id: _nid(), boutiqueId: a.boutiqueId,
          libelle: l.produitNom.trim(), categorie: 'Autre',
          prixAchat: l.prixUnitaire, prixVente: l.prixUnitaire,
          stock: l.quantite.toInt(), seuil: 3,
        );
        produits.add(nouveau);
        await CloudRepository.upsertProduit(nouveau);
        await _fileUpsert('produits', _payloadProduit(nouveau));
        await _syncCatalogueDepuisProduit(nouveau);
      }
    }
    achats[i] = a.copyWith(statut: Achat.statutRecu);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await _fileUpsert('achats', _payloadAchat(achats[i]));
    return null;
  }

  /// Paiement total ou partiel : met à jour le payé/restant et enregistre
  /// une charge « Fournisseurs » (sortie de trésorerie traçable).
  Future<String?> payerAchat(String id, double montant,
      {String? mode}) async {
    if (!peut(Permission.gererAchats)) return 'Réservé (admin, gérant, comptable)';
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutPayer) return 'Aucun montant à payer sur cet achat';
    if (montant <= 0) return 'Montant > 0 requis';
    if (montant > a.montantRestant + 0.001) {
      return 'Montant supérieur au reste dû (${a.montantRestant.toStringAsFixed(0)})';
    }
    final paye = (a.montantPaye + montant).clamp(0.0, a.montantTTC);
    achats[i] = a.copyWith(
        montantPaye: paye, modePaiement: mode ?? a.modePaiement);
    final charge = Charge(
      id: _nid(), boutiqueId: a.boutiqueId, categorie: 'Fournisseurs',
      libelle: 'Paiement ${a.numero} — ${a.fournisseurNom}',
      montant: montant, date: DateTime.now(), recurrente: false,
    );
    depenses.insert(0, charge);
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await _fileUpsert('achats', _payloadAchat(achats[i]));
    await CloudRepository.upsertCharge(charge);
    await _fileUpsert('charges', {
      'id': charge.id, 'boutique_id': charge.boutiqueId,
      'categorie': charge.categorie, 'libelle': charge.libelle,
      'montant': charge.montant,
      'date_charge': charge.date.toIso8601String(),
      'recurrente': charge.recurrente,
    });
    return null;
  }

  /// Annulation avec motif obligatoire. Si déjà reçu : contre-écriture
  /// stock (retrait des quantités, plancher 0) — jamais de suppression
  /// d'écriture, l'historique reste lisible.
  Future<String?> annulerAchat(String id, String motif) async {
    if (!peut(Permission.gererAchats)) return 'Réservé (admin, gérant, comptable)';
    if (motif.trim().length < 3) return 'Motif requis (3 car. min.)';
    final i = achats.indexWhere((x) => x.id == id);
    if (i < 0) return 'Achat introuvable';
    final a = achats[i];
    if (!a.peutAnnuler) return 'Achat déjà annulé';
    if (a.statut == Achat.statutRecu) {
      for (final l in a.lignes) {
        final pi = produits.indexWhere((p) =>
            p.boutiqueId == a.boutiqueId &&
            (l.produitId.isNotEmpty
                ? p.id == l.produitId
                : _memeLibelle(p.libelle, l.produitNom)));
        if (pi >= 0) {
          final p = produits[pi];
          final maj = p.copyWith(
              stock: (p.stock - l.quantite.toInt()).clamp(0, 1 << 30));
          produits[pi] = maj;
          await CloudRepository.upsertProduit(maj);
          await _fileUpsert('produits', _payloadProduit(maj));
        }
      }
    }
    achats[i] = a.copyWith(
        statut: Achat.statutAnnule, motifAnnulation: motif.trim());
    notifyListeners();
    await CloudRepository.upsertAchat(achats[i]);
    await _fileUpsert('achats', _payloadAchat(achats[i]));
    return null;
  }

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
             'telephone': c.telephone, 'adresse': c.adresse},
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
             'prix': t.prix, 'description': t.description, 'actif': t.actif},
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
             'image_path': p.imagePath},
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
      };

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
      logoPath: p['logo_path']?.toString(),
      cachetPath: p['cachet_path']?.toString(),
      signaturePath: p['signature_path']?.toString(),
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
            adresse: c['adresse']?.toString() ?? '',
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
            imagePath: p['image_path']?.toString(),
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
      Produit(id: 'pr_1', boutiqueId: 'bt_siege', libelle: 'Câble RJ45 (305m)', categorie: 'Télécom & Réseau', prixAchat: 18000, prixVente: 25000, stock: 4, seuil: 3),
      Produit(id: 'pr_2', boutiqueId: 'bt_siege', libelle: 'Disjoncteur 32A', categorie: 'Électricité', prixAchat: 2500, prixVente: 4000, stock: 25, seuil: 5),
      Produit(id: 'pr_3', boutiqueId: 'bt_siege', libelle: 'Écran 24 pouces', categorie: 'Accessoire PC', prixAchat: 45000, prixVente: 60000, stock: 2, seuil: 2),
      Produit(id: 'pr_4', boutiqueId: 'bt_siege', libelle: 'Chargeur type-C 25W', categorie: 'Accessoire téléphone', prixAchat: 3000, prixVente: 5500, stock: 40, seuil: 8),
      Produit(id: 'pr_5', boutiqueId: 'bt_marche', libelle: 'Caméra IP Hikvision', categorie: 'Télécom & Réseau', prixAchat: 22000, prixVente: 32000, stock: 6, seuil: 2),
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
