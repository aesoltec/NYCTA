import '../../models/achat.dart';
import '../store.dart';
import '../../models/app_user.dart';
import '../../models/boutique.dart';
import '../../models/charge.dart';
import '../../models/client.dart';
import '../../models/company_profile.dart';
import '../../services/document_service.dart';
import '../../models/ecriture.dart';
import '../../models/enums.dart';
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
import '../../services/media_service.dart';

/// Photo d'état du Store (Phase 6) : structure intermédiaire TYPÉE
/// entre les sources (JSON local, lignes Supabase) et les listes du
/// Store. Les deux sources ont des formats de clés différents
/// (`date` vs `date_transaction`, catégories Map vs List…) : chaque
/// lecteur (serializer local, cloud_loader) construit un snapshot,
/// et `Store._appliquerSnapshot` l'applique en un seul endroit.
/// Comportement recopié à l'identique de `Store` (pas de migration
/// de format : les snapshots existants restent lisibles).
class StoreSnapshot {
  CompanyProfile profile;
  AppUser user;
  List<AppUser> users;
  String? monPartenaireId;
  bool profilCloudManquant;
  String boutiqueId;
  List<Boutique> boutiques;
  List<Tx> transactions;
  List<Produit> produits;
  List<Partenaire> partenaires;
  List<Partage> partages;
  List<Charge> depenses;
  List<Client> clients;
  List<Fournisseur> fournisseurs;
  List<Message> messages;
  List<Evenement> evenements;
  List<Note> notesPerso;
  List<Feedback> feedbacks;
  List<Tarif> catalogue;
  List<DocumentBati> documentsEmis;
  List<Achat> achats;
  List<MouvementStock> mouvements;
  List<Ecriture> ecritures;
  List<String> catsProduit;
  List<String> catsCharge;
  List<String> opsMobileMoney;
  List<String> opsCredit;
  List<String> domainesPresta;
  List<String> dureesForfaitListe;

  StoreSnapshot({
    this.profile = const CompanyProfile(),
    AppUser? user,
    List<AppUser>? users,
    this.monPartenaireId,
    this.profilCloudManquant = false,
    this.boutiqueId = '',
    List<Boutique>? boutiques,
    List<Tx>? transactions,
    List<Produit>? produits,
    List<Partenaire>? partenaires,
    List<Partage>? partages,
    List<Charge>? depenses,
    List<Client>? clients,
    List<Fournisseur>? fournisseurs,
    List<Message>? messages,
    List<Evenement>? evenements,
    List<Note>? notesPerso,
    List<Feedback>? feedbacks,
    List<Tarif>? catalogue,
    List<DocumentBati>? documentsEmis,
    List<Achat>? achats,
    List<MouvementStock>? mouvements,
    List<Ecriture>? ecritures,
    List<String>? catsProduit,
    List<String>? catsCharge,
    List<String>? opsMobileMoney,
    List<String>? opsCredit,
    List<String>? domainesPresta,
    List<String>? dureesForfaitListe,
  })  : user = user ??
            const AppUser(id: '', nom: '', role: Role.stagiaire),
        users = users ?? [],
        boutiques = boutiques ?? [],
        transactions = transactions ?? [],
        produits = produits ?? [],
        partenaires = partenaires ?? [],
        partages = partages ?? [],
        depenses = depenses ?? [],
        clients = clients ?? [],
        fournisseurs = fournisseurs ?? [],
        messages = messages ?? [],
        evenements = evenements ?? [],
        notesPerso = notesPerso ?? [],
        feedbacks = feedbacks ?? [],
        catalogue = catalogue ?? [],
        documentsEmis = documentsEmis ?? [],
        achats = achats ?? [],
        mouvements = mouvements ?? [],
        ecritures = ecritures ?? [],
        catsProduit = catsProduit ?? [],
        catsCharge = catsCharge ?? [],
        opsMobileMoney = opsMobileMoney ?? [],
        opsCredit = opsCredit ?? [],
        domainesPresta = domainesPresta ?? [],
        dureesForfaitListe = dureesForfaitListe ?? [];
}

