-- ============================================================================
-- PME Gestion — RPC RÉOUVERTURE BOUTIQUE (point 22bis) — 2026-09-26
-- ============================================================================
-- Réactive une boutique fermée (soft delete). Réservée admin/gérant,
-- côté serveur (miroir de la policy "boutiques update").
-- SECURITY DEFINER : le rôle vendeur, qui n'a pas la policy UPDATE sur
-- public.boutiques, peut passer par elle.
-- Idempotent : rejouable, aucune donnée perdue (historique conservé).
--
-- Journalisation : chaque réouverture est tracée dans public.journal_activite
-- (audit trail, même table que les triggers d'audit).
-- ============================================================================

create or replace function public.reouvrir_boutique(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nom text;
begin
  if public.user_role() not in ('admin', 'gerant') then
    raise exception 'Réouverture boutique réservée (admin, gérant).';
  end if;
  -- Vérifie l'état AVANT tout update : la boutique doit être fermée.
  select nom into v_nom from public.boutiques where id = p_id;
  if not found then
    raise exception 'Boutique introuvable : %', p_id;
  end if;
  if exists (select 1 from public.boutiques
              where id = p_id and actif = true) then
    raise exception 'Boutique déjà active : %', v_nom;
  end if;
  update public.boutiques
     set actif = true
   where id = p_id;
  insert into public.journal_activite (user_id, user_nom, action,
      table_nom, ligne_id, detail)
  values (auth.uid(), (select nom from public.users
                       where id = auth.uid()), 'update', 'boutiques',
      p_id::text, jsonb_build_object(
        'action_metier', 'reouverture_boutique', 'boutique_nom', v_nom));
end;
$$;

-- ============================================================================
-- VÉRIFICATION (optionnel) :
--   select id, nom, actif from public.boutiques order by nom;
--   select * from public.journal_activite
--    where detail->>'action_metier' = 'reouverture_boutique';
-- ============================================================================
