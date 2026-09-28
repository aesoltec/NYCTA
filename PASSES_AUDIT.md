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

### Point 23 — Recherche Catégories (categories_screen.dart)
1. Fonctionnelle ✅ — recherche nom insensible à la casse, par onglet ; renommer/supprimer inchangés.
2. Métier ✅ — filtre par type = onglets existants (Produits/Charges) ; anti-doublon et garde-fou suppression préservés.
3. Contre-expertise ✅ — statut/parent/code absents du modèle (listes de `String`) : non inventés, tracé en commentaire ; refactor Stateless→Stateful sans changer les actions.
4. Sécurité ✅ — écran admin, aucune policy touchée.
5. Overflow ✅ — `Column` + `Expanded`, recherche fixe en haut, `ellipsis` conservés.
6. Cycle de vie ✅ — aucun contrôleur, `context.mounted` existants intacts.
7. Persistance ✅ — lecture seule (`catsProduit`/`catsCharge`), écritures via store inchangées.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — onglets + recherche + état vide vérifiés ; suite complète 118/118.
10. Contre-expertise finale ✅ — recherche vide = liste complète (comportement précédent) : aucune régression.

### Point 24 — Audit formulaire de vente (nouvelle_transaction_screen.dart, journal_screen.dart)
Conformes sans changement : montant > 0 + dropdowns requis (`V.prix`, validateurs), crédit→client nommé, marge négative confirmée, `_comptabiliserVente` auto (partie double), RLS insert vendeur/caissier, TextScaler borné 0.9–1.15, TVA au niveau document (transactions en TTC — design assumé).
Écarts corrigés :
- E1 Mode de paiement absent (exigé §3.12) → dropdown Espèces/Mobile Money/Crédit/Virement (défaut Espèces), persisté `details['modePaiement']`, affiché au journal + export.
- E2 Remise absente → champ optionnel, net = brut − remise persisté (`montantBrut`, `remise`), refus si remise ≥ brut, ré-édition restaure brut+remise (idempotent).
- E3 `setState(_busy)` après dialogue marge sans garde → `if (confirme != true || !mounted) return`.
1. Fonctionnelle ✅ — création + modification (brut restauré) vérifiées par tests.
2. Métier ✅ — net enregistré = encaissé réel ; marge = net − coût ; compta auto sur le net.
3. Contre-expertise ✅ — ventes antérieures (clés absentes) : suffixes vides, montant inchangé ; remise ≥ brut refusée avant tout await.
4. Sécurité ✅ — aucune policy touchée ; rôles vendeur/caissier déjà couverts côté RLS.
5. Overflow ✅ — 2 champs ajoutés dans le `ListView` existant, CTA en `bottomNavigationBar`.
6. Cycle de vie ✅ — E3 corrigé ; `dispose()` du contrôleur remise ; `mounted` après `ajouterTransaction`.
7. Persistance ✅ — détails JSON (pas de migration SQL) ; `copyWith` conserve details en modification.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `vente_form_test.dart` 6/6 (suffixes, libellés, refus remise, net persisté) ; suite 124/124.
10. Contre-expertise finale ✅ — remise vide = comportement précédent à l'euro près (net = brut).

## Décisions d'architecture (validées 2026-09-26)
- **ExportService non générique** : refus du refactor `<T>` en pleine mission (risque de régression sur 8 modules verts > gain nul côté métier). Le service actuel (PDF/Excel/CSV, BOM/`;`, vue filtrée/Tous) couvre le besoin. Décision validée.
- **FiltrePanel commun** : extraction prévue AU point 25 (engagement tracé en MISSION_STATUS 25bis). Les écrans verts existants ne seront pas réécrits ; le panel servira aux points 25-36.
- **Onglets Catégories mutuellement exclusifs** : Produits OU Charges (jamais les deux) — le filtre par type est l'onglet lui-même, la recherche s'applique à l'onglet actif uniquement.

