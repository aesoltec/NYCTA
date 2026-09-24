# AUDIT PHASE 0 — NYCTA / pme_gestion_pro

> Rapport généré le 2026-09-24. Aucune modification de code à cette phase.
> Méthode : lecture directe des fichiers + `flutter analyze` + `flutter test` + `flutter pub outdated`.

## 0.1. Cartographie de `lib/` (~72 fichiers Dart)

### `lib/core/` (5)
- `main.dart` (racine) : bootstrap, locale fr_FR via `intl`, `MaterialApp` sans `localizationsDelegates` ni `supportedLocales` (voir §0.2).
- `core/env.dart` : lecture `.env` avec fallbacks.
- `core/theme.dart` : design system pro (encre `#0F172A`, menthe `#10B981`).
- `core/constants.dart` : libellés/icônes/couleurs par `TypeTransaction`, listes par défaut.
- `core/validators.dart` : validateurs universels (`prix`, `entier`, `entierFacultatif`, `pourcent`, `telephone`, `email`, `texte`).
- `core/secure_session.dart` : session chiffrée (keystore).

### `lib/data/` (1, 2012 lignes)
- `data/store.dart` : état global `Provider` (god-object) : profil, boutiques, produits, transactions, partenaires, charges, documents, catalogue, collab, file offline, persistance locale. `dispose()` annule le timer de persistance.

### `lib/models/` (15)
`app_user`, `boutique`, `charge`, `client`, `company_profile`, `document` (+ `TypeDocument` : facture, devis, bon de commande, ticket, **bon livraison**), `enums` (7 rôles, 10 permissions, matrice), `evenement` (+ `Note`), `feedback`, `fournisseur`, `message`, `partage`, `partenaire`, `produit`, `tarif`, `transaction` (`TypeTransaction` : prestation, **venteMateriel**, mobileMoney, creditCommunication, forfaitHotspot — **pas de type `achat`**).

### `lib/services/` (10)
- `supabase_service.dart` : init client, connexion, RPC `clotuler_partage`, upload `media`, lecture/écriture `company_profile`.
- `cloud_repository.dart` (562 lignes) : chargement cloud + écritures directes (produits, charges, transactions, partenaires, users, boutiques, catégories, clients, collab, feedbacks, tarifs, documents+lignes, sauvegardes, journal), RPC `prochain_numero`, `sauvegarder_base`, `restaurer_base`.
- `sync_service.dart` : file Hive offline-first (insert transactions, upsert autres tables).
- `local_persistence.dart`, `backup_service.dart` (CSV/JSON), `pdf_service.dart` (+ archive bucket `documents`), `document_service.dart` (construction, `parseAffichage`), `media_service.dart`, `notification_service.dart`, `api_service.dart` (REST Node optionnel, `TODO P7` : token non persisté en secure storage).

### `lib/widgets/` (8, réutilisables)
`soft_card`, `money_text` (anti-overflow), `empty_view`, `type_chip`, `app_image`, `signature_pad`, `section_header`, `date_selector` (`ChampDate`, voir §0.2).

