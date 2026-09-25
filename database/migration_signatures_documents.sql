-- ============================================================================
-- MIGRATION signatures documents — Signature manuscrite du client /
-- réceptionnaire capturée à l'émission (facture, devis, ticket, bon de
-- commande, BL). À exécuter dans Supabase → SQL Editor. Idempotent.
-- Le PNG est stocké dans le bucket privé `documents/signatures/` ; cette
-- colonne conserve le chemin storage (re-téléchargé après rechargement).
-- ============================================================================

alter table public.documents
  add column if not exists signature_client_path text;
-- ============================================================================
