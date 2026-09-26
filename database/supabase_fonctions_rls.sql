-- ============================================================================
-- PME Gestion — Fonctions RPC + RLS SUPABASE (PostgreSQL 15) — v3.0
-- ============================================================================
-- 2e script (APRÈS supabase_schema.sql ; ou après supabase_migration.sql
-- pour une base existante). Tout est idempotent et ré-exécutable.
-- Contenu : politiques RLS finales + triggers + fonctions RPC + buckets.
-- ============================================================================

-- RLS — SÉCURITÉ FINALE (v1.0 + v1.1 + v1.6 + v1.8 fusionnées)
-- Règle de lecture : seules les politiques FINALES figurent ci-dessous —
-- chaque CREATE POLICY est précédé de DROP POLICY IF EXISTS couvrant AUSSI
-- les noms historiques (v1.0), pour réaligner une base existante.
-- CREATE POLICY n'a pas de variante "OR REPLACE".
-- ---------------------------------------------------------------------------
alter table public.company_profile   enable row level security;
alter table public.boutiques         enable row level security;
alter table public.users             enable row level security;
alter table public.user_boutiques    enable row level security;
alter table public.clients           enable row level security;
alter table public.produits          enable row level security;
alter table public.transactions      enable row level security;
alter table public.partenaires       enable row level security;
alter table public.partages_mensuels enable row level security;
alter table public.charges           enable row level security;
alter table public.budgets_mensuels  enable row level security;
alter table public.fonds_roulement   enable row level security;
alter table public.documents         enable row level security;
alter table public.document_lignes   enable row level security;
alter table public.compteurs_documents enable row level security;
alter table public.fichiers          enable row level security;
alter table public.categories        enable row level security;
alter table public.fournisseurs      enable row level security;
alter table public.messages          enable row level security;
alter table public.evenements        enable row level security;
alter table public.notes             enable row level security;
alter table public.feedbacks         enable row level security;
alter table public.tarifs            enable row level security;
alter table public.sauvegardes       enable row level security;
alter table public.journal_activite  enable row level security;

-- ---- Profil ----
drop policy if exists "lecture profile" on public.company_profile;
create policy "lecture profile"  on public.company_profile
  for select to authenticated using (true);
drop policy if exists "config profile" on public.company_profile;
create policy "config profile" on public.company_profile
  for update to authenticated
  using (public.user_role() in ('admin','gerant'));

-- ---- Boutiques ----
drop policy if exists "lecture boutiques" on public.boutiques;
create policy "lecture boutiques" on public.boutiques
  for select to authenticated using (true);
drop policy if exists "boutiques insert" on public.boutiques;
create policy "boutiques insert" on public.boutiques
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant'));
drop policy if exists "boutiques update" on public.boutiques;
create policy "boutiques update" on public.boutiques
  for update to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Users ----
drop policy if exists "lecture users" on public.users;
create policy "lecture users" on public.users
  for select to authenticated using (true);
drop policy if exists "users insert" on public.users;
create policy "users insert" on public.users
  for insert to authenticated
  with check (public.user_role() = 'admin' or id = auth.uid());
drop policy if exists "users update" on public.users;
create policy "users update" on public.users
  for update to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- User_boutiques ----
drop policy if exists "user_boutiques select" on public.user_boutiques;
create policy "user_boutiques select" on public.user_boutiques
  for select to authenticated
  using (user_id = auth.uid() or public.user_role() in ('admin','gerant'));
drop policy if exists "user_boutiques write" on public.user_boutiques;
create policy "user_boutiques write" on public.user_boutiques
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant'));
drop policy if exists "user_boutiques delete" on public.user_boutiques;
create policy "user_boutiques delete" on public.user_boutiques
  for delete to authenticated
  using (public.user_role() in ('admin','gerant'));

-- ---- Clients (lecture/insert boutique, update admin-gérant) ----
drop policy if exists "lecture clients" on public.clients;
drop policy if exists "clients select" on public.clients;
create policy "clients select" on public.clients
  for select to authenticated using (
    public.accede_boutique(boutique_id)
  );
drop policy if exists "clients insert" on public.clients;
create policy "clients insert" on public.clients
  for insert to authenticated
  with check (
    public.accede_boutique(boutique_id)
  );
drop policy if exists "clients update" on public.clients;
create policy "clients update" on public.clients
  for update to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Produits (lecture isolée boutique ; écriture vendeurs+) ----
drop policy if exists "lecture produits" on public.produits;
drop policy if exists "produits select" on public.produits;
create policy "produits select" on public.produits
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "ecriture produits" on public.produits;
create policy "ecriture produits" on public.produits
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','vendeur'));
drop policy if exists "maj produits" on public.produits;
create policy "maj produits" on public.produits
  for update to authenticated
  using (public.user_role() in ('admin','gerant','vendeur'));

