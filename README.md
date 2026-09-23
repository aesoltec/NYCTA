# PME Gestion — Application complète (v0.9)

Application Flutter de gestion centralisée pour PME multi-activités et
multi-boutiques (devise FCFA). **Elle tourne immédiatement** avec des
données de démo réalistes — aucune configuration Firebase requise.

## Fonctionnalités livrées

| Module | Contenu |
|--------|---------|
| 🔐 Connexion | Écran de connexion (démo : tout identifiant) |
| 🏠 Tableau de bord | CA du jour/mois, marge, répartition par activité (barres animées) |
| ➕ Nouvelle opération | Formulaire dynamique par activité : prestation, Mobile Money, crédit, forfait hotspot, matériel |
| 📒 Journal | Toutes les transactions, filtres par activité, recherche client |
| 📦 Stock | Inventaire par boutique, alertes de rupture, vente directe (sortie de stock + transaction atomiques) |
| 🤝 Partenaires | Ventes mensuelles par partenaire, **clôture du mois** avec calcul automatique des parts |
| 📊 Rapports | CA/marge du mois, détail par activité, **frais Mobile Money par opérateur**, CA par boutique |
| 🏬 Multi-boutiques | Sélecteur dans l'AppBar, toutes les données filtrées par boutique |

## Règles anti-overflow appliquées (senior)

1. **TextScaler borné à 115 %** globalement — cause n°1 de débordement en production (accessibilité système).
2. **`MoneyText`** : chaque montant passe dans un `FittedBox` → un montant en FCFA ne déborde jamais.
3. **Tous les écrans scrollables** (`ListView`), jamais de `Column` nue avec clavier.
4. **`LayoutBuilder`** sur la grille d'activités → 2 ou 3 colonnes selon la largeur réelle.
5. **Tous les textes longs** : `maxLines` + `ellipsis` + `Flexible`/`Expanded`.
6. **`ErrorWidget.builder`** personnalisé : une erreur de rendu affiche un placeholder gris au lieu de l'écran rouge.
7. Grilles à `childAspectRatio` fixe, chips en `ListView` horizontal, bottom sheets `isScrollControlled`.

## Lancer

```bash
flutter pub get
flutter run
```

## Structure

```
lib/
  core/        Thème "soft" + constantes (activités, opérateurs, format FCFA)
  models/      Tx, Produit, Partenaire, Partage, Boutique, AppUser
  data/store.dart   État global (Provider) + calculs métier + seed démo
  screens/     login, shell, dashboard, transaction, journal,
               stock, partenaires, rapports
  widgets/     MoneyText, SoftCard, EmptyView, TypeChip
```

## Brancher Firebase ensuite (sans casser l'UI)

Remplacer les méthodes de `Store` (`ajouterTransaction`, `ajouterProduit`,
`cloturerMois`…) par des appels Firestore. Les écrans n'ont pas à changer :
ils ne consomment que `Store` via Provider. Structure Firestore recommandée :
`boutiques / users / produits / transactions / partenaires / partagesMensuels`.

## Ajouter une activité (vous en avez plus de 7 ?)

1. `enum TypeTransaction` → ajouter la valeur.
2. `C.infosTypes` → libellé, icône, couleur.
3. `_champsSpecifiques` dans `nouvelle_transaction_screen.dart` → ses champs.

C'est tout. Dashboard, journal, rapports et filtres la gèrent automatiquement.


---

📋 **Le cahier des charges complet et suivi d'avancement est dans `CAHIER_DES_CHARGES.md`**


## Nouveautés v0.10

- **Charges & dépenses** : catégorisées (loyer, salaires, fournisseurs, taxes…), récurrentes, total mensuel
- **Trésorerie** : fonds de roulement initial par boutique, solde de caisse = fonds + CA encaissé − dépenses
- **Budgets mensuels** par catégorie avec barres de suivi et alerte dépassement
- **Configuration entreprise** : nom, devise, contacts, RCCM, IFU, références fiscales, banque, pied de document, TVA — tout est dynamique
- **Documents commerciaux** : facture, devis proforma, bon de commande, ticket de caisse — en-tête légal automatique (RCCM, IFU), numérotation auto, totaux HT/TVA/TTC


## Nouveautés v0.11

