-- ============================================================================
-- FIXES CRITIQUES (mission §2.6/2.7) — RLS + NOT NULL created_by.
-- À exécuter dans Supabase → SQL Editor. Idempotent et ré-exécutable.
-- Prérequis : schéma consolidé + migration_achats.sql déjà appliqués.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Charges & documents : `created_by NOT NULL` provoquait 23502 dès que
--    le client envoyait null (session expirée, rejeu). Valeur par défaut
--    serveur = auteur réel. Le client envoie toujours created_by aussi
--    (CloudRepository) ; le défaut ne sert que de garde-fou.
-- ---------------------------------------------------------------------------
alter table public.charges
  alter column created_by set default auth.uid();
alter table public.documents
  alter column created_by set default auth.uid();

-- ---------------------------------------------------------------------------
-- 2. Achats : les vendeurs/caissiers (sans Permission.gererAchats) doivent
--    pouvoir créer des DEMANDES (statut='demande'), pas des achats directs.
--    Sans cette policy : 42501 RLS sur toute demande vendeur.
--    Garde-fous : statut imposé 'demande', boutique accessible, insert seul
--    (aucune modification/suppression — validation réservée admin/gérant/
--    comptable via "achats ecriture").
-- ---------------------------------------------------------------------------
drop policy if exists "achats demandes vendeurs" on public.achats;
create policy "achats demandes vendeurs" on public.achats
  for insert to authenticated
  with check (
    public.user_role() in ('vendeur','caissier')
    and statut = 'demande'
    and public.accede_boutique(boutique_id)
  );

-- ---------------------------------------------------------------------------
-- 3. Stock : un vendeur peut créer/modifier/vendre (matrice app) mais ne
--    doit JAMAIS retirer un article (actif=false). La policy "maj produits"
--    ne distingue pas les colonnes : ce trigger verrouille l'archivage
--    côté serveur aux seuls admin/gérant. Le client masque déjà le bouton
--    (StockScreen) et Store.supprimerProduit refuse ces rôles.
-- ---------------------------------------------------------------------------
create or replace function public.verrouiller_archivage_produit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.actif = true and new.actif = false
     and public.user_role() not in ('admin','gerant') then
    raise exception 'Archivage produit réservé (admin, gérant).';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_verrou_archivage_produit on public.produits;
create trigger trg_verrou_archivage_produit
  before update on public.produits
  for each row execute function public.verrouiller_archivage_produit();

-- ---------------------------------------------------------------------------
-- 4. Documents : les vendeurs émettent ticket/BL/facture/devis (mission
--    §2.9) mais JAMAIS de bon de commande (filtré côté app). Ajout du rôle
--    à la policy d'écriture (boutique accessible requise, inchangée).
-- ---------------------------------------------------------------------------
drop policy if exists "ecriture documents" on public.documents;
create policy "ecriture documents" on public.documents
  for insert to authenticated
  with check (
    public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
    and public.accede_boutique(boutique_id)
  );
-- ============================================================================
