-- ============================================================================
-- PME Gestion — Schéma SUPABASE (PostgreSQL 15)  v1.0 — 2026-09-10
-- Hébergement GRATUIT : https://supabase.com (tier Free : 500 Mo DB,
-- authentification, API auto, stockage images, realtime).
-- Déploiement : Supabase Dashboard → SQL Editor → coller ce fichier → Run.
-- RLS activée : les politiques appliquent la matrice des 7 rôles.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Extensions & types
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp";

do $$ begin
  create type role_utilisateur as enum
    ('admin','gerant','comptable','caissier','vendeur','stagiaire','partenaire');
exception when duplicate_object then null; end $$;

do $$ begin
  create type type_transaction as enum
    ('prestation_service','vente_materiel','mobile_money',
     'credit_communication','forfait_hotspot');
exception when duplicate_object then null; end $$;

do $$ begin
  create type type_document as enum
    ('facture','devis_proforma','bon_commande','ticket_caisse','bon_livraison');
exception when duplicate_object then null; end $$;

do $$ begin
  create type statut_paiement as enum ('paye','partiel','impaye');
exception when duplicate_object then null; end $$;

do $$ begin
  create type statut_partage as enum ('en_cours','valide','paye');
exception when duplicate_object then null; end $$;

do $$ begin
  create type statut_document as enum ('brouillon','emis','paye','annule');
exception when duplicate_object then null; end $$;

do $$ begin
  create type type_fichier as enum
    ('logo','cachet','signature','produit','document','autre');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 1. PROFIL ENTREPRISE (une ligne — écran Configuration)
-- ---------------------------------------------------------------------------
create table if not exists public.company_profile (
  id                 integer generated always as identity primary key,
  nom_entreprise     text not null default 'Mon Entreprise',
  devise             text not null default 'FCFA',
  telephone          text default '',
  telephone2         text default '',
  email              text default '',
  adresse            text default '',
  rccm               text default '',           -- Registre de Commerce
  ifu                text default '',           -- Identifiant Fiscal Unique
  autre_ref_fiscale  text default '',
  banque             text default '',
  coordonnees_bancaires text default '',
  message_pied       text default 'Merci de votre confiance.',
  tva                numeric(5,2) not null default 0,
  logo_path          text,                     -- URL bucket « media »
  cachet_path        text,
  signature_path     text,
  mois_charges_generees text,                  -- 'AAAA-MM' : anti-doublon
  updated_at         timestamptz not null default now()
);
-- `alter ... add column if not exists`, pas seulement `create table if not
-- exists` : une base déjà installée avant l'ajout de cette colonne ne la
-- recevrait jamais autrement (le CREATE TABLE ci-dessus ne s'exécute que
-- si la table n'existe pas encore).
alter table public.company_profile
  add column if not exists mois_charges_generees text;

-- `id` est auto-généré (identity) : aucune colonne unique ne peut servir de
-- cible à ON CONFLICT, donc on garde la ligne unique en la conditionnant à
-- une table encore vide plutôt qu'à un ON CONFLICT DO NOTHING (qui, sans
-- cible, ne se serait jamais déclenché ici et aurait dupliqué la ligne à
-- chaque ré-exécution du script).
insert into public.company_profile (nom_entreprise, devise)
select 'Mon Entreprise', 'FCFA'
where not exists (select 1 from public.company_profile);

-- ---------------------------------------------------------------------------
-- 2. BOUTIQUES
-- ---------------------------------------------------------------------------
create table if not exists public.boutiques (
  id         uuid primary key default uuid_generate_v4(),
  nom        text not null,
  adresse    text default '',
  telephone  text default '',
  siege      boolean not null default false,
  actif      boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. UTILISATEURS (liés à auth.users de Supabase Auth)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  nom        text not null,
  telephone  text default '',
  role       role_utilisateur not null default 'vendeur',
  partenaire_id uuid,
  actif      boolean not null default true,
  created_at timestamptz not null default now()
);

-- `language sql` (contrairement à plpgsql) est résolu immédiatement à la
-- création : la fonction doit donc être déclarée APRÈS public.users, sous
-- peine d'un 42P01 "relation public.users does not exist" au CREATE.
-- `and actif = true` : sans ce filtre, désactiver un compte (écran
-- Utilisateurs → Supprimer) ne l'empêchait pas d'agir — aucune policy RLS
-- (toutes basées sur user_role()) ne consultait la colonne "actif", donc un
-- employé "supprimé" gardait un accès en écriture intact tant que sa
-- session restait valide (l'anon key ne permet pas de révoquer la session
-- Auth elle-même). Avec ce filtre, user_role() renvoie NULL pour un compte
-- désactivé et toute policy "user_role() in (...)" ou "= '...'" échoue.
create or replace function public.user_role() returns text language sql stable as
$$ select role from public.users where id = auth.uid() and actif = true $$;

