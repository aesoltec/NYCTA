import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achat.dart';
import '../models/app_user.dart';
import '../models/mouvement_stock.dart';
import '../models/boutique.dart';
import '../models/client.dart';
import '../models/evenement.dart';
import '../models/feedback.dart';
import '../models/fournisseur.dart';
import '../models/message.dart';
import '../models/charge.dart';
import '../models/company_profile.dart';
import '../models/document.dart';
import '../models/ecriture.dart';
import 'document_service.dart';
import '../models/enums.dart';
import '../models/partenaire.dart';
import '../models/produit.dart';
import '../models/tarif.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

/// Alias de mapping pour le Store (évite d'exposer le dictionnaire interne).
class CloudTx {
  static TypeTransaction type(dynamic v) =>
      CloudRepository._txTypes[v.toString()] ?? TypeTransaction.prestationService;

  /// Sens inverse : enum Dart (camelCase) → valeur ENUM Postgres (snake_case).
  /// Réutilise la même table de correspondance que [type] (source unique).
  static String dbValue(TypeTransaction t) =>
      CloudRepository._txTypes.entries.firstWhere((e) => e.value == t).key;
}

/// Pont production Supabase : charge initiale + écritures en direct.
/// Toutes les méthodes sont tolérantes aux erreurs réseau (offline-first) :
/// en cas d'échec, l'opération reste valable localement et la file de
/// synchronisation (SyncService) reprendra le relais au retour du réseau.
class CloudRepository {
  static SupabaseClient? get _c => SupabaseService.client;
  static bool get actif => _c != null;

  /// Le schéma SQL utilise des ENUM snake_case ; Dart du camelCase.
  static const _txTypes = {
    'prestation_service': TypeTransaction.prestationService,
    'vente_materiel': TypeTransaction.venteMateriel,
    'mobile_money': TypeTransaction.mobileMoney,
    'credit_communication': TypeTransaction.creditCommunication,
    'forfait_hotspot': TypeTransaction.forfaitHotspot,
  };

