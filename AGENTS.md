# AGENTS.md — Règles pour les agents IA (opencode, Copilot, Cursor, Claude, etc.)

> ⚠️ **INSTRUCTION IMPÉRATIVE — LECTURE OBLIGATOIRE AVANT TOUTE ACTION**
>
> Ce fichier définit les règles absolues que TOUT agent IA doit respecter
> lorsqu'il travaille sur le projet NYCTA.
> Le non-respect d'une seule règle entraîne l'invalidation de la mission.
> Ta réputation d'expert senior en dépend.

---

## 1. Lecture et compréhension obligatoires

1. **Lire INTÉGRALEMENT `MISSION.md`** à la racine du projet avant toute action.
2. **Lire INTÉGRALEMENT `README.md`, `CAHIER_DES_CHARGES.md`, `MATRICE_PERMISSIONS.md`, `AUDIT_FINAL_NYCTA.md` et `PASSES_AUDIT.md`** avant toute modification.
3. **Lire INTÉGRALEMENT chaque fichier concerné** par une modification (code, tests, doc, SQL) avant de le modifier. Aucune modification à l'aveugle.
4. **Comprendre le contexte métier** : gestion PME, comptabilité SYSCOHADA/IFRS, devise FCFA, multi-boutiques, rôles et permissions.
5. En cas de doute sur une exigence, **relire `MISSION.md`** et ne jamais improviser.

---

## 2. Exécution de la mission

1. **Traiter CHAQUE point listé dans `MISSION.md`**, sans exception, sans saut, sans report.
2. **Suivre l'ordre de priorisation** défini dans `MISSION.md` (🔴 critique → 🟠 haute → 🟡 moyenne → 🟢 basse).
3. **Ne passer au point suivant** qu'après **preuve de conformité** du précédent.
4. **Mettre à jour `MISSION_STATUS.md`** après chaque point traité :
   - Statut : ⬜ → 🟡 → ✅ (ou ⚠️ / ❌).
   - Preuve : chemin fichier + n° ligne + test + capture.
   - Date.
5. **Un point non traité = mission NON TERMINÉE.**
6. **Tant que 100% des lignes de `MISSION_STATUS.md` ne sont pas ✅, la mission n'est PAS terminée.**

---

## 3. Règles de qualité absolues

1. **Aucune supposition.** Tout doit être prouvé (code, test, capture, log).
2. **Aucune complaisance.** Si c'est partiel, c'est partiel — statut ⚠️, pas ✅.
3. **Aucune négligence.** Chaque détail compte, même les plus petits.
4. **Aucune régression.** Vérifier que les corrections n'ont rien cassé ailleurs.
5. **Aucun code mort, aucun TODO laissé en suspens.**
6. **Aucun secret exposé** (tokens, clés, mots de passe, service_role).
7. **Aucun overflow** sur toutes tailles (320/360/768/1024) et tous TextScaler (1.0/1.3/1.5/2.0).
8. **Aucune faille RLS.** Toutes les politiques Supabase doivent être cohérentes avec `MATRICE_PERMISSIONS.md`.
9. **Aucune incohérence métier** avec les normes SYSCOHADA/IFRS et les bonnes pratiques comptables.
10. **Aucun doublon** dans le code, les fichiers SQL, la documentation.

---

## 4. Preuves obligatoires

Pour **chaque** point traité, fournir **au minimum 3 preuves** parmi :

- **Code** : chemin fichier + n° ligne + extrait.
- **Test** : nom + résultat (`flutter test` vert).
- **Capture Supabase** : politique RLS, trigger, table, migration.
- **Capture UI** : écran avant/après (si pertinent).
- **Log** : exécution, requête, erreur corrigée.
- **Documentation** : section précise mise à jour.

**Aucune preuve = point NON CONFORME.**

---

## 5. Tests et vérifications techniques

1. **`flutter analyze` = 0 erreur** (warnings acceptables mais à justifier).
2. **`flutter test` = 100% vert** (tous les tests, à chaque push).
3. **`flutter test integration_test/` = 100% vert** sur émulateur (si applicable au lot).
4. **Tests unitaires** : obligatoires pour toute logique métier.
5. **Tests widget** : obligatoires pour tout nouvel écran ou modification UI majeure.
6. **Tests d'intégration** : obligatoires pour tout parcours utilisateur critique.
7. **Golden tests** : obligatoires pour tout écran sensible à l'overflow.
8. **Tests SQL RLS** : obligatoires pour toute modification de politique de sécurité.

---

## 6. Méthodologie d'audit

1. **10 passes d'expertise/contre-expertise** par modification majeure, documentées dans `PASSES_AUDIT.md` :
   - Passe 1 : Vérification fonctionnelle
   - Passe 2 : Vérification métier (normes SYSCOHADA/IFRS)
   - Passe 3 : Vérification sécurité (RLS, permissions)
   - Passe 4 : Vérification overflow/layout
   - Passe 5 : Vérification performance
   - Passe 6 : Vérification tests
   - Passe 7 : Vérification documentation
   - Passe 8 : Vérification régression
   - Passe 9 : Vérification UX
   - Passe 10 : Contre-expertise finale (avocat du diable)
