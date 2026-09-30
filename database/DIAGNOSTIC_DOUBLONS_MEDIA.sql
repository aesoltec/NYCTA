-- =============================================================================
-- DIAGNOSTIC DOUBLONS MEDIA — NYCTA / PME Gestion
-- -----------------------------------------------------------------------------
-- A executer dans le SQL Editor de Supabase (lecture seule : ne modifie RIEN).
-- Objectif : lister les objets du bucket `media` / `produits` et dire lesquels
-- sont reellement utilises par une table metier.
--
-- RESULTAT ATTENDU : 3 colonnes
--   utilise     = oui  -> garde (meme si le nom est « ancien »)
--   nature      = a quoi ca sert
--   nom_objet   = chemin dans le bucket
-- =============================================================================

with objets as (
  select
    bucket_id,
    name as nom_objet,
    -- Dossier de premier niveau, en SQL pur : pas de dépendance à
    -- storage.foldername (absent sur certaines instances).
    case
      when position('/' in name) > 0 then split_part(name, '/', 1)
      else ''
    end as dossier
  from storage.objects
  where bucket_id in ('media', 'produits')
    and lower(name) ~ '\.(jpg|jpeg|png)$'
),

-- Toutes les references « chemin d'objet » issues des tables metier.
refs as (
  select 'produit.image_path'::text as nature, image_path as url
  from public.produits where image_path is not null
  union all
  select 'produit.images', u
  from public.produits, lateral jsonb_array_elements_text(images) as u
  union all
  select 'tarif.images', u
  from public.tarifs, lateral jsonb_array_elements_text(images) as u
  union all
  select 'client.logo_path', logo_path
  from public.clients where logo_path is not null
  union all
  select 'company_profile.logo_path', logo_path
  from public.company_profile where logo_path is not null
  union all
  select 'company_profile.cachet_path', cachet_path
  from public.company_profile where cachet_path is not null
  union all
  select 'company_profile.signature_path', signature_path
  from public.company_profile where signature_path is not null
),

-- On ne compare que le DERNIER segment : les URLs stockees sont des
-- URLs publiques completes (.../object/public/media/produits/xxx.jpg).
ref_noms as (
  select distinct nature, split_part(url, '/', array_length(string_to_array(url,'/'),1)) as nom
  from refs
)

select
  o.bucket_id,
  o.dossier,
  o.nom_objet,
  case
    when o.bucket_id = 'media'
         and (o.dossier in ('galerie', 'produits')) then 'image metier'
    when o.bucket_id = 'produits' then 'image metier (bucket produits)'
    when o.bucket_id = 'media' then 'autre (documents, signature…)'
    else 'autre'
  end as nature,
  case
    when exists (select 1 from ref_noms r where r.nom = o.nom_objet)
      then 'OUI - NE PAS SUPPRIMER'
    else 'NON - ORPHELIN (supprimable)'
  end as utilise,
  -- Les upload « ancien format » sont nommes <millisecondes>.jpg : ils sont
  -- la trace du bug de renommage corrige en 1.13.1.
  case
    when o.nom_objet ~ '^[0-9]{10,}\.(jpg|jpeg|png)$'
      then 'ancien format (millisecondes) - a migrer'
    else 'format actuel'
  end as format_fichier
from objets o
order by utilise desc, o.bucket_id, o.nom_objet;

-- =============================================================================
-- COMPTE-RAPIDE (2e requete, facultative)
-- =============================================================================
-- select
--   bucket_id,
--   count(*) as total,
--   count(*) filter (where name ~ '^[0-9]{10,}\.(jpg|jpeg|png)$') as ancien_format
-- from storage.objects
-- where bucket_id in ('media','produits')
--   and lower(name) ~ '\.(jpg|jpeg|png)$'
-- group by bucket_id order by bucket_id;
