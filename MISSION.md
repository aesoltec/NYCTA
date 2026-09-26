# Règles pour les agents IA (opencode, Copilot, Cursor, etc.)

1. Lire INTÉGRALEMENT `MISSION.md` à la racine avant toute action.
2. Traiter CHAQUE point listé dans `MISSION.md`, sans exception.
3. Après chaque point traité, mettre à jour `MISSION_STATUS.md` :
   - Passer le statut de ⬜ à ✅ (ou ⚠️ / ❌).
   - Renseigner la colonne Preuve (chemin fichier + test + capture).
   - Renseigner la date.
4. Aucune supposition. Aucune complaisance. Aucune négligence.
5. Preuves obligatoires pour chaque point : code + test + capture.
6. `flutter analyze` = 0 erreur, `flutter test` = 100% vert après chaque lot.
7. 10 passes d'expertise/contre-expertise par modification majeure (voir `PASSES_AUDIT.md`).
8. Documentation mise à jour : `CHANGELOG.md`, `README.md`, `MATRICE_PERMISSIONS.md`, `CAHIER_DES_CHARGES.md`.
9. Tant que 100% des lignes de `MISSION_STATUS.md` ne sont pas ✅, la mission n'est PAS terminée.
10. Ta réputation d'expert senior en dépend.

# Prompt complet — Corrections et réorganisation NYCTA (lot final)

## 1. Rôle et contexte

Tu es un développeur senior Flutter avec plus de 20 ans d'expérience, expert en gestion financière, comptabilité, économie, sécurité financière et audit logiciel. Le projet **NYCTA** ([https://github.com/aesoltec/NYCTA](https://github.com/aesoltec/NYCTA)) est une application de gestion PME multi-activités (FCFA), Flutter + Provider + Supabase, actuellement à 86% de conformité selon `AUDIT_FINAL_NYCTA.md`.

**Règles absolues :**
- Aucune supposition. Tout doit être prouvé (code + tests + captures).
- Aucune complaisance. Aucune négligence. Ta réputation d'expert senior en dépend.
- 10 passes d'expertise/contre-expertise par modification majeure (référence `PASSES_AUDIT.md`).
- `flutter analyze` = 0 erreur, `flutter test` = 100% vert après chaque lot.
- Documentation mise à jour : `CHANGELOG.md`, `README.md`, `MATRICE_PERMISSIONS.md`, `CAHIER_DES_CHARGES.md`.

**Objectif de ce lot :** traiter l'ensemble des corrections listées ci-dessous, côté SQL, Flutter et UI, et réorganiser l'application pour un usage professionnel.

---

## 2. Côté SQL / Supabase — Regroupement et nettoyage

### 2.1. Regrouper les migrations

**Problème :** Trop de petits fichiers de migration individuels (`migration_achats.sql`, `migration_mouvements_stock.sql`, `migration_fixes_critiques_rls.sql`, `migration_signatures_documents.sql`, `migration_compta.sql`, `migration_rapprochement.sql`, etc.).