-- ---- Transactions (lecture isolée boutique + espace partenaire P8 ;
--      écriture par rôle + boutique, sauf partenaire : forfaits à son nom) ----
drop policy if exists "lecture transactions" on public.transactions;
drop policy if exists "transactions select" on public.transactions;
create policy "transactions select" on public.transactions
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "partenaire lit ses ventes" on public.transactions;
create policy "partenaire lit ses ventes" on public.transactions
  for select to authenticated
  using (
    public.user_role() <> 'partenaire'
    or partenaire_id = public.mon_partenaire_id()
  );
drop policy if exists "ecriture transactions" on public.transactions;
create policy "ecriture transactions" on public.transactions
  for insert to authenticated
  with check (
    public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
    and public.accede_boutique(boutique_id)
  );
drop policy if exists "partenaire vend ses forfaits" on public.transactions;
create policy "partenaire vend ses forfaits" on public.transactions
  for insert to authenticated
  with check (
    public.user_role() = 'partenaire'
    and type = 'forfait_hotspot'
    and partenaire_id = public.mon_partenaire_id()
  );

-- ---- Partenaires (lecture restreinte P8 ; écriture admin-gérant) ----
-- La policy globale "lecture partenaires" (using(true), v1.0) est
-- volontairement ABSENTE : sous RLS les policies permissives se combinent
-- en OR — la garder annulerait la restriction partenaire ci-dessous.
drop policy if exists "lecture partenaires" on public.partenaires;
drop policy if exists "partenaire lit son profil" on public.partenaires;
create policy "partenaire lit son profil" on public.partenaires
  for select to authenticated
  using (
    public.user_role() <> 'partenaire'
    or id = public.mon_partenaire_id()
  );
drop policy if exists "ecriture partenaires" on public.partenaires;
create policy "ecriture partenaires" on public.partenaires
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Partages ----
drop policy if exists "lecture partages" on public.partages_mensuels;
create policy "lecture partages" on public.partages_mensuels
  for select to authenticated using (true);
drop policy if exists "ecriture partages" on public.partages_mensuels;
create policy "ecriture partages" on public.partages_mensuels
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant'));

-- ---- Charges ----
drop policy if exists "lecture charges" on public.charges;
drop policy if exists "charges select" on public.charges;
create policy "charges select" on public.charges
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "ecriture charges" on public.charges;
create policy "ecriture charges" on public.charges
  for insert to authenticated
  with check (public.user_role() in ('admin','gerant','comptable'));
-- Rejeu offline d'une charge existante (upsert) : sans policy UPDATE, la
-- file de synchronisation restait bloquée après 8 essais sur une charge
-- déjà insérée. Mêmes rôles que l'insertion (matrice app).
drop policy if exists "maj charges" on public.charges;
create policy "maj charges" on public.charges
  for update to authenticated
  using (public.user_role() in ('admin','gerant','comptable'))
  with check (public.user_role() in ('admin','gerant','comptable'));

-- ---- Budgets / fonds ----
drop policy if exists "maj budgets" on public.budgets_mensuels;
create policy "maj budgets" on public.budgets_mensuels
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));
drop policy if exists "maj fonds" on public.fonds_roulement;
create policy "maj fonds" on public.fonds_roulement
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Documents ----
-- ⚠️ CORRECTIF vs historique : aucune migration ne créait de policy
-- d'INSERT sur public.documents — tout en-tête de document émis était
-- REJETÉ par RLS (échec silencieux côté app, historique cloud vide après
-- rechargement). Rôles = matrice app (admin/gérant/comptable/caissier).
drop policy if exists "lecture documents" on public.documents;
drop policy if exists "documents select" on public.documents;
create policy "documents select" on public.documents
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "ecriture documents" on public.documents;
create policy "ecriture documents" on public.documents
  for insert to authenticated
  with check (
    public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
    and public.accede_boutique(boutique_id)
  );
drop policy if exists "lecture lignes" on public.document_lignes;
create policy "lecture lignes" on public.document_lignes
  for select to authenticated using (true);
drop policy if exists "ecriture lignes" on public.document_lignes;
create policy "ecriture lignes" on public.document_lignes
  for insert to authenticated
  with check (
    exists (
      select 1 from public.documents d
      where d.id = document_id and public.accede_boutique(d.boutique_id)
    )
  );

-- ---- Compteurs / fichiers (deny by default ; RPC security definer) ----
drop policy if exists "compteurs select" on public.compteurs_documents;
create policy "compteurs select" on public.compteurs_documents
  for select to authenticated using (true);
drop policy if exists "fichiers select" on public.fichiers;
create policy "fichiers select" on public.fichiers
  for select to authenticated using (true);
drop policy if exists "fichiers insert" on public.fichiers;
create policy "fichiers insert" on public.fichiers
  for insert to authenticated with check (true);
drop policy if exists "fichiers delete" on public.fichiers;
create policy "fichiers delete" on public.fichiers
  for delete to authenticated
  using (public.user_role() in ('admin','gerant'));

-- ---- Catégories & listes ----
drop policy if exists "lecture categories" on public.categories;
create policy "lecture categories" on public.categories
  for select to authenticated using (true);
