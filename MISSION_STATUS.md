# MISSION_STATUS — Suivi d'exécution

| # | Point | Statut | Preuve | Date |
|---|-------|--------|--------|------|
| 1 | Regrouper SQL en supabase_schema.sql + supabase_migration.sql + supabase_fonctions_rls.sql | ✅ | database/ (582+148+944 lignes) + supabase_apply_all.sql (1540, généré) + supabase_verify.sql ; tests/analyze verts | 2026-09-26 |
| 2 | Supprimer fichiers de migration obsolètes | ✅ | 13 fichiers supprimés (git) ; database/ = 6 fichiers utiles | 2026-09-26 |
| 3 | Déplacer bouton Journal → onglet Plus | ✅ | app_shell.dart:85-91 (AchatListScreen) + menu_screen.dart:43-50 (tuile Journal) ; parcours_test vert | 2026-09-26 |
| 4 | Remplacer place Journal par bouton Achat | ✅ | app_shell.dart:244-248 (destination Achats) ; tuile dashboard existante | 2026-09-26 |
| 5 | Export PDF/Excel/CSV onglet Achat | ✅ | achat_list_screen.dart (menu « Exporter (vue filtrée ou tout) » : 3 formats sur vue filtrée + 3 sur « Tous », totaux TTC/dû) ; achat_export_test.dart 3/3 (BOM, en-têtes, totaux, xlsx, PDF plein+vide) + ecrans_test | 2026-09-26 |
| 6 | Filtres période/intervalle/catégorie/sous-catégorie Journal | ✅ | journal_screen.dart (plage dates, sous-catégorie/type) ; test export ci-dessous | 2026-09-26 |
| 7 | Corriger bug impression/export PDF vide | ✅ | ExportService.pdfTableau (ligne « Aucune donnée » garantie) + menu export Journal ; export_service_test.dart 3/3 | 2026-09-26 |
| 8 | Filtres catégorie/sous-catégorie Stock | ✅ | stock_screen.dart (recherche + dropdown catégorie) ; ecrans_test 10/10 | 2026-09-26 |
| 9 | Export PDF/Excel/CSV Stock | ✅ | ExportService + menu export (valorisation incluse) | 2026-09-26 |
| 10 | Corriger persistance images Stock | ✅ | Bucket `produits` + colonne JSON + upload cloud + recharge au démarrage (plus de chemins cache) | 2026-09-26 |
| 11 | Multi-images produits (max 05) | ✅ | Galerie (ajout/aperçu/principal/suppression), Produit.images, produit_images_test 4/4 | 2026-09-26 |
| 12 | Filtres catégorie/sous-catégorie Dépenses | ✅ | charges_screen.dart (recherche + dropdown catégorie) ; ecrans_test | 2026-09-26 |
| 13 | Export PDF/Excel/CSV Dépenses | ✅ | ExportService + menu export (total inclus) | 2026-09-26 |
| 14 | Export PDF/Excel/CSV Partenaires hotspot | ✅ | ExportService + menu AppBar (ventes, parts, clôture) | 2026-09-26 |
| 15 | Export + filtres Trésorerie | ✅ | ExportService + filtre catégorie/boutique | 2026-09-26 |
| 16 | Export + filtres Rapport financier | ✅ | ExportService + filtre boutiques | 2026-09-26 |
| 17 | Export + filtres Analytique CA & Dépenses | ✅ | ExportService (série + détail CSV déjà là) ; ecrans_test 10/10 | 2026-09-26 |
| 18 | Audit Documents commerciaux | ✅ | document.dart (5 types, préfixes uniques, BL sansPrix, règles stock) + document_service (TVA profil, entête RCCM/IFU, numérotation séquentielle RPC) ; signature_document_test 5/5 | 2026-09-26 |
| 19 | Signature entreprise gauche + espace client droite | ✅ | pdf_service.dart (2 zones encadrées toujours imprimées, libellés exacts) + preview relabellé ; PdfService.generer sans images OK | 2026-09-26 |
| 20 | Corriger overflow Documents émis (33px) | ✅ | documents_history_screen.dart (actions en Wrap sous l'en-tête, plus de trailing en colonne) ; ecrans_test 12/12 + golden test/golden/documents_emis_360_test.dart (PNG 360×800, 0 exception) | 2026-09-26 |
| 21 | Filtres Documents émis | ✅ | documents_history_screen.dart (type ChoiceChips, recherche client/numéro, dates Début/Fin, Min/Max, LayoutBuilder étroit) ; ecrans_test 12/12 | 2026-09-26 |
| 22 | Filtre + recherche Boutique | ✅ | boutiques_screen.dart (recherche nom/adresse, chips Actives/Fermées/Toutes + Siège/Annexes, badge FERMÉE, fermées en lecture seule) ; ecrans_test 13/13 + suite 117/117 | 2026-09-26 |
| 22bis | Réouverture boutique fermée | ✅ | RPC `reouvrir_boutique` (garde admin/gérant + vérif fermée + audit trail) + UI confirmation + MATRICE_PERMISSIONS + test 4/4 ; SQL prêt (SUPABASE_A_EXECUTER.sql) | 2026-09-26 |
| 22ter | Champs boutique étendus (ville, responsable, code) | ⬜ (🟢, hors périmètre v1 — CDC §8bis : « À valider avec le métier avant implémentation ») | Aucun flux actuel n'exige ces champs ; non inventés, tracés au CDC | — |
| 23 | Filtre + recherche Catégories | ✅ | categories_screen.dart (recherche nom par onglet, type = onglets Produits/Charges ; statut/parent/code absents du modèle, non inventés) ; ecrans_test 14/14 + suite 118/118 | 2026-09-26 |
| 23bis | Modèle catégories String → table dédiée | ⬜ (🟢, hors périmètre v1 — CDC §8bis : « migration à planifier hors mission ») | La table SQL `categories` existe (v1.2) ; le modèle Dart reste des listes de String volontairement (seed + listes dynamiques) | — |
| 24 | Audit formulaire vente | ✅ | nouvelle_transaction_screen.dart (remise + mode paiement ajoutés, net = brut − remise, garde mounted) + journal suffixes ; vente_form_test.dart 6/6 + suite 124/124 | 2026-09-26 |
| 25 | Filtres + export Achat et fournisseurs | ✅ | achat_list_screen.dart sur FiltrePanel (statuts + recherche + NOUVEAU filtre période Début/Fin) ; export point 5 inchangé ; suite 128/128 | 2026-09-26 |
| 25bis | Extraction FiltrePanel commun | ✅ | widgets/filtre_panel.dart (recherche, chips, dropdown, dates, min/max, LayoutBuilder) ; filtre_panel_test.dart 3/3 ; migrés : Achat, Boutique, Catégories | 2026-09-26 |
| 26 | Filtre spécialité + recherche + export Fournisseurs | ✅ | fournisseurs_screen.dart sur FiltrePanel (recherche nom/tél/spé + dropdown spécialités) + menu export PDF/Excel/CSV ; ecrans_test | 2026-09-26 |
| 27 | Recherche + filtre Clients | ✅ | clients_screen.dart sur FiltrePanel (recherche nom/tél/adresse + chips Tous/Professionnels/Particuliers) ; clients_test.dart | 2026-09-26 |
| 28 | Champs clients étendus (RIB, RCCM, logo, coordonnées) | ✅ | Client.email/rccm/rib/logoPath + formulaire (Email/RCCM/RIB/logo bucket media) + migration SQL + upsert avec repli ; fromJson rétrocompatible | 2026-09-26 |
| 29 | Export Clients | ✅ | Menu PDF/Excel/CSV (nom, tél, email, adresse, RCCM, RIB, catégorie) | 2026-09-26 |
| 30 | Brancher Comptabilité | ✅ | store.dart (contre-passe maj vente + suppression charge, anti-double caisse paiement) ; compta_test.dart 7/7 (D=C par flux, nets nuls, invariant global) + suite 141/141 | 2026-09-26 |
| 31 | Export + filtres Comptabilité | ✅ | compta_screen.dart sur FiltrePanel (journal + recherche + période) + exports journal/balance PDF/Excel/CSV ; ecrans_test | 2026-09-26 |
| 32 | Filtres Statistiques & graphiques | ✅ | stats_screen.dart sur FiltrePanel (activité + période, seaux jour/semaine/mois) ; stats_test.dart 3/3 | 2026-09-26 |
| 33 | Export PDF/Excel Statistiques | ✅ | Menu export vue filtrée (série + par activité + total, PDF/Excel/CSV) | 2026-09-26 |
| 34 | Filtres Tarifs & catégories | ✅ | tarifs_screen.dart sur FiltrePanel (recherche + dropdown catégories catalogue) ; tarifs_test.dart | 2026-09-26 |
| 35 | Formulaire catégorie connecté + anti-doublon | ✅ | Autocomplete (module ∪ catalogue, casse+accents via Store.sansAccents/memeCategorie) + création auto transactionnelle ; tarifs_test.dart 7/7 | 2026-09-26 |
| 36 | Multi-images articles (max 05) | ✅ | Tarif.images + galerie formulaire + vignette liste + cloud bucket `produits` (repli) + SQL tarifs.images + roundtrip test | 2026-09-26 |
| 37 | Réorganiser menu onglet Plus | ✅ | menu_screen.dart (11 sections thématiques : Ventes, Achats, Stock, Finances, Comptabilité, Partenaires, Documents, Rapports, Configuration, Administration, Collaboration — flux métier) ; ecrans_test 19/19 + suite 150/150 + test 360px | 2026-09-26 |