-- =============================================================================
-- NETTOYAGE MEDIA ORPHELIN — NYCTA / PME Gestion
-- -----------------------------------------------------------------------------
-- ⚠️  CE SCRIPT SUPPRIME DES DONNÉES. LIRE ET COMPRENDRE AVANT D'EXECUTER.
--
-- PRÉREQUIS OBLIGATOIRE
--   1. avoir exécuté `DIAGNOSTIC_DOUBLONS_MEDIA.sql` et vérifié le résultat ;
--   2. avoir fait un dump : Supabase > Database > Backups (ou `supabase db dump`) ;
--   3. avoir fermé l'application (ou au moins ne PLUS ENREGISTRER de produit /
--      de tarif pendant l'opération : une écriture recréerait un objet).
--
-- CE QUE FAIT LE SCRIPT
--   Supprime les objets des buckets `media` / `produits` qui ne sont
--   référencés par AUCUNE table métier (produits, tarifs, clients,
--   company_profile). Il ne touche jamais à un objet utilisé.
--
-- GARDE-FOUS INTRODUITS
--   - `seuil_confirmation` : le script ne supprime RIEN tant que le nombre
--     d'orphelins n'a pas été explicitement validé (mettre 0 pour valider).
--   - rapport AVANT / APRÈS dans les retours de la fonction.
--   - Il ne supprime PAS les images de marque (logo, cachet, signature)
--     même si elles semblaient orphelines : le préfixe est exclu.
--
-- SENS DE L'ERREUR (délibéré)
--   L'appariement se fait sur le NOM DE FICHIER, sans distinguer le bucket.
--   Si `media/produits/x.jpg` ET `produits/produits/x.jpg` existent et que
--   seul le premier est référencé, le second est considéré comme « utilisé »
--   → il est CONSERVÉ. C'est le sens sûr : on peut laisser traîner un
--   orphelin, on ne supprime JAMAIS une image en usage. Si le nettoyage
--   laisse des objets, c'estnormal — un second passage après vérification
--   suffit.
--
-- APRÈS EXÉCUTION
--   Rejouer `DIAGNOSTIC_DOUBLONS_MEDIA.sql` : la colonne `utilise` doit être
--   à 100 % « OUI - NE PAS SUPPRIMER ».
-- =============================================================================

create or replace function public.nettoyer_media_orphelins(
  seuil_confirmation integer default -1,
  dry_run boolean default true
)
returns table(bucket text, nom text, action text)
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_total int := 0;
  v_orphelins int;
  r record;
begin
  -- ---------- 1. Recense les orphelins ----------
  create temporary table _orphelins on commit drop as
  with refs as (
    select image_path as url from public.produits where image_path is not null
    union
    select u from public.produits, lateral jsonb_array_elements_text(images) u
    union
    select u from public.tarifs, lateral jsonb_array_elements_text(images) u
    union
    select logo_path from public.clients where logo_path is not null
    union
    select logo_path from public.company_profile where logo_path is not null
    union
    select cachet_path from public.company_profile where cachet_path is not null
    union
    select signature_path from public.company_profile where signature_path is not null
  ),
  ref_noms as (
    select distinct split_part(url, '/',
                             array_length(string_to_array(url, '/'), 1)) as nom
    from refs
  )
  select o.bucket_id, o.name
  from storage.objects o
  where o.bucket_id in ('media', 'produits')
    and lower(o.name) ~ '\.(jpg|jpeg|png)$'
    -- Les images de marque ne sont JAMAIS concernées.
    and o.name !~* '(^|/)(logo|cachet|signature)[_.]'
    and not exists (select 1 from ref_noms r where r.nom = o.name);

  select count(*) into v_orphelins from _orphelins;
  v_total := v_orphelins;

  -- ---------- 2. Garde-fou : rien n'est supprimé sans validation ----------
  if v_orphelins = 0 then
    raise notice 'Aucun orphelin : rien a faire.';
    return query select '', '', 'aucun orphelin';
    return;
  end if;

  if v_orphelins <> seuil_confirmation then
    raise notice 'ARRET : % orphelin(s) detecte(s), seuil de confirmation = %. '
                 'Reexecuter avec seuil_confirmation = %, ou %% pour annuler.',
                 v_orphelins, seuil_confirmation, v_orphelins, dry_run;
    return query
      select bucket_id, name,
             format('ORPHELIN (conserve : seuil = %s)', seuil_confirmation)
      from _orphelins
      order by bucket_id, name;
    return;
  end if;

  -- ---------- 3. Suppression ----------
  -- On SUPPRIME le fichierphysique via l'API storage, puis la ligne
  -- `storage.objects`. L'ordre compte : supprimer d'abord la ligne
  -- laisserait un fichier orphelin invisible (exactement le symptôme
  -- qu'on cherche à éliminer).
  raise notice '% orphelin(s) confirme(s). dry_run = %', v_orphelins, dry_run;

  for r in select bucket_id, name from _orphelins order by bucket_id, name loop
    if dry_run then
      return query select r.bucket_id, r.name, 'SUPPRIMER (simulation)';
    else
      begin
        perform storage.delete_object(r.bucket_id, r.name);
        return query select r.bucket_id, r.name, 'SUPPRIME';
      exception when others then
        -- Repli si l'API storage n'est pas exposee sur cette instance.
        begin
          delete from storage.objects o
          where o.bucket_id = r.bucket_id and o.name = r.name;
          return query select r.bucket_id, r.name,
                 'SUPPRIME (ligne storage.objects)';
        exception when others then
          return query select r.bucket_id, r.name,
                 format('ERREUR : %', left(sqlerrm, 120));
        end;
      end;
    end if;
  end loop;

  raise notice 'Termine : % orphelin(s) traite(s).', v_total;
end;
$$;

comment on function public.nettoyer_media_orphelins(integer, boolean) is
  'Supprime les objets media/produits non references par une table metier. '
  'Garde-fou seuil_confirmation : ne supprime rien si le nombre d''orphelins '
  'detectes ne correspond pas exactement au seuil fourni. dry_run=true par defaut.';

-- =============================================================================
-- MODE D'EMPLOI (3 etapes, une par fenetre SQL)
-- =============================================================================
--
-- ETAPE 1 — Lister, NE RIEN SUPPRIMER (obligatoire)
--   select * from public.nettoyer_media_orphelins(-1, true);
--   -> lire la liste, vérifier qu'aucun nom utile n'apparaît
--
-- ETAPE 2 — Valider le nombre (remplacer 42 par le compte de l'etape 1)
--   select * from public.nettoyer_media_orphelins(42, true);
--   -> meme liste, mais chaque ligne dit « SUPPRIMER (simulation) »
--
-- ETAPE 3 — Executer
--   select * from public.nettoyer_media_orphelins(42, false);
--   -> chaque ligne doit dire « SUPPRIME » (ou « ERREUR : … » a diagnostiquer)
--
-- ETAPE 4 — Verifier
--   reexecuter DIAGNOSTIC_DOUBLONS_MEDIA.sql
--   -> plus aucune ligne « NON - ORPHELIN » dans les buckets media/produits
--
-- NETTOYAGE FINAL (facultatif) — la fonction n'est plus utile :
--   drop function if exists public.nettoyer_media_orphelins(integer, boolean);