create table if not exists public.user_boutiques (
  user_id     uuid not null references public.users(id) on delete cascade,
  boutique_id uuid not null references public.boutiques(id) on delete cascade,
  primary key (user_id, boutique_id)
);

-- ---------------------------------------------------------------------------
-- 4. CLIENTS
-- ---------------------------------------------------------------------------
create table if not exists public.clients (
  id          uuid primary key default uuid_generate_v4(),
  boutique_id uuid not null references public.boutiques(id),
  nom         text not null,
  telephone   text default '',
  adresse     text default '',
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. PRODUITS (stock + photo)
-- ---------------------------------------------------------------------------
create table if not exists public.produits (
  id              uuid primary key default uuid_generate_v4(),
  boutique_id     uuid not null references public.boutiques(id),
  libelle         text not null,
  categorie       text not null default 'Autre',
  prix_achat      numeric(15,2) not null default 0,
  prix_vente      numeric(15,2) not null default 0,
  quantite_stock  integer not null default 0,
  seuil_alerte    integer not null default 3,
  image_path      text,                        -- URL bucket « media »
  actif           boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. TRANSACTIONS (marge calculée automatiquement)
-- ---------------------------------------------------------------------------
create table if not exists public.transactions (
  id               uuid primary key default uuid_generate_v4(),
  boutique_id      uuid not null references public.boutiques(id),
  employe_id       uuid not null references public.users(id),
  type             type_transaction not null,
  montant          numeric(15,2) not null,
  cout             numeric(15,2) not null default 0,
  marge            numeric(15,2) generated always as (montant - cout) stored,
  statut           statut_paiement not null default 'paye',
  client_id        uuid references public.clients(id),
  client_nom       text,
  partenaire_id    uuid,
  details          jsonb,
  date_transaction timestamptz not null default now(),
  created_at       timestamptz not null default now()
);
create index if not exists idx_tx_boutique_date
  on public.transactions (boutique_id, date_transaction desc);
create index if not exists idx_tx_partenaire
  on public.transactions (partenaire_id, type, date_transaction);

-- ---------------------------------------------------------------------------
-- 7. PARTENAIRES & PARTAGES MENSUELS
-- ---------------------------------------------------------------------------
create table if not exists public.partenaires (
  id           uuid primary key default uuid_generate_v4(),
  nom          text not null,
  telephone    text default '',
  localisation text default '',
  taux_partage numeric(5,4) not null default 0.6000,
  user_id      uuid references public.users(id),  -- compte app (P8)
  actif        boolean not null default true,
  created_at   timestamptz not null default now()
);

alter table public.transactions
  drop constraint if exists fk_tx_partenaire;
alter table public.transactions
  add constraint fk_tx_partenaire
  foreign key (partenaire_id) references public.partenaires(id);

create table if not exists public.partages_mensuels (
  id              uuid primary key default uuid_generate_v4(),
  partenaire_id   uuid not null references public.partenaires(id),
  boutique_id     uuid not null references public.boutiques(id),
  mois            char(7) not null,            -- 'AAAA-MM'
  total_ventes    numeric(15,2) not null default 0,
  taux_partage    numeric(5,4) not null,
  part_partenaire numeric(15,2) not null,
  part_entreprise numeric(15,2) not null,
  statut          statut_partage not null default 'valide',
  valide_le       timestamptz,
  valide_par      uuid references public.users(id),
  created_at      timestamptz not null default now(),
  unique (partenaire_id, mois)                 -- une clôture par mois
);

-- ---------------------------------------------------------------------------
-- 8. CHARGES, BUDGETS, FONDS DE ROULEMENT
-- ---------------------------------------------------------------------------
create table if not exists public.charges (
  id          uuid primary key default uuid_generate_v4(),
  boutique_id uuid not null references public.boutiques(id),
  categorie   text not null default 'Autre',
  libelle     text not null,
  montant     numeric(15,2) not null,
  date_charge timestamptz not null default now(),
  recurrente  boolean not null default false,
  created_by  uuid not null references public.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_charges_boutique_mois
  on public.charges (boutique_id, categorie, date_charge);

create table if not exists public.budgets_mensuels (
  categorie text primary key,
  montant   numeric(15,2) not null default 0
);

create table if not exists public.fonds_roulement (
  boutique_id uuid primary key references public.boutiques(id),
  montant     numeric(15,2) not null default 0,
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 9. DOCUMENTS COMMERCIAUX
-- ---------------------------------------------------------------------------
create table if not exists public.documents (
  id          uuid primary key default uuid_generate_v4(),
  boutique_id uuid not null references public.boutiques(id),
  type        type_document not null,
  numero      text unique not null,            -- ex : FACT-2026-00042
  date_doc    timestamptz not null default now(),
  client_nom  text default '',
  total_ht    numeric(15,2) not null default 0,
  tva         numeric(15,2) not null default 0,
  total_ttc   numeric(15,2) not null default 0,
  statut      statut_document not null default 'emis',
  created_by  uuid not null references public.users(id),
  created_at  timestamptz not null default now()
);

create table if not exists public.document_lignes (
  id            uuid primary key default uuid_generate_v4(),
  document_id   uuid not null references public.documents(id) on delete cascade,
  libelle       text not null,
  quantite      integer not null default 1,
  prix_unitaire numeric(15,2) not null default 0,
  total         numeric(15,2) generated always as (quantite * prix_unitaire) stored
);

create table if not exists public.compteurs_documents (
  prefixe  text not null,
  annee    smallint not null,
  compteur integer not null default 0,
  primary key (prefixe, annee)
);

-- ---------------------------------------------------------------------------
-- 10. FICHIERS (traçabilité médias)
-- ---------------------------------------------------------------------------
create table if not exists public.fichiers (
  id              uuid primary key default uuid_generate_v4(),
  chemin          text not null,
  type            type_fichier not null,
  proprietaire_id uuid,
  uploaded_by     uuid references public.users(id),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- VUES MÉTIER
-- ---------------------------------------------------------------------------
-- DROP explicite : CREATE OR REPLACE VIEW refuse de changer l'ensemble des
-- colonnes d'une vue existante (erreur 42P16) ; DROP + CREATE le permet et
-- rend ce script rejouable même après une exécution partielle antérieure.
drop view if exists public.v_soldes_caisse;
create view public.v_soldes_caisse as
select
  b.id   as boutique_id,
  b.nom  as boutique,
  coalesce(fr.montant, 0) as fonds_roulement,
  coalesce((select sum(t.montant) from public.transactions t
            where t.boutique_id = b.id and t.statut = 'paye'), 0) as total_encaisse,
  coalesce((select sum(c.montant) from public.charges c
            where c.boutique_id = b.id), 0) as total_depenses,
  coalesce(fr.montant, 0)
    + coalesce((select sum(t.montant) from public.transactions t
                where t.boutique_id = b.id and t.statut = 'paye'), 0)
    - coalesce((select sum(c.montant) from public.charges c
                where c.boutique_id = b.id), 0) as solde_caisse
from public.boutiques b
left join public.fonds_roulement fr on fr.boutique_id = b.id;

drop view if exists public.v_ca_par_activite;
create view public.v_ca_par_activite as
select
  boutique_id,
  to_char(date_transaction, 'YYYY-MM') as mois,
  type,
  sum(montant) as ca,
  sum(marge)   as marge
from public.transactions
group by boutique_id, mois, type;

-- ---------------------------------------------------------------------------
-- RLS — SÉCURITÉ PAR RÔLE (matrice identique à l'app Flutter)
-- ---------------------------------------------------------------------------
alter table public.company_profile  enable row level security;
alter table public.boutiques        enable row level security;
alter table public.users            enable row level security;
alter table public.user_boutiques   enable row level security;
alter table public.clients          enable row level security;
alter table public.produits         enable row level security;
alter table public.transactions     enable row level security;
alter table public.partenaires      enable row level security;
alter table public.partages_mensuels enable row level security;
alter table public.charges          enable row level security;
alter table public.budgets_mensuels enable row level security;
alter table public.fonds_roulement  enable row level security;
alter table public.documents        enable row level security;
alter table public.document_lignes  enable row level security;
alter table public.compteurs_documents enable row level security;
alter table public.fichiers         enable row level security;
-- Aucune policy ci-dessous pour ces deux tables : ni le client Flutter ni
-- aucune policy "lecture"/"ecriture" ne les touche directement — deny-by-
-- default est le comportement voulu. compteurs_documents n'est modifiée que
-- par prochain_numero() (SECURITY DEFINER, contourne RLS) ; fichiers reste
-- une table de traçabilité côté serveur.

-- Toutes les policies sont précédées d'un DROP POLICY IF EXISTS : CREATE
-- POLICY n'a pas de variante "OR REPLACE", donc sans ce garde-fou une
-- ré-exécution partielle ou répétée de ce script (édition, correctif, essai
-- raté) échoue avec "policy already exists" dès la deuxième tentative.

-- Lectures : tout utilisateur authentifié (l'app filtre par boutique/permissions)
drop policy if exists "lecture profile" on public.company_profile;
create policy "lecture profile"  on public.company_profile
  for select to authenticated using (true);
drop policy if exists "lecture boutiques" on public.boutiques;
create policy "lecture boutiques" on public.boutiques
  for select to authenticated using (true);
drop policy if exists "lecture produits" on public.produits;
create policy "lecture produits" on public.produits
  for select to authenticated using (true);
drop policy if exists "lecture transactions" on public.transactions;
create policy "lecture transactions" on public.transactions
  for select to authenticated using (true);
drop policy if exists "lecture charges" on public.charges;
create policy "lecture charges" on public.charges
  for select to authenticated using (true);
drop policy if exists "lecture partenaires" on public.partenaires;
create policy "lecture partenaires" on public.partenaires
  for select to authenticated using (true);
drop policy if exists "lecture partages" on public.partages_mensuels;
create policy "lecture partages" on public.partages_mensuels
  for select to authenticated using (true);
drop policy if exists "lecture documents" on public.documents;
create policy "lecture documents" on public.documents
  for select to authenticated using (true);
drop policy if exists "lecture lignes" on public.document_lignes;
create policy "lecture lignes" on public.document_lignes
  for select to authenticated using (true);
drop policy if exists "lecture budgets" on public.budgets_mensuels;
create policy "lecture budgets" on public.budgets_mensuels
  for select to authenticated using (true);
drop policy if exists "lecture users" on public.users;
create policy "lecture users" on public.users
  for select to authenticated using (true);

-- Écritures : permissions par rôle (user_role() lit le rôle dans public.users)
drop policy if exists "config profile" on public.company_profile;
create policy "config profile" on public.company_profile
  for update to authenticated
  using (public.user_role() in ('admin','gerant'));

drop policy if exists "ecriture produits" on public.produits;
create policy "ecriture produits" on public.produits
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','vendeur'));
drop policy if exists "maj produits" on public.produits;
create policy "maj produits" on public.produits
  for update to authenticated
  using (public.user_role() in ('admin','gerant','vendeur'));

drop policy if exists "ecriture transactions" on public.transactions;
create policy "ecriture transactions" on public.transactions
  for insert to authenticated
  with check (public.user_role() in
    ('admin','gerant','comptable','caissier','vendeur','partenaire'));

drop policy if exists "ecriture charges" on public.charges;
create policy "ecriture charges" on public.charges
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','comptable'));
drop policy if exists "maj budgets" on public.budgets_mensuels;
create policy "maj budgets" on public.budgets_mensuels
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));
drop policy if exists "maj fonds" on public.fonds_roulement;
create policy "maj fonds" on public.fonds_roulement
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

drop policy if exists "ecriture partenaires" on public.partenaires;
create policy "ecriture partenaires" on public.partenaires
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));
drop policy if exists "ecriture partages" on public.partages_mensuels;
create policy "ecriture partages" on public.partages_mensuels
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant'));

drop policy if exists "ecriture documents" on public.documents;
create policy "ecriture documents" on public.documents
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','comptable','caissier'));
-- `with check (true)` laissait n'importe quel rôle authentifié (y compris
-- stagiaire/partenaire) ajouter des lignes à N'IMPORTE QUEL document : la FK
-- garantit seulement que document_id existe, pas le droit d'y toucher.
drop policy if exists "ecriture lignes" on public.document_lignes;
create policy "ecriture lignes" on public.document_lignes
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','comptable','caissier'));

-- « for all using(true) with check(true) » à tout rôle authentifié laissait
-- n'importe quel compte (y compris stagiaire — lecture seule dans l'app —
-- ou partenaire) lire/modifier/supprimer n'importe quelle fiche client via
-- l'API REST, en contournant totalement l'UI.
drop policy if exists "lecture clients" on public.clients;
create policy "lecture clients" on public.clients
  for select to authenticated using (true);
drop policy if exists "ecriture clients" on public.clients;
create policy "ecriture clients" on public.clients
  for all to authenticated
  using (public.user_role() <> 'stagiaire')
  with check (public.user_role() <> 'stagiaire');

-- ---------------------------------------------------------------------------
-- DONNÉES DE RÉFÉRENCE
-- ---------------------------------------------------------------------------
insert into public.budgets_mensuels (categorie, montant) values
  ('Loyer', 0), ('Salaires', 0), ('Fournisseurs', 0),
  ('Électricité & Eau', 0), ('Taxes & Fiscalité', 0),
  ('Transport', 0), ('Communication', 0), ('Autre', 0)
on conflict (categorie) do nothing;

-- ---------------------------------------------------------------------------
-- STOCKAGE IMAGES : exécuter aussi, dans Storage → New bucket
--   nom : media   |  Public : OUI   (logo, cachet, signatures, photos produits)
-- Historique : v1.0 création initiale (miroir du schéma MySQL v1.0).
-- ---------------------------------------------------------------------------
