-- =====================================================================
--  DROITS PRODUITS — OPTION A
--  À exécuter dans Supabase Dashboard → SQL Editor.
--
--  Le VENDEUR ne doit plus pouvoir CRÉER de fiche produit.
--  Il conserve la lecture du stock et la modification de ses fiches.
--
--  POURQUOI CE FICHIER EST INDISPENSABLE
--  ------------------------------------
--  La matrice des permissions est verifiee cote APP, mais c'est la
--  policy RLS qui fait foi : sans ce script, un vendeur peut continuer
--  d'insérer un produit en contournant l'app (appel direct a l'API
--  PostgREST avec la cle anon). L'app et le serveur divergeraient, ce que
--  MATRICE_PERMISSIONS.md qualifie explicitement de bug.
--
--  AVANT (database/supabase_fonctions_rls.sql, ligne 117-119) :
--    with check (public.user_role() in ('admin','gerant','vendeur'))
--
--  APRES :
--    with check (public.user_role() in ('admin','gerant'))
--
--  IDEMPOTENT : rejouable sans risque sur base existante.
-- =====================================================================

-- ---- 1. INSERT : plus de vendeur -------------------------------
drop policy if exists "ecriture produits" on public.produits;
create policy "ecriture produits" on public.produits
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant'));

-- ---- 2. UPDATE : le vendeur garde son autonomie terrain --------
--    (prix de vente, photo, seuil, quantite constatee)
drop policy if exists "maj produits" on public.produits;
create policy "maj produits" on public.produits
  for update to authenticated
  using (public.user_role() in ('admin','gerant','vendeur'));

-- =====================================================================
--  VÉRIFICATION (facultatif) — attendu : 2 lignes
-- =====================================================================
-- select policyname, cmd, qual, with_check from pg_policies
--  where schemaname = 'public' and tablename = 'produits'
--  order by policyname;
--
--  Attendu :
--   ecriture produits | INSERT | null                    | (user_role() = ANY (ARRAY[...admin, gerant]))
--   maj produits      | UPDATE | (user_role() = ANY (...admin, gerant, vendeur)) | null