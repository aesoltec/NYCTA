-- =====================================================================
--  VERIFICATION MIGRATION  --  lecture seule
--  A coller dans Supabase Dashboard -> SQL Editor -> Run.
--  Attendu : 9 lignes, colonne `ok` = true partout.
--  Ne modifie rien.
-- =====================================================================

select '1. produits.date_ajout (badge Nouveau)' as controle,
       (select count(*) = 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'produits'
           and column_name = 'date_ajout') as ok
union all
select '2. tarifs.date_ajout (badge Nouveau)',
       (select count(*) = 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'tarifs'
           and column_name = 'date_ajout')
union all
select '3. tarifs.images (galerie articles)',
       (select count(*) = 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'tarifs'
           and column_name = 'images')
union all
select '4. clients.email/rccm/rib/logo_path',
       (select count(*) = 4 from information_schema.columns
         where table_schema = 'public' and table_name = 'clients'
           and column_name in ('email', 'rccm', 'rib', 'logo_path'))
union all
select '5. RPC reouvrir_boutique (22bis)',
       (select count(*) = 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'reouvrir_boutique')
union all
select '6. RLS active sur produits',
       (select relrowsecurity from pg_class c
         join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'produits')
union all
select '7. 3 policies produits (select/insert/update)',
       (select count(*) = 3 from pg_policies
         where schemaname = 'public' and tablename = 'produits'
           and policyname in ('produits select', 'ecriture produits',
                              'maj produits'))
union all
select '8. fonction publique.user_role()',
       (select count(*) = 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'user_role')
union all
select '9. fonction publique.accede_boutique()',
       (select count(*) = 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'accede_boutique');

-- =====================================================================
--  SUIVI : combien de produits ont deja une date ? (badge « Nouveau »)
--  Si 0, la colonne est vide : c'est normal pour une migration appliquee
--  a une base deja remplit ; le badge apparaitra sur les NOUVEAUX produits.
-- =====================================================================
select count(*) as produits_total,
       count(date_ajout) as produits_avec_date
from public.produits;