drop policy if exists "ecriture categories" on public.categories;
create policy "ecriture categories" on public.categories
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Collaboration ----
drop policy if exists "lecture fournisseurs" on public.fournisseurs;
create policy "lecture fournisseurs" on public.fournisseurs
  for select to authenticated using (true);
drop policy if exists "ecriture fournisseurs" on public.fournisseurs;
create policy "ecriture fournisseurs" on public.fournisseurs
  for all to authenticated
  using (public.user_role() in ('admin','gerant','comptable'))
  with check (public.user_role() in ('admin','gerant','comptable'));

drop policy if exists "lecture messages" on public.messages;
create policy "lecture messages" on public.messages
  for select to authenticated using (true);
drop policy if exists "envoi messages" on public.messages;
create policy "envoi messages" on public.messages
  for insert to authenticated
  with check (expediteur_id = auth.uid());
drop policy if exists "maj messages" on public.messages;
create policy "maj messages" on public.messages
  for update to authenticated
  using (true) with check (true);

drop policy if exists "lecture evenements" on public.evenements;
create policy "lecture evenements" on public.evenements
  for select to authenticated using (true);
drop policy if exists "ecriture evenements" on public.evenements;
create policy "ecriture evenements" on public.evenements
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

drop policy if exists "lecture notes" on public.notes;
create policy "lecture notes" on public.notes
  for select to authenticated using (true);
drop policy if exists "ecriture notes" on public.notes;
create policy "ecriture notes" on public.notes
  for all to authenticated
  using (createur_id = auth.uid() or public.user_role() in ('admin','gerant'))
  with check (createur_id = auth.uid() or public.user_role() in ('admin','gerant'));

-- ---- Feedbacks ----
drop policy if exists "lecture feedbacks" on public.feedbacks;
create policy "lecture feedbacks" on public.feedbacks
  for select to authenticated using (true);
drop policy if exists "envoi feedbacks" on public.feedbacks;
create policy "envoi feedbacks" on public.feedbacks
  for insert to authenticated
  with check (auteur_id = auth.uid());
drop policy if exists "traitement feedbacks" on public.feedbacks;
create policy "traitement feedbacks" on public.feedbacks
  for update to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Tarifs ----
drop policy if exists "lecture tarifs" on public.tarifs;
create policy "lecture tarifs" on public.tarifs
  for select to authenticated using (true);
drop policy if exists "ecriture tarifs" on public.tarifs;
create policy "ecriture tarifs" on public.tarifs
  for all to authenticated
  using (public.user_role() in ('admin','gerant'))
  with check (public.user_role() in ('admin','gerant'));

-- ---- Sauvegardes (écriture via RPC security definer uniquement) ----
drop policy if exists "sauvegardes select" on public.sauvegardes;
create policy "sauvegardes select" on public.sauvegardes
  for select to authenticated
  using (public.user_role() in ('admin','gerant'));
drop policy if exists "sauvegardes delete" on public.sauvegardes;
create policy "sauvegardes delete" on public.sauvegardes
  for delete to authenticated
  using (public.user_role() = 'admin');

-- ---- Journal (lecture admin-gérant ; écriture par triggers uniquement) ----
drop policy if exists "lecture journal" on public.journal_activite;
create policy "lecture journal" on public.journal_activite
  for select to authenticated
  using (public.user_role() in ('admin','gerant'));

-- ============================================================================
-- FIN DU SCHÉMA (tables) — suite : supabase_fonctions_rls.sql
-- (fonctions RPC, triggers d'audit, buckets Storage + leurs politiques)
-- ============================================================================


-- ============================================================================
-- RLS — NOUVELLES TABLES & CORRECTIFS (ex-migrations individuelles)
-- Règle : chaque CREATE POLICY est précédé de DROP POLICY IF EXISTS.
-- ============================================================================
alter table public.achats enable row level security;
alter table public.mouvements_stock enable row level security;
alter table public.ecritures enable row level security;

-- ---- Ventes & charges : modification / suppression ----
-- Règle : suppression réservée admin+gérant, modification admin+gérant+
-- comptable. Vendeur/caissier = création seule (anti-fraude).
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
drop policy if exists "suppression transactions" on public.transactions;
create policy "suppression transactions" on public.transactions
  for delete to authenticated
  using (
    public.user_role() in ('admin','gerant')
    and public.accede_boutique(boutique_id)
  );
drop policy if exists "suppression charges" on public.charges;
create policy "suppression charges" on public.charges
  for delete to authenticated
  using (public.user_role() in ('admin','gerant'));

-- ---- Messagerie & feedbacks : modification / suppression ----
-- Règle : auteur + admin/gérant. « Marquer comme lu » reste couvert par
-- la policy large « maj messages » (volontaire — ne pas resserrer).
drop policy if exists "suppression messages" on public.messages;
create policy "suppression messages" on public.messages
  for delete to authenticated
  using (expediteur_id = auth.uid()
    or public.user_role() in ('admin','gerant'));
drop policy if exists "maj feedbacks auteur" on public.feedbacks;
create policy "maj feedbacks auteur" on public.feedbacks
  for update to authenticated
  using (auteur_id = auth.uid())
  with check (auteur_id = auth.uid());
drop policy if exists "suppression feedbacks" on public.feedbacks;
create policy "suppression feedbacks" on public.feedbacks
  for delete to authenticated
  using (auteur_id = auth.uid()
    or public.user_role() in ('admin','gerant'));

-- ---- Achats : lecture boutique, écriture rôles achats, demandes vendeurs ----
drop policy if exists "achats select" on public.achats;
create policy "achats select" on public.achats
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "achats ecriture" on public.achats;
create policy "achats ecriture" on public.achats
  for all to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));
