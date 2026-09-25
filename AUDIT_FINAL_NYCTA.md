# AUDIT FINAL — NYCTA (missionbis, 100% conformité)

> Audit exercé le 2026-09-25 sur `main` = `e0116d5` (+ docs). Dépôt :
> `https://github.com/aesoltec/NYCTA` (renommé depuis `aestechnoinfo-ai`).
> Méthode : lecture du code, `flutter analyze`, `flutter test`, revue SQL.
> Non vérifié par l'auditeur : exécution sur appareils physiques, projet
> Supabase réel (les preuves serveur sont code + migrations à appliquer).

## 3.1. Bugs critiques (exigences 1–14)

### Exigence 1 : Sélecteur de date — ⚠️ PARTIEL (85%)
- Flutter : `lib/widgets/date_picker_field.dart:104` (`choisirDateRobuste`, clamp auto) ; `:25`/`40` (parse + validation JJ/MM/AAAA) ; `lib/main.dart:55-57` (locale FR, délégués) ; 5 formulaires via `ChampDate`, 2 via `DatePickerField`, zéro picker brut.
- Supabase : sans objet.
- Test : `test/date_picker_field_test.dart` — 9/9 verts (dont reproduction du bug `MaterialLocalizations` avant fix).
- UI : calendrier + saisie clavier + effaçable.
- Doc : `CHANGELOG.md` §1.8.0.
- Réserve : pas d'exécution Android/Web par l'auditeur.

### Exigence 2 : Tuile Achat — ✅ CONFORME (95%)
- Flutter : `lib/screens/dashboard/dashboard_screen.dart` (tuile `_TuileAchats` : mois, en attente, dû, alerte stock bas) + `lib/screens/menu/menu_screen.dart` (entrée Achats) ; permission `gererAchats`, vendeur/caissier inclus.
- Supabase : table `achats` (`database/migration_achats.sql`).
- Test : `test/achat_test.dart` (création, statuts, totaux).
- Réserve : pas de test widget du tap tuile.

### Exigence 3 : Logique Achat — ✅ CONFORME (95%)
- Flutter : `lib/data/store.dart` (~l.2160-2360 : `creerAchat`, `validerAchat`, `recevoirAchat` CUMP, `payerAchat` + charge, `annulerAchat` contre-écriture) ; `lib/models/achat.dart` (HT/TVA/TTC, reste dû).
- Supabase : `migration_achats.sql` (statuts, RLS, trigger journal).
- Test : `test/achat_test.dart` — 9/9 (cycle complet, surpaiement refusé).
- Réserve : pas de test bout-en-bout multi-écrans.

### Exigence 4 : Matériel — ✅ CONFORME (95%)
- Flutter : `store.dart:2331` (CUMP), `_journaliser` (5 points : vente, réception, document, annulation, correction), `valeurStock`, `ajusterStock` (motif obligatoire) ; `lib/screens/stock/mouvements_screen.dart` ; `lib/models/mouvement_stock.dart`.
- Supabase : `database/migration_mouvements_stock.sql` (table + RLS + trigger).
- Test : `test/mouvement_stock_test.dart` — 5/5.
- Doc : README (ligne Stock), `MATRICE_PERMISSIONS.md`.

### Exigence 5 : Overflow messagerie — ⚠️ PARTIEL (85%)
- Flutter : `lib/screens/collab/messagerie_screen.dart` (trailing `Row` → `Column` compacte, date avec ellipsis).
- Test : aucun test de TextScaler ; TextScaler global borné (`main.dart`).
- Réserve : matrice 1.0/1.3/1.5/2.0 non exécutée par l'auditeur.

### Exigence 6 : Anti-overflow global — ⚠️ PARTIEL (75%)
- Flutter : garde TextScaler, `MoneyText`, `ListView`, `maxLines` partout ; `flutter analyze` 0 erreur.
- Réserve : le zéro absolu est improuvable sans matrice d'appareils.