/// Sérialisation locale (Phase 6) : contenu déplacé à l'identique de
/// `Store.toJson` / `Store._chargerEtat`. Les documents ne sont pas
/// persistés en local (comportement d'origine conservé).
class StoreSerializer {
  const StoreSerializer._();

  /// Snapshot typé depuis l'état courant du Store (listes partagées, sans
  /// copie). Séparé de [toJson] pour que la façade reste lisible.
  static StoreSnapshot capturer(Store store) => StoreSnapshot(
        profile: store.profile,
        user: store.user,
        users: store.users,
        monPartenaireId: store.monPartenaireId,
        profilCloudManquant: store.profilCloudManquant,
        boutiqueId: store.boutiqueId,
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
        catsProduit: store.catsProduit,
        catsCharge: store.catsCharge,
        opsMobileMoney: store.opsMobileMoney,
        opsCredit: store.opsCredit,
        domainesPresta: store.domainesPresta,
        dureesForfaitListe: store.dureesForfaitListe,
      );

  /// Snapshot → JSON local (ex-`Store.toJson`).
  static Map<String, dynamic> toJson(StoreSnapshot s) => {
        'version': 1,
        'boutique_id_courante': s.boutiqueId,
        'profil': {
          'nom_entreprise': s.profile.nomEntreprise,
          'devise': s.profile.devise,
          'telephone': s.profile.telephone,
          'telephone2': s.profile.telephone2,
          'email': s.profile.email,
          'adresse': s.profile.adresse,
          'rccm': s.profile.rccm,
          'ifu': s.profile.ifu,
          'autre_ref_fiscale': s.profile.autreRefFiscale,
          'banque': s.profile.banque,
          'coordonnees_bancaires': s.profile.coordonneesBancaires,
          'message_pied': s.profile.messagePied,
          'tva': s.profile.tva,
          'logo_path': s.profile.logoPath,
          'cachet_path': s.profile.cachetPath,
          'signature_path': s.profile.signaturePath,
          'fonds_roulement': s.profile.fondsRoulement,
          'budgets': s.profile.budgetsMensuels,
          'compteurs': s.profile.compteursDocs,
          'mois_charges_generees': s.profile.moisChargesGenerees,
        },
        'utilisateur': {
          'id': s.user.id,
          'nom': s.user.nom,
          'role': s.user.role.name,
          'boutique_ids': s.user.boutiqueIds,
        },
        'utilisateurs': [
          for (final u in s.users)
            {
              'id': u.id,
              'nom': u.nom,
              'role': u.role.name,
              'boutique_ids': u.boutiqueIds
            },
        ],
        'boutiques': [
          for (final b in s.boutiques)
            {
              'id': b.id,
              'nom': b.nom,
              'adresse': b.adresse,
              'siege': b.siege,
              'actif': b.actif
            },
        ],
        'categories': {
          'produits': s.catsProduit,
          'charges': s.catsCharge,
          'operateurs_mobile_money': s.opsMobileMoney,
          'operateurs_credit': s.opsCredit,
          'domaines_prestation': s.domainesPresta,
          'durees_forfait': s.dureesForfaitListe,
        },
        'clients': [
          for (final c in s.clients)
            {
              'id': c.id,
              'boutique_id': c.boutiqueId,
              'nom': c.nom,
              'telephone': c.telephone,
              'email': c.email,
              'adresse': c.adresse,
              'rccm': c.rccm,
              'ifu': c.ifu,
              'rib': c.rib,
              'logo_path': c.logoPath
            },
        ],
        'fournisseurs': [
          for (final f in s.fournisseurs)
            {
              'id': f.id,
              'nom': f.nom,
              'telephone': f.telephone,
              'email': f.email,
              'adresse': f.adresse,
              'specialite': f.specialite,
              'notes': f.notes
            },
        ],
        'messages': [
          for (final m in s.messages)
            {
              'id': m.id,
              'expediteur_id': m.expediteurId,
              'expediteur_nom': m.expediteurNom,
              'destinataire_id': m.destinataireId,
              'sujet': m.sujet,
              'contenu': m.contenu,
              'date': m.date.toIso8601String(),
              'lu': m.lu
            },
        ],
        'evenements': [
          for (final e in s.evenements)
            {
              'id': e.id,
              'titre': e.titre,
              'date': e.date.toIso8601String(),
              'heure': e.heure,
              'lieu': e.lieu,
              'description': e.description,
              'createur_id': e.createurId
            },
        ],
        'catalogue': [
          for (final t in s.catalogue)
            {
              'id': t.id,
              'libelle': t.libelle,
              'categorie': t.categorie,
              'prix': t.prix,
              'description': t.description,
              'actif': t.actif,
              'images': t.images,
              'date_ajout': t.dateAjout?.toIso8601String()
            },
        ],
        'feedbacks': [
          for (final f in s.feedbacks)
            {
              'id': f.id,
              'auteur_id': f.auteurId,
              'auteur_nom': f.auteurNom,
              'boutique_id': f.boutiqueId,
              'type': f.type.name,
              'priorite': f.priorite.name,
              'titre': f.titre,
              'contenu': f.contenu,
              'statut': f.statut.name,
              'date': f.date.toIso8601String()
            },
        ],
        'notes': [
          for (final n in s.notesPerso)
            {
              'id': n.id,
              'titre': n.titre,
              'contenu': n.contenu,
              'date': n.date.toIso8601String(),
              'rappel_le': n.rappelLe?.toIso8601String(),
              'createur_id': n.createurId
            },
        ],
        'produits': [
          for (final p in s.produits)
            {
              'id': p.id,
              'boutique_id': p.boutiqueId,
              'libelle': p.libelle,
              'categorie': p.categorie,
              'prix_achat': p.prixAchat,
              'prix_vente': p.prixVente,
              'stock': p.stock,
              'seuil': p.seuil,
              'image_path': p.imagePath,
              'images': p.images,
              'date_ajout': p.dateAjout?.toIso8601String()
            },
        ],
        'partenaires': [
          for (final p in s.partenaires)
            {
              'id': p.id,
              'nom': p.nom,
              'telephone': p.telephone,
              'localisation': p.localisation,
              'taux': p.taux
            },
        ],
        'transactions': [
          for (final t in s.transactions)
            {
              'id': t.id,
              'boutique_id': t.boutiqueId,
              'type': t.type.name,
              'montant': t.montant,
              'cout': t.cout,
              'statut': t.statut.name,
              'client_nom': t.clientNom,
              'partenaire_id': t.partenaireId,
              'details': t.details,
              'date': t.date.toIso8601String()
            },
        ],
        'charges': [
          for (final c in s.depenses)
            {
              'id': c.id,
              'boutique_id': c.boutiqueId,
              'categorie': c.categorie,
              'libelle': c.libelle,
              'montant': c.montant,
              'date': c.date.toIso8601String(),
              'recurrente': c.recurrente
            },
        ],
        'partages': [
          for (final p in s.partages)
            {
              'partenaire_id': p.partenaireId,
              'mois': p.mois,
              'total_ventes': p.totalVentes,
              'taux': p.taux,
              'part_partenaire': p.partPartenaire,
              'part_entreprise': p.partEntreprise
            },
        ],
        'achats': [for (final a in s.achats) a.toJson()],
        'mouvements': [for (final m in s.mouvements) m.toJson()],
        'ecritures': [for (final e in s.ecritures) e.toJson()],
      };

