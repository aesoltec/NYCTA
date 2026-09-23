-- ============================================================
-- MIGRATION — Modification / suppression messagerie & feedbacks
-- À exécuter dans l'éditeur SQL Supabase.
--
-- État existant : messages = SELECT + INSERT + UPDATE (using(true)) ;
-- feedbacks = SELECT + INSERT + UPDATE admin/gérant (« traitement »).
-- Il manque les DELETE des deux tables, et l'UPDATE auteur sur feedbacks
-- (un non-admin qui corrige son propre signalement serait rejeté 42501).
--
-- RÈGLE : auteur + admin/gérant peuvent modifier et supprimer.
-- Note : « marquer comme lu » (update lu par le destinataire) continue
-- de passer par la policy « maj messages » existante (using(true)),
-- volontairement large — ne pas la resserrer.
-- ============================================================

-- ---- Messages : suppression (auteur ou admin/gérant) ----
drop policy if exists "suppression messages" on public.messages;
create policy "suppression messages" on public.messages
  for delete to authenticated
  using (expediteur_id = auth.uid()
    or public.user_role() in ('admin','gerant'));

-- ---- Feedbacks : modification par l'auteur ----
-- (l'admin/gérant garde « traitement feedbacks » pour les statuts ;
-- les policies UPDATE se combinent en OR, les deux restent valides).
drop policy if exists "maj feedbacks auteur" on public.feedbacks;
create policy "maj feedbacks auteur" on public.feedbacks
  for update to authenticated
  using (auteur_id = auth.uid())
  with check (auteur_id = auth.uid());

-- ---- Feedbacks : suppression (auteur ou admin/gérant) ----
drop policy if exists "suppression feedbacks" on public.feedbacks;
create policy "suppression feedbacks" on public.feedbacks
  for delete to authenticated
  using (auteur_id = auth.uid()
    or public.user_role() in ('admin','gerant'));