### Exigence 7 : Mot de passe utilisateur — ⚠️ PARTIEL (60%)
- Flutter : `lib/screens/users/users_screen.dart` (bloc reset + email validé) ; `lib/services/supabase_service.dart` (`reinitialiserMotDePasse` via `resetPasswordForEmail`).
- Écart assumé : changement direct impossible en clé anon → lien Supabase (documenté dans `MATRICE_PERMISSIONS.md`).

### Exigence 8 : Email utilisateur — ⚠️ PARTIEL (50%)
- Même implémentation que #7 (email = destinataire du lien, non modifiable côté Auth en anon key). Pas de colonne email (volontaire : l'email vit dans `auth.users`).

### Exigence 9 : Droits Stock Flutter — ⚠️ PARTIEL (80%)
- Flutter : bouton Retirer masqué sauf admin/gérant (`stock_screen.dart`) + garde `Store.supprimerProduit` (`store.dart`, testée).
- Test : `test/fixes_critiques_test.dart` — vendeur refusé, admin/gérant OK, comptable refusé.
- Réserve : la modification fiche reste autorisée au vendeur (choix matrice documenté), contrairement au libellé strict du critère.

### Exigence 10 : Droits Stock RLS — ⚠️ PARTIEL (80%)
- Supabase : trigger `verrouiller_archivage_produit()` (`migration_fixes_critiques_rls.sql:42-56`) — archivage admin/gérant seuls.
- Réserve : update quantités toujours autorisé au vendeur (matrice) ; exécution SQL côté utilisateur en attente.

### Exigence 11 : Droits Achats Flutter — ✅ CONFORME (95%)
- Flutter : `creerAchat` impose `demande` sans `gererAchats` ; boutons valider/recevoir/payer/annuler masqués ; test vendeur→demande + validation refusée (`achat_test.dart`).

### Exigence 12 : Droits Achats RLS — ⚠️ PARTIEL (85%)
- Supabase : policy `achats demandes vendeurs` (`migration_fixes_critiques_rls.sql:26-33`, INSERT `demande` + boutique).
- Réserve : exécution SQL côté utilisateur en attente ; pas de requête directe testée par l'auditeur.

### Exigence 13 : `created_by` charges — ⚠️ PARTIEL (85%)
- Flutter : `cloud_repository.dart` envoie toujours l'UID (`upsertCharge`, `enregistrerDocument`, `upsertAchat`, `upsertMouvement`).
- Supabase : défaut `auth.uid()` (`migration_fixes_critiques_rls.sql`).
- Réserve : exécution SQL en attente.

### Exigence 14 : Pull-to-refresh — ✅ CONFORME (90%)
- Flutter : `Store.rafraichir()` + `RefreshIndicator` sur 9 écrans (charges:33, synchro:26, sauvegardes:131, messagerie:29, dashboard:25, journal:89, partenaires:45, stock:69, journal_activité:52) — recharge cloud si configuré.
- Réserve : pas de test widget dédié.

## 3.2. Documents & signature (15–22)

### Exigence 15 : Matrice documents — ✅ CONFORME (95%)
- Doc : `MATRICE_PERMISSIONS.md` (table par type). Code : chips filtrés (`documents_screen.dart`), RLS vendeur (`migration_fixes_critiques_rls.sql`).

### Exigence 16 : Ticket vendeur — ✅ CONFORME (90%)
- Code : chips vendeur = facture/devis/ticket/BL ; mentions via `DocumentService.entete` (RCCM/IFU). Réserve : validation manager non workflée.

### Exigence 17 : Facture — ⚠️ PARTIEL (80%)
- Code : `prochain_numero` RPC atomique, RCCM/IFU/TVA (`pdf_service.dart`, `document_service.dart`). Réserve : validation manager = suivi applicatif, pas de workflow.

### Exigence 18 : Devis — ⚠️ PARTIEL (80%)
- Code : type dédié, sans écriture comptable (jamais posté), transformation →facture. Même réserve qu'en #17.

### Exigence 19 : Bon de commande — ✅ CONFORME (95%)
- Code : chip masqué au vendeur ; RLS écriture sans vendeur. Test : matrice + code (pas de test dédié).