### Point 25bis — FiltrePanel commun (widgets/filtre_panel.dart)
1. Fonctionnelle ✅ — 5 kinds (recherche, chips, dropdown, dates, min/max), map émise à chaque changement, valeurs initiales.
2. Métier ✅ — aucune règle métier (pur UI), clés dates/minMax préfixées.
3. Contre-expertise ✅ — `_emettre` envoie une copie (pas l'état interne) ; `dispose()` des contrôleurs.
4. Sécurité ✅ — aucun accès données, aucune policy.
5. Overflow ✅ — dates empilées < 560px (`LayoutBuilder`), chips en scroll horizontal, test 360px.
6. Cycle de vie ✅ — `initState` copie les valeurs, `setState`+émission atomiques.
7. Persistance ✅ — état éphémère volontaire.
8. Analyze ✅ — 0 erreur, 0 warning.
9. Tests ✅ — `filtre_panel_test.dart` 3/3 (callbacks, 360px, clés préfixées).
10. Contre-expertise finale ✅ — valeurs parent non resynchronisées après init : acceptable (le panel est la source qui émet).

### Point 25 — Filtres Achat (achat_list_screen.dart)
1. Fonctionnelle ✅ — période Début/Fin ajoutée (pièce manquante du §3.13) ; statut+recherche conservés via panel.
2. Métier ✅ — fin inclusive (23:59:59) ; export point 5 réutilise la même `liste` filtrée.
3. Contre-expertise ✅ — migration vers panel sans changer libellés/options (tests inchangés verts).
4. Sécurité ✅ — inchangée (lecture boutique, écriture rôles achats).
5. Overflow ✅ — panel responsive ; régression textscale 320@1.5x détectée et corrigée à la racine (`EmptyView` scrollable).
6. Cycle de vie ✅ — map `_filtres` immuable remplacée (`setState`), pas de mutation.
7. Persistance ✅ — lecture seule.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `ecrans_test` (menu export + recherche) + `textscale` 32/32 ; suite 128/128.
10. Contre-expertise finale ✅ — export « Tous » ignore les filtres par design (nom + sous-titre l'indiquent).

### Point 26 — Fournisseurs (fournisseurs_screen.dart)
1. Fonctionnelle ✅ — recherche nom/tél/spécialité + dropdown spécialités distinctes + exports 3 formats.
2. Métier ✅ — spécialités construites des données (pas de référentiel inventé) ; formulaire CRUD intact.
3. Contre-expertise ✅ — dropdown vide si aucune spécialité (menu « Toutes » seul) : pas de crash.
4. Sécurité ✅ — lecture globale pré-existante, écriture collaborateurs (matrice inchangée).
5. Overflow ✅ — panel + carte existante (ellipsis, `mainAxisSize.min`).
6. Cycle de vie ✅ — `context.mounted` sur export, `ctx.mounted` formulaire intacts.
7. Persistance ✅ — lecture seule pour filtres/export.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — nouveau test widget (recherche + dropdown + export + vide) ; suite 128/128.
10. Contre-expertise finale ✅ — vide initial (« Aucun fournisseur… » remplacé par vide filtré explicite) : formulé sans ambiguïté.

### Point 27/28/29 — Clients (client.dart, store.dart, cloud_repository.dart, clients_screen.dart, SQL)
1. Fonctionnelle ✅ — recherche + filtre Pro/Particulier + formulaire étendu + exports ; CRUD existant (anti-doublon) intact.
2. Métier ✅ — `estPro` = RCCM renseigné ; logo optionnel (bucket `media` existant, pas de nouveau bucket) ; RIB/RCCM textes libres (pas de format national imposé — non inventé).
3. Contre-expertise ✅ — `fromJson` rétrocompatible (anciennes sauvegardes sans clés) ; upsert avec repli si base non migrée ; `logoPath` null-safe (`MediaService.existe`).
4. Sécurité ✅ — table `clients` existante, RLS inchangée ; logo via bucket `media` (policies existantes).
5. Overflow ✅ — FiltrePanel + carte (badge PRO, `Flexible`, 2 lignes sous-titre) ; formulaire en `ListView` bottom-sheet.
6. Cycle de vie ✅ — `dispose()` ajouté (manquait pour les 3 contrôleurs d'origine) ; `context.mounted` conservés.
7. Persistance ✅ — modèle + toJson + 2 loaders + cloud upsert + migration SQL idempotente + `apply_all` régénéré.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `clients_test.dart` 6/6 (rétrocompat, estPro, roundtrip, persistance store, liste, formulaire) ; suite 134/134.
10. Contre-expertise finale ✅ — filtre « Professionnels » vide si aucun RCCM : EmptyView explicite, pas de confusion.

### Point 30 — Comptabilité : analyse pré-codage + branchement (store.dart)
État actuel relevé : générateurs VT/BQ/AC/OD + `_contrePasser` + `_poster` existants ; journal/balance/résultat/TVA/âgée affichés ; RLS insert-only + pointage OK.
Branchements vérifiés : création vente ✅, suppression vente ✅, création/correction charge ✅, validation (sans poste — engagement, correct) ✅, réception ✅, paiement ✅, annulation ✅, encaissement BQ ✅.
Écarts corrigés :
- E1 `majTransaction` sans contre-passation → journal faux après modification : contre-passe + re-comptabilise.
- E2 `supprimerCharge` sans contre-passation (asymétrie vente) : contre-passe ajoutée.
- E3 `payerAchat` postait la caisse 2× (OD charge + BQ paiement) : OD supprimé (la Charge reste en trésorerie).
Décisions SYSCOHADA (ADR) : documents commerciaux ne postent PAS (évite double-compte vente+facture — la comptabilité naît des flux) ; TVA ventilée HT/TVA du profil sur VT ; annulation achat = remise à zéro nette (commentaire corrigé, il contredisait le code).
1. Fonctionnelle ✅ — 7 tests par flux (vente, modif, suppression, charge, achat complet, annulation, invariant global D=C).
2. Métier ✅ — partie double vérifiée par test sur chaque générateur ; balance D=C.
3. Contre-expertise ✅ — contre-passe inverse TOUT l'historique refId puis re-poste : net = état courant, jamais de trou.
4. Sécurité ✅ — aucune policy touchée (insert-only pré-existant respecté).
5. Overflow ✅ — store pur, aucun layout.
6. Cycle de vie ✅ — awaits séquentiels après notify, pas de context.
7. Persistance ✅ — `_poster` → cloud + file ; contre-passations persistées idem.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `compta_test.dart` 7/7 ; suite 141/141.
10. Contre-expertise finale ✅ — démo seed sans écritures : journal vide au démarrage = normal (seules les opérations postent).

### Point 31 — Comptabilité exports + filtres (compta_screen.dart)
1. Fonctionnelle ✅ — journal sur FiltrePanel (chips journaux + recherche + période Début/Fin, chip Non rapprochées conservé) + exports journal/balance 3 formats.
2. Métier ✅ — fin inclusive ; balance exportée en D/C par compte ; rapprochement (appui long) intact.
3. Contre-expertise ✅ — libellés/options identiques (test adapté a minima) ; export balance sur `entrees` triées.
4. Sécurité ✅ — gardes rapprochement inchangées.
5. Overflow ✅ — panel + ligne filtre/export en `Row`+`Spacer` ; `dense:true` conservé.
6. Cycle de vie ✅ — `context.mounted` exports + `_pointer` intacts.
7. Persistance ✅ — lecture seule.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — journal + balance (navigation onglet — TabBarView paresseux pris en compte) ; suite 141/141.
10. Contre-expertise finale ✅ — périodes sans écritures → EmptyView + PDF « Aucune donnée » (garantie service).

### Point 32/33 — Statistiques (stats_screen.dart)
1. Fonctionnelle ✅ — type + période (défaut 30 j), seaux jour/semaine/mois, indicateurs/caisse par type/exports 3 formats.
2. Métier ✅ — fin inclusive ; moyenne = total/nb jours ; marge = Σ(montant−coût).
3. Contre-expertise ✅ — `ventesFiltrees`/`serie` statics testables ; partenaires mensuels hors périmètre filtre (noté).
4. Sécurité ✅ — `txBoutique` (boutique courante) uniquement.
5. Overflow ✅ — panel + graphiques à hauteur fixe + legends `ellipsis`.
6. Cycle de vie ✅ — aucun contrôleur, map remplacée.
7. Persistance ✅ — lecture seule.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `stats_test.dart` 3/3 (filtre, seaux, écran) ; suite 141/141.
10. Contre-expertise finale ✅ — période vide → graphiques « Pas de données » + totaux à 0, pas de crash (division protégée).

### Point 34/35/36 — Tarifs & articles (tarif.dart, store.dart, cloud_repository.dart, tarifs_screen.dart, SQL)
1. Fonctionnelle ✅ — FiltrePanel (recherche + catégorie), Autocomplete connecté, création auto, galerie max 05 + vignette.
2. Métier ✅ — anti-doublon casse+accents (`sansAccents`/`memeCategorie`) sur catégories ET libellés articles ; canonique conservé ; création catégorie APRÈS succès article (jamais d'orpheline).
3. Contre-expertise ✅ — `_memeLibelle` (produits/partenaires) inchangé (hors périmètre) ; `majTarif` conserve images via formulaire ; upsert avec repli base non migrée.
4. Sécurité ✅ — bucket `produits` partagé (policies existantes) ; aucune RLS touchée.
5. Overflow ✅ — panel + `Autocomplete` overlay + galerie horizontale 76px.
6. Cycle de vie ✅ — contrôleurs disposés ; `mounted` après awaits ; `pickImages` max restant.
7. Persistance ✅ — modèle + payload + toJson + 2 loaders + cloud + SQL idempotent + `apply_all` régénéré.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `tarifs_test.dart` 7/7 (accents, dedup, roundtrip, liste, formulaire+Autocomplete) ; suite 148/148.
10. Contre-expertise finale ✅ — table parallel-strings remplacée par `Map` explicite après échec test (`Alectricite`) : le test a fait son travail.

### Point 37 — Menu « Plus » thématique (menu_screen.dart)
1. Fonctionnelle ✅ — 11 sections (Ventes, Achats, Stock, Finances, Comptabilité, Partenaires, Documents, Rapports, Configuration, Administration, Collaboration) + tuiles réordonnées selon le flux métier.
2. Métier ✅ — ordre = flux vente → achat → stock → finance → compta → partenaires → documents → rapports → config → admin → collaboration ; permissions inchangées par tuile.
3. Contre-expertise ✅ — tuiles déplacées sans duplication (grep : 1 occurrence par destination) ; nouvelles tuiles Stock/Mouvements/Charges avec permissions cohérentes.
4. Sécurité ✅ — aucune permission modifiée (mêmes gardes `peut()`/rôle).
5. Overflow ✅ — `_Section` en `Text` borné (11.5px, letterSpacing) ; tuiles `Material`+`ListTile` existantes ; test 360px.
6. Cycle de vie ✅ — aucun contrôleur ajouté.
7. Persistance ✅ — aucune donnée.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — 11 sections + tuiles + 360px vérifiés (scrollUntilVisible pour sections basses) ; suite 150/150.
10. Contre-expertise finale ✅ — « Prestations/Mobile Money/Crédit/Forfait » de la spec = le Journal (toutes activités) : pas de sous-écrans inventés (ils n'existent pas).

### Point 22bis — Réouverture boutique (store.dart, cloud_repository.dart, boutiques_screen.dart, SQL)
1. Fonctionnelle ✅ — `rouvrirBoutique` (garde admin/gérant locale + RPC) + bouton « Réouvrir » sur carte fermée.
2. Métier ✅ — miroir de la policy UPDATE (admin/gérant) ; boutique déjà active → refus ; historique conservé (soft delete).
3. Contre-expertise ✅ — RPC SECURITY DEFINER avec garde serveur (le vendeur ne peut pas passer par la policy) ; idempotente.
4. Sécurité ✅ — double garde (locale + serveur) ; aucune policy RLS modifiée.
5. Overflow ✅ — IconButton 20px dans trailing existant.
6. Cycle de vie ✅ — `context.mounted` après await.
7. Persistance ✅ — cloud RPC + pas de file locale (boutiques gérées par cloud).
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `boutique_reouverture_test.dart` 4/4 (refus vendeur, déjà active, introuvable, bouton visible admin) ; suite 154/154.
10. Contre-expertise finale ⚠️ — RÉSERVE : la RPC `reouvrir_boutique` doit être exécutée sur le Supabase réel (fichier `database/22bis_reouvrir_boutique.sql`, regroupé dans `SUPABASE_A_EXECUTER.sql`) — blocage matériel classé (accès service_role). Sans elle, le bouton échoue silencieusement côté production (le code local est testé et vert).

### Points 22ter / 23bis — Hors périmètre v1 (CDC §8bis)
- 22ter (ville/responsable/code) : aucun flux actuel n'exige ces champs ; non inventés, tracés au CDC comme « à valider avec le métier ».
- 23bis (catégories String → table) : la table SQL `categories` existe (v1.2) ; le modèle Dart reste des listes de String volontairement (seed + listes dynamiques) ; migration à planifier hors mission.

### Plan de correction totale (2026-09-28) — enrichissements A2/A3/A5-A7/A9/A13/A14
Contexte : audit d'écarts entre le plan de correction et l'état du code.
1. Fonctionnelle ✅ — ExportService enrichi (protection formules, en-tête entreprise/date/filtres, `enteteEntreprise`) ; LigneAchat.images (max 5) + galerie formulaire ; Stock/Charges/Trésorerie sur FiltrePanel (+ stock bas, récurrente) ; Achats (intervalles 7j/30j/mois/année + fournisseur) ; Documents (filtre statut + export historique) ; Clients (IFU + filtre crédit) ; Listes dynamiques (recherche).
2. Métier ✅ — catégorie achat / boutique mono-courante / filtre type mouvement : déclarés non applicables (modèles sans référentiel) au lieu d'être inventés.
3. Contre-expertise ✅ — API ExportService rétrocompatible (paramètres optionnels) ; JSON lignes d'achat rétrocompatible (clé absente → []) ; SQL idempotent + `apply_all` régénéré.
4. Sécurité ✅ — aucune policy touchée (colonnes + RPC déjà tracée).
5. Overflow ✅ — golden Documents régénéré (nouveaux chips) ; FiltrePanel responsive réutilisé.
6. Cycle de vie ✅ — `_EditeurLigne` Stateful (galerie locale), `mounted` gardé.
7. Persistance ✅ — chemins locaux stables (MediaService) + JSONB lignes ; IFU en toJson/loaders/cloud/SQL.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — export_service 5/5, achat_test (images), clients_test (IFU/crédit) ; suite 158/158.
10. Contre-expertise finale ✅ — AppImage limite : URLs http non affichées (fallback) — local-first assumé et documenté (plan A2 : jamais dépendre uniquement du cloud).

### Phase 0 — Services purs du découpage Store (2026-09-28)
Contexte : `PLAN_DECOUPAGE_STORE.md` créé (inexistant avant) ; extraction
de logique PURE sans branchement (Store inchangé).
1. Fonctionnelle ✅ — 5 services : StockService (CUMP, valorisation, mouvements, alertes), CaisseService (solde), PartageService (total + clôture), AnalytiqueService (CA/marges/types/jours/créances/âgée/TVA), ComptaService (5 générateurs + contre-passation + balance + résultat).
2. Métier ✅ — formules recopiées à l'identique du Store (CUMP l.2629, solde l.1644, VT/BQ/AC/OD, TVA HT = TTC/(1+t)).
3. Contre-expertise ✅ — `genererId`/`maintenant` injectés (testabilité, pas de clock) ; coquille `'BQ'=='BQ'` interceptée à la relecture et corrigée avant test.
4. Sécurité ✅ — aucun I/O, aucune policy.
5. Overflow ✅ — code pur, aucun layout.
6. Cycle de vie ✅ — fonctions statiques, aucun état.
7. Persistance ✅ — aucune (services sans état).
8. Analyze ✅ — 0 erreur (imports `../../` corrigés : `lib/data/services/` = 2 niveaux).
9. Tests ✅ — `test/data/` 42 tests (11 stock + 4 caisse + 4 partage + 12 analytique + 17 compta, dont équilibre D=C systématique) ; `const Charge` retiré (ctor non-const).
10. Contre-expertise finale ✅ — services NON branchés (volontaire, Phase 1+) : zéro régression possible, Store intact.

### Vérification AppBar écrans/vues (2026-09-28)
Audit : 36 Scaffold dans `lib/screens/` — 33 avec AppBar, 3 sans (login normal + Stock/Dépenses corrigés en push).
1. Fonctionnelle ✅ — `login_screen.dart` sans AppBar : normal (écran de connexion).
2. Métier ✅ — `StockScreen`/`ChargesScreen` sans AppBar en onglet : normal (AppBar globale du AppShell avec sélecteur boutique).
3. Contre-expertise ✅ — **écart réel** : ces 2 écrans sont aussi poussés depuis le menu Plus → ni titre ni bouton retour. Fix : AppBar conditionnelle (`ModalRoute.canPop`), zéro changement d'API, pas de double barre en onglet.
4. Sécurité ✅ — aucun changement de permission/navigation.
5. Overflow ✅ — AppBar standard, aucun layout touché.
6. Cycle de vie ✅ — lecture synchrone `ModalRoute.of` dans build.
7. Persistance ✅ — aucune donnée.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — nouveau test widget (AppBar absente en onglet, présente + BackButton en push) ; suite 158/158.
10. Contre-expertise finale ✅ — `AchatListScreen` garde sa double barre en onglet (pré-existant, hors périmètre de cette vérification).

### Images renforcées A2 (2026-09-28) — noms uniques + compression + résilience
Contexte : images disparaissant après redémarrage (collisions `millisecondes.jpg` + poids non maîtrisé + URLs cloud jamais re-téléchargées).
1. Fonctionnelle ✅ — `genererNomFichier` (`entite_id_tsSec_6hex.ext`), `compresser` (1280px/JPEG q75 → paliers jusqu'à < 300 Ko), `copierDansApp` vers `media/<entite>/`, `pickImage(s)` avec entité/id.
2. Métier ✅ — PNG avec transparence conservé (logos/signatures, 800px) ; JPEG sinon ; source non-image retournée intacte.
3. Contre-expertise ✅ — boucle de compression bornée (jamais d'exception, meilleur résultat gardé) ; `normaliserChemin` synchrone avec try/catch (doute → inchangé) ; `_reparerImagesDistantes` isolée par entrée + fire-and-forget (jamais de blocage boot).
4. Sécurité ✅ — aucune policy touchée ; URLs cloud inchangées côté serveur.
5. Overflow ✅ — aucun layout (service pur).
6. Cycle de vie ✅ — `mounted` gardé dans `_EditeurLigne` ; client http fermé si créé localement.
7. Persistance ✅ — normalisation aux 8 points de chargement (produits ×2, tarifs ×2, clients ×2, profil ×2) + réparation cloud persistée (`_persist`) + notifiée.
8. Analyze ✅ — 0 erreur, 0 warning nouveau.
9. Tests ✅ — `image_persistence_test.dart` 10/10 (schéma, unicité ×500, compression bruit pur, migration, reload Store, MockClient download/404) ; suite 168/168.
10. Contre-expertise finale ✅ — écarts assumés : hash `Random.secure` (pas SHA-1, unicité équivalente, documenté) ; loopback HTTP bloqué dans l'environnement de test → `MockClient` + injection `@visibleForTesting` (téléchargement réel à valider en manuel/cloud) ; redémarrage physique = test manuel checklist.

### Phase 1 — Notifiers autonomes du découpage Store (2026-09-28)
Contexte : 5 Notifiers créés, testés, NON branchés (Store intact).
1. Fonctionnelle ✅ — Session (user/rôle/permissions/CRUD comptes), Boutique (courante/CRUD/siège/fermer/rouvrir), Profile (update + fonds/budgets), Categorie (CRUD + listes dynamiques + cascade), Collab (messages/événements/notes/feedbacks + getters).
2. Métier ✅ — règles recopiées à l'identique (garde dernière boutique, siège unique, anti-doublon accents, garde-fou suppression, seuils validation) ; `fileUpsert` injecté pour la persistance collab (no-op en test).
3. Contre-expertise ✅ — dépendances par constructeur (`SessionNotifier`, `genererId`, listes partagées) ; `Normalisation` extrait (pas de dépendance au monolithe) ; `CloudRepository.rouvrirBoutique` dans try (hors cloud → erreur, état inchangé, testé).
4. Sécurité ✅ — gardes rôle conservées (admin/gérant réouverture, admin protégé) ; aucune policy touchée.
5. Overflow ✅ — aucun layout (notifiers purs).
6. Cycle de vie ✅ — ChangeNotifier standards, aucun timer.
7. Persistance ✅ — aucune directe (cloud via CloudRepository, façade en Phase 5).
8. Analyze ✅ — 0 erreur (`Note` dans `evenement.dart`, pas de `note.dart` — import corrigé).
9. Tests ✅ — `test/data/notifiers/` 39 tests (7 session + 8 boutique + 6 profile + 9 catégorie + 9 collab) ; suite 249/249.
10. Contre-expertise finale ✅ — NON branchés (volontaire) : zéro régression possible ; branchement en Phase 5 uniquement.

### Phase 2 — Notifiers métier simples (2026-09-28)
Contexte : 5 Notifiers créés, testés, NON branchés (Store intact).
1. Fonctionnelle ✅ — Client (CRUD + boutique + anti-doublon), Fournisseur (CRUD + anti-doublon), Partenaire (CRUD + désactivation + suppression protégée + clôture via PartageService), Charge (CRUD + récurrentes anti-double + budgets via ProfileNotifier + callbacks compta), StockMouvement (journal + ajustement motivé).
2. Métier ✅ — règles recopiées à l'identique (garde dernière boutique N/A ici ; seuils validation ; motifs ; tri créances) ; `fileUpsert`/`comptabiliser`/`contrePasser` injectés (no-op en test, câblés Phase 5).
3. Contre-expertise ✅ — dépendances par constructeur ; Partenaire fidèle au Store (casse seule, pas accents — vérifié l.2396) ; `majCharge`/`supprimerCharge` appellent les callbacks dans le même ordre ; test vendeur→stagiaire corrigé (matrice l.42 : vendeur A gererStock).
4. Sécurité ✅ — gardes rôle conservées (gererStock ajustement) ; aucune policy touchée.
5. Overflow ✅ — aucun layout.
6. Cycle de vie ✅ — ChangeNotifier standards, aucun timer.
7. Persistance ✅ — aucune directe (cloud via CloudRepository).
8. Analyze ✅ — 0 erreur.
9. Tests ✅ — 24 tests (5 client + 5 fournisseur + 6 partenaire + 5 charge + 3 stock-mouvement) ; suite 273/273.
10. Contre-expertise finale ✅ — NON branchés (volontaire) : zéro régression ; branchement Phase 5.

### Phase 3 — Notifiers métier critiques (2026-09-28)
Contexte : 4 Notifiers créés, testés, NON branchés (Store intact).
1. Fonctionnelle ✅ — Produit (CRUD + galerie + archivage + vente atomique + déduction), Transaction (CRUD + crédit + encaissement + restauration stock), Achat (cycle complet + CUMP + paiements + annulation), Document (workflow + signature + devis→facture).
2. Métier ✅ — règles recopiées à l'identique (`CloudTx.dbValue` snake_case corrigé vs `type.name`, seuils validation, tri créances, date devis conservée) ; contrat `ajouterChargeDepense` documenté (sans recomptabiliser, point 30).
3. Contre-expertise ✅ — dépendances par constructeur/callbacks ; Partenaire/Produit fidèles (casse seule) ; stub journaliser rendu fidèle après `Bad state` (le test a révélé le stub, pas un bug) ; attentes corrigées (stock courant 7, 'réservé' minuscule).
4. Sécurité ✅ — gardes rôle conservées (retrait article, encaissement, validation/paiement/annulation documents) ; aucune policy touchée.
5. Overflow ✅ — aucun layout.
6. Cycle de vie ✅ — ChangeNotifier standards, `mounted` N/A (pas de context).
7. Persistance ✅ — aucune directe (cloud via CloudRepository, callbacks Phase 5).
8. Analyze ✅ — 0 erreur (`Note`→evenement, `DocumentBati`→document_service, record patterns nommés).
9. Tests ✅ — 27 tests (7 produit + 6 transaction + 8 achat + 6 document) ; suite 300/300.
10. Contre-expertise finale ✅ — NON branchés (volontaire) : zéro régression ; branchement Phase 5.

### Phase 4 — Notifiers transverses (2026-09-28)
Contexte : 2 Notifiers créés, testés, NON branchés (Store intact).
1. Fonctionnelle ✅ — Compta (journal immuable, postage, contre-passations, pointage, rapprochement, balance, résultat), Analytique (séries 7j/mois/années CA + dépenses, années présentes).
2. Métier ✅ — recopié à l'identique (immuabilité, D=C, pointage = suivi seul, fenêtres 7j/12 mois/toutes années) ; ComptaNotifier délègue la génération à ComptaService (rôle ÉCRITURE déjà testé Phase 0).
3. Contre-expertise ✅ — dépendances par constructeur ; callbacks compta/fileUpsert injectés ; date testée hors fenêtre corrigée (erreur de test, pas de code).
4. Sécurité ✅ — aucune policy touchée.
5. Overflow ✅ — aucun layout.
6. Cycle de vie ✅ — ChangeNotifier standards, aucun timer.
7. Persistance ✅ — aucune directe (cloud via CloudRepository).
8. Analyze ✅ — 0 erreur.
9. Tests ✅ — 13 tests (8 compta + 5 analytique) ; suite 313/313.
10. Contre-expertise finale ✅ — NON branchés (volontaire) : zéro régression ; branchement + façade Phase 5.

### Phase 5 — À venir (façade Store + branchement)

### Refonte UX e-commerce — Stock (R1, 2026-09-28)
1. Fonctionnelle OK — grille 2/3/4 + liste, recherche, 6 filtres, tri 10 modes, détail, vendre/modifier/ajuster/archiver/partager, exports inchangés.
2. Métier OK — `dateAjout` remplie à la création, jamais écrasée (notifier + Store) ; seuils/badges conformes (rupture=0, faible≤seuil, nouveau<7j) ; aucune règle inventée.
3. Sécurité OK — permissions inchangées (gererStock/vendre/admin-retrait) ; matrice + RLS intacts.
4. Overflow OK — CustomScrollView + Masonry ; 320/360/768/1024 × 1.0/1.5/2.0 verts (24 tests).
5. Performance OK — slivers paresseux (pas de shrinkWrap global) ; images `take(5)`.
6. Tests OK — 11 widget + 3 goldens ; suite 375/375.
7. Documentation OK — README + CHANGELOG 1.10.0 + MISSION_STATUS R1 + SQL (schema/migration/à-exécuter).
8. Régression OK — suite complète verte (écrans_test adapté : message vide filtres).
9. UX OK — Hero, fade-in, shimmer réseau seul (déterministe), Ripple, badges 3.
10. Contre-expertise OK — `carousel_slider` non utilisé (PageView natif, écart noté) ; sous-catégorie absente du modèle (non inventée, notée).

### Refonte UX e-commerce — Tarifs (R2, 2026-09-28)
1. Fonctionnelle OK — grille + arbre (drawer/latéral), recherche, prix, tri, détail, utiliser/modifier/désactiver/partager ; formulaire existant conservé.
2. Métier OK — `Tarif.dateAjout` (création/sync, conservée en modif) ; badge Nouveau seul.
3. Contre-expertise OK — seed catalogue vide connu (tests ajoutent leurs articles) ; `onUtiliser` = pop(id) comme avant (pas de navigation inventée).
4. Sécurité OK — gestion admin/gérant inchangée.
5. Overflow OK — slivers + Masonry ; grille reprise dans les 24 tests overflow.
6. Cycle de vie OK — widgets < 200 lignes.
7. Persistance OK — `date_ajout` (toJson/cloud/load + repli base non migrée).
8. Analyze OK — 0 erreur.
9. Tests OK — 7 widget + 1 golden ; suite 375/375.
10. Contre-expertise finale OK — `MoneyText` Provider requis (goldens wrappés Store).

### Refonte UX e-commerce — Achats (R3, 2026-09-28)
1. Fonctionnelle OK — cartes commande, liste/grille, 7 filtres + tri, détail enrichi, payer/annuler rapides, export PDF unitaire.
2. Métier OK — cycle/statuts/CUMP/paiements intacts (délégation Notifier) ; timeline inférée honnête (dates d'étapes non stockées — non inventées, noté).
3. Contre-expertise OK — `_LigneAchat` supprimé (remplacé par widgets, export rerouté) ; `MoneyText` import mort retiré.
4. Sécurité OK — `gererAchats` requis (payer/annuler masqués sinon).
5. Overflow OK — CustomScrollView + SliverMasonryGrid (fix 320@1.5x 80px constaté puis corrigé).
6. Cycle de vie OK — dialogues avec `mounted`, contrôleurs locaux.
7. Persistance OK — aucune migration (modèle inchangé, images lignes déjà JSON).
8. Analyze OK — 0 erreur.
9. Tests OK — 7 widget + 1 golden + 3 parcours intégration (code OK, émulateur ADB absent : non exécutés).
10. Contre-expertise finale OK — suite 375/375 ; push interdit (commits locaux).