**Actions attendues :**
- Créer **`supabase_schema.sql`** : regroupant l'ensemble du schéma de base de données (tables, colonnes, types, index, contraintes, valeurs par défaut, extensions).
- Créer **`supabase_migration.sql`** : regroupant l'ensemble des migrations (ALTER TABLE, ajouts de colonnes, corrections de contraintes).
- Créer **`supabase_fonctions_rls.sql`** : regroupant l'ensemble des fonctions SQL, triggers et politiques RLS (Row Level Security).
- **Supprimer** tous les fichiers de migration individuels devenus obsolètes ou doublons (`migration_*.sql`, `APPLIQUER_TOUT.sql`, `VERIFIER_RLS.sql` si redondants — ou les remplacer par un script unique d'application).
- Conserver éventuellement un **`supabase_apply_all.sql`** unique qui exécute les trois fichiers ci-dessus dans le bon ordre.
- Mettre à jour `README.md` et `MATRICE_PERMISSIONS.md` pour référencer la nouvelle organisation.
- Vérifier que **les 6 blocs PASS/FAIL** de vérification RLS sont intégrés dans `supabase_fonctions_rls.sql` ou un fichier dédié `supabase_verify.sql`.

**Preuve exigée :** Arborescence `database/` propre + exécution réussie des 3 fichiers sur Supabase + captures.

---

## 3. Côté Flutter — Corrections par module

### 3.1. Journal

- **Déplacer** le bouton « Journal » dans l'onglet **Plus**.
- **Remplacer** sa place dans la barre principale par un bouton **Achat**.
- **Ajouter export PDF, Excel et CSV** dans l'onglet Achat.
- **Ajouter filtres** : par période, intervalle de temps, catégorie, sous-catégorie.
- **Corriger le bug d'impression/export PDF** qui affiche un cadre vide sans contenu.
- **Ajouter les formats Excel et CSV** pour l'export.
- **Ajouter filtre par période et sous-catégorie.**

### 3.2. Stock

- **Ajouter filtres** par catégorie et sous-catégorie.
- **Ajouter export** PDF, Excel et CSV.
- **Corriger la persistance des images produits** : actuellement les images disparaissent après redémarrage de l'application. Il faut :
  - Stocker les images dans Supabase Storage (bucket `produits`).
  - Sauvegarder les URLs/chemins dans la table `produits`.
  - Recharger les images depuis Supabase au démarrage.
- **Association multi-images (max 05)** non obligatoire par produit :
  - UI : ajout/suppression d'images, prévisualisation, ordre.
  - Sauvegarde dans Supabase Storage + table `produit_images` (ou colonne JSON).
  - Affichage galerie.

### 3.3. Dépenses

- **Ajouter filtres** par catégorie et sous-catégorie.
- **Ajouter export** PDF, Excel et CSV.

### 3.4. Partenaires hotspot

- **Ajouter export** PDF, Excel et CSV.

### 3.5. Trésorerie

- **Ajouter export** PDF, Excel et CSV.
- **Ajouter filtres** : catégorie, sous-catégorie, type, période.

### 3.6. Rapport financier

- **Ajouter export** PDF, Excel et CSV.
- **Ajouter filtres** : catégorie, sous-catégorie, type, période.

### 3.7. Analytique CA & Dépenses

- **Ajouter export** PDF, Excel et CSV.
- **Ajouter filtres** : catégorie, sous-catégorie, type, période exacte ou intervalle.

### 3.8. Documents commerciaux

- **Audit général** et vérification de conformité (normes SYSCOHADA/IFRS, mentions légales, numérotation séquentielle).
- **Signature à main levée** :
  - La signature actuelle (à main levée sur l'app) représente **l'entreprise**, positionnée **à gauche**.
  - Prévoir un **espace à droite** dans le PDF pour que le **client** puisse signer au stylo une fois le document imprimé.
  - Ajouter un libellé clair : « Signature entreprise (à gauche) » et « Signature client (à droite) ».
- Vérifier la conformité de **chaque type de document** (facture, devis proforma, bon de commande, ticket de caisse, bordereau de livraison — BL sans prix).

### 3.9. Historique des documents (documents émis)

- **Corriger l'erreur** `bottom overflowed by 33 pixel`.
- **Ajouter filtres** : période, catégorie, type, client, date, somme, intervalle de temps.

### 3.10. Boutique

- **Ajouter filtre** et **recherche**.

### 3.11. Catégories

- **Ajouter filtre** et **recherche**.

### 3.12. Liste du formulaire de vente

- **Audit général** et vérification de conformité (champs obligatoires, calculs, TVA, remises, modes de paiement).

### 3.13. Achat et fournisseurs

- **Ajouter filtre** par période et intervalle de temps.
- **Ajouter export** PDF, Excel et CSV.

### 3.14. Fournisseurs

- **Ajouter filtre** par spécialité et **recherche**.
- **Ajouter export** PDF, Excel et CSV.

### 3.15. Clients

- **Ajouter recherche** et **filtre**.
- **Formulaire client** : ajouter les champs non obligatoires :
  - Coordonnées (téléphone, email, adresse).
  - Logo.
  - Références commerciales : RIB, RCCM, coordonnées bancaires.
- **Ajouter option export** PDF, Excel et CSV.

### 3.16. Comptabilité

- **Module non terminé ou non branché** : aucune donnée n'y apparaît.
- **Corriger le branchement** : les écritures comptables doivent être générées et visibles.
- **Ajouter export** PDF, Excel et CSV.
- **Ajouter filtres** : période et intervalle de temps.

### 3.17. Statistiques & graphiques

- **Ajouter filtres** : catégorie, sous-catégorie, type, période, intervalle de temps.
- **Ajouter export** PDF et Excel.

### 3.18. Tarifs et catégories

- **Ajouter filtres** par catégorie.
- **Formulaire « Ajouter article »** :
  - La section **catégorie** doit être **connectée** au module Catégories.
  - Permettre la **sélection** depuis les catégories existantes.
  - Permettre la **saisie manuelle** si la catégorie n'existe pas.
  - **Créer automatiquement** la catégorie saisie dans Supabase si absente.
  - **Éviter les doublons** (vérification insensible à la casse/accents).
- **Ajouter un champ images article** : multi-images (max 05), non obligatoire.

---

## 4. Réorganisation générale

- **Réorganiser l'ordre des boutons du menu** dans l'onglet « Plus » de façon **professionnelle** :
  - Regrouper par thème (Ventes, Achats, Stock, Finances, Partenaires, Documents, Configuration, Administration).
  - Placer les modules les plus utilisés en haut.
  - Utiliser des sections/sous-titres si nécessaire.
  - Respecter la logique métier (flux vente → achat → stock → finance → reporting).
- Vérifier la cohérence avec la barre principale (déplacement Journal → Plus, Achat → barre principale).
- Mettre à jour la documentation de navigation (`README.md`, `CAHIER_DES_CHARGES.md`).

---

## 5. Contraintes techniques

- **Framework :** Flutter (Dart), Provider.
- **Base de données :** Supabase (PostgreSQL).
- **Localisation :** fr_FR. **Devise :** FCFA.
- **Anti-overflow :** `Flexible`, `Expanded`, `SingleChildScrollView`, `ListView`, `LayoutBuilder`, `TextScaler` borné.
- **Sécurité :** RLS Supabase correctement configuré, aucun secret exposé.
- **Persistance :** images dans Supabase Storage, pas en local éphémère.
- **Exports :** PDF (via `pdf` package), Excel (via `excel` package), CSV (via `csv` package). Uniformiser un service `ExportService`.
- **Tests :** unitaires + widget + intégration pour chaque nouveau module.
- **10 passes d'audit** par modification majeure.

---

## 6. Livrables attendus

1. **SQL regroupé** : `supabase_schema.sql`, `supabase_migration.sql`, `supabase_fonctions_rls.sql`, `supabase_apply_all.sql`, `supabase_verify.sql`. Anciens fichiers de migration supprimés.
2. **Code Flutter** corrigé pour tous les modules listés (section 3).
3. **Service `ExportService`** unifié (PDF + Excel + CSV) réutilisé partout.
4. **Service images** unifié (upload Supabase Storage, max 05, multi-modules : produits, articles, clients).
5. **Filtres** unifiés (période, intervalle, catégorie, sous-catégorie, type, recherche) réutilisables.
6. **Comptabilité branchée** et alimentée.
7. **Réorganisation** du menu « Plus ».
8. **Tests** : unitaires + widget + intégration verts.
9. **Documentation** : `CHANGELOG.md`, `README.md`, `MATRICE_PERMISSIONS.md`, `CAHIER_DES_CHARGES.md`, `AUDIT_FINAL_NYCTA_v3.md` mis à jour.
10. **Rapport d'audit final** avec score révisé (objectif 100%).

---

## 7. Priorisation

1. **🔴 Critique :**
   - Regroupement SQL + suppression doublons.
   - Correction bug export PDF vide (Journal).
   - Correction persistance images Stock.
   - Correction overflow documents émis.
   - Branchement Comptabilité.

2. **🟠 Haute :**
   - Déplacement Journal → Plus, Achat → barre principale.
   - Multi-images produits/articles/clients (max 05).
   - Filtres et exports sur tous les modules listés.
   - Formulaire catégorie connecté + création auto + anti-doublon.
   - Signature entreprise à gauche + espace client à droite.

3. **🟡 Moyenne :**
   - Réorganisation menu « Plus ».
   - Audit formulaire de vente.
   - Audit documents commerciaux.
   - Champs clients étendus (RIB, RCCM, logo, coordonnées).

4. **🟢 Basse :**
   - Finitions UI.
   - Documentation.

---

## 8. Méthodologie obligatoire

1. **Branche Git dédiée** par lot (`feat/sql-regroup`, `fix/exports`, `feat/images`, `feat/filtres`, `feat/menu`).
2. **Lecture intégrale** des fichiers avant modification (règle `PASSES_AUDIT.md`).
3. **Code** aligné sur normes SYSCOHADA/IFRS + `MATRICE_PERMISSIONS.md`.
4. **Tests** obligatoires pour chaque correction.
5. **Documentation** mise à jour à chaque lot.
6. **10 passes** d'expertise/contre-expertise documentées.
7. **`flutter analyze` = 0 erreur** et **`flutter test` = 100% vert** avant push.

---

## 9. Règles d'or

1. Aucune supposition — tout doit être prouvé.
2. Aucune complaisance — si c'est partiel, c'est partiel.
3. Aucune négligence — chaque détail compte.
4. Aucune régression — vérifier l'existant.
5. Aucun secret exposé.
6. Aucun overflow sur toutes tailles et TextScaler.
7. Aucune faille RLS.
8. Aucune incohérence métier (SYSCOHADA/IFRS).
9. Documentation à jour.
10. **Ta réputation d'expert senior en dépend.**

---

## 10. Critère de sortie

- SQL regroupé et exécuté sans erreur.
- Tous les modules listés disposent de leurs filtres et exports (PDF + Excel + CSV).
- Les images produits/articles/clients persistent après redémarrage.
- Le bug d'export PDF vide est corrigé.
- Le module Comptabilité affiche des données.
- L'overflow documents émis est corrigé.
- Le formulaire catégorie est connecté + anti-doublon.
- Les signatures distinguent entreprise (gauche) et client (droite).
- Le menu « Plus » est réorganisé professionnellement.
- `flutter analyze` = 0 erreur, `flutter test` = 100% vert.
- `AUDIT_FINAL_NYCTA_v3.md` mis à jour avec preuves.

---

**Commence par le 🔴 critique. Ne passe au lot suivant qu'après preuve de conformité du précédent. Ta réputation d'expert senior en dépend.**