-- ============================================================================
-- PME Gestion — RPC RÉOUVERTURE BOUTIQUE (point 22bis) — 2026-09-26
-- ============================================================================
-- Réactive une boutique fermée (soft delete). Réservée admin/gérant,
-- côté serveur (miroir de la policy "boutiques update").
-- La fonction est SECURITY DEFINER : le rôle vendeur, qui n'a pas la
-- policy UPDATE sur public.boutiques, peut passer par elle.
-- Idempotent : rejouable, aucune donnée perdue (l'historique reste rattaché).
-- ============================================================================

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

-- Droits : aucun rôle n'a EXECUTE par défaut sur les fonctions
-- (GRANT EXECUTE revoked) ; la policy de lecture des boutiques couvre
-- tous les utilisateurs authentifiés, donc aucune modification RLS
-- n'est nécessaire pour ce point.

-- ============================================================================
-- VÉRIFICATION (optionnel) :
--   select id, nom, actif from public.boutiques order by nom;
-- ============================================================================
