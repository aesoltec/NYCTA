# MISSION_STATUS — Suivi d'exécution

| # | Point | Statut | Preuve | Date |
|---|-------|--------|--------|------|
| 1 | Regrouper SQL en supabase_schema.sql + supabase_migration.sql + supabase_fonctions_rls.sql | ✅ | database/ (582+148+944 lignes) + supabase_apply_all.sql (1540, généré) + supabase_verify.sql ; tests/analyze verts | 2026-09-26 |
| 2 | Supprimer fichiers de migration obsolètes | ✅ | 13 fichiers supprimés (git) ; database/ = 6 fichiers utiles | 2026-09-26 |
| 3 | Déplacer bouton Journal → onglet Plus | ✅ | app_shell.dart:85-91 (AchatListScreen) + menu_screen.dart:43-50 (tuile Journal) ; parcours_test vert | 2026-09-26 |
| 4 | Remplacer place Journal par bouton Achat | ✅ | app_shell.dart:244-248 (destination Achats) ; tuile dashboard existante | 2026-09-26 |
| 5 | Export PDF/Excel/CSV onglet Achat | ⬜ | — | — |
| 6 | Filtres période/intervalle/catégorie/sous-catégorie Journal | ✅ | journal_screen.dart (plage dates, sous-catégorie/type) ; test export ci-dessous | 2026-09-26 |
| 7 | Corriger bug impression/export PDF vide | ✅ | ExportService.pdfTableau (ligne « Aucune donnée » garantie) + menu export Journal ; export_service_test.dart 3/3 | 2026-09-26 |
| 8 | Filtres catégorie/sous-catégorie Stock | ✅ | stock_screen.dart (recherche + dropdown catégorie) ; ecrans_test 10/10 | 2026-09-26 |
| 9 | Export PDF/Excel/CSV Stock | ✅ | ExportService + menu export (valorisation incluse) | 2026-09-26 |
| 10 | Corriger persistance images Stock | ✅ | Bucket `produits` + colonne JSON + upload cloud + recharge au démarrage (plus de chemins cache) | 2026-09-26 |
| 11 | Multi-images produits (max 05) | ✅ | Galerie (ajout/aperçu/principal/suppression), Produit.images, produit_images_test 4/4 | 2026-09-26 |
| 12 | Filtres catégorie/sous-catégorie Dépenses | ✅ | charges_screen.dart (recherche + dropdown catégorie) ; ecrans_test | 2026-09-26 |
| 13 | Export PDF/Excel/CSV Dépenses | ✅ | ExportService + menu export (total inclus) | 2026-09-26 |
| 14 | Export PDF/Excel/CSV Partenaires hotspot | ✅ | ExportService + menu AppBar (ventes, parts, clôture) | 2026-09-26 |
| 15 | Export + filtres Trésorerie | ⬜ | — | — |
| 16 | Export + filtres Rapport financier | ⬜ | — | — |
| 17 | Export + filtres Analytique CA & Dépenses | ⬜ | — | — |
| 18 | Audit Documents commerciaux | ⬜ | — | — |
| 19 | Signature entreprise gauche + espace client droite | ⬜ | — | — |
| 20 | Corriger overflow Documents émis (33px) | ⬜ | — | — |
| 21 | Filtres Documents émis | ⬜ | — | — |
| 22 | Filtre + recherche Boutique | ⬜ | — | — |
| 23 | Filtre + recherche Catégories | ⬜ | — | — |
| 24 | Audit formulaire vente | ⬜ | — | — |
| 25 | Filtres + export Achat et fournisseurs | ⬜ | — | — |
| 26 | Filtre spécialité + recherche + export Fournisseurs | ⬜ | — | — |
| 27 | Recherche + filtre Clients | ⬜ | — | — |
| 28 | Champs clients étendus (RIB, RCCM, logo, coordonnées) | ⬜ | — | — |
| 29 | Export Clients | ⬜ | — | — |
| 30 | Brancher Comptabilité | ⬜ | — | — |
| 31 | Export + filtres Comptabilité | ⬜ | — | — |
| 32 | Filtres Statistiques & graphiques | ⬜ | — | — |
| 33 | Export PDF/Excel Statistiques | ⬜ | — | — |
| 34 | Filtres Tarifs & catégories | ⬜ | — | — |
| 35 | Formulaire catégorie connecté + anti-doublon | ⬜ | — | — |
| 36 | Multi-images articles (max 05) | ⬜ | — | — |
| 37 | Réorganiser menu onglet Plus | ⬜ | — | — |