drop policy if exists "achats demandes vendeurs" on public.achats;
create policy "achats demandes vendeurs" on public.achats
  for insert to authenticated
  with check (
    public.user_role() in ('vendeur','caissier')
    and statut = 'demande'
    and public.accede_boutique(boutique_id)
  );

-- ---- Mouvements de stock : lecture boutique, écriture opérationnels ----
drop policy if exists "mouvements select" on public.mouvements_stock;
create policy "mouvements select" on public.mouvements_stock
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "mouvements ecriture" on public.mouvements_stock;
create policy "mouvements ecriture" on public.mouvements_stock
  for all to authenticated
  using (public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
              and public.accede_boutique(boutique_id));

-- ---- Écritures comptables : lecture boutique, insert financier, pointage ----
-- Immuabilité : aucun update/delete large — corrections par contre-écritures
-- en insert ; seule mise à jour autorisée : le flag `pointee`.
drop policy if exists "ecriture select" on public.ecritures;
drop policy if exists "ecritures select" on public.ecritures;
create policy "ecritures select" on public.ecritures
  for select to authenticated using (public.accede_boutique(boutique_id));
drop policy if exists "ecritures insert" on public.ecritures;
create policy "ecritures insert" on public.ecritures
  for insert to authenticated
  with check (
    public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
    and public.accede_boutique(boutique_id)
  );
drop policy if exists "ecritures pointage" on public.ecritures;
create policy "ecritures pointage" on public.ecritures
  for update to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));

-- ---- Documents : validation / signature après émission ----
drop policy if exists "maj documents" on public.documents;
create policy "maj documents" on public.documents
  for update to authenticated
  using (public.user_role() in ('admin','gerant','comptable')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable')
              and public.accede_boutique(boutique_id));

-- ---- Stock : verrou d'archivage serveur (vendeur = création/modification/
-- ---- vente, JAMAIS de retrait actif=false — trigger, admin/gérant seuls) ----
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
-- Clôture mensuelle d'un partenaire hotspot.
-- Atomique + anti-double (contrainte unique partenaire_id/mois).
-- ---------------------------------------------------------------------------
create or replace function public.cloturer_partage(
  p_partenaire uuid,
  p_boutique   uuid,
  p_mois       char(7)   -- 'AAAA-MM'
) returns jsonb
language plpgsql
security definer           -- exécute avec les droits du créateur (lecture ventes)
set search_path = public
as $$
declare
  v_taux  numeric;
  v_total numeric;
  v_id    uuid;
begin
  -- Sécurité : rôles autorisés (doublon de la policy RLS, défense en profondeur)
  if public.user_role() not in ('admin', 'gerant') then
    raise exception 'Permission refusée';
  end if;

  select taux_partage into v_taux
  from public.partenaires where id = p_partenaire;
  if not found then
    raise exception 'Partenaire introuvable';
  end if;

  select coalesce(sum(montant), 0) into v_total
  from public.transactions
  where partenaire_id = p_partenaire
    and type = 'forfait_hotspot'
    and to_char(date_transaction, 'YYYY-MM') = p_mois;

  insert into public.partages_mensuels
    (id, partenaire_id, boutique_id, mois, total_ventes, taux_partage,
     part_partenaire, part_entreprise, statut, valide_le, valide_par)
  values
    (uuid_generate_v4(), p_partenaire, p_boutique, p_mois, v_total, v_taux,
     v_total * v_taux, v_total * (1 - v_taux), 'valide', now(), auth.uid())
  on conflict (partenaire_id, mois) do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'Mois déjà clôturé pour ce partenaire';
  end if;

  return jsonb_build_object(
    'id', v_id,
    'mois', p_mois,
    'total_ventes', v_total,
    'taux_partage', v_taux,
    'part_partenaire', v_total * v_taux,
    'part_entreprise', v_total * (1 - v_taux)
  );
end;
$$;

grant execute on function public.cloturer_partage(uuid, uuid, char(7))
  to authenticated;

