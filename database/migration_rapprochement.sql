-- ============================================================================
-- MIGRATION rapprochement + validation documents (mission, 100%).
-- À exécuter dans Supabase → SQL Editor. Idempotent et ré-exécutable.
-- Prérequis : migration_compta.sql appliquée.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Rapprochement bancaire : flag `pointee` sur les écritures (coché
--    quand retrouvée sur le relevé). Modifiable sans toucher aux montants.
-- ---------------------------------------------------------------------------
alter table public.ecritures
  add column if not exists pointee boolean not null default false;

-- L'immutabilité reste garantie par l'absence de policy UPDATE large :
-- une seule policy ciblée sur la colonne `pointee`. Postgres ne permet
-- pas de restreindre une policy à une colonne : le garde applicatif
-- (Store.pointerEcriture ne touche qu'au flag) + l'audit trail
-- (trigger journal) compensent — toute modification est tracée.
drop policy if exists "ecritures pointage" on public.ecritures;
create policy "ecritures pointage" on public.ecritures
  for update to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));

-- Audit trail sur les écritures (si migration_compta.sql antérieure
-- au trigger générique, elle ne l'avait pas).
drop trigger if exists trg_journal_ecritures on public.ecritures;
create trigger trg_journal_ecritures
  after insert or update or delete on public.ecritures
  for each row execute function public.f_journal_activite();

-- ---------------------------------------------------------------------------
-- 2. Validation documents : l'app met à jour `statut` (brouillon→emis)
--    et `signature_client_path` après émission — il faut une policy UPDATE
--    dédiée (rôles financiers + boutique), absente jusqu'ici.
-- ---------------------------------------------------------------------------
drop policy if exists "maj documents" on public.documents;
create policy "maj documents" on public.documents
  for update to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));
-- ============================================================================