2. Chaque passe conclut : ✅ OK | ⚠️ Réserve | ❌ Échec.
3. **Une seule passe ❌ = modification rejetée et à refaire.**

---

## 7. Gestion Git et branches

1. **Une branche Git dédiée par lot** : `feat/xxx`, `fix/xxx`, `refactor/xxx`.
2. **Commits atomiques** : un commit = un point cohérent.
3. **Messages de commit clairs** en français : `fix(stock): persistance images produits`.
4. **Aucun push direct sur `main`** sans tests verts.
5. **Aucun force-push** sur une branche partagée.
6. **Pull Request obligatoire** pour tout lot majeur, avec description détaillée.

---

## 8. Documentation obligatoire

À mettre à jour **à chaque lot** :

- **`CHANGELOG.md`** : entrée par version, liste des corrections/ajouts.
- **`README.md`** : fonctionnalités, navigation, arborescence.
- **`MATRICE_PERMISSIONS.md`** : toute modification de permissions.
- **`CAHIER_DES_CHARGES.md`** : tout ajout de périmètre ou roadmap.
- **`MISSION_STATUS.md`** : après chaque point traité.
- **`AUDIT_FINAL_NYCTA_v3.md`** : rapport final avec score.
- **`PASSES_AUDIT.md`** : journal des 10 passes par modification.

**Documentation non mise à jour = point non conforme.**

---

## 9. Contraintes techniques projet

1. **Framework** : Flutter (Dart), Provider pour l'état.
2. **Base de données** : Supabase (PostgreSQL) + RLS.
3. **Localisation** : fr_FR. **Devise** : FCFA.
4. **Plateformes** : Android, iOS, Web, Desktop.
5. **SQL** : regrouper dans `supabase_schema.sql`, `supabase_migration.sql`, `supabase_fonctions_rls.sql`. Pas de fichiers individuels.
6. **Exports** : service `ExportService` unifié (PDF + Excel + CSV).
7. **Images** : Supabase Storage (bucket dédié), max 05 par entité, non obligatoires, persistantes.
8. **Filtres** : composant unifié (période, intervalle, catégorie, sous-catégorie, type, recherche).
9. **Signatures** : entreprise à gauche (main levée), espace client à droite (stylo après impression).
10. **Anti-overflow** : `Flexible`, `Expanded`, `SingleChildScrollView`, `ListView`, `LayoutBuilder`, `TextScaler` borné.

---

## 10. Interdictions formelles

1. ❌ **Ne jamais supprimer une fonctionnalité existante** sans validation explicite.
2. ❌ **Ne jamais modifier la matrice de permissions** sans mise à jour de `MATRICE_PERMISSIONS.md`.
3. ❌ **Ne jamais exposer de secret** (clé service_role, token, mot de passe).
4. ❌ **Ne jamais pousser du code non testé.**
5. ❌ **Ne jamais ignorer un point de `MISSION.md`.**
6. ❌ **Ne jamais marquer ✅ un point partiel** (utiliser ⚠️).
7. ❌ **Ne jamais clôturer la mission** tant que 100% des points ne sont pas ✅.
8. ❌ **Ne jamais inventer** une exigence, une règle métier ou une norme.
9. ❌ **Ne jamais casser une fonctionnalité** pour en corriger une autre.
10. ❌ **Ne jamais négliger** les détails UI (overflow, alignement, lisibilité).

---

## 11. Communication avec le demandeur

1. **Rapport clair** à chaque fin de lot :
   - Points traités (avec preuves).
   - Points restants.
   - Blocages éventuels.
   - Recommandations.
2. **Signaler immédiatement** tout point bloquant (SQL à exécuter, émulateur, accès).
3. **Ne jamais masquer** un échec ou une réserve.
4. **Fournir un tableau récapitulatif** point → statut → preuve.
5. **Proposer un plan d'action** pour les points non terminés.

---

## 12. Critère de sortie — 100%

La mission est **terminée** lorsque :

- **100% des lignes de `MISSION_STATUS.md` sont ✅.**
- **`flutter analyze` = 0 erreur.**
- **`flutter test` = 100% vert.**
- **`flutter test integration_test/` = 100% vert** (si applicable).
- **SQL exécuté** sur Supabase réel + captures.
- **`AUDIT_FINAL_NYCTA_v3.md`** affiche **score 100%** et verdict ✅ **CONFORME — Mise en production autorisée**.
- **Documentation à jour** (CHANGELOG, README, MATRICE_PERMISSIONS, CDC, PASSES_AUDIT).
- **Aucune réserve ⚠️ ni ❌** dans `MISSION_STATUS.md`.

**Tant que ces critères ne sont pas tous satisfaits, la mission n'est PAS terminée.**

---

## 13. Rappel final

> **Ta réputation d'expert senior en dépend.**
>
> Aucune supposition. Aucune complaisance. Aucune négligence.
> Chaque point compte. Chaque preuve compte. Chaque test compte.
> Traite `MISSION.md` comme un contrat : tu t'engages à livrer 100%.
>
> **Bonne mission.**