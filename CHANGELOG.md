# CHANGELOG — NYCTA / PME Gestion

> Historique des versions livrées (voir `CAHIER_DES_CHARGES.md` §9 pour le détail).

## 1.12.0 — 2026-09-29 (Phase 6bis — allègement RÉEL du Store)
- **Store : 1945 → 338 lignes** (objectif < 350). La 1.11.0 avait déplacé la logique dans des fichiers `part`, ce qui n'allège rien (1933 → 1945, soit +12) : régression annulée et refaite en vraies bibliothèques
- Suppression physique des 5 corps géants (1021 lignes) : `chargerDuCloud` (439), `_chargerEtat` (309), `toJson` (130), `_reparerImagesDistantes` (78), `_seedDemo` (65) → appels courts aux bibliothèques pures
- 129 délégations déplacées dans 9 vraies `extension on Store` (`lib/data/facade/*.dart` : achats, catalogue, collab, compta_docs, fichiers, session, stock, transverse, ventes), **ré-exportées par `store.dart`** → un seul import, zéro churn sur les 200+ appelants
- Nouvelles bibliothèques : `StoreSync` (catalogue depuis produit, journal, vente, payloads cloud/file, numérotation) + `SnapshotApplier` (fusion de snapshot, règle catégories cloud-prioritaire, restauration de sauvegarde) ; suppression de `store_persistence.dart` (doublon)
- Vérification anti-duplication : analyse croisée classe ↔ extensions → 0 doublon résiduel
- 3 membres privés devenus publics (`genererId`, `fileUpsert`, `numeroDocument`) + 7 lectures transverses en extension (`catsProduit`, `catsCharge`, `opsMobileMoney`, `opsCredit`, `domainesPresta`, `dureesForfaitListe`, `moisCourant`) — coût assumé et documenté d'une extraction réelle
- Nettoyage : 31 imports inutiles retirés (dont 2 blocs d'imports dupliqués dans `clients_screen.dart` / `fournisseurs_screen.dart`), `_memeLibelle` et `_memeListe` morts supprimés au profit de `StoreHelpers`
- `wiring_test.dart` réécrit sur la nouvelle API (`EntreesWiring` reçoit le `Store` et construit lui-même ses callbacks) — 4/4
- Anti-régression : `dart analyze` **0 erreur**, `flutter test` **395/395 verts**

**Dette connue reportée (non traitée par cette phase) :**
- `lib/screens/stock/stock_screen.dart` = **952 lignes**, bien au-dessus de la règle « widgets < 200 lignes » (AGENTS.md §9). Hérité de la refonte UX R1, pas de la 6bis → tracé au CDC point **40bis**
- **133 warnings** `inference_failure_*` / `unnecessary_cast` préexistants dans le projet, aucun introduit par la 6bis → tracé au CDC point **40ter** (v1.13.0)
- Visibilité publique de `genererId` / `fileUpsert` / `numeroDocument` : réductible seulement via une couche d’accès dédiée, non rentable → tracé au CDC point **40quater**

## 1.13.2 — 2026-09-30 (SyncService résiliant aux colonnes absentes)
- **Correction du blocage définitif** : `SyncService` détectait `PGRST204` (colonne inexistante) et réessayait à l'identique, [_maxEssais] fois, avant de marquer l'entrée `en_erreur` — donc définitivement. Or une colonne absente ne.réussira **jamais** : toute saisie faite hors-ligne était perdue silencieusement.
- Désormais : une seule relance **sans les colonnes optionnelles** (`date_ajout`), avec repli sur le même message de log et rappel du fichier SQL à exécuter. Cohérent avec le repli déjà fait par `CloudRepository.upsertProduit`.
- Liste volontairement restreinte à `date_ajout` : retirer une colonne métier en silence masquerait une vraie perte d'information.
- Conséquence assumée : tant que la migration n'est pas appliquée, le badge « Nouveau » manque en base, mais plus rien n'est bloqué ni perdu.
- Cause racine du symptôme : `database/SUPABASE_A_EXECUTER.sql` section 3 (`date_ajout` sur `produits` et `tarifs`) n'avait jamais été exécutée sur la base réelle. Procédure détaillée dans `database/APPLIQUER_MAINTENANT.md`.

## 1.13.2 — 2026-09-30 (SyncService résiliant aux colonnes absentes)
- **Correction du blocage définitif** : `SyncService` détectait `PGRST204` (colonne inexistante) et réessayait à l'identique, [_maxEssais] fois, avant de marquer l'entrée `en_erreur` — donc définitivement. Or une colonne absente ne.réussira **jamais** : toute saisie faite hors-ligne était perdue silencieusement.
- Désormais : une seule relance **sans les colonnes optionnelles** (`date_ajout`), avec repli sur le même message de log et rappel du fichier SQL à exécuter. Cohérent avec le repli déjà fait par `CloudRepository.upsertProduit`.
- Liste volontairement restreinte à `date_ajout` : retirer une colonne métier en silence masquerait une vraie perte d'information.
- Conséquence assumée : tant que la migration n'est pas appliquée, le badge « Nouveau » manque en base, mais plus rien n'est bloqué ni perdu.
- Cause racine du symptôme : `database/SUPABASE_A_EXECUTER.sql` section 3 (`date_ajout` sur `produits` et `tarifs`) n'avait jamais été exécutée sur la base réelle. Procédure détaillée dans `database/APPLIQUER_MAINTENANT.md`.

## 1.13.1 — 2026-09-30 (correctif doublons galerie + lot + images de marque)
- **Correctif des doublons** (133 entrées affichées pour 19 images réelles) : trois causes cumulées
  1. `CloudRepository._urlMedia/_urlProduits` reconstruisaient le nom cloud en `produits/<millisecondes>.jpg` — chaque `upsertProduit` créait un **nouvel objet** sous un nouveau nom. Le nom d'origine est désormais conservé, avec `upsert: true` (réécrit au même emplacement au lieu d'empiler)
  2. `listerMedia()` ne listait que le préfixe `galerie/` — les images existantes, stockées dans `produits/`, n'étaient **jamais vues**. Les deux préfixes sont désormais listés
  3. la déduplication comparait le chemin **local complet** au chemin **cloud (nom seul)** → jamais égaux. La clé d'identité est désormais le **nom de fichier**, et les deux vues sont **fusionnées** (local + URL) au lieu que l'une écrase l'autre