- **7 rôles avec matrice de permissions** : admin, gérant, comptable, caissier(ère), vendeur, stagiaire, partenaire — onglets masqués, boutons verrouillés, sélecteur de rôle sur l'écran de connexion pour tester
- **Photos produits** : import galerie ou appareil sur chaque fiche stock, visibles dans la liste
- **Image de marque** : logo, cachet, et **signature à main levée** (pavé dédié) — configurables et stockés, apposés sur les documents commerciaux


## Backend & déploiement (v0.12)

- **`.env`** : credentials, URL API, clés MoMo… — à compléter après déploiement (`.env.example` documenté)
- **`database/schema.sql`** : schéma MySQL/MariaDB complet et versionné (13 tables + vues métier) — déployé avec `mysql -u root -p < database/schema.sql`
- **`lib/core/env.dart`** : chargé au démarrage, valeurs de secours si le `.env` est absent
- Les deux fichiers seront **mis à jour à chaque évolution** du projet


## Backend API REST (v0.13 — phase P6)

Dossier `backend/` : Node.js + Express + MySQL2 + JWT, 7 rôles appliqués **côté serveur**.

```bash
mysql -u root -p < database/schema.sql   # 1. base
cd backend && npm install                # 2. deps
cp .env.example .env  # renseigner DB_* et JWT_SECRET
npm run seed                             # 3. admin initial
npm run dev                              # 4. http://localhost:3000/api
```

- `src/permissions.js` : matrice miroir du Flutter — permissions vraiment appliquées sur chaque endpoint
- `src/crud.js` : CRUD générique à colonnes en liste blanche + requêtes préparées
- Numérotation document **atomique** ; clôture mensuelle **anti-double** (contrainte SQL + contrôle 409)
- Flutter : `lib/services/api_service.dart` prête à brancher sur le Store (fallback hors-ligne conservé)


## Hébergement gratuit sans serveur (v0.14)

Sans serveur, la solution retenue est **Supabase** (tier Free) : base PostgreSQL + API auto +
auth + stockage images, le tout gratuit. Deux options de backend sont livrées :

| Option | Quand la choisir | Fichiers |
|---|---|---|
| **(a) Supabase — RECOMMANDÉ** | Aucun serveur, aucun coût, démarrage en 20 min | `database/supabase_schema.sql`, `database/SUPABASE_DEPLOIEMENT.md`, `lib/services/supabase_service.dart` |
| (b) API Node + MySQL | Si vous avez un jour un VPS (~5 $/mois) | `backend/` |

Suivre le guide `database/SUPABASE_DEPLOIEMENT.md` (7 étapes), remplir `SUPABASE_URL` et
`SUPABASE_ANON_KEY` dans le `.env`, et l'application passe en mode cloud ; sinon elle
continue en mode local démo. L'APK se distribue directement par WhatsApp (`flutter build apk --release`).


## Offline-first & fonctions SQL (v0.15 — phase P7)

- `database/supabase_functions.sql` : RPC `cloturer_partage` (clôture mensuelle
  atomique + anti-double) et `prochain_numero` (numérotation document sans doublon
  même à 2 caissiers simultanés) — à coller dans Supabase → SQL Editor
- `lib/services/sync_service.dart` : file d'attente Hive — une vente saisie sans
  réseau est conservée puis poussée vers Supabase automatiquement au retour du
  réseau (détection wifi/4G). Après 8 échecs, l'entrée est marquée `en_erreur`
  pour investigation : une donnée financière ne se perd jamais silencieusement.
- Branchement : `Store.ajouterTransaction` alimente la file dès que Supabase est
  configuré ; l'app reste 100 % fonctionnelle en local sans configuration.


## Export PDF & espace partenaire (v0.16 — phases P5 fin / P8)

- **PDF** : `lib/services/pdf_service.dart` — facture/devis/bon/ticket en PDF A4
  (logo, RCCM/IFU, totaux, signature + cachet) avec **partage direct WhatsApp**
  (`Printing.sharePdf`) ou impression. Bouton branché dans l'aperçu document.
- **Espace partenaire** (`lib/screens/partenaire/`) : le rôle Partenaire reçoit
  un écran unique — vendre un forfait, voir ses ventes du mois et sa part
  calculée. Sécurité serveur : RLS v1.1 (`database/supabase_functions.sql`) —
  insertion de forfaits À SON NOM uniquement, lecture de SES ventes uniquement.


