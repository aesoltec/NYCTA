# 📋 CAHIER DES CHARGES — Application « PME Gestion »

> **Document vivant** — mis à jour à chaque itération. Légende :
> ✅ Livré · 🟡 Partiel / en cours · ⬜ À faire
>
> **Version 1.8.0 PRODUCTION — 2026-09-25**

---

## 1. Contexte et objectifs

PME tech existante multi-activités : prestations de services (informatique,
électricité, électronique, vidéosurveillance, réseaux…), vente de matériel,
transactions Mobile Money, crédits de communication, forfaits hotspot
(siège + partenaires à partage de gains mensuel).

**Objectif :** une application mobile Flutter de gestion centralisée,
multi-boutiques, fluide, sans débordement d'interface, évolutive.

---

## 2. Identité & configuration de l'entreprise (données dynamiques)

Toutes ces informations sont **saisissables depuis l'écran Configuration**
et stockées dans la base — elles alimentent automatiquement les documents
(factures, devis, bons de commande, tickets).

| Information | Statut |
|---|---|
| Nom de l'entreprise | ✅ |
| Devise (FCFA par défaut, modifiable) | ✅ |
| Logo | ✅ (import galerie/appareil) |
| Cachet / empreinte | ✅ (import galerie/appareil) |
| Signature numérique | ✅ (import OU **signature à main levée** dans l'app, persistée) |
| Téléphone(s) | ✅ |
| Email | ✅ |
| Adresse complète | ✅ |
| **RCCM** | ✅ |
| **IFU** (Identifiant Fiscal Unique) | ✅ |
| N° contribuable / autres références fiscales | ✅ |
| Banque & coordonnées bancaires | ✅ |
| Message de pied de facture | ✅ |
| Préfixes de numérotation (FACT-, DEV-, BC-, TCK-) + compteurs | ✅ |

## 3. Modules fonctionnels

| Module | Détail | Statut |
|---|---|---|
| Connexion | Écran de connexion (Firebase Auth à brancher) | 🟡 |
| Tableau de bord | CA jour/mois, marge, répartition par activité | ✅ |
| Nouvelle opération | Formulaire dynamique par activité | ✅ |
| Journal | Filtres par activité + recherche client | ✅ |
| Multi-boutiques | Sélecteur, données filtrées par boutique | ✅ |
| **Charges & dépenses** | Loyers, salaires, fournisseurs, taxes, transport… catégorisées, mensuelles | ✅ |
| **Trésorerie** | Fonds de roulement initial, solde de caisse en temps réel | ✅ |
| **Budgets** | Budget mensuel par catégorie de charge, suivi consommé/reste | ✅ |
| **Configuration entreprise** | Toutes les infos d'identité & fiscales (cf. §2) | ✅ |
| **Documents commerciaux** | Facture, Devis proforma, Bon de commande, Ticket de caisse | 🟡 (génération + aperçu ; export PDF ⬜) |
| Stock | Inventaire, alertes rupture, vente atomique stock+CA | ✅ |
| **Statistiques & graphiques (fl_chart)** | Courbe CA 30 jours (accueil + écran dédié), camembert activités, histogramme, indicateurs clés (moyenne/jour, meilleur jour, marge %) | ✅ |
| Partenaires hotspot | Ventes mensuelles, clôture & partage automatique | ✅ |
| Rapports | Par activité, frais MoMo par opérateur, par boutique | ✅ |

## 3bis. Rôles & matrice de permissions (7 rôles)

| Rôle | vendre | stock | caisse | rapports | partenaires | clôturer | dépenses | config | utilisateurs | documents |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Admin** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Gérant** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| **Comptable** | ✅ | — | ✅ | ✅ | — | — | ✅ | — | — | ✅ |
| **Caissier(ère)** | ✅ | — | ✅ | — | — | — | — | — | — | ✅ |
| **Vendeur** | ✅ | ✅ | — | — | — | — | — | — | — | — |
| **Stagiaire** | lecture seule | — | — | — | — | — | — | — | — | — |
| **Partenaire** | forfaits (P8) | — | — | — | — | — | — | — | — | — |

- Matrice implémentée (`rolePermissions`) et **appliquée dans l'UI** :
  onglets masqués, boutons désactivés, messages explicatifs. ✅
- Écran de connexion avec **sélecteur de rôle (démo)** pour tester chaque profil. ✅
- Enforcement côté serveur (règles Firestore) : ⬜ (P6)

## 3ter. Images & image de marque

| Élément | Statut |
|---|---|
| Photo produit (galerie/appareil) sur fiche stock | ✅ |
| Photo produit visible sur les lignes de vente | ✅ |
| Logo entreprise (import) | ✅ |
| Cachet (import) | ✅ |
| Signature manuscrite à main levée (pavé dédié, persistée) | ✅ |
| Logo/signature/cachet apposés sur les documents | ✅ |
| Compression & redimensionnement automatique (max 1200px) | ✅ |

## 4. Documents commerciaux (règles de gestion)

| Règle | Statut |
|---|---|
| En-tête automatique : nom, RCCM, IFU, adresse, contacts | ✅ |
| Logo en en-tête du document | ✅ |
| Signature + cachet apposés en bas du document | ✅ |
| Numérotation automatique par type (préfixe + compteur) | ✅ |
| Lignes d'articles (libellé, quantité, prix unitaire, total) | ✅ |
| Totaux : HT, TVA (taux configurable ⬜), TTC | 🟡 |
| Mentions légales & pied personnalisé | ✅ |
| Devis proforma → transformable en facture (1 geste, nouveau n° FACT) | ✅ |
| Export PDF + partage WhatsApp (package printing) | ✅ |
| Historique des documents émis (liste → aperçu → PDF) | ✅ |

## 5. Finances — règles de gestion

| Règle | Formule | Statut |
|---|---|---|
| Marge sur vente | `montant − coût support` | ✅ |
| Partage partenaire (clôture mensuelle) | `totalVentes × taux` / `totalVentes × (1 − taux)` | ✅ |
| **Solde de caisse par boutique** | `fondsInitial + CA encaissé − dépenses` | ✅ |
| **Fonds de roulement initial** | Saisi à la configuration (l'entreprise existe déjà) | ✅ |
| **Suivi budget** | `consommé` vs `budget mensuel` par catégorie, avec alerte dépassement | ✅ |
| Charges récurrentes | **Génération automatique à l'ouverture du mois** (anti-double par marqueur persisté) | ✅ |

## 6. Exigences techniques

| Exigence | Statut |
|---|---|
| Flutter / Material 3, design « soft » | ✅ |
| **Zéro layout overflow** (TextScaler borné 115 %, FittedBox montants, ListView, ellipsis) | ✅ |
| Gestion d'état Provider | ✅ |
| Multi-boutiques (filtrage global) | ✅ |
| Rôles — 7 rôles & matrice de permissions | 🟡 (UI ✅, enforcement serveur ⬜) |
| Base de données | 🟡 (couche locale démo ; **schéma SQL v1.0 livré** — `database/schema.sql`, déployable) |
| **Mode hors-ligne + synchro** | ✅ file Hive + auto-sync au retour réseau (P7) — reprise sur erreur, jamais de perte |
| Sécurité (règles Firestore, claims) | ⬜ |
| Export PDF | ✅ · Export Excel/CSV | ✅ (transactions + dépenses, BOM UTF-8, accents Excel) |
| Sauvegarde automatique | ✅ sauvegarde cloud Supabase + **sauvegarde complète JSON exportable/restaurable** (double sécurité mode local) |

## 6bis. Backend & déploiement

| Élément | Fichier | Statut |
|---|---|---|
| Variables d'environnement (credentials, URL, clés) | `.env` + `.env.example` documenté | ✅ (à compléter par le client) |
| Chargeur d'env côté Flutter (`Env.apiBaseUrl`, etc.) | `lib/core/env.dart` | ✅ |
| Schéma SQL complet (MySQL/MariaDB) — **fichier vivant** | `database/schema.sql` | ✅ **v1.0** |
| Vues métier : soldes de caisse, CA par activité | dans `schema.sql` | ✅ |
| API REST backend (Node/Express/MySQL2/JWT) | `backend/` | ✅ livré — optionnel (nécessite un serveur) |
| **Hébergement GRATUIT sans serveur : Supabase** | `database/supabase_schema.sql` + guide | ✅ (base + API + auth + images) |
| Schéma PostgreSQL + RLS (politiques par rôle) | `database/supabase_schema.sql` | ✅ v1.0 |
| Guide de déploiement gratuit pas à pas | `database/SUPABASE_DEPLOIEMENT.md` | ✅ (7 étapes, ~20 min) |
| Service Flutter Supabase (auth, CRUD, upload images, clôture) | `lib/services/supabase_service.dart` | ✅ |
| Fonctions SQL `cloturer_partage` + `prochain_numero` (atomiques, anti-double) | `database/supabase_functions.sql` | ✅ (à coller dans Supabase, étape 2bis) |
| Sécurité serveur : JWT + matrice de permissions + requêtes préparées | `backend/src/auth.js` | ✅ |
| Clôture mensuelle anti-double + numérotation atomique | `backend/src/routes.js` | ✅ |
| Seed compte admin | `backend/scripts/seed.js` | ✅ |
| Couche HTTP Flutter prête (login, CRUD, clôture) | `lib/services/api_service.dart` | ✅ |
| Synchro Flutter ↔ SQL (offline-first) | — | ⬜ (P7) |

> Convention : toute évolution du schéma sera ajoutée dans `database/schema.sql`
> avec un bloc de migration commenté et une entrée dans son historique de versions.

## 6septdecies-bis. Sauvegarde & restauration cloud (v1.8.0)

| Élément | Détail |
|---|---|
| Snapshot complet | RPC `sauvegarder_base()` (v1.11) : 21 tables + profil entreprise en JSONB, colonnes générées exclues, stocké dans `sauvegardes` |
| Restauration | RPC `restaurer_base(id)` : TRUNCATE ordonné + réinsertion dans l'ordre des FK — **admin uniquement**, ré-exécutable |
| UI | Configuration → Système → Sauvegardes : liste, créer, **télécharger (JSON partageable)**, restaurer |
| Sécurité restauration | Mot de passe système + saisie obligatoire du mot `RESTAURER` (opération destructive) |
| Hors périmètre | Fichiers Storage (le bucket les conserve) ; table `sauvegardes` elle-même |
| Complément | L'export JSON local existant (par boutique/appareil) reste disponible |

## 6duodevicies. Durcissement de la clé anon intégré (v1.7.3)

| Élément | Détail |
|---|---|
| RPC whitelistées (migration v1.10) | `durcir_anon()` (revoke total + default privileges futures), `assouplir_anon()` (rollback complet), `anon_est_durci()` (état) — garde admin/gérant côté serveur |
| UI | Configuration → Système : état en temps réel + boutons **Durcir / Assouplir**, protégés par le mot de passe système (comme le wizard) |
| Couverture | Tables existantes ET futures (default privileges) — sans cela, la prochaine table créée rouvrirait le trou |

## 6novodecies. Obfuscation & build durci (v1.7.2)

| Élément | Fichier |
|---|---|
| Scripts build release obfusqué (APK par ABI + AAB, symboles séparés) | `build/obfusquer.sh` / `build/obfusquer.bat` |
| Règles R8/ProGuard pour les 12 plugins natifs | `android/proguard-rules.pro` |
| Snippet `build.gradle` (minify + shrink + keystore) | `android/build-gradle.snippet` |
| Guide complet : techniques, limites honnêtes, symboles secrets, anti-repackage | `docs/OBFUSCATION.md` |

Obfuscation = `--obfuscate --split-debug-info` (Dart) + R8 (Java) + shrinking.
Les symboles `build/symbols/` sont privés (dé-obfuscation des crashs uniquement).
Limites assumées documentées : secrets présents dans le binaire toujours lisibles
par un attaquant déterminé — la défense réelle reste le RLS et l'absence de
secrets réels dans l'app.

## 6octodecies. Documents : enregistrement cloud & ré-exploitabilité (v1.7.1)

| Exigence | État |
|---|---|
| Copie structurée en base (en-tête + lignes, tables `documents`/`document_lignes`) | ✅ à chaque génération, avec synchronisation du compteur de numérotation |
| Historique reconstruit au login (cloud → app) | ✅ |
| Copie PDF archivée | ✅ bucket privé `documents` à chaque partage (migration v1.9) |
| Copie Excel/CSV | ✅ export CSV par document depuis l'historique |
| Ré-exploitable | ✅ prévisualisation + PDF régénérables à l'infini depuis la structure ; archive PDF privée lisible par les comptes |

⚠️ Exécuter la migration **v1.9** (bucket `documents` + politiques).

## 6septdecies. Audit pré-production — corrections critiques (v1.7.0)

Audit en posture adversariale (DevOps + cybersécurité), 4 axes. Trous
confirmés par inspection directe des politiques déployées, CORRIGÉS par la
migration **v1.8** (à exécuter dans Supabase, puis `verifier_installation.sql`) :

| # | Trou confirmé | Gravité | Correction |
|---|---|---|---|
| 1 | `users`, `boutiques`, `user_boutiques` : RLS activée SANS politique d'écriture → **création d'utilisateurs/boutiques et affectations échouaient silencieusement en production** | 🔴 Bloquant | 5 politiques d'écriture (admin/gérant) |
| 2 | `compteurs_documents`, `fichiers` : **RLS absente** → CRUD ouvert à la clé anon (numérotation falsifiable) | 🔴 Critique | RLS activée + politiques |
| 3 | Insert `transactions` sans contrôle de boutique ; lignes de documents orphelines | 🟠 Élevé | `accede_boutique()` dans les WITH CHECK |
| 4 | Bucket `media` sans politiques explicites | 🟠 Élevé | Politiques storage (lecture publique assumée, écriture authentifiée, suppression admin) |
| 5 | Session chiffrée sans garde web/desktop (crash `flutter_secure_storage`) | 🟠 Moyen | Activation conditionnelle par plateforme |
| 6 | Helper `unawaited()` no-op → futures dangereuses | 🟠 Moyen | `f.ignore()` |
| 7 | Backend : fallback JWT en dur, login sans rate-limit | 🟠 Moyen | Refus de démarrer sans `JWT_SECRET` (32 car. min.) + `express-rate-limit` (10/5 min) |

Dossiers natifs absents du livrable → `docs/CONFIGURATION_NATIF.md`
(`flutter create .` + permissions Android/iOS).

**Verdict final : aucun axe ne bloque la mise en production après exécution
de la migration v1.8.**

## 6sedecies. Audit sécurité offensive & compatibilité (v1.6.2)

**Contre-expertise (scénarios d'attaque évalués — 11/11 couverts) :**
injection SQL (SDK paramétré, 0 interpolation), injection de formule Excel
dans les CSV (**corrigé : apostrophe préfixe**), XSS (Flutter échappe
nativement, 0 rendu HTML), énumération d'IDs (**corrigé : UUID v4
Random.secure**), rejeu de clôture (contrainte unique + RPC atomique),
session volée (keystore chiffré), upload malveillant (re-compression JPEG),
restauration falsifiée (validation d'en-tête), zero-click (notifications
sans payload ni action), contournement wizard (liste blanche + garde +
mot de passe).

**Règles métier vérifiées (9/9) :** marge, solde de caisse, partage
partenaire/entreprise, décrément stock, anti-double clôture, vente à
perte confirmée, marge négative confirmée, détection budget, opérateurs
vérifiés (0 incohérence).

**Compatibilité bibliothèques :** 18 dépendances épinglées, interfaces
vérifiées une à une (LocalStorage 6 méthodes, connectivity 6.x List<…>,
fl_chart ≥ Flutter 3.22, intl initialisé fr_FR). Aucun conflit connu.

**⚠️ Restant (assumé/documenté) :** JWT_SECRET à renseigner impérativement
dans le .env avant tout déploiement du backend Node ; `journal_activite`
créé, alimentation à câbler.

## 6quindecies. Règles de cohérence métier (v1.6.1)

| Incohérence | Comportement |
|---|---|
| **Prix de vente < prix d'achat** (fiche produit) | 🚫 Bloqué par défaut — dialogue « Marge négative » avec perte exacte par unité ; « Vendre à perte » exige une **confirmation explicite** (liquidation délibérée) |
| **Coût support > montant encaissé** (toute transaction) | Même garde : marge négative calculée, confirmation obligatoire |
| **Quantité 0 ou négative** (lignes de documents) | Validateur ≥ 1 + filtrage à la génération |
| **Fonds de roulement négatif** | Validateur ≥ 0 (trésorerie + configuration) |
| Vente dont la quantité dépasse le stock | Déjà bloquée (« Stock insuffisant ») |

Principe appliqué : **une incohérence ne passe jamais silencieusement** — elle est soit bloquée, soit exigée par confirmation délibérée.

## 6quaterdecies. Verrou wizard & données de test (v1.6.0)

| Élément | Détail |
|---|---|
| Verrou de la page assistant | Paramètre **Configuration → Système** : activer/désactiver la page wizard sur l'écran de connexion (verrou mot de passe `WIZARD INSTALLER` **supprimé** — la garde réelle reste côté serveur : RLS + garde admin) |
| Données de test en 1 bouton | Wizard → « Charger les données de test » : RPC `charger_donnees_test()` (migration v1.7) — 2 boutiques, 2 partenaires, 5 produits, 4 tarifs, 3 clients, 2 fournisseurs, 15 transactions sur 6 jours, 3 charges, budgets/fonds, 1 suggestion, 1 événement, 1 note-rappel, 1 message de bienvenue |
| Installateur régénéré | embarque désormais les migrations jusqu'à v1.7 |

## 6terdecies. Assistant d'installation automatique (v1.5.0)

| Élément | Détail |
|---|---|
| Wizard in-app | Écran « Première installation ? Assistant » sur la page de connexion : diagnostic (tables/fonctions/RLS/bucket), journal d'étapes, bouton Installer/Réparer |
| RPC `installer_etape` | `database/installateur_rpc.sql` — **liste blanche** de 3 étapes (`schema_v1`, `migrations`, `bucket_media`), générée depuis les fichiers SQL réels ; idempotent (réparation incluse) |
| Sécurité | appelable uniquement avant le 1er admin (base vierge) ou par un admin ; aucun SQL arbitraire |
| Prérequis unique | coller UNE FOIS `installateur_rpc.sql` dans SQL Editor (crée la fonction) — tout le reste est automatique |

## 6duodecies. Sécurité : session, audit des droits, SQL Supabase (v1.4.1)

### Session & cookies
| Élément | Statut |
|---|---|
| Jetons de session dans le **keystore chiffré** (Keychain/Keystore), jamais en clair | ✅ `core/secure_session.dart` |
| Rafraîchissement automatique du jeton avant expiration | ✅ `autoRefreshToken` |
| Session expirée → retour propre à la connexion (pas de blocage) | ✅ CloudLoader |

### Audit complet des droits Flutter ↔ RLS (migration v1.6)

| Module | Flutter (UI) | RLS (serveur) | Verdict |
|---|---|---|---|
| Transactions | vendre / lecture selon rôle | insert par rôle + **lecture isolée par boutique** | ✅ |
| Produits/stock | gererStock / vendre | écriture admin-gérant-vendeur + lecture isolée boutique | ✅ |
| Charges | gererDepenses | écriture admin-gérant-comptable + lecture isolée boutique | ✅ |
| Documents | gererDocuments | écriture admin-gérant-comptable-caissier + lecture isolée boutique | ✅ |
| Clients | vendre | lecture/insertion boutiques accessibles, **modif admin-gérant** (écart corrigé) | ✅ |
| Partenaires & clôtures | gererPartenaires / cloturerMois | écriture admin-gérant ; partenaire lit le sien, insère forfait à son nom | ✅ |
| Catégories / tarifs | configurer / admin-gérant | écriture admin-gérant | ✅ |
| Utilisateurs | gererUtilisateurs | création via Auth signUp + users/user_boutiques ; désactivation | ✅ |
| Messagerie | tous | insert à son nom ; lecture tous | ✅ |
| Événements / notes | tous | écriture admin-gérant | ✅ |
| Feedbacks | tous soumettent, admin-gérant traitent | identique côté RLS | ✅ |
| Fournisseurs | gererDepenses/configurer | écriture admin-gérant-comptable | ✅ |
| **journal_activite** (nouveau) | lecture admin-gérant | table créée (v1.6), alimentation côté app prévue v1.5 | 🟡 |

### Compatibilité SQL Supabase (PostgreSQL) — vérifiée
- `supabase_schema.sql` : idempotent (`create table if not exists`, types ENUM protégés, `on conflict`), fonctions `security definer` + `search_path` figé ✅
- Migrations v1.1 → v1.6 : ré-exécutables (`create or replace`, `drop policy if exists`) ✅
- Script de contrôle post-installation : `database/verifier_installation.sql` ✅
- `schema.sql` MySQL : ordre de création des clés étrangères corrigé (FK transactions→partenaires différée) ✅

## 6undecies. Tarifs & validateurs universels (v1.4.0)

| Élément | Détail |
|---|---|
| **Tarifs & catalogue** | articles vendus AVEC prix y compris **hors stock** ; CRUD admin/gérant (RLS serveur), lecture tous rôles ; recherche instantanée |
| **Préremplissage factures/devis** | icône catalogue sur chaque ligne → sélecteur avec recherche → ligne remplie (libellé + prix) |
| **Validateurs universels** (`core/validators.dart`) | `V.prix` (regex `^\d+([.,]\d{1,2})?$`, > 0) · `V.entier` · `V.pourcent` (0-100) · `V.telephone` (optionnel, regex internationale) · `V.email` / `V.emailOpt` · `V.texte` (longueur min.) — appliqués aux 17 formulaires de l'app |
| **Claviers numériques** | tous les champs prix/montants/taux passent en `numberWithOptions(decimal: true)` |
| Migration SQL **v1.7** | réutilise `categories` (type élargi) pour opérateurs Mobile Money / Crédit, domaines de prestation, durées de forfait — remplace les listes en dur de `constants.dart` — bas de `database/supabase_functions.sql` (MySQL `schema.sql` non synchronisé : backend Node inutilisé par l'app, voir `lib/services/api_service.dart`) |
| Migration SQL **v1.5** | table `tarifs` + RLS — bas de `database/supabase_functions.sql`, `schema.sql` synchronisé |

## 6decies. Suggestions & signalements (v1.3.0)

| Élément | Détail |
|---|---|
| 5 types | Recommandation 👍 · Suggestion 💡 · Proposition 📋 · Signalement de panne 🔧 · Avis 💬 |
| Formulaire | type (puces), priorité (basse/normale/haute 🔴), titre, description détaillée |
| Suivi de traitement | Nouveau → En cours → Traité ✅ (menu réservé admin/gérant, RLS serveur) |
| Transparence | tous les employés voient les contributions (politique RLS : lecture pour tous, insertion à son nom, traitement admin/gérant) |
| Alertes | badge sur la tuile du menu + notification quotidienne au gérant si contributions en attente ; haute priorité marquée 🔴 |
| Migration SQL **v1.4** | table `feedbacks` + RLS — bas de `database/supabase_functions.sql`, `schema.sql` synchronisé |

## 6novies. Collaboration d'entreprise (v1.2.0)

| Module | Contenu | Détails anticipés |
|---|---|---|
| **Fournisseurs** | Fichier complet (nom, tél, email, adresse, spécialité, notes) | doublon refusé |
| **Messagerie interne** | Message à **un utilisateur** OU à **tous** ; non-lus en badge sur la tuile + point bleu ; « tout marquer lu » | destinataire « Tous » explicite ; lecture = marquage auto ; RLS : insertion uniquement à son nom |
| **Réunions & événements** | Planifier (titre, date par calendrier, heure, lieu, ordre du jour) ; sections À venir / Passés ; notification le jour J | tri chronologique, carte date visuelle |
| **Notes & rappels** | Notes avec **rappel daté optionnel** → notification le jour J, carte surlignée | retrait du rappel en 1 tap |
| Migration SQL **v1.3** | tables `fournisseurs`, `messages`, `evenements`, `notes` + RLS | `supabase_functions.sql` + `schema.sql` synchronisés |

## 6octies. Administration complète sans SQL manuel (v1.1.0)

| Page | Contenu | Garde-fous anticipés |
|---|---|---|
| **Boutiques** | créer, modifier, fermer, siège, affectation des utilisateurs | un seul siège (démet automatiquement l'ancien), dernière boutique protégée, fermeture = désactivation (historique conservé), fermeture de la boutique courante refusée |
| **Catégories** | produits ET charges : ajouter, renommer (renommage en cascade sur les fiches), supprimer | doublon refusé, catégorie utilisée non supprimable (renommage conseillé), utilisée partout : dropdowns stock/dépenses dynamiques |
| **Partenaires** | créer, modifier (tap sur la carte), désactiver | taux 0-100 % validé, désactivation ≠ suppression (ventes conservées) |
| **Clients** | fichier clients par boutique : créer, modifier | doublon par boutique refusé |
| Migration SQL **v1.2** | table `categories` (+ RLS) — à exécuter dans Supabase | `database/supabase_functions.sql` + `schema.sql` MySQL synchronisés |
| Synchronisation cloud | boutiques, catégories, clients remontent en direct | createur + utilisateurs choisis affectés (`user_boutiques`) |

## 6septies. Correctif v1.0.1 — notification à chaque lancement

| Symptôme | Cause | Correction |
|---|---|---|
| Notification à chaque ouverture (stock bas / budget) | Rappel réaffiché tant que la situation persiste | ✅ **Une notification par famille et par jour** (mémoire Hive datée, auto-purge) ; le badge dans l'app reste permanent |

## 6sexies. Passage en production (v1.0.0)

| Élément | Statut |
|---|---|
| Mode démo retiré en production (aucune donnée fictive) | ✅ |
| Connexion réelle Supabase Auth (email + mot de passe) | ✅ |
| Démarrage automatique si session valide (pas de re-connexion) | ✅ |
| Chargement initial complet depuis le cloud (profil, boutiques, produits, partenaires, transactions, charges) | ✅ |
| Écritures en direct sur chaque mutation (produits, charges, partenaires, profil) | ✅ |
| Clôture mensuelle via RPC serveur atomique | ✅ |
| Images uploadées vers Supabase Storage (bucket « media ») — visibles de tous les appareils | ✅ |
| Déconnexion | ✅ |
| IDs UUID conformes PostgreSQL | ✅ |
| File offline-first conservée (SyncService) — les saisies hors-réseau remontent au retour | ✅ |

**Prérequis côté client (Supabase)** : créer le bucket `media` (Storage → New bucket, public) ;
créer votre compte dans Authentication → Add user ; exécuter `supabase_schema.sql` PUIS
`supabase_functions.sql` ; créer vos boutiques via SQL Editor (`insert into boutiques...`).

## 6quinquies. Corrections du retour terrain (v0.22)

| Remontée du client | Diagnostic | Correction |
|---|---|---|
| « Photos/logo/signature non stockés » | 🔴 **Bug réel** : chemins vers le cache temporaire (effacé au redémarrage) + aucune persistance de l'état en mode démo | ✅ `MediaService.copierDansApp` (stockage privé stable) + **persistance complète Hive** de l'état (survit aux redémarrages) |
| « Pas de page de gestion des utilisateurs » | Manquant | ✅ Écran Utilisateurs (création, rôle, boutiques, suppression) — permission dédiée |
| « Pas de modification du produit au tap » | Manquant | ✅ Tap sur la fiche = fiche pré-remplie modifiable (prix, stock, seuil, photo) |
| « Seuil d'alerte absent du formulaire » | Oubli | ✅ Champ « Seuil d'alerte » avec helper |
| « Formulaires cachés par le clavier » | Bottom sheets sans zone sûre | ✅ `useSafeArea` + padding clavier sur tous les bottom sheets |
| « Pas de validation des champs » | Validateurs insuffisants | ✅ Montants strictement > 0, libellés ≥ 2 car., stocks ≥ 0, seuil ≥ 0 |
| « Supabase pas branché » | Attendu : `.env` non renseigné par le client | ✅ Bannière **DÉMO** permanente dans l'AppBar + infobulle expliquant la marche à suivre |

## 6ter. Revue qualité senior (v0.18) — corrections & compléments

| Élément audité | Verdict | Action |
|---|---|---|
| **Crash potentiel** : `NumberFormat('fr_FR')` sans `initializeDateFormatting` | 🔴 Bug critique trouvé | ✅ Corrigé dans `main.dart` |
| Secrets dans le dépôt (.env, clés) | 🟡 Risque | ✅ `.gitignore` ajouté (.env exclu) |
| Linter Flutter officiel | 🟡 Absent | ✅ `analysis_options.yaml` (strict) |
| Test automatisé | 🟡 Aucun | ✅ Smoke test `test/widget_test.dart` — doit rester vert |
| Clôture de caisse quotidienne | ⬜ Manquante | ✅ **Rapport journalier PDF** (détail par activité + transactions, partage WhatsApp au gérant) — bouton dans le Journal |

## 7. Roadmap

| Phase | Contenu | Statut |
|---|---|---|
| **P0 Fondations** | Navigation, thème, modèles, store, anti-overflow | ✅ |
| **P1 Caisse** | Transactions des 5 activités, journal, dashboard | ✅ |
| **P2 Stock** | Produits, alertes, vente atomique | ✅ |
| **P3 Finances** | Charges, trésorerie, budgets, fonds de roulement | ✅ |
| **P4 Identité** | Configuration entreprise (RCCM, IFU…), devise | ✅ |
| **P5 Documents** | Facture, devis, bon de commande, ticket (aperçu) | ✅ → export PDF ⬜ |
| **P6 Backend** | 2 options livrées : (a) Supabase gratuit sans serveur ✅ RECOMMANDÉ (b) API Node/MySQL si VPS un jour | ✅ code prêt — activation client ⬜ |
| **P7 Hors-ligne** | File Hive + détection réseau + auto-sync + retry (max 8 essais, jamais de perte silencieuse) | ✅ |
| **P8 Comptes partenaires** | Espace dédié : saisie forfaits, ses ventes, sa part — UI ✅ + RLS v1.1 ✅ (forfait à son nom uniquement) | ✅ |
| **P9 Rapports avancés** | Historique ✅ · devis→facture ✅ · CA par jour ✅ · rapport journalier ✅ · Excel/CSV ✅ · sauvegarde/restauration ✅ — **P9 TERMINÉE** | ✅ |
| **P10 Missions (v1.8.0)** | Sélecteur de date robuste ✅ · module Achats ✅ · mouvements stock + CUMP + valorisation ✅ · analytique CA/dépenses ✅ · BL sans prix ✅ · pull-to-refresh ✅ · RLS critiques ✅ · reset mdp ✅ · comptabilité SYSCOHADA (journal/balance/résultat) ✅ | ✅ |

## 9. Journal des versions récentes (missions → v1.8.0)

| Version | Contenu |
|---|---|
| Audit Phase 0 | `AUDIT_PHASE_0.md` : cartographie 72 fichiers, diagnostic date picker, registres modules |
| Phase 1 | `DatePickerField` (clamp, saisie JJ/MM/AAAA, tests), délégués FR, `intl` 0.20.3 |
| Phase 2 | Module Achats (cycle demande→reçu, CUMP, dettes, `Permission.gererAchats`, tuile dashboard, `migration_achats.sql`) |
| MISSION1 | Mouvements de stock tracés, valorisation, ajustements (`migration_mouvements_stock.sql`) |
| MISSION3 | Analytique CA/dépenses 7j/mois/années + détail filtrable |
| UI | AppBar bleu nuit globale, en-tête menu, lisibilité AppBar |
| MISSION critique | RLS demandes vendeur, défauts `created_by`, verrou archivage, overflow messagerie, reset mdp, `MATRICE_PERMISSIONS.md` |
| MISSION reste | BL sans prix (aperçu + PDF + signatures), matrice documentaire vendeur, tuiles Dépenses, pull-to-refresh |
| MISSION compta | Journal SYSCOHADA auto (VT/AC/BQ/OD), balance, compte de résultat (`migration_compta.sql`) |

## 8. Backlog (idées à prioriser ensemble)

- TVA configurable et factures normalisées (normes fiscales du pays)
- Gestion des fournisseurs & réapprovisionnement
- Paie simplifiée des employés
- Imprimante thermique pour tickets de caisse
- Notifications (alerte stock, seuil budget dépassé, clôture mensuelle)
- Tablette / mode paysage pour le point de vente

---
*Prochaine mise à jour : après validation de la phase P5/P6.*

---

🚀 **Vision stratégique à grande échelle (SaaS, IA, marketplace) : voir `VISION_PRODUIT.md`**