  /// JSON local → snapshot (ex-`Store._chargerEtat`, sans l'affectation).
  /// [utilisateurSecours] : identité de session conservée quand le
  /// snapshot ne la contient pas (les transactions restaurées portent
  /// alors cet auteur — origine : `user.id` de session).
  /// [genererId] : ids des partages reconstruits (calculés, jamais
  /// persistés — origine conservée).
  /// Reconstruit un produit depuis sa ligne serialisee.
  ///
  /// La galerie est resolue AVANT le constructeur afin de pouvoir servir
  /// de repli a `image_path` : les instantanes ecrits par les versions
  /// anterieures a la 1.13.4 contiennent `image_path: null` avec une
  /// galerie NON vide (le constructeur ne derivait alors rien du tout),
  /// donc la photo y restait invisible meme si elle etait la. Regle
  /// unique de resolution : [Produit.principal].
  static Produit _produit(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final galerie = <String>[
      for (final u in (p['images'] as List? ?? const []))
        MediaService.normaliserChemin(u.toString(),
                entite: 'produit', id: id) ??
            u.toString(),
    ];
    return Produit(
      id: id,
      boutiqueId: p['boutique_id'].toString(),
      libelle: p['libelle'].toString(),
      categorie: p['categorie'].toString(),
      prixAchat: (p['prix_achat'] as num?)?.toDouble() ?? 0,
      prixVente: (p['prix_vente'] as num?)?.toDouble() ?? 0,
      stock: (p['stock'] as num?)?.toInt() ?? 0,
      seuil: (p['seuil'] as num?)?.toInt() ?? 3,
      dateAjout: DateTime.tryParse(p['date_ajout']?.toString() ?? ''),
      imagePath: Produit.principal(
        imagePath: MediaService.normaliserChemin(
            p['image_path']?.toString(),
            entite: 'produit',
            id: id),
        images: galerie,
      ),
      images: galerie,
    );
  }

