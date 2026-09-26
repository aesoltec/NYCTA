# APPLIQUER MAINTENANT — Guide d'exécution manuelle (hors opencode)

> Destinataire : l'utilisateur. Date : 2026-09-26.
> Tout est **idempotent** : rejouable sans risque sur base existante.

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