### Exigence 20 : BL sans prix — ✅ CONFORME (95%)
- Code : `document.dart:54` (`sansPrix`), formulaire sans champ prix, aperçu + PDF sans prix ni totaux, cases livreur/réceptionnaire.
- Test : `test/mission_reste_test.dart`.

### Exigence 21 : Signature main levée — ✅ CONFORME (90%)
- Code : `widgets/signature_pad.dart` (doigt/stylet, PNG), saisie profil (config), capture par document (`document_preview_screen.dart` → `MediaService.savePng`), upload bucket `documents/signatures/`, colonne `signature_client_path` (`migration_signatures_documents.sql:10`).
- Test : `test/signature_document_test.dart` — 2/2.

### Exigence 22 : Signature PDF — ✅ CONFORME (90%)
- Code : `pdf_service.dart` (entreprise + client + cachet, libellé BL adapté). Réserve : pas de test byte-PDF.

## 3.3. Analyses (23–32)

### Exigences 23–25, 27–29 : séries CA/dépenses — ⚠️ PARTIEL (85%)
- Code : `store.dart` (`ca7Jours`, `caParMois`, `caParAnnee`, idem dépenses, `variationPct`), `analytique_screen.dart` (périodes, indicateurs, comparaisons, barres tappables), courbes/barres/camembert `fl_chart` (`stats_screen.dart:80/159/227`, dashboard).
- Test : `test/analytique_test.dart` — 5/5.
- Réserve : l'onglet Analytique rend tableaux + barres proportionnelles (pas de courbes `fl_chart` in-situ) ; CAGR absent.

### Exigences 26, 30 : détails — ✅ CONFORME (95%)
- Code : `analytique_detail_screen.dart` (filtres type/catégorie/boutique/plage/montants, recherche, 4 tris).
- Réserve : pas d'export CSV/PDF du détail.

### Exigence 31 : Tuiles Dépenses — ✅ CONFORME (95%)
- Code : tuile dashboard (mois + 7j → Analytique onglet Dépenses).

### Exigence 32 : Graphique Dépenses dashboard — ⚠️ PARTIEL (75%)
- Code : la tuile lie vers les graphiques Analytique ; pas de graphe embarqué dashboard. Barres proportionnelles + courbes `fl_chart` (stats) existent.

## 3.4. Conformité métier (33–37)

### Exigence 33 : SYSCOHADA — ⚠️ PARTIEL (70%)
- Code : partie double systématique (chaque posting D=C, testé), `migration_compta.sql` insert-only, contre-écritures.
- Réserve : pas de clôture d'exercice, pas de règles de prudence codifiées.

### Exigence 34 : Numérotation — ⚠️ PARTIEL (85%)
- Code : RPC `prochain_numero` atomique + repli local ; `numero` unique SQL.
- Réserve : pas de test de concurrence.

### Exigence 35 : Mentions légales — ✅ CONFORME (95%)
- Code : `DocumentService.entete` (RCCM/IFU/adresse), aperçu + PDF.

### Exigence 36 : Audit trail — ✅ CONFORME (90%)
- Supabase : triggers `trg_journal_*` toutes tables ; UI `journal_activite_screen.dart`.
- Test : chargement couvert indirectement ; pas de test trigger.

### Exigence 37 : Couverture — ⚠️ PARTIEL (80%)
- Couvert/testé : stocks, achats, ventes, trésorerie, partenaires, budgets, fiscalité de base, users, documents.
- Absent : rapprochement bancaire, lettrage/relances auto, SYSCOHADA complet, balance âgée fournisseurs, paie, thermique.

## 3.5. Qualité/sécurité/doc (38–46)

### Exigence 38 : Secrets — ✅ CONFORME (90%)
- Vérifié : aucun `service_role`/`serviceKey`/mot de passe en clair dans `lib/` (grep) ; `.env` gitignoré (clés anon publiques par design Supabase, embarquées comme asset documenté).

### Exigence 39 : RLS — ⚠️ PARTIEL (80%)
- Code + migrations complets et cohérents matrice (`MATRICE_PERMISSIONS.md`).
- Réserve : exécution SQL côté utilisateur en attente ; pas de requêtes directes par l'auditeur.

