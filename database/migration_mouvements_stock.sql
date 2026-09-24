-- ============================================================================
-- MIGRATION mouvements_stock (mission 1, §1.3) — Traçabilité des stocks :
-- chaque entrée/sortie/ajustement/retour est journalisé avec auteur,
-- motif et stock résultant. À exécuter dans Supabase → SQL Editor.
-- Idempotent et ré-exécutable.
--
-- Prérequis : fonctions consolidées à jour (f_journal_activite, v1.12+).
-- ============================================================================

create table if not exists public.mouvements_stock (
  id            uuid primary key default uuid_generate_v4(),
  boutique_id   uuid not null references public.boutiques(id),
  produit_id    uuid references public.produits(id),
  produit_nom   text not null default '',
  type          text not null default 'ajustement'
                check (type in ('entree','sortie','ajustement','retour','inventaire')),
  quantite      integer not null default 0,  -- signée : + entrée, − sortie
  stock_apres   integer not null default 0,
  motif         text not null default '',
  ref_id        uuid,                        -- achat/vente/document d'origine
  date_mouvement timestamptz not null default now(),
  created_by    uuid references auth.users(id),
  created_at    timestamptz not null default now()
);
create index if not exists idx_mouvements_produit_date
  on public.mouvements_stock (produit_id, date_mouvement desc);
create index if not exists idx_mouvements_boutique_date
  on public.mouvements_stock (boutique_id, date_mouvement desc);

alter table public.mouvements_stock enable row level security;

-- Lecture : boutiques accessibles (comme transactions/produits/charges).
drop policy if exists "mouvements select" on public.mouvements_stock;
create policy "mouvements select" on public.mouvements_stock
  for select to authenticated using (public.accede_boutique(boutique_id));

-- Écriture : rôles opérationnels caisse/stock/compta (miroir des policies
-- d'écriture transactions/produits/charges).
drop policy if exists "mouvements ecriture" on public.mouvements_stock;
create policy "mouvements ecriture" on public.mouvements_stock
  for all to authenticated
  using (public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
         and public.accede_boutique(boutique_id))
  with check (public.user_role() in ('admin','gerant','comptable','caissier','vendeur')
              and public.accede_boutique(boutique_id));

-- Audit trail : même trigger générique que les autres tables métier.
drop trigger if exists trg_journal_mouvements_stock on public.mouvements_stock;
create trigger trg_journal_mouvements_stock
  after insert or update or delete on public.mouvements_stock
  for each row execute function public.f_journal_activite();
-- ============================================================================
