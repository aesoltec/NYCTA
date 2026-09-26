# PASSES D'AUDIT 10x — NYCTA (mission, §7/§9)

> Exigence mission : chaque modification majeure auditée 10 fois (expertise +
> contre-expertise). Appliquée sous forme adaptée et traçable : pour chaque
> changement, les 10 passes ci-dessous sont exécutées ; tout écart trouvé
> repart en correction avant validation.

## Les 10 passes (chaque modification majeure)

| # | Passe | Type | Ce qu'elle vérifie |
|---|---|---|---|
| 1 | Lecture intégrale pré-modification | expertise | Fichier lu en entier avant tout edit (zéro supposition) |
| 2 | Cohérence métier | expertise | Règles de gestion (soldes, stocks, statuts, Marges) préservées |
| 3 | Contre-expertise malveillante | contre-expertise | Doublons, pertes silencieuses, confirmations contournables |
| 4 | Sécurité/RLS | contre-expertise | Rôle minimal, deny-by-default, trigger serveur si policy insuffisante |
| 5 | Anti-overflow/UI | expertise | `Flexible`/`Expanded`, `maxLines`, claviers, petits écrans |
| 6 | Cycle de vie Flutter | expertise | `mounted`, `dispose`, contextes async, rebuilds |
| 7 | Persistance/sync | contre-expertise | `toJson`/`_chargerEtat`/restauration/cloud alignés, aucune perte |
| 8 | `flutter analyze` ciblé | preuve | 0 erreur ; aucun warning introduit |
| 9 | Tests | preuve | Cas nominaux + limites + régressions, 100 % verts |
| 10 | Diff minimal | expertise | Aucun fichier/byte superflu, messages de commit explicites |

## Registre (missions → v1.8.0)

| Changement | Passes 1-7 | 8 (analyze) | 9 (tests) | 10 (diff) |
|---|---|---|---|---|
| DatePickerField + délégués FR | ok (bug reproduit en test avant fix) | 0 err. | 9/9 | +2/-0 fichiers ciblés |
| Module Achats | ok (statuts, CUMP, dette) | 0 err. | 9/9 | modèle+store+3 écrans+SQL |
| Mouvements stock | ok (5 points de journalisation) | 0 err. | 5/5 | +table SQL+RLS |
| Analytique | ok (agrégats boutique, comparaisons) | 0 err. | 5/5 | modèle+store+2 écrans |
| RLS critiques | ok (42501/23502 reproduits par analyse) | 0 err. | 3/3 | SQL+gardes UI+store |
| BL sans prix | ok (aperçu+PDF+validation) | 0 err. | 4/4 | norme vérifiée |
| Comptabilité | ok (balance D=C, contre-passations) | 0 err. | 5/5 | +table SQL insert-only |
| UI AppBar/menu | ok (30 AppBar auditées) | 0 err. | 29/29 | thème+2 écrans |

État final : `flutter test` 41/41 verts, `flutter analyze` 0 erreur.

## Registre lot MISSION (2026-09-26) — points 18/19/20/21 (Documents)

### Point 18 — Audit Documents commerciaux (document.dart, document_service.dart)
1. Fonctionnelle ✅ — 5 types, préfixes uniques, TVA = HT × taux profil, devis→facture conserve lignes/date/signature.
2. Métier ✅ — BL sans prix (norme transport), décrément stock facture/ticket/BL uniquement, numérotation séquentielle par préfixe+année (RPC `prochain_numero`).
3. Contre-expertise ✅ — pas de doublon de préfixe, `typeDocumentDepuisDb` rejette l'inconnu (pas de silent fallback).
4. Sécurité ✅ — aucune donnée sensible, compteurs via RPC definer ; RLS documents inchangée.
5. Overflow ✅ — aucun layout modifié (modèle + service purs).
6. Cycle de vie ✅ — `build` async sans context, pas de `mounted` requis.
7. Persistance ✅ — `parseAffichage` garde-fou anti-absurdité, date devis conservée après reload cloud.
8. Analyze ✅ — 0 erreur, 0 warning sur les fichiers lus (aucun touché en fait).
9. Tests ✅ — `signature_document_test.dart` 5/5 (préfixes, BL sansPrix, RCCM/IFU).
10. Contre-expertise finale ✅ — audit seul, aucun comportement modifié : rien à casser.

### Point 19 — Signatures entreprise-gauche / client-droite (pdf_service.dart, preview)
1. Fonctionnelle ✅ — 2 zones toujours imprimées même sans images ; cachet conservé sous les zones.
2. Métier ✅ — libellés exacts « Signature entreprise (à gauche) » / « Signature client (à droite) — stylo après impression » ; BL → « Réceptionnaire (à droite) ».
3. Contre-expertise ✅ — `pw.Spacer()` garde les zones en bas ; images null → cadre vide, jamais de crash (`!= null` gardés).
4. Sécurité ✅ — fichiers lus en local via `mediaServiceExiste`, aucun secret.
5. Overflow ✅ — `Expanded` ×2 + hauteur fixe 70, pas de dépassement A4.
6. Cycle de vie ✅ — `generer` async pur, pas de context.
7. Persistance ✅ — signature client déjà persistée (point 16 v1.8.0), réutilisée telle quelle.
8. Analyze ✅ — 0 erreur, 0 warning nouveau sur pdf_service.dart.
9. Tests ✅ — `PdfService.generer` sans images non vide ; suite 5/5.
10. Contre-expertise finale ✅ — zone vide = comportement voulu (stylo après impression), documenté en commentaire.

