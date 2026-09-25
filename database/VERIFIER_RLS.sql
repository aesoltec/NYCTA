-- ============================================================================
-- VERIFIER_RLS.sql — Jeu de vérification post-installation (missionbis §6.4).
-- À exécuter dans Supabase → SQL Editor APRÈS APPLIQUER_TOUT.sql.
-- Chaque ligne rend PASS ou FAIL. Tout FAIL = migration manquante.
-- (Les tests par rôle connecté exigent d'exécuter les blocs 7-9 avec des
-- JWT de test ; ils sont fournis en commentaires à adapter.)
-- ============================================================================

-- ---- Bloc 1 : tables métier présentes ----
select 'T1 tables' as test,
  case when count(*) = 12 then 'PASS' else 'FAIL: ' || count(*)::text || '/12' end as resultat
from (select unnest(array[
  'company_profile','boutiques','users','user_boutiques','clients','produits',
  'transactions','partenaires','partages_mensuels','charges','budgets_mensuels',
  'fonds_roulement','documents','document_lignes','compteurs_documents','fichiers',
  'categories','fournisseurs','messages','evenements','notes','feedbacks',
  'tarifs','sauvegardes','journal_activite','achats','mouvements_stock',
  'ecritures']) as t) tables
join information_schema.tables i
  on i.table_schema = 'public' and i.table_name = tables.t;

-- ---- Bloc 2 : colonne signature_client_path ----
select 'T2 signature_client_path' as test,
  case when count(*) = 1 then 'PASS' else 'FAIL' end as resultat
from information_schema.columns
where table_schema = 'public' and table_name = 'documents'
  and column_name = 'signature_client_path';

-- ---- Bloc 3 : défauts created_by (charges, documents) ----
select 'T3 defauts created_by' as test,
  case when count(*) = 2 then 'PASS' else 'FAIL' end as resultat
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'charges' and column_name = 'created_by')
    or (table_name = 'documents' and column_name = 'created_by'))
  and column_default is not null;

-- ---- Bloc 4 : policies critiques ----
select 'T4 policies' as test,
  case when count(*) = 4 then 'PASS' else 'FAIL: ' || count(*)::text || '/4' end as resultat
from pg_policies
where schemaname = 'public' and policyname in (
  'achats demandes vendeurs', 'ecriture documents',
  'mouvements ecriture', 'ecritures insert');

-- ---- Bloc 5 : triggers critiques ----
select 'T5 triggers' as test,
  case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*)::text || '/3' end as resultat
from pg_trigger
where tgname in (
  'trg_verrou_archivage_produit', 'trg_journal_achats', 'trg_journal_ecritures');

-- ---- Bloc 6 : enum type_document complète ----
select 'T6 enum documents' as test,
  case when count(*) = 5 then 'PASS' else 'FAIL' end as resultat
from pg_enum e join pg_type t on t.oid = e.enumtypid
where t.typname = 'type_document';

-- ---- Blocs 7-9 : tests par rôle (à exécuter connectés avec un JWT
-- de test de chaque rôle ; résultats attendus en commentaire) ----
-- set local role authenticated; -- + JWT vendeur :
-- insert into public.achats (numero,boutique_id,fournisseur_nom,statut)
--   values ('TEST-001',(select id from public.boutiques limit 1),'T', 'demande');
-- -- attendu : 1 ligne (OK). Puis statut='valide' : attendu 42501.
-- update public.produits set actif = false
--   where id = (select id from public.produits limit 1);
-- -- attendu en vendeur : erreur verrouillage ; en admin : OK (rollback ensuite).
-- ============================================================================
