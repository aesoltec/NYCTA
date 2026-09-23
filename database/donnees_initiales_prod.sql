-- ============================================================================
-- PME Gestion — DÉMARRAGE PRODUCTION (AESOLTEC AFRIQUE)
-- À exécuter UNE FOIS dans Supabase → SQL Editor, APRÈS avoir nettoyé les
-- données de test (voir database/nettoyer_donnees_test.sql).
--
-- Contenu volontairement minimal et modifiable : profil entreprise + une
-- boutique + un petit catalogue de départ. Aucune transaction, client ou
-- partenaire fictif n'est inséré — ces données naissent de l'activité réelle,
-- pas d'un script.
--
-- 🔴 Champs marqués ainsi = valeurs à vérifier/corriger (tu as dit vouloir
-- les modifier très prochainement — remplace-les via Configuration dans
-- l'app quand tu auras les infos exactes, pas besoin de rejouer ce fichier).
--
-- Volontairement laissés VIDES (jamais inventés) : RCCM et IFU — ce sont des
-- numéros d'identification officiels ; une valeur fictive qui resterait par
-- erreur sur une vraie facture pourrait poser un problème légal/fiscal.
-- Remplis-les toi-même dans Configuration dès que tu les as sous la main.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Profil entreprise (met à jour la ligne unique existante, id = 1)
-- ---------------------------------------------------------------------------
update public.company_profile set
  nom_entreprise = 'AESOLTEC AFRIQUE',
  devise         = 'FCFA',
  email          = 'aestechno.info@gmail.com',
  telephone      = '',              -- 🔴 ton numéro principal
  telephone2     = '',              -- 🔴 numéro secondaire (optionnel)
  adresse        = '',              -- 🔴 adresse du siège
  rccm           = '',              -- laissé vide volontairement (voir note ci-dessus)
  ifu            = '',              -- laissé vide volontairement (voir note ci-dessus)
  banque         = '',              -- 🔴 nom de la banque (optionnel)
  coordonnees_bancaires = '',       -- 🔴 RIB/IBAN (optionnel)
  message_pied   = 'Merci de votre confiance.',
  tva            = 0                -- 🔴 taux de TVA si applicable (0 = non assujetti)
where id = 1;

-- ---------------------------------------------------------------------------
-- 2. Boutique de départ (siège) — id fixe pour pouvoir la retrouver/l'éditer
-- ---------------------------------------------------------------------------
-- Si la boutique de démo "Siège — Hotspot & Services" existe encore (tu n'as
-- pas encore lancé nettoyer_donnees_test.sql ou tu l'as gardée), on lui
-- retire le flag siège pour n'en avoir qu'un seul actif à la fois.
update public.boutiques set siege = false
where id = '11111111-1111-4111-8111-111111111111' and siege = true;

insert into public.boutiques (id, nom, adresse, telephone, siege, actif)
values (
  '99999999-9999-4999-8999-999999999999',
  'Siège AESOLTEC AFRIQUE',   -- 🔴 nom réel si différent
  '',                          -- 🔴 adresse
  '',                          -- 🔴 téléphone de cette boutique
  true, true
)
on conflict (id) do update set
  nom = excluded.nom, adresse = excluded.adresse, telephone = excluded.telephone;

-- Rattache l'admin déjà créé à cette boutique (sinon il ne la verra pas).
insert into public.user_boutiques (user_id, boutique_id)
select u.id, '99999999-9999-4999-8999-999999999999'
from public.users u
where u.role = 'admin'
on conflict do nothing;

-- Fonds de roulement de départ — 🔴 à corriger avec le montant réel en caisse.
insert into public.fonds_roulement (boutique_id, montant)
values ('99999999-9999-4999-8999-999999999999', 0)
on conflict (boutique_id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Catalogue de départ — prestations courantes du secteur (informatique,
-- électricité, vidéosurveillance, réseaux). 🔴 Prix à ajuster à tes tarifs
-- réels ; supprime les lignes qui ne correspondent pas à ton activité via
-- Plus → Tarifs & catalogue dans l'app.
-- ---------------------------------------------------------------------------
-- `tarifs` n'a pas de colonne unique sur libelle : un ON CONFLICT DO NOTHING
-- nu ne viserait aucune contrainte réelle et dupliquerait le catalogue à
-- chaque ré-exécution. On filtre donc explicitement par libelle déjà présent.
insert into public.tarifs (libelle, categorie, prix, description)
select v.libelle, v.categorie, v.prix, v.description
from (values
  ('Installation caméra de vidéosurveillance (unité)', 'Vidéosurveillance', 5000::numeric, 'Pose et configuration par caméra'),
  ('Dépannage informatique', 'Informatique', 10000::numeric, 'Diagnostic et réparation sur site ou atelier'),
  ('Configuration routeur / réseau', 'Réseaux & Télécom', 7500::numeric, 'Paramétrage et mise en service'),
  ('Forfait maintenance mensuel', 'Contrat', 25000::numeric, 'Astreinte et maintenance préventive'),
  ('Installation tableau électrique', 'Électricité', 15000::numeric, 'Pose et mise aux normes')
) as v(libelle, categorie, prix, description)
where not exists (
  select 1 from public.tarifs t where t.libelle = v.libelle
);

-- ============================================================================
-- Rappel : les catégories de produits/charges (Stock, Dépenses) et le taux
-- de partage des partenaires hotspot restent éditables librement dans l'app
-- — aucun besoin de SQL pour ça.
-- ============================================================================