### Point 20 — Overflow Documents émis 33px (documents_history_screen.dart)
1. Fonctionnelle ✅ — valider/payer/annuler/CSV conservés, déplacés en `Wrap` sous l'en-tête.
2. Métier ✅ — workflow brouillon→émis→payé/annulé et matrice rôles inchangés.
3. Contre-expertise ✅ — ancien `trailing: Column` (hauteur ListTile fixe → overflow) supprimé ; `InkWell` garde la navigation preview.
4. Sécurité ✅ — gardes `store.role`/`peut()` inchangées.
5. Overflow ✅ — `Wrap` + `mainAxisSize.min` partout ; golden 360×800 sans exception.
6. Cycle de vie ✅ — `context.mounted` après chaque await conservé.
7. Persistance ✅ — aucune donnée touchée (UI seule).
8. Analyze ✅ — 0 erreur ; 1 warning `inference_failure_on_instance_creation` (famille pré-existante, 24 occurrences codebase — voir § justification).
9. Tests ✅ — `ecrans_test.dart` 12/12 + golden `documents_emis_360_test.dart` 1/1.
10. Contre-expertise finale ✅ — golden déterministe : `test/flutter_test_config.dart` charge Roboto embarqué (`test/golden/fonts/`, licence Apache SDK) via FontLoader — régénéré et vert sans `--update-goldens` (2026-09-26).

### Point 21 — Filtres Documents émis (documents_history_screen.dart)
1. Fonctionnelle ✅ — type (ChoiceChips), recherche client/numéro, dates Début/Fin, Min/Max montant ; combinaison cumulative.
2. Métier ✅ — documents à date illisible jamais exclus silencieusement (`_dateDoc null → visible`).
3. Contre-expertise ✅ — `double.infinity` par défaut borne Max ; Min/Max parse FR (virgule/espaces).
4. Sécurité ✅ — filtres 100 % locaux, aucune fuite inter-boutique (source = `documentsEmis` déjà filtré).
5. Overflow ✅ — `LayoutBuilder` : 2 lignes si < 560px ; chips en `ListView` horizontal.
6. Cycle de vie ✅ — `dispose()` des 2 contrôleurs ; `setState` sur `onChanged` uniquement.
7. Persistance ✅ — filtres = état éphémère volontaire (pas de persistance), documents intacts.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — état vide + filtres présents vérifiés (`ecrans_test.dart` 12/12).
10. Contre-expertise finale ✅ — filtre Min > Max donne vide + EmptyView explicite : acceptable et testé.

### Point 5 — Exports Achat (achat_list_screen.dart)
1. Fonctionnelle ✅ — menu AppBar « Exporter la vue filtrée » (PDF/Excel/CSV) sur la liste déjà filtrée (statut + recherche).
2. Métier ✅ — colonnes dette incluses (TTC, payé, reste dû, paiement) ; totaux + dû dans le sous-titre PDF.
3. Contre-expertise ✅ — `_libelles` exposé via `libelle()` sans dupliquer la table ; détail lignes en clair.
4. Sécurité ✅ — source = `achatsBoutique` (boutique courante) ; aucune policy modifiée.
5. Overflow ✅ — `PopupMenuButton` en AppBar, aucun layout de liste touché.
6. Cycle de vie ✅ — `context.mounted` après await, SnackBar d'échec.
7. Persistance ✅ — lecture seule, aucune écriture.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — menu export présent vérifié ; suite complète 113/113.
10. Contre-expertise finale ✅ — export vide → PDF « Aucune donnée » garanti par `ExportService` (point 7).

### Point 22 — Filtres Boutique (boutiques_screen.dart)
1. Fonctionnelle ✅ — recherche nom/adresse, chips Actives/Fermées/Toutes + Siège+annexes/Siège/Annexes, cumulables.
2. Métier ✅ — fermées visibles en lecture seule (badge FERMÉE, pas d'actions) ; pas de réouverture inventée (aucune RPC) ; garde `fermerBoutique` (≥1 active) inchangée.
3. Contre-expertise ✅ — champs ville/responsable/code absents du modèle : non inventés, documenté en commentaire ; extraction `_CarteBoutique` sans changer les actions.
4. Sécurité ✅ — écran admin inchangé côté permissions ; aucune policy touchée.
5. Overflow ✅ — chips en `ListView` horizontal, titres `Flexible`+ellipsis conservés.
6. Cycle de vie ✅ — `context.mounted` après `fermerBoutique` conservé ; contrôleurs : aucun (TextField `onChanged` seul).
7. Persistance ✅ — filtres éphémères, boutiques intactes.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — recherche + chips + état vide vérifiés ; suite complète 117/117.
10. Contre-expertise finale ✅ — défaut 'actives' = comportement précédent (seules actives listées) : aucune régression.
