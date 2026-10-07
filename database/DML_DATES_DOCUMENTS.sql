-- ============================================================================
-- NYCTA / PME Gestion - Documents : date, conditions de reglement,
-- unite et reference par ligne
--
-- POURQUOI
-- -------
-- La modification d'un document (devis / bon de commande / bordereau)
-- passe desormais par `DocumentNotifier.modifierDocument`. Elle ne peut
-- fonctionner que si ces informations sont STOCEES et RELUES.
--
-- Deux points de vigilance :
--
-- 1. Les colonnes sont AJOUTEES, jamais renommees ni supprimees. Une
--    ligne de document deja enregistree garde ses valeurs : `unite` et
--    `reference` valent '' par defaut, et le code les remplace par 'pcs'
--    a la lecture (cf. `LigneDoc.depuisJson`) plutot que d'afficher une
--    ligne sans unite.
--
-- 2. `date_doc` existe deja (migration P9). On ne la redefinit PAS, on
--    verifie seulement qu'elle est laible, et on travaille avec.
--
-- A EXECUTER UNE SEULE FOIS sur la base Supabase.
-- Idempotent : chaque `IF NOT EXISTS` est verifie avant creation.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Colonnes du document
-- ----------------------------------------------------------------------------

-- Date du document au format d'affichage jj/MM/aaaa. Nullable : un
-- import sans colonne « date » ne doit pasechouer, l'import ecrit alors
-- 'non renseignee' comme libelle.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'documents'
                   AND column_name = 'date_doc') THEN
    ALTER TABLE documents ADD COLUMN date_doc text;
    RAISE NOTICE 'colonne documents.date_doc ajoutee';
  END IF;
END $$;

-- Note libre / conditions imprimees en pied de document.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'documents'
                   AND column_name = 'note') THEN
    ALTER TABLE documents ADD COLUMN note text NOT NULL DEFAULT '';
    RAISE NOTICE 'colonne documents.note ajoutee';
  END IF;
END $$;

-- Adresse de livraison quand elle differe de l'adresse de facturation
-- (bordereau livre ailleurs que le client facture).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'documents'
                   AND column_name = 'adresse_livraison') THEN
    ALTER TABLE documents ADD COLUMN adresse_livraison text NOT NULL DEFAULT '';
    RAISE NOTICE 'colonne documents.adresse_livraison ajoutee';
  END IF;
END $$;

-- Date d'echeance de paiement, format jj/MM/aaaa.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'documents'
                   AND column_name = 'echeance') THEN
    ALTER TABLE documents ADD COLUMN echeance text NOT NULL DEFAULT '';
    RAISE NOTICE 'colonne documents.echeance ajoutee';
  END IF;
END $$;

-- Duree de reglement en jours. 0 = comptant. L'echeance est calculee
-- cote application ; on stocke les deux pour que le document affiche et
-- imprime la meme chose meme si la date du document change apres coup.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'documents'
                   AND column_name = 'delai_paiement_jours') THEN
    ALTER TABLE documents
      ADD COLUMN delai_paiement_jours integer NOT NULL DEFAULT 0;
    RAISE NOTICE 'colonne documents.delai_paiement_jours ajoutee';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Colonnes des lignes
-- ----------------------------------------------------------------------------

-- Unite de vente (pcs, kg, h, lot...). Sans elle, « 3 » ne dit rien.
-- Valeur par defaut 'pcs' : une ligne existante reste exploitable.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'document_lignes'
                   AND column_name = 'unite') THEN
    ALTER TABLE document_lignes
      ADD COLUMN unite text NOT NULL DEFAULT 'pcs';
    RAISE NOTICE 'colonne document_lignes.unite ajoutee';
  END IF;
END $$;

-- Reference article : relie la ligne a sa fiche produit.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'document_lignes'
                   AND column_name = 'reference') THEN
    ALTER TABLE document_lignes
      ADD COLUMN reference text NOT NULL DEFAULT '';
    RAISE NOTICE 'colonne document_lignes.reference ajoutee';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. Journal des corrections (table)
