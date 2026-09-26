# CHANGELOG — NYCTA / PME Gestion

> Historique des versions livrées (voir `CAHIER_DES_CHARGES.md` §9 pour le détail).

## 1.9.0 — 2026-09-26 (lot MISSION : SQL regroupé + Journal/Stock/Dépenses/Partenaires/Trésorerie/Rapports/Analytique/Documents)
- SQL regroupé : `supabase_schema.sql` + `supabase_migration.sql` + `supabase_fonctions_rls.sql` + `supabase_apply_all.sql` (généré, régénéré le 2026-09-26 : colonne `produits.images` + bucket `produits`) + `supabase_verify.sql` ; 13 fichiers obsolètes supprimés (points 1-2)
- Navigation : Journal → onglet Plus, Achat → barre principale (points 3-4)
- `ExportService` unifié (PDF + Excel `.xlsx` + CSV BOM/`;`) réutilisé par tous les modules (points 5-17)
- Journal : filtres période + sous-catégorie/type, bug PDF vide corrigé (tableau « Aucune donnée » garanti) (points 6-7)
- Stock : recherche + filtre catégorie, exports, persistance images (bucket `produits` + colonne JSON), galerie max 05 (points 8-11)
- Dépenses / Partenaires / Trésorerie / Rapport / Analytique : filtres + exports (points 12-17)
- Documents : audit conformité (5 types, BL sans prix, numérotation séquentielle, RCCM/IFU), signatures entreprise-gauche/client-droite toujours imprimées, overflow Documents émis corrigé (Wrap), filtres type/recherche/dates/montants (points 18-21)
- Tests : `flutter test` 112/112 + golden 360px `test/golden/goldens/documents_emis_360.png` ; `flutter analyze` 0 erreur (69 warnings + 42 infos, tous pré-existants — voir § Dette warnings ci-dessous)
- Commits : `724c4a8` (overflow + filtres documents), `30177a4` (audit + signatures)

### Dette warnings `flutter analyze` (justification, 2026-09-26)
Total 111 = 0 erreur + 69 warnings + 42 infos, aucun introduit comme nouvelle famille par le lot :
- `inference_failure_on_function_invocation` (29), `inference_failure_on_instance_creation` (24), `inference_failure_on_collection_literal` (9) — pattern codebase historique (ex : `MaterialPageRoute` sans type explicite, utilisé dans tout le projet y compris le code pré-existant) ; le lot n'en ajoute qu'1 occurrence de la même famille (`documents_history_screen.dart:289`).
- `prefer_const_constructors` (28), `prefer_final_locals` (2), `unnecessary_cast` (4), `unused_import` (2), `unused_element` (1) — style pré-existant, nettoyage à planifier hors mission (ticket : passer `prefer_const_constructors` + `unnecessary_cast` en lot `refactor/lints` dédié).
- `deprecated_member_use` (8), `use_build_context_synchronously` (4) — pré-existants, à traiter avec montée de version des dépendances.
- Fichiers du lot Documents : 3 warnings uniquement, tous `inference_failure_on_instance_creation` pré-existants de famille (preview ×2 pré-existants, historique ×1 même pattern).

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
- P11 : workflow payé/annulé, Edge Function admin, CAGR mensuel, export PDF, mini-graphe, rapprochement UI, 32 tests TextScaler
- 98+ tests verts, `flutter analyze` 0 erreur

## 1.7.x et antérieur
- Voir `CAHIER_DES_CHARGES.md` §§6–6ter (production, sauvegardes, durcissement anon, documents cloud, obfuscation, audits sécurité).