## Rapports avancés (v0.17 — phase P9)

- **Devis → Facture** : depuis l'aperçu d'un devis proforma, un bouton génère
  la facture (nouveau numéro FACT, mêmes lignes et totaux) — le geste commercial
  classique, en 2 secondes.
- **Historique des documents** (`lib/screens/documents/documents_history_screen.dart`) :
  chaque document émis est conservé (numéro, type, client, TTC, date) ; un tap
  rouvre l'aperçu et le PDF.
- **Rapports** : nouvelle section « CA par jour (30 jours) » avec barres
  comparatives — repérer les creux d'activité en un coup d'œil.


## Revue qualité senior (v0.18)

- **Bug critique corrigé** : initialisation de la locale fr_FR (crash au 1er
  montant affiché sur appareil réel)
- `.gitignore` (secrets exclus), `analysis_options.yaml` (linter strict),
  smoke test `test/widget_test.dart` (régression bloquante si rouge)
- **Rapport journalier PDF** : clôture de caisse du soir — CA, marge, détail
  par activité, liste des transactions — partage WhatsApp direct au gérant
  (bouton 📄 dans l'onglet Journal)


## Sauvegardes & exports (v0.19 — fin du backlog P9)

- **Exports Excel (CSV)** : transactions et dépenses du mois — s'ouvrent
  directement dans Excel (BOM UTF-8, séparateur `;`, accents préservés)
- **Sauvegarde complète JSON** : profil (RCCM, IFU…), boutiques, produits,
  partenaires, transactions, charges, partages — partageable WhatsApp/Drive
- **Restauration** : depuis n'importe quel fichier de sauvegarde (changement
  de téléphone, réparation, réinstallation)
- Écran : « Plus → Sauvegardes & exports » (réservé admin/gérant)
- `Store.restaurerSauvegarde` : restauration transactionnelle en mémoire,
  boutique courante réajustée automatiquement


## Notifications & charges récurrentes (v0.20)

- **Notifications locales intelligentes** (`lib/services/notification_service.dart`),
  vérifiées à chaque ouverture : stock bas, budget dépassé, rappel de clôture
  mensuelle (du 28), rappel de sauvegarde (lundi). Android 13+ : la permission
  est demandée au premier lancement. Aucune configuration, aucun serveur.
- **Charges récurrentes automatiques** : les dépenses marquées « récurrentes »
  (loyer, salaires…) sont recréées à l'ouverture de chaque nouveau mois —
  marqueur `moisChargesGenerees` dans le profil, aucun doublon possible.


## Statistiques & graphiques (v0.21)

- **Écran dédié** « Plus → Statistiques & graphiques » (package `fl_chart`) :
  courbe d'évolution du CA sur 30 jours (touch = montant exact), camembert de
  répartition par activité, histogramme comparatif, indicateurs clés
  (CA moyen/jour, meilleur jour, marge en %, opérations du mois), ventes
  partenaires du mois
- **Mini-courbe** identique sur le tableau de bord d'accueil — la tendance
  est visible dès l'ouverture de l'app


## Corrections terrain (v0.22)

- **Persistance locale complète** (`lib/services/local_persistence.dart`) :
  l'état entier (produits, transactions, charges, profil, utilisateurs…) est
  sauvegardé sur disque à chaque mutation et restauré au démarrage — le mode
  démo ne perd plus RIEN au redémarrage
- **Photos stables** : chaque image choisie est copiée dans le stockage privé
  de l'app (`MediaService.copierDansApp`) — fini les images qui disparaissent
