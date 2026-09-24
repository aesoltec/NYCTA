-- ============================================================================
-- MIGRATION achats (Phase 2) — Achats fournisseurs : réapprovisionnement
-- stock + dette fournisseur. À exécuter dans Supabase → SQL Editor.
-- Idempotent et ré-exécutable.
--
-- Table unique : lignes en JSONB (même pattern que transactions.details) —
-- pas de table de lignes, pas de RLS supplémentaire.
-- Cycle : demande → en_attente → valide → recu (+paiements) ; annule.
--
-- Prérequis : fonctions consolidées à jour (f_journal_activite, v1.12+).
-- ============================================================================

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

alter table public.achats enable row level security;

-- Lecture : boutiques accessibles (comme transactions/produits/charges).
drop policy if exists "achats select" on public.achats;
create policy "achats select" on public.achats
  for select to authenticated using (public.accede_boutique(boutique_id));

-- Écriture : admin/gérant/comptable (matrice app, Permission.gererAchats).
-- Les demandes vendeur/caissier transitent par un compte autorisé via
-- l'app ; le statut `demande` reste modifiable uniquement par ces rôles.
drop policy if exists "achats ecriture" on public.achats;
create policy "achats ecriture" on public.achats
  for all to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));

-- Audit trail : même trigger générique que les autres tables métier.
drop trigger if exists trg_journal_achats on public.achats;
create trigger trg_journal_achats
  after insert or update or delete on public.achats
  for each row execute function public.f_journal_activite();
-- ============================================================================
