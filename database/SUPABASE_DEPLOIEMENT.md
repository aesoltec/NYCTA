# 🚀 Déploiement GRATUIT — Guide pas à pas (sans serveur)

> Services utilisés : **Supabase** (base + API + auth + images, tier Free) —
> aucun serveur, aucune carte bancaire, aucune facture.

## Étape 1 — Créer le projet (5 min)

1. https://supabase.com → **Start your project** → connexion GitHub/Google (gratuit)
2. **New project** → nom : `pme-gestion` → mot de passe base (notez-le) → région : Europe (West)
3. Attendre la fin du provisionnement (~2 min)

## Étape 2 — Créer la base (5 min)

1. Menu **SQL Editor** → **+ New query**
2. Coller **tout le contenu** de `database/supabase_schema.sql` → **Run**
3. **+ New query** → coller `database/supabase_fonctions_rls.sql` → **Run**
4. ✅ 28 tables + 2 vues + politiques RLS finales + 11 fonctions RPC + triggers d'audit + buckets créés

> **Base existante (créée avant v3.0) ?** Exécutez `database/supabase_migration.sql`
> PUIS `database/supabase_fonctions_rls.sql` — tout est idempotent.
> **Vérification :** exécutez `database/VERIFIER_RLS.sql` (6 blocs PASS/FAIL).

## Étape 3 — Stockage des images (2 min)

1. Menu **Storage** → **New bucket** → nom : `media` → **Public : OUI** → Save
   (logo, cachet, signatures et photos produits seront stockés ici — 1 Go gratuit)

## Étape 4 — Authentification (3 min)

1. Menu **Authentication** → **Providers**
2. Activer **Email** (déjà actif par défaut) — l'app crée les comptes
3. (Optionnel) Activer **Phone** pour connexion par OTP Orange/Moov

## Étape 5 — Créer votre compte admin (2 min)

1. **Authentication → Add user → Create new user** : votre email + mot de passe
2. **SQL Editor** :
```sql
insert into public.users (id, nom, role)
select id, 'AESOLTEC AFRIQUE', 'admin' from auth.users where email = 'aestechno.info@gmail.com';
-- boutiques de départ :
insert into public.boutiques (nom, siege) values ('Siège', true);
insert into public.user_boutiques
select u.id, b.id from public.users u, public.boutiques b where u.role = 'admin';
```

## Étape 6 — Brancher l'application (5 min)

1. **Settings → API** : copier `Project URL` et `anon public`
2. Les coller dans le `.env` racine du projet :
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```
3. `flutter pub get && flutter run` — le `SupabaseService` se connecte au démarrage

## Étape 7 — Distribuer l'app (gratuit, sans Play Store)

```bash
flutter build apk --release
```
Le fichier `build/app/outputs/flutter-apk/app-release.apk` (~15 Mo) se partage
directement par **WhatsApp / Bluetooth / Google Drive** à vos employés.
(Play Store : 25 $ one-time — facultatif et payant, pas nécessaire.)

## Limites du tier gratuit (largement suffisantes pour démarrer)

| Ressource | Gratuit | Votre usage estimé |
|---|---|---|
| Base de données | 500 Mo | ~50 000 transactions = ~30 Mo ✅ |
| Stockage images | 1 Go | ~2 000 photos = ~500 Mo ✅ |
| Utilisateurs auth | 50 000/mois | quelques employés ✅ |
| API | 500 000 appels/mois | largement suffisant ✅ |
| Projets | 2 actifs | ✅ |

## Si un jour vous dépassez

- Tier **Pro = 25 $/mois** (toujours sans serveur) — ou repasser au backend
  Node/MySQL fourni dans `backend/` (à héberger sur VPS ~5 $/mois)
- Les deux schémas (MySQL + Supabase) restent synchronisés dans `database/`
