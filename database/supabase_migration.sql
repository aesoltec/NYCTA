-- ============================================================================
-- PME Gestion — MIGRATION vers v3.0 — 2026-09-26
-- ============================================================================
-- Pour les bases EXISTANTES (créées avec le schéma v1.0 ou consolidé).
-- Ordre : 1. supabase_migration.sql (ce fichier : structure manquante)
--         2. supabase_fonctions_rls.sql (réaligne RLS + fonctions + triggers)
-- Tout est idempotent : ré-exécutable sans risque, ne touche jamais aux
-- données existantes (que des CREATE IF NOT EXISTS / ADD COLUMN IF NOT
-- EXISTS / DROP+CREATE de policies, contraintes et triggers).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Valeur 'bon_livraison' dans l'enum type_document (bordereau de livraison).
-- Idempotent : ne fait rien si la valeur existe déjà.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'type_document' AND e.enumlabel = 'bon_livraison'
  ) THEN
    ALTER TYPE type_document ADD VALUE 'bon_livraison';
  END IF;
END
$$;

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

-- FIN DE LA MIGRATION — suite : supabase_fonctions_rls.sql
