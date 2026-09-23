-- ============================================================
-- Migration : bordereau de livraison (bon_livraison)
-- À exécuter UNE FOIS dans Supabase → SQL Editor.
-- Ajoute la valeur 'bon_livraison' à l'enum Postgres `type_document`
-- utilisée par les tables documents / document_lignes.
-- Idempotent : ne fait rien si la valeur existe déjà.
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'type_document' AND e.enumlabel = 'bon_livraison'
  ) THEN
    ALTER TYPE type_document ADD VALUE 'bon_livraison';
  END IF;
END
$$;
