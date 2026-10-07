import '../../models/achat.dart';
import '../../models/app_user.dart';
import '../../models/boutique.dart';
import '../../models/charge.dart';
import '../../models/client.dart';
import '../../models/company_profile.dart';
import '../../models/document.dart';
import '../../services/document_service.dart';
import '../../models/ecriture.dart';
import '../../models/enums.dart';
import '../../models/evenement.dart';
import '../../models/feedback.dart';
import '../../models/fournisseur.dart';
import '../../models/message.dart';
import '../../models/mouvement_stock.dart';
import '../../models/partenaire.dart';
import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../../models/transaction.dart';
import '../../services/cloud_repository.dart'
    show CloudRepository, CloudTx;
import '../../services/media_service.dart';
import '../../services/supabase_service.dart';
import '../persistence/serializer.dart';

/// Chargement production (Phase 6) : contenu déplacé à l'identique de
/// `Store.chargerDuCloud` (traduction lignes Supabase → modèles).
/// Les accès réseau／Supabase sont injectés en paramètres pour tester
/// la traduction sans backend (`cloud_loader_test.dart`).
class CloudLoader {
  const CloudLoader._();

  /// Charge tout depuis Supabase puis traduit. Retourne null si le
  /// backend est injoignable (l'appelant bascule sur le snapshot
  /// local). [signatureLocale] et [chargerLignesDocs] sont injectés
  /// (défaut : implémentations cloud réelles).
  static Future<StoreSnapshot?> chargerSnapshot({
    required AppUser sessionUser,
    required String? sessionPartenaireId,
    required bool sessionProfilManquant,
    required String Function() genererId,
    Future<String?> Function(String? chemin)? signatureLocale,
    Future<Map<String, List<Map<String, dynamic>>>> Function(
            List docRows)?
        chargerLignesDocs,
    String? uidReelForTest,
  }) async {
    final data = await CloudRepository.chargerTout();
    if (data == null) return null;
    return traduire(
      data,
      sessionUser: sessionUser,
      sessionPartenaireId: sessionPartenaireId,
      sessionProfilManquant: sessionProfilManquant,
      genererId: genererId,
      signatureLocale: signatureLocale,
      chargerLignesDocs: chargerLignesDocs,
      uidReelForTest: uidReelForTest,
    );
  }

  /// Alias de lecture : charge tout depuis Supabase et traduit en
  /// snapshot (null si le backend est injoignable).
  static Future<StoreSnapshot?> chargerTout({
    required AppUser sessionUser,
    required String? sessionPartenaireId,
    required bool sessionProfilManquant,
    required String Function() genererId,
  }) =>
      chargerSnapshot(
        sessionUser: sessionUser,
        sessionPartenaireId: sessionPartenaireId,
        sessionProfilManquant: sessionProfilManquant,
        genererId: genererId,
      );

  /// Traduction pure (testable) des lignes Supabase → snapshot.
  /// Reconstruit un produit depuis sa ligne Supabase.
  ///
  /// La galerie est resolue AVANT le constructeur afin de pouvoir servir
  /// de repli a `image_path` : les lignes ecrites avant la 1.13.4
  /// portent `image_path` nul alors que `images` contient la photo (le
  /// constructeur ne derivait alors rien). Sans ce repli la photo
  /// restait invisible au chargement du cloud. Regle unique de
  /// resolution : [Produit.principal].
  static Produit _produit(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final galerie = <String>[
      for (final u in (r['images'] as List? ?? const []))
        MediaService.normaliserChemin(u.toString(),
                entite: 'produit', id: id) ??
            u.toString(),
    ];
    return Produit(
      id: id,
      boutiqueId: r['boutique_id'].toString(),
      libelle: r['libelle'].toString(),
      categorie: r['categorie'].toString(),
      prixAchat: (r['prix_achat'] as num?)?.toDouble() ?? 0,
      prixVente: (r['prix_vente'] as num?)?.toDouble() ?? 0,
      stock: (r['quantite_stock'] as num?)?.toInt() ?? 0,
      seuil: (r['seuil_alerte'] as num?)?.toInt() ?? 3,
      dateAjout: DateTime.tryParse(r['date_ajout']?.toString() ?? ''),
      imagePath: Produit.principal(
        imagePath: MediaService.normaliserChemin(
            r['image_path']?.toString(),
            entite: 'produit',
            id: id),
        images: galerie,
      ),
      images: galerie,
    );
  }

