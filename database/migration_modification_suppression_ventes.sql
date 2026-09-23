-- ============================================================
-- MIGRATION — Modification / suppression des ventes et charges
-- À exécuter dans l'éditeur SQL Supabase AVANT de déployer l'app
-- contenant le Journal modifiable (majTransaction /
-- supprimerTransaction / supprimerCharge).
--
-- Contexte : les policies existantes n'autorisaient que l'INSERT sur
-- public.transactions (« ecriture transactions ») et INSERT (+ UPDATE
-- pour le rejeu offline) sur public.charges. Sans les policies
-- ci-dessous, toute modification ou suppression depuis l'app est
-- REJETÉE par RLS — et l'app l'avale en silence (_silencieux) :
-- l'utilisateur verrait « ✅ Vente modifiée » puis retrouverait
-- l'ancienne valeur au rechargement.
--
-- RÈGLE ADOPTÉE (option A) : la suppression est réservée à
-- admin + gérant, la modification à admin + gérant + comptable.
-- Vendeur/caissier = création seule (anti-fraude : encaisser puis
-- supprimer la vente). L'UI masque les boutons selon le même découpage.
-- ============================================================

-- ---- Transactions : modification (upsert sur l'id) ----
drop policy if exists "maj transactions" on public.transactions;
create policy "maj transactions" on public.transactions
  for update to authenticated
  using (
    public.user_role() in ('admin','gerant','comptable')
    and public.accede_boutique(boutique_id)
  )
  with check (
    public.user_role() in ('admin','gerant','comptable')
    and public.accede_boutique(boutique_id)
  );

-- ---- Transactions : suppression définitive (journal → Supprimer) ----
-- Admin + gérant UNIQUEMENT. Le partenaire ne peut NI modifier NI
-- supprimer (ses ventes passent par la clôture mensuelle).
drop policy if exists "suppression transactions" on public.transactions;
create policy "suppression transactions" on public.transactions
  for delete to authenticated
  using (
    public.user_role() in ('admin','gerant')
    and public.accede_boutique(boutique_id)
  );

-- ---- Charges : suppression définitive (écran Charges → Supprimer) ----
-- Admin + gérant uniquement (la maj reste admin/gérant/comptable,
-- voir policy « maj charges » existante).
drop policy if exists "suppression charges" on public.charges;
create policy "suppression charges" on public.charges
  for delete to authenticated
  using (public.user_role() in ('admin','gerant'));
