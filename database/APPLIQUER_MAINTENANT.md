# APPLIQUER MAINTENANT — Guide d'exécution manuelle (hors opencode)

> Destinataire : l'utilisateur. Date : 2026-09-26.
> Tout est **idempotent** : rejouable sans risque sur base existante.

## 0. Nettoyage des médias en double (133 entrées / 19 images réelles)

*Opération de DONNÉES, à faire UNE SEULE FOIS après la correction du code
(v1.13.1, commit `9adf1fb`).*

| Étape | Fichier | Effet |
|---|---|---|
| 1. Diagnostic | `DIAGNOSTIC_DOUBLONS_MEDIA.sql` | Lecture seule : liste les objets et dit lesquels sont utilisés |
| 2. Fonction | `NETTOYAGE_MEDIA_ORPHELINS.sql` (fonction seule) | Installe `nettoyer_media_orphelins()` — ne supprime rien |
| 3-5. Nettoyage | idem, 3 appels `select` | Liste → valide le compte → supprime |
| 6. Vérification | rejouer le diagnostic | Plus aucun orphelin |

**Guide pas à pas : `NETTOYAGE_MEDIA_GUIDE.md`**

⚠️ Sauvegarde obligatoire avant l'étape 5, et application fermée pendant
l'opération (enregistrer un produit recréerait un objet). La fonction est
protégée par un seuil de confirmation : elle refuse de supprimer si le
nombre d'orphelins détectés ne correspond pas exactement au nombre validé.

Le script exclut les images de marque (logo, cachet, signature) et son sens
d'erreur est volontairement conservateur : une image utilisée n'est jamais
supprimée, un orphelin peut parfois survivre un passage.

### Migration appliquée le 2026-10-03

`database/SUPABASE_A_EXECUTER.sql` a été exécuté sur la base réelle.
**Vérification immédiate** (lecture seule, 9 contrôles attendus `ok = true`) :

```sql
-- coller dans Supabase Dashboard -> SQL Editor
-- ou : database/VERIFIER_MIGRATION.sql
```

### ENCORE : `null value in column "boutique_id"` (code 23502)

```
❌ SyncService : opération bloquée définitivement (produits)
   - PostgrestException(null value in column "boutique_id" ... violates
     not-null constraint, code: 23502)
```

**Ce n'était pas un problème de migration.** Cause racine : la file de
synchronisation rejouait des payloads **partiels** (`{id, actif: false}`)
avec `upsert`, qui est un `INSERT ... ON CONFLICT DO UPDATE`. La ligne
passait tant qu'elle existait en base ; dès qu'elle n'existait pas
(produit créé hors-ligne), le serveur tentait de l'insérer sans
`boutique_id` et l'entrée se bloquait définitivement après 8 essais.

**Corrigé en v1.13.4 (commit `72bcb0d`).** Les mises à jour partielles
passent maintenant par le suffixe `__update` (un vrai `UPDATE`), et
`SyncService.reparerEntreesLegacy()` re-route au démarrage les entrées
déjà bloquées avant le correctif. **Aucune action de ta part.**

Si ce message revient encore, la base n'a pas été atteinte : vérifie le
réseau, puis Menu Plus -> Synchronisation pour l'état de la file.

### Ancienne consigne, périmée

> ~~« Vider la file bloquée » : Menu Plus -> Synchronisation ->
> « Relancer les opérations bloquées ».~~

Plus nécessaire depuis la 1.13.4 : la file se débloque seule au
démarrage. Le bouton reste disponible si tu dois forcer.

## 1. SQL — migrations en attente (Supabase réel)

**Fichier unique : `database/SUPABASE_A_EXECUTER.sql`** (ordre interne géré).

1. Ouvrir **Supabase Dashboard → SQL Editor → New query**.
2. Copier-coller **tout le contenu** de `database/SUPABASE_A_EXECUTER.sql`.
3. **Run**. Attendu : 0 erreur.

Contenu (rappel) :
| # | Objet | Détail |
|---|---|---|
| 1 | `clients` | colonnes `email`, `rccm`, `rib`, `logo_path` (point 28) |
| 2 | `tarifs` | colonne `images` JSONB (point 36) |
| 3 | `produits`, `tarifs` | colonne `date_ajout timestamptz` — badge « Nouveau » |
| 4 | RPC `reouvrir_boutique(p_id)` | admin/gérant, vérifie « fermée », journalise (point 22bis) |

**Vérification** : `database/VERIFIER_MIGRATION.sql` (lecture seule,
9 contrôles, attendu `ok = true` partout). Plus fiable que de relire les
DDL : le SQL Editor affiche « success » même quand une section a
échoué silencieusement.

## 2. SQL — installation complète (base NEUVE uniquement)

Ordre strict (jamais sur base existante) :
1. `database/supabase_apply_all.sql` (schéma + fonctions/RLS, 1 exécution)
2. `database/supabase_verify.sql` → **6 blocs PASS/FAIL attendus : 6 PASS**

Base **existante** : `database/supabase_migration.sql` PUIS
`database/supabase_fonctions_rls.sql` PUIS `database/supabase_verify.sql`.

## 3. Edge Function `admin-update-user` (v3)

```bash
supabase functions deploy admin-update-user --project-ref <VOTRE_REF>
```
Vérifier dans Dashboard → Edge Functions : `admin-update-user` = Active.
(Rôle : création/modification de comptes utilisateurs par l'admin,
côté serveur, avec audit `journal_activite`.)

## 4. Tests d'intégration (émulateur physique requis)

```bash
flutter test integration_test/app_flow_test.dart
```
Parcours : démarrage → connexion démo → dashboard → vente prestation →
journal (via Plus). Le miroir VM `test/parcours_test.dart` est vert en CI.

## 5. Build de production (rappel)

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS (macOS)
flutter build web --release          # Web
```

## En cas d'erreur

| Erreur | Cause probable | Correctif |
|---|---|---|
| `23502` `boutique_id` not-null | payload partiel rejoué en `upsert` | **corrigé en 1.13.4** ; vider la file via Menu Plus -> Synchronisation si résiduel |
| `PGRST204` `date_ajout` | migration non jouée | `database/SUPABASE_A_EXECUTER.sql` section 3 |
| `42501` sur `boutiques` | policy UPDATE | passer par la RPC (déployée en §1) |
| `42P01` sur `reouvrir_boutique` | fonction absente | rejouer §1.3 |
| `column does not exist` (clients/tarifs) | migration non jouée | rejouer §1.1/§1.2 |
| `relation "categories" does not exist` | base ancienne | §2 base existante |
