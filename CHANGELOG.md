# CHANGELOG — NYCTA / PME Gestion

> Historique des versions livrées (voir `CAHIER_DES_CHARGES.md` §9 pour le détail).

## 1.8.0 — 2026-09-25
- Sélecteur de date robuste (`DatePickerField`, délégués FR, saisie manuelle)
- Module Achats fournisseurs (cycle, CUMP, dettes, `migration_achats.sql`)
- Mouvements de stock tracés + valorisation + ajustements (`migration_mouvements_stock.sql`)
- Analytique CA & dépenses (7j/mois/années, détail filtrable)
- Bordereau de livraison sans prix (aperçu + PDF + signatures)
- Pull-to-refresh (Journal, Stock, Charges, Partenaires, Messagerie, Dashboard)
- RLS critiques : demandes vendeur, défauts `created_by`, verrou archivage (`migration_fixes_critiques_rls.sql`)
- Reset mot de passe (lien Supabase), `MATRICE_PERMISSIONS.md`
- Comptabilité SYSCOHADA : journal auto, balance, compte de résultat (`migration_compta.sql`)
- Crédit client + relances + balance âgée + TVA mensuelle
- Signature client manuscrite par document (`migration_signatures_documents.sql`)
- Validation manager des documents (brouillon→émis), rapprochement bancaire pointé (`migration_rapprochement.sql`)
- Tests d'intégration (parcours) + matrice TextScaler 1.0–2.0 + CAGR + export CSV analytique
- UI : AppBar bleu nuit globale, lisibilité AppBar
- Validation manager des documents (brouillon→émis), rapprochement bancaire pointé (`migration_rapprochement.sql`)
- Tests d'intégration (parcours), matrice TextScaler 1.0–2.0, CAGR, export CSV analytique
- 68 tests verts, `flutter analyze` 0 erreur

## 1.7.x et antérieur
- Voir `CAHIER_DES_CHARGES.md` §§6–6ter (production, sauvegardes, durcissement anon, documents cloud, obfuscation, audits sécurité).