-- ---------------------------------------------------------------------------
-- Numéro de document atomique : évite tout doublon même à 2 caissiers
-- simultanés. Renvoie ex : 'FACT-2026-00042'.
-- ---------------------------------------------------------------------------
create or replace function public.prochain_numero(p_prefixe text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_annee smallint := extract(year from now())::smallint;
  v_compteur integer;
begin
  insert into public.compteurs_documents (prefixe, annee, compteur)
  values (p_prefixe, v_annee, 1)
  on conflict (prefixe, annee)
  do update set compteur = public.compteurs_documents.compteur + 1
  returning compteur into v_compteur;

  return p_prefixe || '-' || v_annee || '-' ||
         lpad(v_compteur::text, 5, '0');
end;
$$;

grant execute on function public.prochain_numero(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Données de test en un appel (base de démo réaliste, idempotente).
-- Depuis l'app (déjà authentifiée) : `select charger_donnees_test();`
-- Depuis le SQL Editor (auth.uid() vide) :
--   `select charger_donnees_test('votre@email.com');`
-- Admin ou gérant uniquement.
-- ---------------------------------------------------------------------------
-- La signature a changé au cours de l'historique (0 → 1 argument) : ce DROP
-- évite qu'une ancienne version sans argument subsiste à côté de la nouvelle
-- (appel ambigu ou ancien comportement conservé).
drop function if exists public.charger_donnees_test();
create or replace function public.charger_donnees_test(p_email text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid;
  v_role text;
  v_bt1 uuid := '11111111-1111-4111-8111-111111111111';
  v_bt2 uuid := '22222222-2222-4222-8222-222222222222';
  v_p1  uuid := '33333333-3333-4333-8333-333333333333';
  v_p2  uuid := '44444444-4444-4444-8444-444444444444';
begin
  if p_email is not null then
    -- Appel depuis le SQL Editor : pas de auth.uid(), on résout l'admin
    -- explicitement par son email (compte déjà créé via Authentication).
    select id into v_uid from auth.users where email = p_email;
    if v_uid is null then
      raise exception 'Aucun compte auth trouvé pour l''email : %', p_email;
    end if;
    select role into v_role from public.users where id = v_uid;
  else
    v_uid := auth.uid();
    v_role := public.user_role();
  end if;

  if v_role is null or v_role not in ('admin','gerant') then
    raise exception 'Réservé à l''administrateur ou au gérant (compte % introuvable dans public.users, ou rôle insuffisant).', coalesce(p_email, v_uid::text);
  end if;

  insert into public.boutiques (id, nom, adresse, siege) values
    (v_bt1, 'Siège — Hotspot & Services', 'Centre-ville', true),
    (v_bt2, 'Boutique Marché', 'Grand marché', false)
  on conflict (id) do nothing;

  insert into public.fonds_roulement (boutique_id, montant) values
    (v_bt1, 500000), (v_bt2, 300000)
  on conflict (boutique_id) do nothing;

  update public.budgets_mensuels set montant = 150000 where categorie = 'Loyer';
  update public.budgets_mensuels set montant = 400000 where categorie = 'Salaires';
  update public.budgets_mensuels set montant = 60000 where categorie = 'Électricité & Eau';

  insert into public.partenaires (id, nom, telephone, localisation, taux_partage) values
    (v_p1, 'Kouassi Jean', '07 08 09 10 11', 'Quieré', 0.60),
    (v_p2, 'Traoré Awa', '05 06 07 08 09', 'Gare routière', 0.55)
  on conflict (id) do nothing;

  insert into public.produits (id, boutique_id, libelle, categorie, prix_achat, prix_vente, quantite_stock, seuil_alerte) values
    ('a1111111-1111-4111-8111-111111111111', v_bt1, 'Câble RJ45 (305m)', 'Télécom & Réseau', 18000, 25000, 4, 3),
    ('a2222222-2222-4222-8222-222222222222', v_bt1, 'Disjoncteur 32A', 'Électricité', 2500, 4000, 25, 5),
    ('a3333333-3333-4333-8333-333333333333', v_bt1, 'Écran 24 pouces', 'Accessoire PC', 45000, 60000, 2, 2),
    ('a4444444-4444-4444-8444-444444444444', v_bt1, 'Chargeur type-C 25W', 'Accessoire téléphone', 3000, 5500, 40, 8),
    ('a5555555-5555-4555-8555-555555555555', v_bt2, 'Caméra IP Hikvision', 'Télécom & Réseau', 22000, 32000, 6, 2)
  on conflict (id) do nothing;

  insert into public.tarifs (id, libelle, categorie, prix, description) values
    ('b1111111-1111-4111-8111-111111111111', 'Installation caméra (unité)', 'Prestation', 5000, 'Pose et configuration par caméra'),
    ('b2222222-2222-4222-8222-222222222222', 'Dépannage informatique', 'Prestation', 10000, 'Diagnostic et réparation'),
    ('b3333333-3333-4333-8333-333333333333', 'Forfait maintenance mensuel', 'Contrat', 25000, 'Astreinte et maintenance préventive'),
    ('b4444444-4444-4444-8444-444444444444', 'Configuration routeur', 'Prestation', 7500, 'Paramétrage complet')
  on conflict (id) do nothing;

  insert into public.clients (id, boutique_id, nom, telephone) values
    ('c1111111-1111-4111-8111-111111111111', v_bt1, 'M. Koné', '07 11 11 11 11'),
    ('c2222222-2222-4222-8222-222222222222', v_bt1, 'Mme Bamba', '05 22 22 22 22'),
    ('c3333333-3333-4333-8333-333333333333', v_bt1, 'Pharmacie du Nord', '27 33 33 33 33')
  on conflict (id) do nothing;

  insert into public.fournisseurs (nom, telephone, specialite) values
    ('ETS Fourni-Tech', '27 44 44 44 44', 'Matériel informatique et réseau'),
    ('CI-Elec Distribution', '27 55 55 55 55', 'Matériel électrique')
  on conflict do nothing;

  -- Transactions des 6 derniers jours (employe = l'admin qui lance).
  insert into public.transactions (boutique_id, employe_id, type, montant, cout, client_nom, partenaire_id, details, date_transaction) values
    (v_bt1, v_uid, 'prestation_service', 25000, 3000, 'M. Koné', null, '{"domaine":"Vidéosurveillance","description":"Installation 4 caméras"}', now() - interval '0 days'),
    (v_bt1, v_uid, 'mobile_money', 50000, 0, null, null, '{"operateur":"Orange Money","frais":400,"operation":"Dépôt"}', now() - interval '0 hours 2 minutes'),
    (v_bt1, v_uid, 'mobile_money', 30000, 0, null, null, '{"operateur":"Moov Money","frais":250,"operation":"Retrait"}', now() - interval '0 hours 3 minutes'),
    (v_bt1, v_uid, 'credit_communication', 2000, 1960, null, null, '{"operateur":"Orange"}', now() - interval '0 hours 4 minutes'),
    (v_bt1, v_uid, 'forfait_hotspot', 1000, 0, null, null, '{"duree":"1 heure"}', now() - interval '0 hours 5 minutes'),
    (v_bt1, v_uid, 'forfait_hotspot', 2500, 0, null, v_p1, '{"duree":"1 jour"}', now() - interval '0 hours 6 minutes'),
    (v_bt1, v_uid, 'prestation_service', 15000, 2000, 'Mme Bamba', null, '{"domaine":"Informatique","description":"Formatage + installation"}', now() - interval '1 days'),
    (v_bt1, v_uid, 'forfait_hotspot', 5000, 0, null, v_p1, '{"duree":"1 semaine"}', now() - interval '1 days'),
    (v_bt1, v_uid, 'forfait_hotspot', 10000, 0, null, v_p2, '{"duree":"1 mois"}', now() - interval '1 days'),
    (v_bt1, v_uid, 'credit_communication', 5000, 4900, null, null, '{"operateur":"Moov"}', now() - interval '1 days'),
    (v_bt2, v_uid, 'vente_materiel', 64000, 44000, 'Entreprise Sahel', null, '{"lignes":[{"libelle":"Caméra IP Hikvision","quantite":2}]}', now() - interval '3 days'),
    (v_bt2, v_uid, 'prestation_service', 40000, 5000, 'Pharmacie du Nord', null, '{"domaine":"Électricité","description":"Mise aux normes tableau"}', now() - interval '5 days'),
    (v_bt1, v_uid, 'mobile_money', 100000, 0, null, null, '{"operateur":"Telecel Money","frais":800,"operation":"Transfert"}', now() - interval '2 days'),
    (v_bt1, v_uid, 'forfait_hotspot', 2500, 0, null, v_p1, '{"duree":"1 jour"}', now() - interval '4 days'),
    (v_bt1, v_uid, 'forfait_hotspot', 1000, 0, null, null, '{"duree":"1 heure"}', now() - interval '4 days');

  insert into public.charges (boutique_id, categorie, libelle, montant, date_charge, recurrente, created_by) values
    (v_bt1, 'Loyer', 'Loyer local siège', 150000, now() - interval '8 days', true, v_uid),
    (v_bt1, 'Électricité & Eau', 'Facture CIE', 45000, now() - interval '4 days', false, v_uid),
    (v_bt1, 'Fournisseurs', 'Achat câbles et connectiques', 75000, now() - interval '2 days', false, v_uid);

  insert into public.feedbacks (auteur_id, auteur_nom, boutique_id, type, priorite, titre, contenu) values
    (v_uid, 'Administrateur', v_bt1, 'suggestion', 'normale',
     'Imprimante tickets caisse', 'Envisager une imprimante thermique pour les tickets de caisse du siège.');

  insert into public.evenements (titre, date, heure, lieu, description) values
    ('Réunion équipe — bilan mensuel', now() + interval '3 days', '09h00',
     'Siège', 'Bilan du mois, parts partenaires, stocks à commander');

  insert into public.notes (titre, contenu, rappel_le) values
    ('Renouveler abonnement internet', 'Contacter le FAI avant coupure', now() + interval '2 days');

  insert into public.messages (expediteur_id, expediteur_nom, destinataire_id, sujet, contenu) values
    (v_uid, 'Système', null, 'Bienvenue 👋', 'Base initialisée avec les données de test. '
     'Pensez à modifier le profil entreprise (RCCM, IFU…) dans Configuration.');

  return '✅ Données de test chargées (boutiques, produits, tarifs, clients, '
         'transactions 6 jours, charges, partenaires).';
end;
$$;
grant execute on function public.charger_donnees_test(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Buckets Storage + politiques (ex-migrations v1.8 bonus + v1.9)
-- Bucket « media » : créé via Dashboard (Storage → New bucket, public).
-- Bucket « documents » (privé, archives PDF) : créé ici, idempotent.
-- Lecture publique media assumée (logos/signatures sur documents partagés) ;
-- écriture authentifiée, suppression admin-gérant.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

drop policy if exists "media lecture publique" on storage.objects;
create policy "media lecture publique" on storage.objects
  for select to public using (bucket_id = 'media');
drop policy if exists "media ecriture" on storage.objects;
create policy "media ecriture" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media');
drop policy if exists "media suppression" on storage.objects;
create policy "media suppression" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and public.user_role() in ('admin','gerant'));

drop policy if exists "documents lecture" on storage.objects;
create policy "documents lecture" on storage.objects
  for select to authenticated using (bucket_id = 'documents');
drop policy if exists "documents ecriture" on storage.objects;
create policy "documents ecriture" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'documents');
drop policy if exists "documents suppression" on storage.objects;
create policy "documents suppression" on storage.objects
  for delete to authenticated
  using (bucket_id = 'documents' and public.user_role() in ('admin','gerant'));

-- ---------------------------------------------------------------------------
-- Durcissement de la clé ANON (1 appel, ex-migration v1.10)
-- La clé anon ne doit RIEN pouvoir faire en direct : l'app exige une
-- session (rôle "authenticated"). Couvre tables EXISTANTES et FUTURES.
-- Rollback complet : assouplir_anon(). État : anon_est_durci().
-- ---------------------------------------------------------------------------
create or replace function public.durcir_anon() returns text
language plpgsql security definer set search_path = public as $$
begin
  if public.user_role() not in ('admin','gerant') then
    raise exception 'Réservé à l''administrateur.';
  end if;
  revoke all on all tables    in schema public from anon;
  revoke all on all sequences in schema public from anon;
  revoke all on all functions in schema public from anon;
  grant usage on schema public to anon; -- nécessaire technique
  -- Tables FUTURES : empêcher que les grants par défaut reviennent
  alter default privileges in schema public revoke all on tables    from anon;
  alter default privileges in schema public revoke all on sequences from anon;
  alter default privileges in schema public revoke all on routines  from anon;
  return 'OK : clé anon durcie — aucun accès direct. Testez connexion + vente.';
end;
$$;

create or replace function public.assouplir_anon() returns text
language plpgsql security definer set search_path = public as $$
begin
  if public.user_role() not in ('admin','gerant') then
    raise exception 'Réservé à l''administrateur.';
  end if;
  grant select, insert, update, delete on all tables    in schema public to anon;
  grant usage on all sequences in schema public to anon;
  grant execute on all functions in schema public to anon;
  grant usage on schema public to anon;
  alter default privileges in schema public grant all on tables    to anon;
  alter default privileges in schema public grant all on sequences to anon;
  alter default privileges in schema public grant all on routines  to anon;
  return 'OK : grants par défaut Supabase rétablis.';
end;
$$;

-- État courant (proxy : anon peut-il lire transactions ?)
create or replace function public.anon_est_durci() returns boolean
language sql stable security definer set search_path = public as $$
  select not has_table_privilege('anon', 'public.transactions', 'SELECT')
$$;

grant execute on function public.durcir_anon()     to authenticated;
grant execute on function public.assouplir_anon()  to authenticated;
grant execute on function public.anon_est_durci()  to authenticated;

-- ---------------------------------------------------------------------------
-- SAUVEGARDE & RESTAURATION (ex-migration v1.11)
-- Depuis l'application (Configuration → Système → Sauvegardes).
--   • sauvegarder_base()  : snapshot JSONB complet (colonnes générées
--     exclues), stocké dans `sauvegardes`.
--   • restaurer_base(id)  : TRUNCATE + réinsertion dans l'ordre des FK.
--     ADMIN UNIQUEMENT. Ré-exécutable.
-- Fichiers Storage non couverts (le bucket les conserve indépendamment).
-- ---------------------------------------------------------------------------
create or replace function public.sauvegarder_base()
returns table(id uuid, nb_lignes integer)
language plpgsql security definer set search_path = public as $$
declare
  v_tables text[] := array['boutiques','users','user_boutiques','categories',
    'fournisseurs','tarifs','produits','partenaires','clients',
    'budgets_mensuels','fonds_roulement','compteurs_documents',
    'transactions','charges','partages_mensuels','documents',
    'document_lignes','messages','evenements','notes','feedbacks'];
  v_id     uuid := uuid_generate_v4();
  v_data   jsonb := '{}'::jsonb;
  v_total  integer := 0;
  v_part   jsonb;
  v_excl   text;
  v_n      bigint;
  v_tn     text;
begin
  if public.user_role() not in ('admin','gerant') then
    raise exception 'Réservé à l''administrateur.';
  end if;
  foreach v_tn in array v_tables loop
    -- exclure les colonnes générées (marge, total…) : opérateur jsonb "-"
    select coalesce(string_agg('- ' || quote_literal(column_name), ' '), '')
      into v_excl
      from information_schema.columns
      where table_schema = 'public' and table_name = v_tn
        and is_generated = 'ALWAYS';
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(x) %s), ''[]''::jsonb), count(*) '
      'from (select * from public.%I) x', v_excl, v_tn)
      into v_part, v_n;
    v_data  := v_data || jsonb_build_object(v_tn, v_part);
    v_total := v_total + v_n::integer;
  end loop;
  select to_jsonb(c) into v_part from public.company_profile c where id = 1;
  v_data := v_data || jsonb_build_object('company_profile', coalesce(v_part, '{}'::jsonb));

  insert into public.sauvegardes (id, auteur_id, auteur_nom, nb_lignes, donnees)
  values (v_id, auth.uid(),
          coalesce((select nom from public.users where id = auth.uid()), 'admin'),
          v_total, v_data);
  return query select v_id, v_total;
