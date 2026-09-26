-- ============================================================================
-- PME GESTION — MIGRATIONS EN ATTENTE (à exécuter sur le Supabase RÉEL)
-- ============================================================================
-- Date : 2026-09-26. Tout est IDEMPOTENT (rejouable sans risque).
-- Ordre d'exécution : ce fichier, dans l'ordre, via SQL Editor Supabase.
-- Base déjà à jour (v3.0) : ne rien exécuter, tout est déjà appliqué.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. CLIENTS — champs étendus (point 28) : email, RCCM, RIB, logo
-- ---------------------------------------------------------------------------
alter table public.clients
  add column if not exists email text default '';
alter table public.clients
  add column if not exists rccm text default '';
alter table public.clients
  add column if not exists rib text default '';
alter table public.clients
  add column if not exists logo_path text;


-- ---------------------------------------------------------------------------
-- 2. TARIFS — galerie multi-images (point 36)
-- ---------------------------------------------------------------------------
alter table public.tarifs
  add column if not exists images jsonb not null default '[]'::jsonb;


-- ---------------------------------------------------------------------------
-- 3. RPC RÉOUVERTURE BOUTIQUE (point 22bis) — admin/gérant, SECURITY DEFINER
-- ---------------------------------------------------------------------------
create or replace function public.reouvrir_boutique(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.user_role() not in ('admin', 'gerant') then
    raise exception 'Réouverture boutique réservée (admin, gérant).';
  end if;
  update public.boutiques
     set actif = true
   where id = p_id;
  if not found then
    raise exception 'Boutique introuvable : %', p_id;
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 4. VÉRIFICATION (optionnel, en fin d'exécution)
-- ---------------------------------------------------------------------------
-- select column_name from information_schema.columns
--  where table_name = 'clients' and column_name in ('email','rccm','rib','logo_path');
-- select column_name from information_schema.columns
--  where table_name = 'tarifs' and column_name = 'images';
-- select proname from pg_proc where proname = 'reouvrir_boutique';