-- ----------------------------------------------------------------------------
-- Une correction d'un document EMIS (devis / BC / bordereau) doit rester
-- demonstrable : qui l'a fait, quand, pourquoi. Cette table en est la
-- trace, et elle est ecrite au moment de la modification.
--
-- Le numero du document est une colonne simple, volontairement PAS de
-- cle etrangere vers documents(id) : un document peut etre modifie avant
-- d'etre synchronise (mode hors-ligne), et la modification ne doit pas
-- disparaitre parce que la ligne d'origine n'est pas encore remontee.
--
-- `authorisation` : la meme politique que documents (RLS par
-- boutique_id). Sans elle, un document d'une boutique pourrait etre lu
-- par une autre.

CREATE TABLE IF NOT EXISTS document_modifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id uuid NOT NULL REFERENCES boutiques(id) ON DELETE CASCADE,
  numero      text NOT NULL,
  date        text NOT NULL,
  auteur      text NOT NULL DEFAULT '',
  motif       text NOT NULL DEFAULT '',
  resume      text NOT NULL DEFAULT '',
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  cree_le     timestamptz NOT NULL DEFAULT now()
);

-- Requete courante : toutes les corrections d'une boutique, les plus
-- recentes d'abord.
CREATE INDEX IF NOT EXISTS idx_document_modifications_boutique
  ON document_modifications (boutique_id, date DESC);

-- Une meme correction ne doit pas etre ecrite deux fois : la lecture
-- cloud remplace le journal en memoire, un doublon fausserait le compte
-- affiche (« 2 corrections » pour une seule).
CREATE UNIQUE INDEX IF NOT EXISTS idx_document_modifications_unique
  ON document_modifications (boutique_id, numero, date, motif);

-- Meme politique que les autres tables de la boutique : un utilisateur
-- ne voit que les documents de ses boutiques.
ALTER TABLE document_modifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS document_modifications_select ON document_modifications;
CREATE POLICY document_modifications_select ON document_modifications
  FOR SELECT
  USING (boutique_id IN (
    SELECT boutique_id FROM user_boutiques
    WHERE user_id = auth.uid()
  ));

-- Les corrections sont des TRACES : on les insere (le client ecrit sa
-- propre correction) et on ne les modifie ni ne les supprime jamais.
-- Corriger une trace n'a pas de sens ; on ecrit une nouvelle trace.
DROP POLICY IF EXISTS document_modifications_insert ON document_modifications;
CREATE POLICY document_modifications_insert ON document_modifications
  FOR INSERT
  WITH CHECK (boutique_id IN (
    SELECT boutique_id FROM user_boutiques
    WHERE user_id = auth.uid()
  ));

-- ----------------------------------------------------------------------------
-- 4. Valeurs par defaut sur les lignes deja enregistrees
-- ----------------------------------------------------------------------------
-- Une ligne anterieure a cette migration a unite NULL ou vide selon la
-- colonne ; on force 'pcs' pour qu'aucun document existant ne soit
-- incoherent avec le reste.
UPDATE document_lignes
   SET unite = 'pcs'
 WHERE unite IS NULL OR btrim(unite) = '';

UPDATE documents
   SET note = ''
 WHERE note IS NULL;

UPDATE documents
   SET adresse_livraison = ''
 WHERE adresse_livraison IS NULL;

UPDATE documents
   SET echeance = ''
 WHERE echeance IS NULL;

-- ----------------------------------------------------------------------------
-- 5. Verification
-- ----------------------------------------------------------------------------
SELECT to_regclass('public.document_modifications') AS table_journal,
       (SELECT count(*) FROM pg_policies
         WHERE tablename = 'document_modifications') AS politiques_rls;
SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
 WHERE table_name = 'documents'
   AND column_name IN ('date_doc', 'note', 'adresse_livraison',
                       'echeance', 'delai_paiement_jours')
 ORDER BY column_name;

SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
 WHERE table_name = 'document_lignes'
   AND column_name IN ('unite', 'reference')
 ORDER BY column_name;