-- ============================================================================
-- MIGRATION comptabilité (mission §3.3/§4) — Journal SYSCOHADA simplifié.
-- Écritures immuables (corrections par contre-écriture), générées par
-- l'app : ventes (VT), Mobile Money (BQ), réceptions (AC), paiements (BQ),
-- charges (OD). À exécuter dans Supabase → SQL Editor. Idempotent.
--
-- Prérequis : schéma consolidé + f_journal_activite (v1.12+).
-- ============================================================================

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
  check (debit >= 0 and credit >= 0)
);
create index if not exists idx_ecritures_boutique_compte
  on public.ecritures (boutique_id, compte);
create index if not exists idx_ecritures_ref
  on public.ecritures (ref_id);

alter table public.ecritures enable row level security;

-- Lecture : boutiques accessibles (rôles caisse/rapports).
drop policy if exists "ecriture select" on public.ecritures;
drop policy if exists "ecritures select" on public.ecritures;
create policy "ecritures select" on public.ecritures
  for select to authenticated using (public.accede_boutique(boutique_id));

-- Écriture : générées par l'app pour les rôles financiers. JAMAIS
-- d'update/delete direct (immuabilité : seules des contre-écritures
-- en insert corrigent — policy insert seule, aucun update/delete).
drop policy if exists "ecritures insert" on public.ecritures;
create policy "ecritures insert" on public.ecritures
  for insert to authenticated
  with check (
    public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
    and public.accede_boutique(boutique_id)
  );

-- Audit trail : même trigger générique que les autres tables métier.
drop trigger if exists trg_journal_ecritures on public.ecritures;
create trigger trg_journal_ecritures
  after insert or update or delete on public.ecritures
  for each row execute function public.f_journal_activite();
-- ============================================================================