  // ---------- Chargement initial après connexion ----------
  /// Une table manquante ou illisible (migration SQL non exécutée côté
  /// Supabase) ne doit JAMAIS faire échouer tout le chargement : avant ce
  /// correctif, un seul `Future.wait` global transformait l'absence d'UNE
  /// table (ex. `achats`, `mouvements_stock`, `ecritures`) en échec total —
  /// l'app basculait hors-ligne en permanence alors que le réseau et le
  /// reste de la base fonctionnaient. Chaque table est donc chargée
  /// isolément : échec = liste vide + log nommé, le reste passe.
  static Future<List> _fetch(
      Future<dynamic> Function() requete, String table) async {
    try {
      return (await requete()) as List;
    } catch (e) {
      // Piste d'action immédiate : exécutez la migration SQL créant
      // cette table (voir database/migration_*.sql), puis Reconnecter.
      debugPrint('⚠️ CloudRepository.chargerTout() : table '
          '« $table » illisible — ignorée ($e)');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> chargerTout() async {
    final c = _c;
    if (c == null) return null;
    try {
      final results = await Future.wait([
        _fetch(() => c.from('company_profile').select().limit(1),
            'company_profile'),
        _fetch(
            () => c.from('boutiques').select().eq('actif', true),
            'boutiques'),
        _fetch(
            () => c.from('produits').select().eq('actif', true),
            'produits'),
        _fetch(
            () => c.from('partenaires').select().eq('actif', true),
            'partenaires'),
        _fetch(
            () => c.from('transactions').select().order('date_transaction',
                ascending: false).limit(2000),
            'transactions'),
        _fetch(
            () => c.from('charges').select().order('date_charge',
                ascending: false).limit(1000),
            'charges'),
        _fetch(() => c.from('budgets_mensuels').select(),
            'budgets_mensuels'),
        _fetch(
            () => c.from('fonds_roulement').select(), 'fonds_roulement'),
        _fetch(() => c.from('categories').select(), 'categories'),
        _fetch(() => c.from('fournisseurs').select(), 'fournisseurs'),
        _fetch(
            () => c.from('messages').select().order('created_at',
                ascending: false).limit(300),
            'messages'),
        _fetch(
            () => c.from('evenements').select().gte('date',
                DateTime.now().subtract(const Duration(days: 30)).toIso8601String()).order('date',
                ascending: true).limit(200),
            'evenements'),
        _fetch(
            () => c.from('notes').select().order('created_at',
                ascending: false).limit(300),
            'notes'),
        _fetch(
            () => c.from('feedbacks').select().order('created_at',
                ascending: false).limit(300),
            'feedbacks'),
        _fetch(
            () => c.from('tarifs').select().eq('actif', true).order(
                'libelle',
                ascending: true).limit(500),
            'tarifs'),
        _fetch(
            () => c.from('documents').select().order('date_doc',
                ascending: false).limit(300),
            'documents'),
        // Tous les comptes actifs (écran Utilisateurs, réservé admin) :
        // RLS "lecture users" = using(true), donc sans risque à charger ici.
        // Sans ce chargement, Store.users restait vide à chaque
        // redémarrage — l'admin ne pouvait plus voir ni gérer les
        // comptes existants après avoir quitté puis rouvert l'app.
        _fetch(() => c.from('users').select().eq('actif', true), 'users'),
        // "user_boutiques select" (RLS) ne renvoie que sa propre ligne
        // pour un rôle non admin/gerant — sans danger de tout demander ici.
        _fetch(() => c.from('user_boutiques').select(), 'user_boutiques'),
        // Achats fournisseurs (Phase 2) — en fin de liste pour ne pas
        // décaler les indices results[16]/[17] existants.
        _fetch(
            () => c.from('achats').select().order('date_achat',
                ascending: false).limit(500),
            'achats'),
        // Mouvements de stock (mission 1 §1.3) — idem, en fin de liste.
        _fetch(
            () => c.from('mouvements_stock').select().order(
                'date_mouvement',
                ascending: false).limit(1000),
            'mouvements_stock'),
        // Écritures comptables (mission §3.3) — idem, en fin de liste.
        _fetch(
            () => c.from('ecritures').select().order('date_ecriture',
                ascending: false).limit(2000),
            'ecritures'),
      ]);
      final uid = c.auth.currentUser?.id;
      Map<String, dynamic>? monProfil;
      List<Map<String, dynamic>> mesBoutiques = [];
      final tousUsers = List<Map<String, dynamic>>.from(results[16] as List);
      final toutesUserBoutiques =
          List<Map<String, dynamic>>.from(results[17] as List);
      if (uid != null) {
        monProfil = tousUsers.where((u) => u['id'] == uid).firstOrNull;
        if (monProfil != null) {
          mesBoutiques = toutesUserBoutiques
              .where((ub) => ub['user_id'] == uid).toList();
        }
      }
      // Clients : toutes les boutiques accessibles de l'utilisateur.
      List<dynamic> clientsRows = [];
      try {
        final ids = mesBoutiques.map((b) => b['boutique_id']).toList();
        if (ids.isNotEmpty) {
          clientsRows = await c.from('clients').select().inFilter('boutique_id', ids);
        }
      } catch (_) {}
      return {
        'profile': (results[0] as List).isNotEmpty ? (results[0] as List).first : null,
        'boutiques': results[1], 'produits': results[2],
        'partenaires': results[3], 'transactions': results[4],
        'charges': results[5], 'budgets': results[6],
        'fonds': results[7], 'categories': results[8],
        'fournisseurs': results[9], 'messages': results[10],
        'evenements': results[11], 'notes': results[12],
        'feedbacks': results[13], 'catalogue': results[14],
        'documents': results[15],
        'clients': clientsRows,
        'mon_profil': monProfil, 'mes_boutiques': mesBoutiques,
        'users': tousUsers, 'user_boutiques': toutesUserBoutiques,
        'achats': results[18], 'mouvements': results[19],
        'ecritures': results[20],
      };
    } catch (e, st) {
      // Ne jamais avaler cette erreur en silence : c'est la seule piste pour
      // diagnostiquer une table/colonne manquante ou une policy RLS trop
      // stricte. Visible dans la console `flutter run` / logcat.
      debugPrint('❌ CloudRepository.chargerTout() a échoué : $e');
      debugPrint('$st');
      return null;
    }
  }

  // ---------- Écritures en direct ----------
  static Future<void> upsertProduit(Produit p) => _silencieux(() async {
        await _c!.from('produits').upsert({
          'id': p.id, 'boutique_id': p.boutiqueId, 'libelle': p.libelle,
          'categorie': p.categorie, 'prix_achat': p.prixAchat,
          'prix_vente': p.prixVente, 'quantite_stock': p.stock,
          'seuil_alerte': p.seuil,
          // En production : l'image locale est uploadée vers Supabase
          // Storage — le chemin local ne serait visible que sur cet appareil.
          'image_path': await _urlMedia(p.imagePath), 'actif': true,
        });
      });

  /// Archivage (soft delete) : chargerTout() ne recharge que les produits
  /// actifs — sans cet appel, un produit "archivé" côté app réapparaissait
  /// au prochain rechargement car jamais désactivé en base.
  static Future<void> archiverProduit(String id) => _silencieux(() async {
        await _c!.from('produits').update({'actif': false}).eq('id', id);
      });

  static Future<void> supprimerPartenaire(String id) => _silencieux(() async {
        // Soft delete : l'historique (transactions, partages) reste lisible.
        await _c!.from('partenaires').update({'actif': false}).eq('id', id);
      });

  /// Convertit un chemin local en URL publique Supabase Storage
  /// (bucket « media », à créer — voir guide de déploiement).
  static Future<String?> _urlMedia(String? cheminLocal) async {
    if (cheminLocal == null || cheminLocal.startsWith('http')) return cheminLocal;
    if (!actif || !File(cheminLocal).existsSync()) return cheminLocal;
    try {
      final nom = 'produits/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _c!.storage.from('media').upload(nom, File(cheminLocal));
      return _c!.storage.from('media').getPublicUrl(nom);
    } catch (_) {
      return cheminLocal; // upload impossible : on garde le chemin local
    }
  }

  static Future<void> upsertCharge(Charge ch) => _silencieux(() async {
        await _c!.from('charges').upsert({
          'id': ch.id, 'boutique_id': ch.boutiqueId, 'categorie': ch.categorie,
          'libelle': ch.libelle, 'montant': ch.montant,
          'date_charge': ch.date.toIso8601String(),
          'recurrente': ch.recurrente,
          // created_by NOT NULL côté Postgres (23502 sinon) : toujours
          // l'auteur réel, jamais null en production.
          'created_by': _c!.auth.currentUser?.id,
        });
      });

  static Future<void> supprimerCharge(String id) => _silencieux(() async {
        await _c!.from('charges').delete().eq('id', id);
      });

  /// Modification / correction d'une vente existante (upsert sur l'id).
  /// Utilisé par Store.majTransaction — sans cela, une vente corrigée en
  /// local réapparaissait avec l'ancienne valeur au rechargement cloud.
  static Future<void> upsertTransaction(Tx t) => _silencieux(() async {
        await _c!.from('transactions').upsert({
          'id': t.id, 'boutique_id': t.boutiqueId,
          'employe_id': t.employeId,
          'type': _txTypes.entries.firstWhere((e) => e.value == t.type).key,
          'montant': t.montant, 'cout': t.cout,
          'statut': t.statut.name, 'client_nom': t.clientNom,
          'partenaire_id': t.partenaireId, 'details': t.details,
          'date_transaction': t.date.toIso8601String(),
        }, onConflict: 'id');
      });

  /// Suppression définitive d'une vente (journal → menu contextuel).
  static Future<void> supprimerTransaction(String id) =>
      _silencieux(() async {
        await _c!.from('transactions').delete().eq('id', id);
      });

  static Future<void> upsertPartenaire(Partenaire p) => _silencieux(() async {
        await _c!.from('partenaires').upsert({
          'id': p.id, 'nom': p.nom, 'telephone': p.telephone,
          'localisation': p.localisation, 'taux_partage': p.taux, 'actif': p.actif,
        });
      });

  static Future<void> updateProfile(CompanyProfile p) => _silencieux(() async {
        await _c!.from('company_profile').update({
          'nom_entreprise': p.nomEntreprise, 'devise': p.devise,
          'telephone': p.telephone, 'telephone2': p.telephone2,
          'email': p.email, 'adresse': p.adresse, 'rccm': p.rccm,
          'ifu': p.ifu, 'autre_ref_fiscale': p.autreRefFiscale,
          'banque': p.banque,
          'coordonnees_bancaires': p.coordonneesBancaires,
          'message_pied': p.messagePied, 'tva': p.tva,
          'logo_path': await _urlMedia(p.logoPath),
          'cachet_path': await _urlMedia(p.cachetPath),
          'signature_path': await _urlMedia(p.signaturePath),
        }).eq('id', 1);
        for (final e in p.fondsRoulement.entries) {
          await _c!.from('fonds_roulement').upsert(
              {'boutique_id': e.key, 'montant': e.value});
        }
        for (final e in p.budgetsMensuels.entries) {
          // upsert, pas update : "categorie" est la clé primaire mais seules
          // quelques catégories sont pré-semées par le script SQL — définir
          // un budget sur une catégorie de charge ajoutée depuis l'app
          // touchait 0 ligne avec un simple update, et disparaissait donc
          // silencieusement au rechargement.
          await _c!.from('budgets_mensuels')
              .upsert({'categorie': e.key, 'montant': e.value});
        }
      });

  /// Persiste le mois de dernière génération des charges récurrentes —
  /// sans ça, `profile.moisChargesGenerees` repartait à null à chaque
  /// redémarrage (jamais renvoyé par updateProfile ni relu par
  /// chargerDuCloud) et la génération se redéclenchait à chaque session.
  static Future<void> majMoisChargesGenerees(String mois) =>
      _silencieux(() async {
        await _c!.from('company_profile')
            .update({'mois_charges_generees': mois}).eq('id', 1);
      });

  /// Clôture mensuelle via la RPC atomique (anti-double côté serveur).
  static Future<Map<String, dynamic>?> cloturer(
          String partenaireId, String boutiqueId, String mois) =>
      _silencieuxRetour(() async {
        final rows = await _c!.rpc('cloturer_partage', params: {
          'p_partenaire': partenaireId,
          'p_boutique': boutiqueId,
          'p_mois': mois,
        });
        final list = rows as List;
        return list.isNotEmpty ? Map<String, dynamic>.from(list.first as Map) : null;
      });

  /// Création d'un compte : inscription Supabase Auth + ligne users métier.
  /// Retourne (erreur, uid) : uid non-null seulement si le compte a bien
  /// été créé — nécessaire pour que l'appelant garde en mémoire le VRAI id
  /// Supabase Auth plutôt qu'un id local temporaire qui ne correspondrait à
  /// rien côté base (l'utilisateur semblerait créé puis disparaîtrait de la
  /// liste au prochain rechargement).
  static Future<(String? erreur, String? uid)> creerUtilisateur({
    required String email, required String motDePasse, required String nom,
    required Role role, required List<String> boutiqueIds,
    String? partenaireId,
  }) async {
    final resultat = await _silencieuxRetour(() async {
      final res = await _c!.auth.signUp(
          email: email, password: motDePasse, data: {'nom': nom});
      final uid = res.user?.id;
      if (uid == null) return ('Échec de la création du compte', null);
      await _c!.from('users').insert({
        'id': uid, 'nom': nom, 'role': role.name,
        'partenaire_id': role == Role.partenaire ? partenaireId : null,
      });
      for (final b in boutiqueIds) {
        await _c!.from('user_boutiques')
            .insert({'user_id': uid, 'boutique_id': b});
      }
      return (null, uid);
    });
    return resultat ?? ('Connexion au serveur impossible', null);
  }

  /// Désactivation (l'anon key ne peut pas supprimer un compte auth).
  static Future<void> desactiverUtilisateur(String id) =>
      _silencieux(() async {
        await _c!.from('users').update({'actif': false}).eq('id', id);
      });

  /// Modification d'un compte existant (nom, rôle, boutiques accessibles).
  /// Store.majUtilisateur ne persistait qu'en local avant ce correctif :
  /// les modifications (ex. changer un rôle) disparaissaient au rechargement.
  static Future<void> majUtilisateur(AppUser u) => _silencieux(() async {
        await _c!.from('users').update({
          'nom': u.nom, 'role': u.role.name,
          'partenaire_id': u.role == Role.partenaire ? u.partenaireId : null,
        }).eq('id', u.id);
        final actuelles = await _c!.from('user_boutiques')
            .select('boutique_id').eq('user_id', u.id);
        final actuellesIds = {
          for (final r in actuelles as List) r['boutique_id'].toString()
        };
        final voulues = u.boutiqueIds.toSet();
        for (final b in voulues.difference(actuellesIds)) {
          await _c!.from('user_boutiques')
              .insert({'user_id': u.id, 'boutique_id': b});
        }
        for (final b in actuellesIds.difference(voulues)) {
          await _c!.from('user_boutiques')
              .delete().eq('user_id', u.id).eq('boutique_id', b);
        }
      });

  // ---------- Boutiques / catégories / clients ----------
  static Future<void> upsertBoutique(Boutique b, List<String> userIds) =>
      _silencieux(() async {
        await _c!.from('boutiques').upsert({
          'id': b.id, 'nom': b.nom, 'adresse': b.adresse,
          'telephone': '', 'siege': b.siege, 'actif': b.actif,
        });
        // Affectation : le créateur + utilisateurs choisis.
        final ids = {if (_c!.auth.currentUser != null) _c!.auth.currentUser!.id,
          ...userIds};
        for (final uid in ids) {
          await _c!.from('user_boutiques')
              .upsert({'user_id': uid, 'boutique_id': b.id});
        }
      });

  static Future<void> desactiverBoutique(String id) => _silencieux(() async {
        await _c!.from('boutiques').update({'actif': false}).eq('id', id);
      });

  static Future<void> upsertCategorie(String type, String nom) =>
      _silencieux(() async {
        await _c!.from('categories').upsert({'type': type, 'nom': nom},
            onConflict: 'type,nom');
      });

  static Future<void> supprimerCategorie(String type, String nom) =>
      _silencieux(() async {
        await _c!.from('categories')
            .delete().eq('type', type).eq('nom', nom);
      });

  static Future<void> upsertClient(Client c) => _silencieux(() async {
        await _c!.from('clients').upsert({
          'id': c.id, 'boutique_id': c.boutiqueId, 'nom': c.nom,
          'telephone': c.telephone, 'adresse': c.adresse,
        });
      });

  // ---------- Fournisseurs / messages / événements / notes ----------
  static Future<void> upsertFournisseur(Fournisseur f) => _silencieux(() async {
        await _c!.from('fournisseurs').upsert({
          'id': f.id, 'nom': f.nom, 'telephone': f.telephone,
          'email': f.email, 'adresse': f.adresse,
          'specialite': f.specialite, 'notes': f.notes,
        });
      });

  static Future<void> supprimerFournisseur(String id) => _silencieux(() async {
        await _c!.from('fournisseurs').delete().eq('id', id);
      });

  static Future<void> envoyerMessage(Message m) => _silencieux(() async {
        await _c!.from('messages').insert({
          'id': m.id,
          'expediteur_id': _c!.auth.currentUser?.id ?? m.expediteurId,
          'expediteur_nom': m.expediteurNom,
          'destinataire_id': m.destinataireId,
          'sujet': m.sujet, 'contenu': m.contenu,
        });
      });

  static Future<void> marquerMessageLu(String id) => _silencieux(() async {
        await _c!.from('messages').update({'lu': true}).eq('id', id);
      });

  static Future<void> marquerTousMessagesLus() => _silencieux(() async {
        await _c!.from('messages').update({'lu': true}).eq('lu', false);
      });

  /// Correction d'un message par son auteur (sujet + contenu).
  /// Passe par la policy « maj messages » existante.
  static Future<void> majMessage(Message m) => _silencieux(() async {
        await _c!.from('messages').update({
          'sujet': m.sujet, 'contenu': m.contenu,
        }).eq('id', m.id);
      });

  /// Suppression d'un message (auteur ou admin/gérant — policy
  /// « suppression messages », voir migration collab).
  static Future<void> supprimerMessage(String id) => _silencieux(() async {
        await _c!.from('messages').delete().eq('id', id);
      });

  static Future<void> upsertEvenement(Evenement e) => _silencieux(() async {
        // createur_id ne doit être fixé qu'à la création : sinon modifier
        // l'événement de quelqu'un d'autre lui en volerait la paternité.
        await _c!.from('evenements').upsert({
          'id': e.id, 'titre': e.titre, 'date': e.date.toIso8601String(),
          'heure': e.heure, 'lieu': e.lieu, 'description': e.description,
          'createur_id':
              e.createurId.isNotEmpty ? e.createurId : _c!.auth.currentUser?.id,
        });
      });

  static Future<void> supprimerEvenement(String id) => _silencieux(() async {
        await _c!.from('evenements').delete().eq('id', id);
      });

  static Future<void> upsertNote(Note n) => _silencieux(() async {
        // createur_id ne doit être fixé qu'à la création : sinon modifier
        // la note de quelqu'un d'autre lui en volerait la paternité (et
        // casserait la policy RLS "ecriture notes" basée sur createur_id).
        await _c!.from('notes').upsert({
          'id': n.id, 'titre': n.titre, 'contenu': n.contenu,
          'date': n.date.toIso8601String(),
          'rappel_le': n.rappelLe?.toIso8601String(),
          'createur_id':
              n.createurId.isNotEmpty ? n.createurId : _c!.auth.currentUser?.id,
        });
      });

  static Future<void> supprimerNote(String id) => _silencieux(() async {
        await _c!.from('notes').delete().eq('id', id);
      });

  static Future<void> ajouterFeedback(Feedback f) => _silencieux(() async {
        await _c!.from('feedbacks').insert({
          'id': f.id,
          'auteur_id': _c!.auth.currentUser?.id ?? f.auteurId,
          'auteur_nom': f.auteurNom, 'boutique_id': f.boutiqueId,
          'type': f.type.name, 'priorite': f.priorite.name,
          'titre': f.titre, 'contenu': f.contenu,
          'statut': f.statut.name,
        });
      });

  static Future<void> majStatutFeedback(String id, StatutFeedback statut) =>
      _silencieux(() async {
        await _c!.from('feedbacks')
            .update({'statut': statut.name}).eq('id', id);
      });

  /// Correction complète d'une contribution par son auteur
  /// (titre, contenu, type, priorité — policy « maj feedbacks auteur »).
  static Future<void> majFeedback(Feedback f) => _silencieux(() async {
        await _c!.from('feedbacks').update({
          'type': f.type.name, 'priorite': f.priorite.name,
          'titre': f.titre, 'contenu': f.contenu,
        }).eq('id', f.id);
      });

  /// Suppression d'une contribution (auteur ou admin/gérant — policy
  /// « suppression feedbacks », voir migration collab).
  static Future<void> supprimerFeedback(String id) => _silencieux(() async {
        await _c!.from('feedbacks').delete().eq('id', id);
      });

  /// Persiste un document émis (en-tête + lignes) dans Supabase —
  /// copie fidèle, ré-exploitable indéfiniment (régénération PDF/CSV).
  /// Retourne l'id cloud du document.
  /// Numéro de document atomique via la RPC serveur (SECURITY DEFINER) —
  /// seule cette fonction a le droit d'écrire dans compteurs_documents
  /// (RLS deny-by-default sur cette table, voir supabase_schema.sql).
  /// Un compteur purement local remis à zéro à chaque redémarrage de l'app
  /// aurait généré des doublons de numéro de facture entre deux sessions ou
  /// deux appareils — exactement ce que cette RPC existe pour empêcher.
  static Future<String?> prochainNumero(String prefixe) =>
      _silencieuxRetour(() async =>
          (await _c!.rpc('prochain_numero', params: {'p_prefixe': prefixe}))
              .toString());

  static Future<String?> enregistrerDocument(
      DocumentBati d, String boutiqueId, {DateTime? date}) => _silencieuxRetour(() async {
        final id = uuid();
        final base = <String, dynamic>{
          'id': id, 'boutique_id': boutiqueId, 'type': d.type.dbValue,
          'numero': d.numero,
          // Date d'émission réelle (formulaire) — pas l'instant d'envoi :
          // un bordereau d'hier synchronisé aujourd'hui garde sa date.
          'date_doc': (date ?? DateTime.now()).toIso8601String(),
          'client_nom': d.client,
          'total_ht': d.totalHT, 'tva': d.tva, 'total_ttc': d.totalTTC,
          'statut': d.statut,
          'created_by': _c!.auth.currentUser?.id,
        };
        try {
          // Colonne ajoutée après coup (cf. supabase_schema.sql) ; les
          // bases non migrées la rejettent → repli sans la colonne.
          await _c!.from('documents').insert({
            ...base,
            'signature_client_path': d.signatureClientPath == null
                ? null
                : await uploaderSignature(
                    d.signatureClientPath!, d.numero),
          });
        } catch (_) {
          await _c!.from('documents').insert(base);
        }
        for (final l in d.lignes) {
          await _c!.from('document_lignes').insert({
            'id': uuid(), 'document_id': id, 'libelle': l.libelle,
            'quantite': l.quantite, 'prix_unitaire': l.prixUnitaire,
          });
        }
        return id;
      });

  /// Upload d'une signature client (PNG local) vers le bucket privé
  /// `documents/signatures/`. Retourne le chemin storage, null si échec.
  static Future<String?> uploaderSignature(
      String cheminLocal, String numero) => _silencieuxRetour(() async {
        final fichier = File(cheminLocal);
        if (!fichier.existsSync()) return null;
        final nom =
            'signatures/${numero.replaceAll('/', '-')}.png';
        await _c!.storage.from('documents').uploadBinary(
            nom, await fichier.readAsBytes(),
            fileOptions: const FileOptions(upsert: true));
        return nom;
      });

  /// Rattache (ou remplace) la signature client d'un document déjà émis :
  /// upload du PNG local puis mise à jour de la colonne avec le chemin
  /// storage. Sans effet en mode local (le fichier local suffit).
  static Future<void> majSignatureDocument(
          {String? id, String? numero, required String cheminLocal}) =>
      _silencieux(() async {
        final nom = 'signatures/${DateTime.now().millisecondsSinceEpoch}.png';
        await _c!.storage.from('documents').uploadBinary(
            nom, await File(cheminLocal).readAsBytes(),
            fileOptions: const FileOptions(upsert: true));
        var requete = _c!
            .from('documents')
            .update({'signature_client_path': nom});
        if (id != null) {
          await requete.eq('id', id);
        } else {
          await requete.eq('numero', numero ?? '');
        }
      });

  /// Télécharge une signature du bucket vers un fichier temporaire local
  /// (prévisualisation + régénération PDF après rechargement).
  static Future<String?> telechargerSignature(String cheminStorage) =>
      _silencieuxRetour(() async {
        final bytes = await _c!.storage
            .from('documents')
            .download(cheminStorage);
        final f = File(
            '${Directory.systemTemp.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png');
        await f.writeAsBytes(bytes, flush: true);
        return f.path;
      });

  /// Validation manager d'un brouillon : `brouillon` → `emis`.
  /// Utilisé par Store.validerDocument (rôles financiers uniquement).
  static Future<void> majStatutDocument(
          {String? id, String? numero, required String statut}) =>
      _silencieux(() async {
        var requete =
            _c!.from('documents').update({'statut': statut});
        if (id != null) {
          await requete.eq('id', id);
        } else {
          await requete.eq('numero', numero ?? '');
        }
      });

  /// Documents + leurs lignes, pour reconstruction de l'historique.
  static Future<Map<String, List<Map<String, dynamic>>>> chargerDocuments(
      List<dynamic> docRows) async {
    final result = <String, List<Map<String, dynamic>>>{};
    if (docRows.isEmpty) return result;
    final ids = [for (final r in docRows) r['id'].toString()];
    final lignes = await _c!.from('document_lignes').select()
        .inFilter('document_id', ids);
    for (final l in (lignes as List).cast<Map<String, dynamic>>()) {
      result.putIfAbsent(l['document_id'].toString(), () => <Map<String, dynamic>>[]).add(l);
    }
    return result;
  }

  // ---------- Sauvegarde / restauration cloud (v1.11) ----------
  static Future<(String, int)?> sauvegarderBase() => _silencieuxRetour(() async {
        final rows = await _c!.rpc('sauvegarder_base');
        final r = (rows as List).first as Map;
        return (r['id'].toString(), (r['nb_lignes'] as num).toInt());
      });

  /// Journal d'activité (v1.12) : qui a fait quoi, alimenté par un trigger
  /// SQL sur chaque table métier — réservé admin/gérant (RLS "lecture journal").
  static Future<List<Map<String, dynamic>>> chargerJournalActivite(
          {int limite = 200}) async =>
      (await _silencieuxRetour(() async {
        final rows = await _c!.from('journal_activite')
            .select()
            .order('created_at', ascending: false)
            .limit(limite);
        return List<Map<String, dynamic>>.from(rows);
      })) ?? [];

  static Future<List<Map<String, dynamic>>> listeSauvegardes() async =>
      (await _silencieuxRetour(() async {
        final rows = await _c!.from('sauvegardes')
            .select('id, auteur_nom, nb_lignes, created_at')
            .order('created_at', ascending: false)
            .limit(30);
        return List<Map<String, dynamic>>.from(rows);
      })) ?? [];

  static Future<String?> restaurerBase(String id) =>
      _silencieuxRetour(() async =>
          (await _c!.rpc('restaurer_base', params: {'p_id': id})).toString());

  static Future<String?> telechargerSauvegarde(String id) =>
      _silencieuxRetour(() async {
        final rows = await _c!.from('sauvegardes')
            .select('donnees').eq('id', id).limit(1);
        if (rows.isEmpty) return null;
        return rows.first['donnees'].toString();
      });

  /// Mouvement de stock : traçabilité des entrées/sorties/ajustements.
  static Future<void> upsertMouvement(MouvementStock m) =>
      _silencieux(() async {
        await _c!.from('mouvements_stock').upsert({
          'id': m.id, 'boutique_id': m.boutiqueId, 'produit_id': m.produitId,
          'produit_nom': m.produitNom, 'type': m.type,
          'quantite': m.quantite, 'stock_apres': m.stockApres,
          'motif': m.motif, 'ref_id': m.refId.isEmpty ? null : m.refId,
          'date_mouvement': m.date.toIso8601String(),
          'created_by': _c!.auth.currentUser?.id,
        }, onConflict: 'id');
      });

  /// Écriture comptable : journal immuable (corrections par
  /// contre-écriture, jamais d'update/delete direct).
  static Future<void> upsertEcriture(Ecriture e) => _silencieux(() async {
        final base = <String, dynamic>{
          'id': e.id, 'journal': e.journal,
          'date_ecriture': e.date.toIso8601String(), 'compte': e.compte,
          'libelle': e.libelle, 'debit': e.debit, 'credit': e.credit,
          'ref_id': e.refId.isEmpty ? null : e.refId,
          'boutique_id': e.boutiqueId,
          'created_by': _c!.auth.currentUser?.id,
        };
        try {
          await _c!.from('ecritures').upsert(
              {...base, 'pointee': e.pointee},
              onConflict: 'id');
        } catch (_) {
          // Base non migrée (colonne absente) : repli sans la colonne.
          await _c!.from('ecritures').upsert(base, onConflict: 'id');
        }
      });

  /// Pointage de rapprochement : nécessite la policy UPDATE dédiée
  /// (supabase_fonctions_rls.sql) — sans elle, refus RLS silencieux.
  static Future<void> upsertEcriturePointee(String id, bool pointee) =>
      _silencieux(() async {
        await _c!
            .from('ecritures')
            .update({'pointee': pointee}).eq('id', id);
      });

  static Future<void> upsertTarif(Tarif t) => _silencieux(() async {
        await _c!.from('tarifs').upsert({
          'id': t.id, 'libelle': t.libelle, 'categorie': t.categorie,
          'prix': t.prix, 'description': t.description, 'actif': t.actif,
        });
      });

  /// Achat fournisseur : en-tête + lignes JSONB (même pattern que les
  /// transactions — une seule table, pas de RLS sur une table de lignes).
  static Future<void> upsertAchat(Achat a) => _silencieux(() async {
        await _c!.from('achats').upsert({
          'id': a.id, 'numero': a.numero, 'boutique_id': a.boutiqueId,
          'fournisseur_id':
              a.fournisseurId.isEmpty ? null : a.fournisseurId,
          'fournisseur_nom': a.fournisseurNom,
          'lignes': [for (final l in a.lignes) l.toJson()],
          'date_achat': a.date.toIso8601String(), 'statut': a.statut,
          'mode_paiement': a.modePaiement,
          'reference_facture': a.referenceFacture, 'notes': a.notes,
          'motif_annulation': a.motifAnnulation,
          'montant_paye': a.montantPaye,
          'created_by': _c!.auth.currentUser?.id,
        }, onConflict: 'id');
      });

  static Future<void> _silencieux(Future<void> Function() fn) async {
    if (!actif) return;
    try {
      await fn();
    } catch (e) {
      // ATTENTION — écart connu : contrairement à ce que le commentaire
      // laissait penser, rien ici ne remet l'opération dans la file
      // SyncService (seul ajouterTransaction() dans store.dart appelle
      // SyncService().mettreEnFile()). Un échec passant par _silencieux
      // (updateProfile, upsertClient, upsertFournisseur, etc.) est donc
      // réellement perdu si l'appareil est hors-ligne à ce moment précis
      // — juste visible ici en debug plutôt qu'invisible à 100 %. Une
      // vraie file d'attente pour ces écritures reste à faire.
      debugPrint('⚠️ CloudRepository (silencieux, non retenté) : $e');
    }
  }

  static Future<T?> _silencieuxRetour<T>(Future<T?> Function() fn) async {
    if (!actif) return null;
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  /// UUID v4 généré côté client (le schéma Postgres attend des UUID).
  /// Random.secure() (RNG du système) : imprévisibles et sans collision,
  /// y compris en génération rapide. Format 8-4-4-4-12, version 4.
  static final _rng = Random.secure();

  static String uuid() {
    String h() => (_rng.nextInt(0x10000) | 0).toRadixString(16).padLeft(4, '0');
    final s1 = h() + h();
    final s2 = h();
    final s3 = '4${h().substring(1)}';
    final s4 = h(); // bits variant déjà positionnés par masque
    final s5 = h() + h() + h();
    return '$s1-$s2-$s3-$s4-$s5'
        .replaceRange(19, 20, ((int.parse(s4[0], radix: 16) & 0x3 | 0x8).toRadixString(16)));
  }
}
