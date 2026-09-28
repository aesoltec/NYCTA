# PLAN DE DÉCOUPAGE DU STORE MONOLITHE — NYCTA / PME Gestion

> Date : 2026-09-28. `lib/data/store.dart` ≈ 3100 lignes.
> Stratégie : extraction de logique PURE testée (Phase 0), puis Notifiers
> par domaine avec façade Store compatible (Phases 1-5). À chaque phase :
> `flutter analyze` = 0 erreur, `flutter test` = 100 % vert, commit local
> (pas de push — directive active).

## Phase 0 — Services purs ✅ (cette phase)
`lib/data/services/` : `stock_service.dart`, `caisse_service.dart`,
`partage_service.dart`, `analytique_service.dart`, `compta_service.dart`.
Tests : `test/data/*_test.dart` (~50 tests). Store inchangé (non branché).

## Phase 1 — Notifiers autonomes
`SessionNotifier` (user/rôle/permissions), `BoutiqueNotifier`
(CRUD + siège + réouverture), `ProfileNotifier` (entreprise, TVA,
fonds, budgets), `CategorieNotifier` (produit/charge + listes
dynamiques + anti-doublon), `CollabNotifier` (messages, événements,
notes, feedbacks).

## Phase 2 — Notifiers métier simples
`ClientNotifier`, `FournisseurNotifier`, `PartenaireNotifier`
(clôture via PartageService), `ChargeNotifier`, `StockMouvementNotifier`.

## Phase 3 — Notifiers métier critiques
`ProduitNotifier` (CRUD + galerie + archivage), `TransactionNotifier`
(vente CRUD + encaissement + crédit), `AchatNotifier` (cycle complet +
CUMP via StockService), `DocumentNotifier` (workflow + numérotation).

## Phase 4 — Notifiers transverses
`ComptaNotifier` (journal immuable + contre-passations via
ComptaService), `AnalytiqueNotifier` (agrégats via AnalytiqueService).

## Phase 5 — Façade et nettoyage
`Store` réduit à une façade légère exposant les mêmes APIs
(composition des Notifiers, délégation pure). Suppression progressive
du monolithe. `store.dart` < 200 lignes.

## Règles
- Ne jamais supprimer de code fonctionnel avant l'équivalent branché.
- Chaque Notifier testable indépendamment (tests dédiés).
- 10 passes d'audit par phase (PASSES_AUDIT.md).
- Diagramme : Store (façade) → Notifiers → Services purs → Modèles.

## Frontières (vérifié Phase 1)
- Un service ne connaît PAS les Notifiers (fonctions statiques pures).
- `StockService` (calculs purs : CUMP, valorisation, quantités) vs
  futur `ProduitNotifier` (état liste + CRUD + cloud + notify).
- `ComptaService` (génération lignes + balance + résultat, rôle
  ÉCRITURE/lecture) vs futur `ComptaNotifier` (état journal + poster).
- `AnalytiqueService.tvaParMois` (LECTURE du journal) vs
  `ComptaService.lignesVente/lignesReception` (ÉCRITURE des 443/445) :
  distincts, non redondants.
- Cas limites Phase 0 déjà couverts : CUMP stock=0, partage taux 0/100,
  caisse solde négatif (vérifié, aucun ajout requis).