- **Déduplication par empreinte de contenu** (`taille + 4 premiers octets`) : rattrape les anciens uploads `millisecondes.jpg`, où le nom ne peut pas apparier local et cloud
- **Images de marque exclues de la galerie** : logo, cachet et signature ne sont pas des visuels produits. `MediaService.estImageDeMarque` (préfixes `logo_`, `cachet_`, `signature_`, et formes `logo.`/`signature.`)
- **Remplacement = écrasement** (exigence non négociable) : changer logo/cachet/signature **supprime le fichier précédent**. La signature passait par `savePng` avec un nom horodaté → un fichier empilé par signature ; elle utilise désormais un nom fixe
- **Multi-sélection** : mode lot (cocher/décocher, Tout, Désélectionner), suppression groupée avec une seule confirmation agrégée
- **Une image → plusieurs articles/produits** : le parcours par la banque utilise une clé par image, donc un seul fichier pour N rattachements (le doublon imagePath + images.first du modèle est traité par `sansImage()`/copyWith)
- Tests : +8 (5 de déduplication, 3 d'images de marque) → suite **463/463 verts**, `dart analyze` **0 erreur**

## 1.13.0 — 2026-09-30 (Galerie interne d'images)
- **Banque d'images** : parcours des images déjà présentes, téléversement, affectation à un produit du stock ou un article du catalogue, suppression définitive
- Accès : tuile **Galerie d'images** dans le menu Plus (section Stock) + bouton **Parcourir** dans le formulaire produit
- **Droits** : lecture et affectation ouvertes à tous les rôles ; **suppression définitive réservée à l'admin et le gérant** (cohérent avec la policy RLS « media suppression » déjà en place)
- Nouvelles briques manquantes : `MediaService.dossierMedia/listerImages/supprimerFichier` (suppression PHYSIQUE — avant, la croix rouge du formulaire ne faisait que retirer l'item d'une liste en mémoire, le fichier restait) et `CloudRepository.listerMedia/urlMedia/televerserMedia/supprimerMedia`
- `MediaItem` + `MediaUsage` (modèles), `GalleryService` (indexation + bascule d'affectation, 100 % pur et testable sans UI ni base), `GalleryNotifier` (17e Notifier, branché par `NotifierWiring`)
- `MediaThumb` : vignette tolérante locale **ou** cloud (`AppImage` ne savait lire qu'un fichier local)
- Suppression définitive = détachement de tous les produits/articles concerns (avec confirmation nom par nom) puis effacement du fichier local et de l'objet du bucket : aucune référence morte possible
- Anti-overflow : grille `maxCrossAxisExtent` (2 colonnes à 320 px, 5 à 1024 px) ; vérifié 320/360/768/1024 × TextScaler 1.0/1.5/2.0
- Tests : +44 (gallery_service 22, media_storage 7, gallery_overflow 15) + 1 test de wiring ; suite **455/455 verts**, `dart analyze` **0 erreur**

## 1.12.1 — 2026-09-29 (correctif bloquant : crash au premier chargement cloud)
- **Crash corrigé** : `LateInitializationError: Field '_boutiqueId' has not been initialized` au tout premier chargement réel (écran de connexion → `chargerDuCloud` → `SnapshotApplier.appliquer` → `changerBoutique`). Introduit par la 1.12.0 : l'éligition de la boutique passait par `changerBoutique`, qui LIT `_boutiqueId` — alors que le champ n'est jamais affecté en mode cloud (le constructeur sort avant).
- `Store._boutiqueId` : `late String` → `String _boutiqueId = ''`. Suppression du `late` partout ailleurs ; le champ n'est plus une bombe à retardement.
- `Store.definirBoutiqueCourante(id)` (nouveau) : exige que la boutique **existe ET** soit accessible, sinon retombe sur la valeur neutre — jamais sur un identifiant fantôme (en-têtes incohérents + listes vides sans explication).
- `Store.changerBoutique(id)` : refuse aussi une boutique **inexistante** (bug préexistant : un admin pouvait « sélectionner » une boutique fantôme, filtres et en-têtes incohérents).
- `SnapshotApplier.appliquer` : n'élit plus que parmi les boutiques **réellement accessibles** (avant : le refus de la garde d'accès laissait un identifiant périmé — typiquement `bt_siege` du mode démo, boutique disparue après application du snapshot).
- `BoutiqueNotifier.boutiqueCourante` : `orElse` vers `boutiqueNeutre` (« Aucune boutique »). Sans lui, les **17 écrans** qui affichent `boutiqueCourante.nom` faisaient `StateError: No element` dès qu'aucune boutique n'est élue (compte sans accès, ou fenêtre entre la connexion et la fin du chargement).
- `StoreSync.elireBoutiqueAccessible` + appel dans `chargerSnapshotLocal` : le repli hors-ligne en production élit désormais une boutique. Sans cela, l'app démarrait avec une boutique neutre et **toutes les listes vides** alors que les données locales étaient chargées.
- `chargerDuCloud` : `_syncBoutiqueId()` redondant supprimé (`choisirBoutique` synchronise déjà).
- Tests : +15 (`snapshot_applier_test.dart`), dont un **garde-fou structurel** interdisant tout `late` non-`final` dans `Store` — suite **410/410 verts**, `dart analyze` **0 erreur**, `store.dart` **349 lignes**.

## 1.11.0 — 2026-09-28 (Phase 6 — découpage du Store, allègement ANNULÉ)
- ⚠️ **Allègement annulé par la 1.12.0** : les façades créées étaient des `part` (bibliothèque partagée), donc aucun gain sur le fichier principal. Conservée pour la trace ; ne pas s'en servir de référence
- Nouveaux modules purs (utiles, conservés en 1.12.0) : `StoreSerializer` (JSON local roundtrip), `CloudLoader` (traduction Supabase → snapshot), `DemoSeed` (données démo), `NotifierWiring` (faisceau 16 Notifiers), `StoreHelpers` (normalisation)
- Store : 3114 → 1933 lignes (Phase 5, commit `84f96e0`) puis 1945 (Phase 6, sans gain net)
- Anti-régression : suite 395/395 verts, `dart analyze` 0 erreur
- Écarts documentés : `carousel_slider` installé mais non utilisé (PageView natif), sous-catégorie absente, timeline achat inférée

## 1.10.0 — 2026-09-28 (refonte UX e-commerce : Stock, Tarifs, Achats)
- Badges : UNIQUEMENT Nouveau (< 7 j, `dateAjout`) / Stock faible / Rupture — tout badge marketing supprimé ; `ProduitExtension` (rupture/faible/nouveau) + `Tarif.nouveau`
- Modèle : `Produit.dateAjout` + `Tarif.dateAjout` (remplie à la création, jamais écrasée ; rétrocompatible null) + persistance locale/cloud/file + SQL `date_ajout` (schema + migration + SUPABASE_A_EXECUTER)
- Stock : grille cartes responsive 2/3/4 + bascule liste (`ProductListTile`), recherche as-you-type, FiltrePanel (boutique/catégorie/stock/prix/tri 10 modes), `ProduitDetailScreen` (galerie Hero, fiche, mouvements, 5 dernières ventes), carrousel + photo_view, Hero, fade-in, shimmer réseau
- Tarifs : grille + arbre catégories (drawer mobile / latéral ≥700px) + prix/tri, `TarifDetailScreen`, badge Nouveau seul
- Achats : cartes commande (statut, totaux, 3 lignes + voir plus, Voir/Payer/Annuler/Exporter) + bascule grille + montant/tri, détail enrichi (en-tête statut, lignes avec images, timeline inférée — dates exactes non stockées, export PDF)
- Anti-overflow : 3 écrans en CustomScrollView (slivers) + Masonry (hauteur libre) — 320/360/768/1024 × 1.0–2.0 verts
- Écarts documentés : pas de sous-catégorie produit, pas de filtre boutique Stock→portée courante+option, timeline achat inférée (modèle sans dates d'étapes)
- Tests : +54 (11 Stock + 3 goldens + 7 Tarifs + 7 Achats + 24 overflow + 2 goldens commerce) — suite 375/375 ; `flutter analyze` 0 erreur ; intégration `commerce_flow_test.dart` (émulateur requis — ADB absent en CI)
- Deps : flutter_staggered_grid_view, cached_network_image, photo_view, carousel_slider, shimmer (écart : carrousel implémenté en `PageView` natif — `carousel_slider` installé mais non utilisé, `photo_view`/`cached_network_image`/`shimmer`/`staggered` utilisés)

## 1.9.2 — 2026-09-28 (plan de correction totale + vérification AppBar)
- ExportService durci : protection formules CSV/Excel (`'` sur `=+-@`), en-tête entreprise (nom + RCCM/IFU) + date de génération + filtres appliqués sur tous les PDF, `enteteEntreprise()` réutilisable — API rétrocompatible
- LigneAchat.images (max 5, optionnel) + galerie dans le formulaire d'achat (aperçu + ajout + retrait) ; JSON rétrocompatible (clé absente → [])
- Filtres homogènes FiltrePanel : Stock (+ stock bas), Charges (+ récurrente), Trésorerie (recherche), Achats (intervalles 7j/30j/mois/année + fournisseur)
- Documents historique : filtre statut (Brouillon/Émis/Payé/Annulé) + export PDF/Excel/CSV de l'historique filtré ; golden régénéré
- Clients : champ IFU (modèle + SQL + formulaire + export) + filtre avec/sans crédit (impayés) ; Listes dynamiques : recherche
- Non-applicables documentés (pas inventés) : catégorie achats, boutique mono-écrans, type mouvement trésorerie, boutique documents → dettes 40bis-40quinquies (CDC §8bis, 🟢 v1.10.0)
- AppBar conditionnelle Stock/Dépenses en navigation push (menu Plus) ; test widget dédié
- Tests : suite complète 158/158 verts ; `flutter analyze` 0 erreur

## 1.9.0 — 2026-09-26 (lot MISSION : SQL regroupé + Journal/Stock/Dépenses/Partenaires/Trésorerie/Rapports/Analytique/Documents)
- SQL regroupé : `supabase_schema.sql` + `supabase_migration.sql` + `supabase_fonctions_rls.sql` + `supabase_apply_all.sql` (généré, régénéré le 2026-09-26 : colonne `produits.images` + bucket `produits`) + `supabase_verify.sql` ; 13 fichiers obsolètes supprimés (points 1-2)
- Navigation : Journal → onglet Plus, Achat → barre principale (points 3-4)
- `ExportService` unifié (PDF + Excel `.xlsx` + CSV BOM/`;`) réutilisé par tous les modules (points 5-17)
- Journal : filtres période + sous-catégorie/type, bug PDF vide corrigé (tableau « Aucune donnée » garanti) (points 6-7)
- Stock : recherche + filtre catégorie, exports, persistance images (bucket `produits` + colonne JSON), galerie max 05 (points 8-11)
- Dépenses / Partenaires / Trésorerie / Rapport / Analytique : filtres + exports (points 12-17)
- Documents : audit conformité (5 types, BL sans prix, numérotation séquentielle, RCCM/IFU), signatures entreprise-gauche/client-droite toujours imprimées, overflow Documents émis corrigé (Wrap), filtres type/recherche/dates/montants (points 18-21)
- Tests : `flutter test` 112/112 + golden 360px `test/golden/goldens/documents_emis_360.png` ; `flutter analyze` 0 erreur (111 infos/warnings au moment du lot, ramenés à 105 en 1.9.1 — voir § Dette warnings ci-dessous)
- Commits : `724c4a8` (overflow + filtres documents), `30177a4` (audit + signatures)

## 1.9.1 — 2026-09-26 (solde lot Documents + point 5 + point 22)
- Golden déterministe : `test/flutter_test_config.dart` (Roboto embarqué `test/golden/fonts/`, licence Apache) — réserve fonts levée (point 20)
- Lints critiques corrigés : 4 `use_build_context_synchronously` (`context.mounted`), 2 `unused_import`, 1 `unused_element` (méthode morte `_formProduit`) — reste 105 infos/warnings pré-existants, 0 erreur
- Point 5 : export Achat = vue filtrée par défaut + option « Tous » (6 entrées menu), `test/achat_export_test.dart` 3/3 (BOM, en-têtes, totaux, xlsx, PDF plein+vide)
- Point 22 : Boutique — recherche nom/adresse + filtres statut/siège, fermées en lecture seule ; dettes 22bis (réouverture, 🟡) et 22ter (champs étendus, 🟢) tracées en MISSION_STATUS + CDC §8bis
- Point 23 : Catégories — recherche nom par onglet (type = onglets) ; statut/parent/code hors modèle, non inventés
- Point 24 : audit vente — remise (net = brut − remise) + mode de paiement, garde `mounted`, suffixes journal/export ; `vente_form_test.dart` 6/6
- Batch 1 : FiltrePanel commun (25bis, testé 3/3, migré Achat/Boutique/Catégories) + filtre période Achat (25) + Fournisseurs recherche/spécialité/exports (26) + `EmptyView` scrollable (fix textscale 320@1.5x)
- Batch 2 : Clients — recherche/filtre Pro-Particulier (27), champs étendus email/RCCM/RIB/logo + migration SQL (28), exports PDF/Excel/CSV (29) ; `clients_test.dart` 6/6
- Batch 3 : Comptabilité branchée (30 : contre-passes manquantes + anti-double caisse, `compta_test.dart` 7/7) + exports/filtres journal-balance (31) + Stats type/période + exports (32/33)
- Batch 4 : Tarifs sur FiltrePanel (34), catégorie connectée Autocomplete + anti-doublon casse/accents + création transactionnelle (35), galerie articles max 05 + SQL (36) ; `tarifs_test.dart` 7/7
- Batch 5 : Menu « Plus » réorganisé en 11 sections thématiques (flux métier) ; ecrans_test 19/19
- Batch 6 : 22bis réouverture boutique (RPC SQL + UI + test 4/4, ⚠️ réserve SQL serveur) ; 22ter/23bis hors périmètre v1 (CDC) ; `SUPABASE_A_EXECUTER.sql` (migrations en attente)
- Finalisation : 22bis complet (RPC vérif + audit trail + confirmation UI + MATRICE_PERMISSIONS) ; `APPLIQUER_MAINTENANT.md` ; `AUDIT_FINAL_NYCTA_v4.md` (39/41 = 95,1 %)
- Plan correction totale (2026-09-28) : ExportService (formules + en-tête), LigneAchat.images + galerie, FiltrePanel Stock/Charges/Trésorerie, Achats (intervalles + fournisseur), Documents (statut + export), Clients (IFU + crédit), Listes (recherche)
- Images renforcées (A2) : noms uniques `<entite>_<id>_<ts>_<hash>`, compression < 300 Ko, dossiers `media/<entite>/`, migration anciens noms, re-téléchargement cloud ; `image_persistence_test.dart` 10/10
- Tests : suite complète 168/168 verts ; `flutter analyze` 0 erreur

### Dette warnings `flutter analyze` (justification, 2026-09-26)
Total 111 = 0 erreur + 69 warnings + 42 infos, aucun introduit comme nouvelle famille par le lot :
- `inference_failure_on_function_invocation` (29), `inference_failure_on_instance_creation` (24), `inference_failure_on_collection_literal` (9) — pattern codebase historique (ex : `MaterialPageRoute` sans type explicite, utilisé dans tout le projet y compris le code pré-existant) ; le lot n'en ajoute qu'1 occurrence de la même famille (`documents_history_screen.dart:289`).
- `prefer_const_constructors` (28), `prefer_final_locals` (2), `unnecessary_cast` (4), `unused_import` (2), `unused_element` (1) — style pré-existant, nettoyage à planifier hors mission (ticket : passer `prefer_const_constructors` + `unnecessary_cast` en lot `refactor/lints` dédié).
- `deprecated_member_use` (8), `use_build_context_synchronously` (4) — pré-existants, à traiter avec montée de version des dépendances.
- Fichiers du lot Documents : 3 warnings uniquement, tous `inference_failure_on_instance_creation` pré-existants de famille (preview ×2 pré-existants, historique ×1 même pattern).

### Ticket `refactor/lints` — priorité 🟡, à traiter avant v1.10.0
**Date cible : avant v1.10.0.** Portée : ramener `flutter analyze` à 0 warning + 0 info (105 restants après le nettoyage du 2026-09-26 : 7 critiques déjà corrigés — 4 `use_build_context_synchronously`, 2 `unused_import`, 1 `unused_element`).
Familles à nettoyer, par charge estimée :
1. `inference_failure_on_instance_creation` (24) + `inference_failure_on_function_invocation` (29) + `inference_failure_on_collection_literal` (9) — **charge M (~1 j)** : ajouter les arguments de type explicites (`MaterialPageRoute<void>`, `showModalBottomSheet<T>`, littéraux typés) ; mécanique, vérifiable par `dart analyze` seul.
2. `prefer_const_constructors` (28) + `prefer_final_locals` (2) + `unnecessary_cast` (4) — **charge S (~0,5 j)** : `dart fix --apply`, puis relecture du diff.
3. `deprecated_member_use` (8) — **charge M (~1 j)** : aligné sur la montée de version des dépendances (`share_plus`, `printing`, `pdf`), à tester écran par écran.
4. Infos restantes (~34, ex : `prefer_const_literals`, docs) — **charge S (~0,5 j)**.
Règle : un commit par famille, `flutter test` vert après chacun. Ne pas mélanger avec du fonctionnel (AGENTS.md §7).

### ADR — ExportService non générique (2026-09-26, validée)
Refus du refactor `<T>` en pleine mission : 8 modules verts dépendent de l'API actuelle (risque > gain).
Le service couvre le besoin (PDF/Excel/CSV, BOM/`;`, vue filtrée/Tous) ; réévaluation éventuelle après v1.10.0.

## 1.8.0 — 2026-09-25
- Sélecteur de date robuste (`DatePickerField`, délégués FR, saisie manuelle)
- Module Achats fournisseurs (cycle, CUMP, dettes, `migration_achats.sql`)
- Mouvements de stock tracés + valorisation + ajustements (`migration_mouvements_stock.sql`)
- Analytique CA & dépenses (7j/mois/années, détail filtrable)
- Bordereau de livraison sans prix (aperçu + PDF + signatures)
- Pull-to-refresh (Journal, Stock, Charges, Partenaires, Messagerie, Dashboard)
- RLS critiques : demandes vendeur, défauts `created_by`, verrou archivage (`migration_fixes_critiques_rls.sql`)
- Reset mot de passe (lien Supabase), `MATRICE_PERMISSIONS.md`
- Comptabilité SYSCOHADA : journal auto, balance, compte de résultat (`migration_compta.sql`)
- Crédit client + relances + balance âgée + TVA mensuelle
- Signature client manuscrite par document (`migration_signatures_documents.sql`)
- Validation manager des documents (brouillon→émis), rapprochement bancaire pointé (`migration_rapprochement.sql`)
- Tests d'intégration (parcours) + matrice TextScaler 1.0–2.0 + CAGR + export CSV analytique
- UI : AppBar bleu nuit globale, lisibilité AppBar
- Validation manager des documents (brouillon→émis), rapprochement bancaire pointé (`migration_rapprochement.sql`)
- Tests d'intégration (parcours), matrice TextScaler 1.0–2.0, CAGR, export CSV analytique
- P11 : workflow payé/annulé, Edge Function admin, CAGR mensuel, export PDF, mini-graphe, rapprochement UI, 32 tests TextScaler
- 98+ tests verts, `flutter analyze` 0 erreur

## 1.7.x et antérieur
- Voir `CAHIER_DES_CHARGES.md` §§6–6ter (production, sauvegardes, durcissement anon, documents cloud, obfuscation, audits sécurité).