  static StoreSnapshot fromJson(
    Map<String, dynamic> data, {
    AppUser? utilisateurSecours,
    String Function()? genererId,
  }) {
    final p = Map<String, dynamic>.from(data['profil'] as Map? ?? {});
    String nid() =>
        genererId != null ? genererId() : 'snapshot_sans_id';
    final s = StoreSnapshot(
      profile: CompanyProfile(
        nomEntreprise:
            p['nom_entreprise']?.toString() ?? 'Mon Entreprise',
        devise: p['devise']?.toString() ?? 'FCFA',
        telephone: p['telephone']?.toString() ?? '',
        telephone2: p['telephone2']?.toString() ?? '',
        email: p['email']?.toString() ?? '',
        adresse: p['adresse']?.toString() ?? '',
        rccm: p['rccm']?.toString() ?? '',
        ifu: p['ifu']?.toString() ?? '',
        autreRefFiscale: p['autre_ref_fiscale']?.toString() ?? '',
        banque: p['banque']?.toString() ?? '',
        coordonneesBancaires:
            p['coordonnees_bancaires']?.toString() ?? '',
        messagePied: p['message_pied']?.toString() ?? '',
        tva: (p['tva'] as num?)?.toDouble() ?? 0,
        logoPath: MediaService.normaliserChemin(
            p['logo_path']?.toString(),
            entite: 'company',
            id: 'logo'),
        cachetPath: MediaService.normaliserChemin(
            p['cachet_path']?.toString(),
            entite: 'company',
            id: 'cachet'),
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
      ),
      user: AppUser(
        id: data['utilisateur']?['id']?.toString() ??
            utilisateurSecours?.id ??
            '',
        nom: data['utilisateur']?['nom']?.toString() ??
            utilisateurSecours?.nom ??
            '',
        role: Role.values.byName(
            data['utilisateur']?['role']?.toString() ?? 'admin'),
        boutiqueIds: List<String>.from(
            data['utilisateur']?['boutique_ids'] as List? ??
                const []),
      ),
      boutiqueId:
          data['boutique_id_courante']?.toString() ?? '',
    );
    s.users.addAll([
      for (final u in (data['utilisateurs'] as List? ?? []))
        AppUser(
          id: u['id'].toString(),
          nom: u['nom'].toString(),
          role: Role.values.byName(u['role'].toString()),
          boutiqueIds: List<String>.from(
              u['boutique_ids'] as List? ?? const []),
        ),
    ]);
    s.boutiques.addAll([
      for (final b in (data['boutiques'] as List? ?? []))
        Boutique(
            id: b['id'].toString(),
            nom: b['nom'].toString(),
            adresse: b['adresse']?.toString() ?? '',
            siege: b['siege'] == true,
            actif: b['actif'] != false),
    ]);
    final cats =
        Map<String, dynamic>.from(data['categories'] as Map? ?? {});
    List<String> cat(String cle) => [
          for (final c in (cats[cle] as List? ?? const []))
            c.toString()
        ];
    // Listes vides = absentes (la fusion cloud-prioritaire vit dans
    // `Store._appliquerSnapshot`, en un seul endroit).
    s.catsProduit.addAll(cat('produits'));
    s.catsCharge.addAll(cat('charges'));
    s.opsMobileMoney.addAll(cat('operateurs_mobile_money'));
    s.opsCredit.addAll(cat('operateurs_credit'));
    s.domainesPresta.addAll(cat('domaines_prestation'));
    s.dureesForfaitListe.addAll(cat('durees_forfait'));
    s.clients.addAll([
      for (final c in (data['clients'] as List? ?? []))
        Client(
          id: c['id'].toString(),
          boutiqueId: c['boutique_id'].toString(),
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
    s.fournisseurs.addAll([
      for (final f in (data['fournisseurs'] as List? ?? []))
        Fournisseur(
          id: f['id'].toString(),
          nom: f['nom'].toString(),
          telephone: f['telephone']?.toString() ?? '',
          email: f['email']?.toString() ?? '',
          adresse: f['adresse']?.toString() ?? '',
          specialite: f['specialite']?.toString() ?? '',
          notes: f['notes']?.toString() ?? '',
        ),
    ]);
    s.messages.addAll([
      for (final m in (data['messages'] as List? ?? []))
        Message(
          id: m['id'].toString(),
          expediteurId: m['expediteur_id'].toString(),
          expediteurNom: m['expediteur_nom']?.toString() ?? '',
          destinataireId: m['destinataire_id'].toString(),
          sujet: m['sujet']?.toString() ?? '',
          contenu: m['contenu']?.toString() ?? '',
          date: DateTime.tryParse(m['date']?.toString() ?? '') ??
              DateTime.now(),
          lu: m['lu'] == true,
        ),
    ]);
    s.evenements.addAll([
      for (final e in (data['evenements'] as List? ?? []))
        Evenement(
          id: e['id'].toString(),
          titre: e['titre'].toString(),
          date: DateTime.tryParse(e['date']?.toString() ?? '') ??
              DateTime.now(),
          heure: e['heure']?.toString() ?? '',
          lieu: e['lieu']?.toString() ?? '',
          description: e['description']?.toString() ?? '',
          createurId: e['createur_id']?.toString() ?? '',
        ),
    ]);
    s.catalogue.addAll([
      for (final t in (data['catalogue'] as List? ?? []))
        Tarif(
          id: t['id'].toString(),
          libelle: t['libelle'].toString(),
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
    s.feedbacks.addAll([
      for (final f in (data['feedbacks'] as List? ?? []))
        Feedback(
          id: f['id'].toString(),
          auteurId: f['auteur_id'].toString(),
          auteurNom: f['auteur_nom']?.toString() ?? '',
          boutiqueId: f['boutique_id']?.toString() ?? '',
          type: TypeFeedback.values
              .byName(f['type']?.toString() ?? 'suggestion'),
          priorite: PrioriteFeedback.values
              .byName(f['priorite']?.toString() ?? 'normale'),
          titre: f['titre']?.toString() ?? '',
          contenu: f['contenu']?.toString() ?? '',
          statut: StatutFeedback.values
              .byName(f['statut']?.toString() ?? 'nouveau'),
          date: DateTime.tryParse(f['date']?.toString() ?? '') ??
              DateTime.now(),
        ),
    ]);
    s.notesPerso.addAll([
      for (final n in (data['notes'] as List? ?? []))
        Note(
          id: n['id'].toString(),
          titre: n['titre'].toString(),
          contenu: n['contenu']?.toString() ?? '',
          date: DateTime.tryParse(n['date']?.toString() ?? '') ??
              DateTime.now(),
          rappelLe:
              DateTime.tryParse(n['rappel_le']?.toString() ?? ''),
          createurId: n['createur_id']?.toString() ?? '',
        ),
    ]);
    s.produits.addAll([
      for (final p in (data['produits'] as List? ?? [])) _produit(p as Map<String, dynamic>),
    ]);
    s.partenaires.addAll([
      for (final p in (data['partenaires'] as List? ?? []))
        Partenaire(
          id: p['id'].toString(),
          nom: p['nom'].toString(),
          telephone: p['telephone']?.toString() ?? '',
          localisation: p['localisation']?.toString() ?? '',
          taux: (p['taux'] as num?)?.toDouble() ?? 0.60,
        ),
    ]);
    s.transactions.addAll([
      for (final t in (data['transactions'] as List? ?? []))
        Tx(
          id: t['id'].toString(),
          boutiqueId: t['boutique_id'].toString(),
          employeId: s.user.id,
          type: TypeTransaction.values.byName(t['type'].toString()),
          montant: (t['montant'] as num?)?.toDouble() ?? 0,
          cout: (t['cout'] as num?)?.toDouble() ?? 0,
          statut: StatutPaiement.values
              .byName(t['statut']?.toString() ?? 'paye'),
          clientNom: t['client_nom']?.toString(),
          partenaireId: t['partenaire_id']?.toString(),
          details:
              Map<String, dynamic>.from(t['details'] as Map? ?? {}),
          date: DateTime.tryParse(t['date']?.toString() ?? '') ??
              DateTime.now(),
        ),
    ]);
    s.depenses.addAll([
      for (final c in (data['charges'] as List? ?? []))
        Charge(
          id: c['id'].toString(),
          boutiqueId: c['boutique_id'].toString(),
          categorie: c['categorie'].toString(),
          libelle: c['libelle'].toString(),
          montant: (c['montant'] as num?)?.toDouble() ?? 0,
          date: DateTime.tryParse(c['date']?.toString() ?? '') ??
              DateTime.now(),
          recurrente: c['recurrente'] == true,
        ),
    ]);
    s.partages.addAll([
      for (final p in (data['partages'] as List? ?? []))
        Partage.calculer(
          id: nid(),
          partenaireId: p['partenaire_id'].toString(),
          mois: p['mois'].toString(),
          totalVentes:
              (p['total_ventes'] as num?)?.toDouble() ?? 0,
          taux: (p['taux'] as num?)?.toDouble() ?? 0.60,
        ),
    ]);
    s.achats.addAll([
      for (final a in (data['achats'] as List? ?? []))
        Achat.fromJson(Map<String, dynamic>.from(a as Map)),
    ]);
    s.mouvements.addAll([
      for (final m in (data['mouvements'] as List? ?? []))
        MouvementStock.fromJson(
            Map<String, dynamic>.from(m as Map)),
    ]);
    s.ecritures.addAll([
      for (final e in (data['ecritures'] as List? ?? []))
        Ecriture.fromJson(Map<String, dynamic>.from(e as Map)),
    ]);
    return s;
  }
}