- **Écran Utilisateurs** : créer des comptes, affecter un rôle et des
  boutiques, modifier, supprimer (réservé à l'admin)
- **Produits modifiables** : un tap sur la fiche ouvre le formulaire pré-rempli
  (prix, stock, **seuil d'alerte**, photo) ; appui long = vente rapide
- **Validations renforcées** : montants strictement positifs, libellés et
  seuils contrôlés sur tous les formulaires
- **Clavier** : `useSafeArea` sur tous les bottom sheets — plus de formulaire
  caché
- **Bannière DÉMO** visible dans l'AppBar tant que Supabase n'est pas
  configuré (avec la marche à suivre en infobulle)


## 🚀 Version 1.0.0 — PRODUCTION

Le mode démo disparaît dès que `SUPABASE_URL` + `SUPABASE_ANON_KEY` sont
renseignés dans le `.env` :

- **Connexion réelle** Supabase Auth (email/mot de passe), démarrage automatique
  si la session est valide, déconnexion disponible
- **Chargement cloud complet** après connexion (profil, boutiques, produits,
  partenaires, transactions, charges, budgets, fonds)
- **Écritures en direct** : chaque saisie (produit, charge, partenaire, profil)
  remonte immédiatement ; les clôtures passent par la RPC atomique
- **Images multi-appareils** : upload automatique vers le bucket `media`
- La bannière DÉMO disparaît ; le rôle vient de la table `users`, les boutiques
  de `user_boutiques`

Check-list de mise en service : SQL (schéma → fonctions) → bucket `media` →
compte Authentication → boutiques en SQL → utilisateurs via l'écran dédié.


## Administration complète (v1.1.0)

Plus RIEN ne se fait dans Supabase à la main — toute la gestion est dans l'app :

- **Plus → Boutiques** : créer, modifier, fermer, gérer le siège (unique) et
  les accès utilisateurs (puces)
- **Plus → Catégories** : onglets Produits / Charges — ajouter, renommer
  (renommage en cascade), supprimer avec garde-fou si utilisée ; les listes
  déroulantes du stock et des dépenses deviennent dynamiques
- **Plus → Partenaires** : créer / modifier au tap / désactiver (ventes conservées)
- **Plus → Clients** : fichier clients de la boutique

⚠️ **Action requise côté Supabase** : exécuter la migration **v1.2** dans
SQL Editor (bas du fichier `database/supabase_functions.sql`) — crée la table
`categories`. Sans elle, les catégories restent locales à chaque appareil.


## Collaboration d'entreprise (v1.2.0)

- **Fournisseurs** : fiche complète (spécialité, contacts, notes)
- **Messagerie interne** : message ciblé ou diffusé à tous, suivi des
  non-lus (badge + point), réception en temps réel depuis Supabase
- **Réunions & événements** : planification complète, notification le jour J
- **Notes & rappels** : rappel daté → notification le jour venu

⚠️ **Action requise Supabase** : exécuter la migration **v1.3** (bas de
`database/supabase_functions.sql`) : crée les 4 tables + leurs politiques RLS.


## Suggestions & signalements (v1.3.0)

Boîte à idées de l'entreprise (Plus → Suggestions & signalements) :
recommandations, suggestions, propositions, signalements de panne et avis —
avec priorité et suivi de traitement (nouveau → en cours → traité).
Badge et notification quotidienne pour le gérant ; RLS : tout le monde
soumet et consulte, seuls admin/gérant traitent.

⚠️ **Action Supabase** : exécuter la migration **v1.4** (bas de
`database/supabase_functions.sql`).


## Tarifs & validateurs universels (v1.4.0)

- **Tarifs & catalogue** (Plus → …) : liste de prix des articles vendus sans
  stock ; gestion admin/gérant (RLS), lecture tous rôles
- **Factures & devis** : icône catalogue sur chaque ligne → sélecteur avec
  recherche → ligne préremplie
- **Validateurs universels** `lib/core/validators.dart` (regex) appliqués aux
  17 formulaires : prix (> 0, 2 décimales max), entiers, pourcentages,
  téléphones, emails, longueurs minimales ; claviers numériques décimaux
  partout

⚠️ **Action Supabase** : exécuter la migration **v1.5** (bas de
`database/supabase_functions.sql`).


## Sécurité & conformité SQL (v1.4.1)

- **Session chiffrée** : jetons Supabase dans le keystore du téléphone
  (`core/secure_session.dart`), rafraîchissement automatique, expiration
  gérée proprement
- **Audit complet des droits** Flutter ↔ RLS documenté dans le CDC ;
  migration **v1.6** à exécuter : durcit `clients`, isole la lecture par
  boutique (transactions, produits, charges, documents) et crée le
  `journal_activite` (socle de l'audit trail)
- **Vérification post-installation** : exécuter `database/verifier_installation.sql`
  après toute installation/migration — tout doit être vert

### Améliorations suggérées (prochaines itérations)
1. Alimenter `journal_activite` à chaque écriture (audit trail complet)
2. Temps réel Supabase (subscriptions) : nouveaux messages/ventes sans
   recharger
3. Chiffrement des sauvegardes JSON exportées (mot de passe)
4. Sauvegardes planifiées automatiques vers un second espace
5. Rate-limit côté client sur les tentatives de connexion
6. Tests d'intégration sur les règles métier (parts, soldes, numérotation)


## Assistant d'installation automatique (v1.5.0)

Fin de la saisie SQL manuelle. Une seule action reste manuelle, une fois :
coller `database/installateur_rpc.sql` dans Supabase → SQL Editor (crée la
fonction `installer_etape`). Ensuite, dans l'application — écran de connexion →
« Première installation ? Assistant » — tout s'installe ou se répare en un
bouton : tables, relations, fonctions, migrations v1.1→v1.6, politiques RLS et
bucket d'images. Diagnostic visuel étape par étape, ré-exécutable à volonté.


## Verrou wizard & données de test (v1.6.0)

- **Configuration → Système** : activer/désactiver la page « Assistant
  d'installation » (écran de connexion), protégée par le mot de passe
  `WIZARD INSTALLER`
- **Données de test en un bouton** : le wizard propose « Charger les données
  de test » (RPC v1.7) — base pré-remplie réaliste pour débuter, idempotente


## Règles de cohérence métier (v1.6.1)

Incohérences bloquées ou soumises à confirmation explicite : prix de vente <
prix d'achat (marge négative chiffrée), coût > montant d'une transaction,
quantités nulles dans les documents, fonds de roulement négatif.


## Audit sécurité offensive (v1.6.2)

Contre-expertise complète documentée dans le CDC (§ 6sedecies) : 11 scénarios
d'attaque évalués (injection, XSS, contournement, zero-click, énumération,
rejeu, session, upload, restauration), 2 failles corrigées (injection de
formule Excel dans les CSV, UUID non cryptographique), règles métier 9/9
vérifiées, compatibilité des 18 bibliothèques validée.


## Audit pré-production & corrections critiques (v1.7.0)

Posture adversariale complète au CDC (§ 6septdecies). Migration **v1.8
OBLIGATOIRE** avant mise en production : corrige les politiques RLS manquantes
(users/boutiques/user_boutiques/compteurs/fichiers), l'isolation boutique sur
les écritures et les politiques du bucket. Backend : JWT_SECRET désormais
obligatoire (32 car. min.) + rate-limit. Voir `docs/CONFIGURATION_NATIF.md`
pour le premier build (`flutter create .` + permissions Android/iOS).


## Documents enregistrés & ré-exploitables (v1.7.1)

Chaque facture/devis/bon/ticket est désormais : enregistré en structure dans
Supabase (en-tête + lignes), archivé en PDF dans le bucket privé `documents`
(à chaque partage), exportable en CSV depuis l'historique, et régénérable à
l'infini (prévisualisation + PDF). L'historique est reconstruit au login.
Migration v1.9 requise (crée le bucket privé + ses politiques).


## Obfuscation & build durci (v1.7.2)

`bash build/obfusquer.sh` (ou `.bat`) : release obfusquée complète —
Dart (`--obfuscate --split-debug-info`), Java (R8 + `proguard-rules.pro`
pour les 12 plugins), ressources réduites. Symboles privés à conserver
pour lire les crashs. Voir `docs/OBFUSCATION.md` (techniques, limites,
anti-repackage, keystore).


## Durcissement de la clé anon intégré (v1.7.3)

Configuration → Système : état + actions **Durcir / Assouplir** protégées par
le mot de passe système. RPC whitelistées (migration v1.10) : la clé anon
perd tout accès direct — y compris sur les tables futures — avec rollback
complet. Testez connexion + vente juste après le durcissement.


## Sauvegarde & restauration cloud (v1.8.0)

Configuration → Système → Sauvegardes : snapshot complet de la base en 1
bouton (21 tables JSONB côté Supabase, migration v1.11), téléchargement en
JSON, restauration intégrale ordonnée (admin uniquement, double confirmation
mot de passe + saisie de « RESTAURER »). Les images/archives PDF restent dans
le bucket indépendamment.