### `lib/screens/` (32 écrans + shell)
| Écran | Accès | Statut |
|---|---|---|
| `login/login_screen.dart` (+ `CloudLoader`) | public | fonctionnel |
| `shell/app_shell.dart` (5 onglets : Accueil, Journal, Stock, Dépenses, Plus) | tous sauf partenaire | fonctionnel |
| `dashboard/dashboard_screen.dart` | `vendre` (tuiles) | fonctionnel ; **pas de tuile Achat** |
| `transaction/nouvelle_transaction_screen.dart` | `vendre` | fonctionnel (5 types, `ChampDate`) |
| `journal/journal_screen.dart` | tous | fonctionnel |
| `stock/stock_screen.dart` | `gererStock`/`vendre` | fonctionnel (vente + `ChampDate`) |
| `charges/charges_screen.dart` | `gererDepenses` | fonctionnel (`ChampDate`) |
| `partenaires/partenaires_screen.dart` | `gererPartenaires`/`cloturerMois` | fonctionnel |
| `partenaire/partner_home_screen.dart` | rôle partenaire | fonctionnel (`ChampDate`) |
| `tresorerie/`, `rapports/`, `stats/` | `voirCaisse`/`voirRapports` | fonctionnels (rapports existants : CA/marge, MoMo, boutiques, CA/jour ; **pas d'analytique 7j/mois/années filtrable**) |
| `documents/`, `documents_history/`, `document_preview/` | `gererDocuments` | fonctionnels (5 types, PDF, CSV) |
| `tarifs/`, `admin/boutiques|clients|categories|listes_dynamiques`, `users/` | ciblés par permission | fonctionnels |
| `collab/` (messagerie, evenements, notes, fournisseurs, feedbacks) | mixte | fonctionnels ; **evenements + notes utilisent `showDatePicker` brut** (voir §0.2) |
| `config/` (config, sauvegardes, synchronisation, journal_activite) | `configurer`/admin | fonctionnels |
| `backup/`, `menu/` | — | fonctionnels |

Navigation : pas de routes nommées (`routes.dart` absent) — `Navigator.push(MaterialPageRoute)` direct + `NavigationBar` 5 destinations + menu « Plus » filtré par permissions. Aucun écran orphelin détecté.

## 0.2. Diagnostic sélecteur de date (CRITIQUE)

Appels recensés :
- `widgets/date_selector.dart:38` (`ChampDate`) — utilisé par 5 formulaires : `charges_screen.dart:307`, `nouvelle_transaction_screen.dart:150`, `stock_screen.dart:145`, `partner_home_screen.dart:106`, `documents_screen.dart:49`. Paramètres sains : `initialDate` clampée dans `[firstDate, lastDate]`, `firstDate: 2020-01-01`, `lastDate` = aujourd'hui (ou +2 ans si futur autorisé), `locale: fr-FR`.
- `collab/evenements_screen.dart:125` — `showDatePicker` brut : `initialDate: date` **non clampée** (date existante potentiellement hors plage ±), pas de `locale`, plage -365j/+3 ans.
- `collab/notes_screen.dart:179` — `showDatePicker` brut : `initialDate: rappel ?? now()`, `firstDate: now()-1j` (**rappel existant plus vieux = hors plage**), pas de `locale`.

Cause racine la plus probable de la page blanche :
1. **`MaterialApp` sans `localizationsDelegates` ni `supportedLocales`** (`main.dart:47`) ET **`flutter_localizations` absent du `pubspec.yaml`** (seul `intl: ^0.19.0` déclaré). Le `locale: fr-FR` passé au picker ne peut pas être résolu → comportement indéfini/écran vide selon plateforme. `initializeDateFormatting('fr_FR')` ne couvre que `intl`, pas les délégués Material.
2. Secondaire : `initialDate` hors `[firstDate, lastDate]` sur les 2 pickers bruts (notes surtout) → assertion/refus d'affichage.
3. Pas de fallback manuel JJ/MM/AAAA, pas de `DatePickerField` unifié, pas de tests du picker (un seul `test/widget_test.dart` : démarrage).

## 0.3. Modules métier

| Module | État | Remarques |
|---|---|---|
| Forfait / crédit / prestation / MoMo / matériel (vente) | présents | 5 `TypeTransaction`, formulaires validés, marge négative confirmée |
| Dépenses/charges, budgets, trésorerie | présents | récurrentes auto, fonds de roulement |
| Stock | présent | décrément vente + documents, alerte seuil, catalogue auto-sync |
| Partenaires + clôture | présent | RPC atomique anti-double |
| Documents (5 types) + PDF/CSV + historique | présents | `bon_livraison` ajouté côté app ; migration enum fournie |
| Clients, fournisseurs, tarifs, catégories, listes dynamiques | présents | CRUD + RLS |
| Collab, feedbacks, users, sauvegardes, journal, sync offline | présents | — |
| **Achats (réapprovisionnement, dette fournisseur)** | **absent** | aucun modèle, aucun écran, aucune tuile ; seule la vente de matériel existe |
| **Matériel (immobilisations, amortissement, maintenance, cession)** | **absent** | `venteMateriel` = simple sortie de stock ; pas de cycle de vie |
| Analytique CA/dépenses 7j/mois/années filtrable | absent | rapports agrégés simples uniquement |
| Rapprochement bancaire, lettrage, plan SYSCOHADA, balance âgée, TVA déclarative | absents | TVA = taux simple sur documents |

## 0.4. UI/UX

Design system centralisé (`core/theme.dart`) appliqué ; `SoftCard`/`MoneyText`/`EmptyView`/`TypeChip` uniques ; anti-overflow global (TextScaler ≤115 %). Navigation homogène (push + bottom nav + menu permissionné). Pas de doublon d'écran. Dette : conteneurs artisanaux résiduels codés en dur dans quelques écrans (cartes collab), snackbars à emoji.

## 0.5. Qualité (brut)

- `flutter analyze` : **0 erreur**, 50 warnings, 41 infos (total 91). Familles dominantes : `inference_failure_on_*` (MaterialPageRoute/showDialog/showModalBottomSheet/rpc sans types explicites), `prefer_const_constructors`, `use_build_context_synchronously` (`app_shell.dart:70`, `stock_screen.dart:384-385,393`).
- `flutter test` : **1/1 vert** (`test/widget_test.dart`, écran de connexion).
- `TODO/FIXME/print` : 1 seul (`api_service.dart:10`, token non persisté) ; `debugPrint`used pour logs (conforme).
- `flutter pub outdated` : 11 dépendances verrouillées en retard (`intl` résolu 0.20.3 vs contraint `^0.19.0` — à aligner en Phase 1 car lié au fix locale ; `fl_chart` 0.68→1.2.0, `flutter_local_notifications` 17→22, `signature` 5→6, `flutter_lints` 3→6 : montées majeures à risque, à planifier).

## Décisions pour Phase 1

1. Ajouter `flutter_localizations` (SDK) + délégués + `supportedLocales` fr/en dans `MaterialApp`.
2. Unifier les 3 pickers sous un `DatePickerField` robuste (clamp, fallback manuel JJ/MM/AAAA validé, tests widget).
3. Aligner `intl` sur la version résolue compatible avant de toucher au reste.