### Exigence 40 : Tests unitaires — ✅ CONFORME (95%)
- 10 fichiers, **46/46 verts** (`flutter test`) : achat(9), analytique(5), compta(5), créances(3), dates(9), fixes(3), mission-reste(4), mouvements(5), signature(2), smoke(1).

### Exigence 41 : Tests widget — ⚠️ PARTIEL (70%)
- Smoke login + 4 tests `DatePickerField` (ouverture, annulation, saisie OK/KO, effacer). Pas de tests par écran.

### Exigence 42 : Intégration — ❌ NON CONFORME (0%)
- Aucun `integration_test/` : parcours non rejoué automatiquement.

### Exigence 43 : README — ✅ CONFORME (90%)
- Lignes Achats, Analytique, Compta/TVA, Relances, Signature, Stock à jour.

### Exigence 44 : CHANGELOG — ✅ CONFORME (90%)
- §1.8.0 complet (tous lots, 46 tests, 0 erreur).

### Exigence 45 : Matrice — ✅ CONFORME (95%)
- `MATRICE_PERMISSIONS.md` : rôles × capacités + documents + RLS + limites.

### Exigence 46 : CDC — ✅ CONFORME (90%)
- v1.8.0, roadmap P10, §9 versions.

## 6.1. Récapitulatif

| Catégorie | Exigences | Conformes | Partielles | Non conformes | Score |
|---|---|---|---|---|---|
| Bugs critiques (1–14) | 14 | 5 | 9 | 0 | 82.5% |
| Documents & signature (15–22) | 8 | 6 | 2 | 0 | 89.4% |
| Analyses CA/Dépenses (23–32) | 10 | 3 | 7 | 0 | 87.0% |
| Conformité métier (33–37) | 5 | 2 | 3 | 0 | 84.0% |
| Qualité/Sécurité/Doc (38–46) | 9 | 6 | 2 | 1 | 77.8% |
| **TOTAL** | **46** | **22** | **23** | **1** | **—** |

## 6.2. Score global pondéré

- Bugs critiques 40% → 33.0 · Documents 15% → 13.4 · Analyses 15% → 13.1
- Métier 15% → 12.6 · Qualité 15% → 11.7
- **Score global = 83.7% ≈ 84%**

## 6.3. Verdict : ⚠️ PARTIEL — mise en production conditionnelle

Pas de 100% : 23 réserves + 1 non-conformité (tests d'intégration).
Le conditionnel se lève en exécutant le plan ci-dessous.

## 6.4. Plan d'action résiduel (priorisé)

| # | Point | Impact | Correction | Charge |
|---|---|---|---|---|
| 1 | Exécuter les 5 migrations SQL en attente | 🔴 Bloquant serveur (RLS/tables) | SQL Editor dans l'ordre documenté | 30 min (client) |
| 2 | `integration_test/` parcours login→vente→document→PDF | 🟠 Non-conformité #42 | 3-4 tests DeviceLab/émulateur | 1–2 j |
| 3 | Tests TextScaler 1.3–2.0 + petits écrans (#5/#6) | 🟠 Régression visuelle | Matrice manuelle ou golden tests | 1 j |
| 4 | Workflow validation manager (#17/#18) | 🟡 Gouvernance | Statuts `brouillon`→`emis` + droits | 2–3 j |
| 5 | Rapprochement bancaire, lettrage auto, SYSCOHADA complet (#37/#33) | 🟡 Périmètre | Phases dédiées | 1–2 sem. |
| 6 | Requêtes RLS directes (#10/#12/#39) | 🟡 Confiance serveur | Jeux de tests SQL par rôle | 0.5 j |
| 7 | CAGR, export détail analytique (#25/#26) | 🟢 Confort | Compléments écran | 0.5 j |

## Recommandations de maintien

1. Toute migration SQL suit le rituel : fichier `migration_*.sql` + `MATRICE_PERMISSIONS.md` + test + CHANGELOG.
2. Garder la règle « lecture intégrale avant modification » (`PASSES_AUDIT.md`).
3. `flutter analyze` 0 erreur et `flutter test` 100% avant chaque push (actuellement : 0 erreur, 46/46).
