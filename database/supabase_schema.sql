-- ============================================================================
-- PME Gestion — Schéma SUPABASE (PostgreSQL 15) — v3.0 — 2026-09-26
-- ============================================================================
-- Installation NEUVE (2 scripts, dans l'ordre) :
--   1. supabase_schema.sql        (ce fichier : types + tables + vues)
--   2. supabase_fonctions_rls.sql (fonctions RPC + politiques RLS + triggers)
-- Base EXISTANTE : exécutez supabase_migration.sql PUIS
-- supabase_fonctions_rls.sql (tout est idempotent et ré-exécutable).
-- RLS activée via supabase_fonctions_rls.sql : les politiques appliquent
-- la matrice des 7 rôles (admin, gérant, comptable, caissier, vendeur,
-- stagiaire, partenaire).
-- ============================================================================

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
-- recevrait jamais autrement.
alter table public.company_profile
  add column if not exists mois_charges_generees text;

-- `id` est auto-généré (identity) : on garde la ligne unique en la
-- conditionnant à une table encore vide plutôt qu'à un ON CONFLICT.
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

-- `language sql` est résolu immédiatement à la création : la fonction doit
-- donc être déclarée APRÈS public.users (42P01 sinon).
-- `and actif = true` : un compte désactivé ne peut plus agir — user_role()
-- renvoie NULL et toute policy basée dessus échoue.
create or replace function public.user_role() returns text language sql stable as
$$ select role from public.users where id = auth.uid() and actif = true $$;

-- Helper : l'utilisateur a-t-il accès à cette boutique ? (admin : tout)
create or replace function public.accede_boutique(p_boutique uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_boutiques
    where user_id = auth.uid() and boutique_id = p_boutique
  ) or public.user_role() = 'admin'
$$;

-- Helper : id du partenaire lié au compte courant (rôle partenaire, P8)
create or replace function public.mon_partenaire_id() returns uuid language sql stable as
$$ select partenaire_id from public.users where id = auth.uid() $$;

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
-- 11. CATÉGORIES & LISTES PARAMÉTRABLES (ex-migrations v1.2 + v1.7/v1.13)
-- Produits, charges, opérateurs Mobile Money / crédit, durées de forfait,
-- domaines de prestation — gérés depuis l'écran « Catégories & listes ».
-- ---------------------------------------------------------------------------
create table if not exists public.categories (
  id   uuid primary key default uuid_generate_v4(),
  type text not null,
  nom  text not null,
  unique (type, nom)
);
-- Contrainte finale (élargie) : recrée-la si une base intermédiaire n'avait
-- que ('produit','charge').
alter table public.categories drop constraint if exists categories_type_check;
alter table public.categories add constraint categories_type_check
  check (type in ('produit', 'charge', 'operateur_momo',
                   'operateur_credit', 'domaine_prestation', 'duree_forfait'));

-- Valeurs de départ (ex-listes codées en dur dans l'app). Idempotent.
insert into public.categories (type, nom) values
  ('operateur_momo', 'Orange Money'),
  ('operateur_momo', 'Moov Money'),
  ('operateur_momo', 'Telecel Money'),
  ('operateur_momo', 'Wave'),
  ('operateur_momo', 'Autre'),
  ('operateur_credit', 'Orange'),
  ('operateur_credit', 'Moov'),
  ('operateur_credit', 'Telecel'),
  ('operateur_credit', 'Autre'),
  ('domaine_prestation', 'Informatique'),
  ('domaine_prestation', 'Électricité'),
  ('domaine_prestation', 'Électronique'),
  ('domaine_prestation', 'Vidéosurveillance'),
  ('domaine_prestation', 'Réseaux & Télécom'),
  ('domaine_prestation', 'Autre'),
  ('duree_forfait', '1 heure'),
  ('duree_forfait', '2 heures'),
  ('duree_forfait', '1 jour'),
  ('duree_forfait', '2 jours'),
  ('duree_forfait', '1 semaine'),
  ('duree_forfait', '2 semaines'),
  ('duree_forfait', '1 mois')
on conflict (type, nom) do nothing;

-- ---------------------------------------------------------------------------
-- 12. COLLABORATION (ex-migration v1.3) : fournisseurs, messagerie,
--     événements, notes
-- ---------------------------------------------------------------------------
create table if not exists public.fournisseurs (
  id          uuid primary key default uuid_generate_v4(),
  nom         text not null,
  telephone   text default '',
  email       text default '',
  adresse     text default '',
  specialite  text default '',
  notes       text default '',
  created_at  timestamptz not null default now()
);

-- Messagerie interne (destinataire_id null = diffusion à tous)
create table if not exists public.messages (
  id              uuid primary key default uuid_generate_v4(),
  expediteur_id   uuid not null references auth.users(id),
  expediteur_nom  text not null,
  destinataire_id uuid references auth.users(id), -- null = tous
  sujet           text not null,
  contenu         text not null,
  lu              boolean not null default false,
  created_at      timestamptz not null default now()
);

create table if not exists public.evenements (
  id          uuid primary key default uuid_generate_v4(),
  titre       text not null,
  date        timestamptz not null,
  heure       text default '',
  lieu        text default '',
  description text default '',
  createur_id uuid references auth.users(id),
  created_at  timestamptz not null default now()
);

create table if not exists public.notes (
  id          uuid primary key default uuid_generate_v4(),
  titre       text not null,
  contenu     text default '',
  date        timestamptz not null default now(),
  rappel_le   timestamptz,
  createur_id uuid references auth.users(id),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 13. SUGGESTIONS & SIGNALEMENTS (ex-migration v1.4)
-- ---------------------------------------------------------------------------
create table if not exists public.feedbacks (
  id          uuid primary key default uuid_generate_v4(),
  auteur_id   uuid references auth.users(id),
  auteur_nom  text not null,
  boutique_id uuid references public.boutiques(id),
  type        text not null check (type in
                ('recommandation','suggestion','proposition','panne','avis')),
  priorite    text not null default 'normale'
              check (priorite in ('basse','normale','haute')),
  titre       text not null,
  contenu     text not null,
  statut      text not null default 'nouveau'
              check (statut in ('nouveau','enCours','traite')),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 14. CATALOGUE TARIFAIRE (ex-migration v1.5)
-- ---------------------------------------------------------------------------
create table if not exists public.tarifs (
  id          uuid primary key default uuid_generate_v4(),
  libelle     text not null,
  categorie   text not null default 'Général',
  prix        numeric(15,2) not null check (prix >= 0),
  description text default '',
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 15. JOURNAL D'ACTIVITÉ — audit trail (ex-migration v1.6 + triggers v1.12)
-- Alimenté par trigger générique (voir supabase_fonctions_rls.sql),
-- jamais par le client : aucune policy d'écriture (deny by default).
-- ---------------------------------------------------------------------------
create table if not exists public.journal_activite (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users(id),
  user_nom    text,
  action      text not null,           -- 'insert' | 'update' | 'delete'
  table_nom   text not null,
  ligne_id    text,
  detail      jsonb,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 16. SAUVEGARDES CLOUD (ex-migration v1.11)
-- Snapshots JSONB via sauvegarder_base() ; restauration via restaurer_base().
-- ---------------------------------------------------------------------------
create table if not exists public.sauvegardes (
  id          uuid primary key default uuid_generate_v4(),
  auteur_id   uuid references auth.users(id),
  auteur_nom  text not null,
  nb_lignes   integer not null default 0,
  donnees     jsonb not null,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 17. ACHATS FOURNISSEURS (réapprovisionnement + dette)
-- ---------------------------------------------------------------------------
create table if not exists public.achats (
  id                uuid primary key default uuid_generate_v4(),
  numero            text unique not null,            -- ex : ACH-2026-00007
  boutique_id       uuid not null references public.boutiques(id),
  fournisseur_id    uuid references public.fournisseurs(id),
  fournisseur_nom   text not null default '',
  lignes            jsonb not null default '[]'::jsonb,
  date_achat        timestamptz not null default now(),
  statut            text not null default 'en_attente'
                    check (statut in ('demande','en_attente','valide','recu','annule')),
  mode_paiement     text not null default 'especes'
                    check (mode_paiement in ('especes','mobile_money','credit','virement')),
  reference_facture text,
  notes             text,
  motif_annulation  text,
  montant_paye      numeric(15,2) not null default 0,
  created_by        uuid references auth.users(id),
  created_at        timestamptz not null default now()
);
create index if not exists idx_achats_boutique_date
  on public.achats (boutique_id, date_achat desc);
create index if not exists idx_achats_statut
  on public.achats (boutique_id, statut);

-- ---------------------------------------------------------------------------
-- 18. MOUVEMENTS DE STOCK (traçabilité entrées/sorties/ajustements)
-- ---------------------------------------------------------------------------
create table if not exists public.mouvements_stock (
  id            uuid primary key default uuid_generate_v4(),
  boutique_id   uuid not null references public.boutiques(id),
  produit_id    uuid references public.produits(id),
  produit_nom   text not null default '',
  type          text not null default 'ajustement'
                check (type in ('entree','sortie','ajustement','retour','inventaire')),
  quantite      integer not null default 0,  -- signée : + entrée, − sortie
  stock_apres   integer not null default 0,
  motif         text not null default '',
  ref_id        uuid,                        -- achat/vente/document d'origine
  date_mouvement timestamptz not null default now(),
  created_by    uuid references auth.users(id),
  created_at    timestamptz not null default now()
);
create index if not exists idx_mouvements_produit_date
  on public.mouvements_stock (produit_id, date_mouvement desc);
create index if not exists idx_mouvements_boutique_date
  on public.mouvements_stock (boutique_id, date_mouvement desc);

-- ---------------------------------------------------------------------------
-- 19. ÉCRITURES COMPTABLES (journal SYSCOHADA, immuable)
-- ---------------------------------------------------------------------------
create table if not exists public.ecritures (
  id            uuid primary key default uuid_generate_v4(),
  journal       text not null default 'OD'
                check (journal in ('VT','AC','CA','BQ','OD')),
  date_ecriture timestamptz not null default now(),
  compte        text not null,                 -- plan SYSCOHADA (4xx, 5xx…)
  libelle       text not null default '',
  debit         numeric(15,2) not null default 0,
  credit        numeric(15,2) not null default 0,
  ref_id        uuid,                          -- vente/achat/charge d'origine
  boutique_id   uuid not null references public.boutiques(id),
  created_by    uuid references auth.users(id),
  created_at    timestamptz not null default now(),
  check (debit >= 0 and credit >= 0),
  pointee       boolean not null default false -- rapprochement bancaire
);
create index if not exists idx_ecritures_boutique_compte
  on public.ecritures (boutique_id, compte);
create index if not exists idx_ecritures_ref
  on public.ecritures (ref_id);

-- ---------------------------------------------------------------------------
-- Colonnes ajoutées après coup (idempotent via IF NOT EXISTS / SET DEFAULT)
-- ---------------------------------------------------------------------------
alter table public.documents
  add column if not exists signature_client_path text;
alter table public.ecritures
  add column if not exists pointee boolean not null default false;
-- Garde-fous NOT NULL created_by (évite l'erreur 23502) :
alter table public.charges
  alter column created_by set default auth.uid();
alter table public.documents
  alter column created_by set default auth.uid();

-- VUES MÉTIER
-- ---------------------------------------------------------------------------
-- DROP explicite : CREATE OR REPLACE VIEW refuse de changer l'ensemble des
-- colonnes d'une vue existante (42P16) ; DROP + CREATE rend ce script
-- rejouable même après une exécution partielle antérieure.
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
-- ============================================================================
-- FIN DU SCHÉMA — suite : supabase_fonctions_rls.sql
-- ============================================================================
