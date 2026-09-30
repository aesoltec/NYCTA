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

### ERREUR AU LANCEMENT : `Could not find the 'date_ajout' column`

```
❌ SyncService : opération bloquée définitivement (produits)
   — PostgrestException(PGRST204 : Could not find the 'date_ajout' column)
```

**Ce n'est pas une erreur de code** : c'est la migration de la refonte UX
(badge « Nouveau ») qui n'a pas encore été appliquée à ta base. Elle
est prête, section 3 de `database/SUPABASE_A_EXECUTER.sql` :

```sql
alter table public.produits add column if not exists date_ajout timestamptz;
alter table public.tarifs   add column if not exists date_ajout timestamptz;
```

**Ce que faire, dans l'ordre :**

1. Ouvre la totalité de `database/SUPABASE_A_EXECUTER.sql` dans le SQL
   Editor et *Run* (il est **idempotent** : rejouable sans risque).
2. Relance l'app.

**Ce qui a été fait en attendant** (v1.13.2) : le `SyncService` retry
maintenant une fois **sans** les colonnes optionnelles quand PostgREST
signale une colonne absente. Tes saisies hors-ligne ne sont donc plus
bloquées définitivement ‐ elles se synchronisent, seul le badge
« Nouveau » manque tant que la migration n'est pas faite.

**Vider la file bloquée** (les entrées passées en `en_erreur` avant le
correctif restent bloquées) : app → Menu Plus → Synchronisation →
« Relancer les opérations bloquées ». Ou les supprimer définitivement
depuis le même écran si tu ne veux pas les rejouer.

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
| 3 | RPC `reouvrir_boutique(p_id)` | admin/gérant, vérifie « fermée », journalise (point 22bis) |

**Vérification** (optionnel, en fin de fichier) :
```sql
select column_name from information_schema.columns
 where table_name = 'clients'
   and column_name in ('email','rccm','rib','logo_path');
select proname from pg_proc where proname = 'reouvrir_boutique';
```

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
| `42501` sur `boutiques` | policy UPDATE | passer par la RPC (déployée en §1) |
| `42P01` sur `reouvrir_boutique` | fonction absente | rejouer §1.3 |
| `column does not exist` (clients/tarifs) | migration non jouée | rejouer §1.1/§1.2 |
| `relation "categories" does not exist` | base ancienne | §2 base existante |