end;
$$;

create or replace function public.restaurer_base(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_tables text[] := array['boutiques','users','user_boutiques','categories',
    'fournisseurs','tarifs','produits','partenaires','clients',
    'budgets_mensuels','fonds_roulement','compteurs_documents',
    'transactions','charges','partages_mensuels','documents',
    'document_lignes','messages','evenements','notes','feedbacks'];
  v_data  jsonb;
  v_cols  text;
  v_tn    text;
begin
  if public.user_role() <> 'admin' then
    raise exception 'Restauration réservée à l''administrateur.';
  end if;
  select donnees into v_data from public.sauvegardes where id = p_id;
  if not found then
    raise exception 'Sauvegarde introuvable.';
  end if;

  execute format('truncate %s restart identity cascade',
    (select string_agg('public.' || t, ', ') from unnest(v_tables) as u(t)));

  foreach v_tn in array v_tables loop
    select string_agg(column_name, ', ') into v_cols
      from information_schema.columns
      where table_schema = 'public' and table_name = v_tn
        and is_generated <> 'ALWAYS';
    execute format(
      'insert into public.%I (%s) select %s '
      'from jsonb_populate_recordset(null::public.%I, $1 -> %L)',
      v_tn, v_cols, v_cols, v_tn, v_tn)
      using v_data;
  end loop;

  -- Profil entreprise (ligne unique id=1)
  delete from public.company_profile where id = 1;
  execute format(
    'insert into public.company_profile (%s) select %s '
    'from jsonb_populate_recordset(null::public.company_profile, $1 -> %L)',
    (select string_agg(column_name, ', ') from information_schema.columns
      where table_schema='public' and table_name='company_profile'
        and is_generated <> 'ALWAYS'),
    (select string_agg(column_name, ', ') from information_schema.columns
      where table_schema='public' and table_name='company_profile'
        and is_generated <> 'ALWAYS'),
    'company_profile')
    using v_data;

  return 'OK : base restaurée (' ||
    (select nb_lignes::text from public.sauvegardes where id = p_id) ||
    ' lignes). Reconnectez-vous pour recharger les données.';
end;
$$;

grant execute on function public.sauvegarder_base() to authenticated;
grant execute on function public.restaurer_base(uuid)  to authenticated;

-- ---------------------------------------------------------------------------
-- JOURNAL D'ACTIVITÉ — audit trail réel (ex-migration v1.12)
-- Un trigger générique sur chaque table métier capture TOUTE écriture,
-- quelle que soit son origine (app, RPC, SQL Editor). Exclut journal_activite
-- (récursion) et sauvegardes (dupliquerait toute la base à chaque snapshot).
-- ---------------------------------------------------------------------------
create or replace function public.f_journal_activite() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_data jsonb := case when TG_OP = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  insert into public.journal_activite
    (user_id, user_nom, action, table_nom, ligne_id, detail)
  values (
    auth.uid(),
    coalesce((select nom from public.users where id = auth.uid()), 'système'),
    lower(TG_OP), TG_TABLE_NAME, v_data ->> 'id', v_data
  );
  return case when TG_OP = 'DELETE' then old else new end;
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'boutiques','users','user_boutiques','clients','produits','transactions',
    'partenaires','charges','budgets_mensuels','fonds_roulement','documents',
    'document_lignes','categories','fournisseurs','messages','evenements',
    'notes','feedbacks','tarifs','company_profile',
    'achats','mouvements_stock','ecritures'
  ] loop
    execute format(
      'drop trigger if exists trg_journal_%1$s on public.%1$s;
       create trigger trg_journal_%1$s
       after insert or update or delete on public.%1$s
       for each row execute function public.f_journal_activite();',
      v_table);
  end loop;
end $$;

-- ============================================================================
-- FIN DES FONCTIONS + RLS — base opérationnelle complète.
-- Optionnel : select charger_donnees_test(); pour une base de démo.
-- ============================================================================