  static Future<StoreSnapshot> traduire(
    Map<String, dynamic> data, {
    required AppUser sessionUser,
    required String? sessionPartenaireId,
    required bool sessionProfilManquant,
    required String Function() genererId,
    Future<String?> Function(String? chemin)? signatureLocale,
    Future<Map<String, List<Map<String, dynamic>>>> Function(
            List docRows)?
        chargerLignesDocs,
    String? uidReelForTest,
  }) async {
    final p = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
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
        moisChargesGenerees:
            p['mois_charges_generees']?.toString(),
      ),
      user: sessionUser,
      monPartenaireId: sessionPartenaireId,
      profilCloudManquant: sessionProfilManquant,
    );
    s.boutiques.addAll([
      for (final b in (data['boutiques'] as List))
        Boutique(
            id: b['id'].toString(),
            nom: b['nom'].toString(),
            adresse: b['adresse']?.toString() ?? '',
            siege: b['siege'] == true),
    ]);
    s.produits.addAll([
      for (final r in (data['produits'] as List)) _produit(r as Map<String, dynamic>),
    ]);
    s.partenaires.addAll([
      for (final r in (data['partenaires'] as List))
        Partenaire(
          id: r['id'].toString(),
          nom: r['nom'].toString(),
          telephone: r['telephone']?.toString() ?? '',
          localisation: r['localisation']?.toString() ?? '',
          taux: (r['taux_partage'] as num?)?.toDouble() ?? 0.60,
        ),
    ]);
    s.transactions.addAll([
      for (final r in (data['transactions'] as List))
        Tx(
          id: r['id'].toString(),
          boutiqueId: r['boutique_id'].toString(),
          employeId: r['employe_id']?.toString() ?? s.user.id,
          type: CloudTx.type(r['type']),
          montant: (r['montant'] as num?)?.toDouble() ?? 0,
          cout: (r['cout'] as num?)?.toDouble() ?? 0,
          statut: StatutPaiement.values
              .byName(r['statut']?.toString() ?? 'paye'),
          clientNom: r['client_nom']?.toString(),
          partenaireId: r['partenaire_id']?.toString(),
          details:
              Map<String, dynamic>.from(r['details'] as Map? ?? {}),
          date: DateTime.tryParse(
                  r['date_transaction']?.toString() ?? '') ??
              DateTime.now(),
        ),
    ]);
    s.depenses.addAll([
      for (final r in (data['charges'] as List))
        Charge(
          id: r['id'].toString(),
          boutiqueId: r['boutique_id'].toString(),
          categorie: r['categorie'].toString(),
          libelle: r['libelle'].toString(),
          montant: (r['montant'] as num?)?.toDouble() ?? 0,
          date: DateTime.tryParse(
                  r['date_charge']?.toString() ?? '') ??
              DateTime.now(),
          recurrente: r['recurrente'] == true,
        ),
    ]);
    s.profile = s.profile.copyWith(
      budgetsMensuels: {
        for (final r in (data['budgets'] as List))
          r['categorie'].toString():
              (r['montant'] as num?)?.toDouble() ?? 0,
      },
      fondsRoulement: {
        for (final r in (data['fonds'] as List))
          r['boutique_id'].toString():
              (r['montant'] as num?)?.toDouble() ?? 0,
      },
    );
    // Rôle et boutiques de l'utilisateur connecté (`id: user.id`
    // local 'u_admin' = bug racine uuid 22P02 — origine conservée :
    // vrai uuid Supabase, rôle minimal si non provisionné).
    final mp = data['mon_profil'] as Map?;
    final uidReel = uidReelForTest ??
        SupabaseService.client?.auth.currentUser?.id;
    if (mp != null) {
      s.profilCloudManquant = false;
      s.user = AppUser(
        id: mp['id'].toString(),
        nom: mp['nom']?.toString() ?? s.user.nom,
        role: Role.values.byName(mp['role']?.toString() ?? 'vendeur'),
        boutiqueIds: [
          for (final b in (data['mes_boutiques'] as List))
            b['boutique_id'].toString(),
        ],
        partenaireId: mp['partenaire_id']?.toString(),
      );
      s.monPartenaireId = mp['partenaire_id']?.toString();
    } else if (uidReel != null) {
      s.profilCloudManquant = true;
      s.user =
          AppUser(id: uidReel, nom: s.user.nom, role: Role.stagiaire);
    }
    final parUser = <String, List<String>>{};
    for (final ub in (data['user_boutiques'] as List? ?? const [])) {
      parUser
          .putIfAbsent(ub['user_id'].toString(), () => [])
          .add(ub['boutique_id'].toString());
    }
    s.users.addAll([
      for (final r in (data['users'] as List? ?? const []))
        AppUser(
          id: r['id'].toString(),
          nom: r['nom']?.toString() ?? '',
          role: Role.values.byName(r['role']?.toString() ?? 'vendeur'),
          boutiqueIds: parUser[r['id'].toString()] ?? const [],
          partenaireId: r['partenaire_id']?.toString(),
        ),
    ]);
    // Catégories dynamiques (cloud prioritaire sur les défauts ;
    // listes vides = absentes, fusion dans `_appliquerSnapshot`).
    final cats = data['categories'] as List? ?? const [];
    List<String> parType(String type) => [
          for (final r in cats.where((r) => r['type'] == type))
            r['nom'].toString()
        ];
    s.catsProduit.addAll(parType('produit'));
    s.catsCharge.addAll(parType('charge'));
    s.opsMobileMoney.addAll(parType('operateur_momo'));
    s.opsCredit.addAll(parType('operateur_credit'));
    s.domainesPresta.addAll(parType('domaine_prestation'));
    s.dureesForfaitListe.addAll(parType('duree_forfait'));
    s.clients.addAll([
      for (final r in (data['clients'] as List? ?? []))
        Client(
          id: r['id'].toString(),
          boutiqueId: r['boutique_id'].toString(),
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
    s.fournisseurs.addAll([
      for (final r in (data['fournisseurs'] as List? ?? []))
        Fournisseur(
          id: r['id'].toString(),
          nom: r['nom'].toString(),
          telephone: r['telephone']?.toString() ?? '',
          email: r['email']?.toString() ?? '',
          adresse: r['adresse']?.toString() ?? '',
          specialite: r['specialite']?.toString() ?? '',
          notes: r['notes']?.toString() ?? '',
        ),
    ]);
    s.messages.addAll([
      for (final r in (data['messages'] as List? ?? []))
        Message(
          id: r['id'].toString(),
          expediteurId: r['expediteur_id'].toString(),
          expediteurNom: r['expediteur_nom']?.toString() ?? '',
          destinataireId: r['destinataire_id'].toString(),
          sujet: r['sujet']?.toString() ?? '',
          contenu: r['contenu']?.toString() ?? '',
          date: DateTime.tryParse(
                  r['created_at']?.toString() ?? '') ??
              DateTime.now(),
          lu: r['lu'] == true,
        ),
    ]);
    s.evenements.addAll([
      for (final r in (data['evenements'] as List? ?? []))
        Evenement(
          id: r['id'].toString(),
          titre: r['titre'].toString(),
          date: DateTime.tryParse(r['date']?.toString() ?? '') ??
              DateTime.now(),
          heure: r['heure']?.toString() ?? '',
          lieu: r['lieu']?.toString() ?? '',
          description: r['description']?.toString() ?? '',
          createurId: r['createur_id']?.toString() ?? '',
        ),
    ]);
    s.notesPerso.addAll([
      for (final r in (data['notes'] as List? ?? []))
        Note(
          id: r['id'].toString(),
          titre: r['titre'].toString(),
          contenu: r['contenu']?.toString() ?? '',
          date: DateTime.tryParse(
                  r['created_at']?.toString() ?? '') ??
              DateTime.now(),
          rappelLe:
              DateTime.tryParse(r['rappel_le']?.toString() ?? ''),
          createurId: r['createur_id']?.toString() ?? '',
        ),
    ]);
    s.feedbacks.addAll([
      for (final r in (data['feedbacks'] as List? ?? []))
        Feedback(
          id: r['id'].toString(),
          auteurId: r['auteur_id'].toString(),
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
          date: DateTime.tryParse(
                  r['created_at']?.toString() ?? '') ??
              DateTime.now(),
        ),
    ]);
    s.catalogue.addAll([
      for (final r in (data['catalogue'] as List? ?? []))
        Tarif(
          id: r['id'].toString(),
          libelle: r['libelle'].toString(),
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
    s.achats.addAll([
      for (final r in (data['achats'] as List? ?? []))
        Achat(
          id: r['id'].toString(),
          numero: r['numero']?.toString() ?? '',
          boutiqueId: r['boutique_id']?.toString() ?? '',
          fournisseurId: r['fournisseur_id']?.toString() ?? '',
          fournisseurNom: r['fournisseur_nom']?.toString() ?? '',
          lignes: [
            for (final l in (r['lignes'] as List? ?? const []))
              LigneAchat.fromJson(
                  Map<String, dynamic>.from(l as Map)),
          ],
          date: DateTime.tryParse(
                  r['date_achat']?.toString() ?? '') ??
              DateTime.now(),
          statut: r['statut']?.toString() ?? Achat.statutEnAttente,
          modePaiement: r['mode_paiement']?.toString() ?? 'especes',
          referenceFacture: r['reference_facture']?.toString(),
          notes: r['notes']?.toString(),
          motifAnnulation: r['motif_annulation']?.toString(),
          montantPaye:
              (r['montant_paye'] as num?)?.toDouble() ?? 0,
          createdBy: r['created_by']?.toString() ?? '',
          createdAt: DateTime.tryParse(
                  r['created_at']?.toString() ?? '') ??
              DateTime.now(),
        ),
    ]);
    s.mouvements.addAll([
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
    s.ecritures.addAll([
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
    // Historique des documents (cloud → reconstruction complète).
    final docRows = data['documents'] as List? ?? [];
    if (docRows.isNotEmpty) {
      final charger =
          chargerLignesDocs ?? CloudRepository.chargerDocuments;
      final lignesParDoc = await charger(docRows);
      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      // Texte cloud Possibly null (colonne absente sur une base non
      // migree) -> chaine vide, jamais `null` : le PDF teste isNotEmpty.
      String _txt(Object? v) => v?.toString() ?? '';
      final Future<String?> Function(String?) signer =
          signatureLocale ??
              ((c) async => c == null || c.isEmpty
                  ? null
                  : CloudRepository.telechargerSignature(c));
      s.documentsEmis.addAll([
        for (final r in docRows)
          DocumentBati(
            id: r['id'].toString(),
            type: typeDocumentDepuisDb(r['type'].toString()),
            numero: r['numero'].toString(),
            date: fmt(DateTime.tryParse(
                    r['date_doc']?.toString() ?? '') ??
                DateTime.now()),
            client: r['client_nom']?.toString() ?? '',
            lignes: [
              for (final l
                  in lignesParDoc[r['id'].toString()] ?? const [])
                LigneDoc.fromMap(
                    (l as Map).cast<String, dynamic>()),
            ],
            totalHT: (r['total_ht'] as num?)?.toDouble() ?? 0,
            tva: (r['tva'] as num?)?.toDouble() ?? 0,
            totalTTC: (r['total_ttc'] as num?)?.toDouble() ?? 0,
            devise: s.profile.devise,
            statut: r['statut']?.toString() ?? 'emis',
            // Colonnes de DML_DATES_DOCUMENTS.sql : absentes sur une base
            // non migree -> repli neutre, jamais une valeur nulle
            // (le PDF teste `isNotEmpty`).
            note: _txt(r['note']),
            adresseLivraison: _txt(r['adresse_livraison']),
            echeance: _txt(r['echeance']),
            delaiPaiementJours:
                (r['delai_paiement_jours'] as num?)?.round() ?? 0,
            signatureClientPath: await signer(
                r['signature_client_path']?.toString()),
          ),
      ]);
    }
    // Journal des corrections : charge APRES les documents, sinon les
    // numeros a interroger ne sont pas encore connus.
    // Le journal est charge par l'appelant (Store.chargerDuCloud), apres
    // application du snapshot : ici les documents ne sont pas encore
    // dans le notifier.

    // Boutique courante : première accessible (origine conservée).
    if (s.boutiques.isNotEmpty) {
      s.boutiqueId = s.boutiques
          .firstWhere(
              (b) =>
                  s.user.accedeA(b.id) ||
                  s.user.role == Role.admin,
              orElse: () => s.boutiques.first)
          .id;
    }
    return s;
  }

  /// Passe réparatrice (plan A2 §Action 4, ex-`Store`) : chemins http
  /// re-téléchargés en local. Persiste + notifie si au moins un chemin
  /// a changé. Jamais d'exception, jamais de blocage du démarrage.
  static bool _reparationEnCours = false;

  /// Répare les chemins distants puis, si un chemin a changé, persiste et
  /// notifie. [getProfile] est relu après chaque écriture.
  static Future<void> reparerImages(
    List<Produit> produits,
    List<Tarif> catalogue,
    List<Client> clients,
    CompanyProfile Function() getProfile,
    void Function(CompanyProfile) setProfile,
    void Function() persist,
    void Function() notify,
  ) async {
    final change = await reparerImagesDistantes(
      produits: produits,
      catalogue: catalogue,
      clients: clients,
      profile: getProfile(),
      setProfile: setProfile,
    );
    if (change) {
      persist();
      notify();
    }
  }

  static Future<bool> reparerImagesDistantes({
    required List<Produit> produits,
    required List<Tarif> catalogue,
    required List<Client> clients,
    required CompanyProfile profile,
    required void Function(CompanyProfile p) setProfile,
  }) async {
    if (_reparationEnCours) return false;
    _reparationEnCours = true;
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
        final principal = await MediaService.assurerLocal(
            p.imagePath,
            entite: 'produit',
            id: p.id);
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
              id: c.id,
              boutiqueId: c.boutiqueId,
              nom: c.nom,
              telephone: c.telephone,
              email: c.email,
              adresse: c.adresse,
              rccm: c.rccm,
              ifu: c.ifu,
              rib: c.rib,
              logoPath: logo);
          change = true;
        }
      }
      final logo = await MediaService.assurerLocal(profile.logoPath,
          entite: 'company', id: 'logo');
      final cachet = await MediaService.assurerLocal(
          profile.cachetPath,
          entite: 'company',
          id: 'cachet');
      final signature = await MediaService.assurerLocal(
          profile.signaturePath,
          entite: 'company',
          id: 'signature');
      if (logo != profile.logoPath ||
          cachet != profile.cachetPath ||
          signature != profile.signaturePath) {
        setProfile(profile.copyWith(
          logoPath: logo ?? profile.logoPath,
          cachetPath: cachet ?? profile.cachetPath,
          signaturePath: signature ?? profile.signaturePath,
        ));
        change = true;
      }
    } catch (_) {
      // Réparation opportuniste : un échec ne bloque jamais l'app.
    } finally {
      _reparationEnCours = false;
    }
    return change;
  }

  static bool _memeListe(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);
}
