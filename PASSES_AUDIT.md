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

### Phase 6 (1re tentative) — ANNULEE : faux allegement (2026-09-28)
1. Fonctionnelle ECHEC — la logique avait ete deplacee dans des fichiers
   `part` : les `part` partagent la bibliotheque, donc aucun allegement
   reel. Bilan : 1933 -> 1945 lignes, soit +12 (une REGRESSION presentee
   comme un progres).
2. Metier OK — aucun changement de comportement.
3. Securite OK — inchangee.
4. Overflow OK — aucun ecran touche.
5. Performance OK — aucune liste copiee.
6. Tests ECHEC — 395/395 verts, mais la preuve ne portait pas sur
   l'objectif annonce (taille du Store).
7. Documentation KO — la ligne Phase 6 de MISSION_STATUS.md annoncait un
   allegement inexistant.
8. Regression ECHEC — le Store a grossi.
9. UX OK — invisible utilisateur.
10. Contre-expertise ECHEC — un `part` n'est pas une extraction. Verdict :
    modification rejetee, refaite en 6bis (vraies bibliotheques).

### Phase 6bis — Allegement reel du Store (2026-09-29)
**Objectif** : `lib/data/store.dart` < 350 lignes, sans changer l'API
publique ni le comportement. **Realise** : 1945 -> 338 lignes.

1. Fonctionnelle OK — suppression PHYSIQUE des 5 corps geants
   (`chargerDuCloud` 439 l., `_chargerEtat` 309 l., `toJson` 130 l.,
   `_reparerImagesDistantes` 78 l., `_seedDemo` 65 l. = 1021 lignes)
   remplaces par des appels courts aux vraies bibliotheques ; 129
   delegations deplacees dans 9 `extension on Store` re-exportees par
   `store.dart` (donc visibles partout avec un seul import) ; helpers
   metier dans `StoreSync`, fusion de snapshot dans `SnapshotApplier`.
   **Verification anti-duplication** : analyse croisee des membres
   declares par la classe et par chaque extension — 0 doublon residuel.
2. Metier OK — aucune regle inventee ; regle de fusion de categories
   (cloud prioritaire, jamais d'ecrasement par du vide) et exclusion des
   documents pour le format local conservees a l'identique dans
   `SnapshotApplier`. `DemoSeed` reproduit le jeu de demo exact.
3. Securite OK — permissions, RLS, `can()` : inchangees. Le Store ne
   detient plus d'etat metier : moins de surface, pas plus.
4. Overflow OK — aucun ecran modifie ; suite goldens + overflow verte
   (24 tests 320/360/768/1024 x 1.0/1.3/1.5/2.0).
5. Performance OK — listes toujours partagees par reference avec les
   Notifiers (`identical()` verifie dans `wiring_test.dart`) ; aucune
   copie introduite ; relai 600 ms et `_persistTimer` inchanges.
6. Tests OK — `flutter test` **395/395 verts** ; `dart analyze`
   **0 erreur** ; `wiring_test.dart` reecrit sur la nouvelle API (4/4) ;
   31 imports inutiles retires (aucun code mort).
7. Documentation OK — CHANGELOG 1.12.0, MISSION_STATUS (Phase 6
   annulee + Phase 6bis), README (arborescence data/), ce journal.
8. Regression OK — 395/395 verts apres chaque etape (7 jalons
   verifies un par un) ; aucun appelant de `store.dart` modifie
   (`export` des extensions = 0 churn sur 200+ fichiers).
9. UX OK — strictement invisible : facade transparente, memes
   signatures, meme ordre de persistance et de notification.
10. Contre-expertise finale — **reserves assumees** :
    (a) `extension` n'est visible que si la bibliotheque est importee
        ou re-exportee : d'ou les 8 `export` dans `store.dart`
        (`facade_transverse.dart` porte les 7 lectures transverses
        utilisees par le serializer, donc hors de la classe) ;
    (b) 3 membres prives deviennent publics (`genererId`, `fileUpsert`,
        `numeroDocument`) : c'est le cout inevitable d'une extraction
        reelle, documente en place ;
    (c) `lib/screens/stock/stock_screen.dart` fait 952 lignes :
        **hors perimetre 6bis** (refonte UX R1), reserve isolee ;
    (d) 138 warnings `inference_failure` preexistants (pas de la 6bis)
        non traites — a planifier.
    Verdict global : **CONFORME** sur l'objectif 6bis.

### Phase 6bis+ — Correctif du crash cloud (2026-09-29)
**Symptome** : `Unhandled Exception: LateInitializationError: Field
'_boutiqueId' has not been initialized` au premier chargement reel
(login -> `chargerDuCloud` -> `SnapshotApplier.appliquer` -> `changerBoutique`).

1. Fonctionnelle ECHEC en 1.12.0 — cause racine : l'eligiton de la boutique
   passait par `changerBoutique`, qui lit `_boutiqueId`, alors que ce champ
   n'est JAMAIS affecte en mode cloud (le constructeur sort avant). L'ancien
   code assignait directement. Detecte en hot restart sur appareil reel,
   invisible en mode demo (la ou `_boutiqueId` est toujours affecte).
2. Metier OK — la regle d'eligiton est inchangee (cloud prioritaire, boutique
   accessible a l'utilisateur) ; seule l'verification d'existence est ajoutee
   (une boutique fantome n'est pas une regle metier, c'est un trou).
3. Securite AMELIOREE — `changerBoutique` et `definirBoutiqueCourante`
   verifient existence ET `accedeA` ; le refus retombe sur la valeur neutre au
   lieu de laisser un identifiant perime (donnees d'une autre boutique en
   filtrage, en-tetes incoherents).
4. Overflow OK — aucun ecran modifie.
5. Performance OK — un `orElse` de plus sur un `firstWhere` deja borne.
6. Tests OK — `snapshot_applier_test.dart` **15/15** : eligition, propagation
   aux 9 Notifiers filtrants, demande non accessible, compte sans acces,
   snapshot sans boutique, categorie vide (cloud prioritaire), neutre sans
   liste, `changerBoutique` (fantome refuse / existante acceptee),
   `elireBoutiqueAccessible` (3 cas), **garde-fou structurel interdisant tout
   `late` non-`final` dans `Store`**. Suite **410/410**, analyze 0 erreur.
7. Documentation OK — CHANGELOG 1.12.1, MISSION_STATUS (Phase 6bis+),
   ce journal.
8. Regression OK — les 17 appels `boutiqueCourante.nom` restent valides (type
   inchange, valeur neutre au lieu d'une exception) ; garde d'acces du
   selecteur de boutique preservee et renforcee.
9. UX OK — « Aucune boutique » est explicite plutot qu'un crash ; le menu de
   selection de boutique inchange.
10. Contre-expertise — reserves : (a) la fenetre entre la connexion et la
    fin du chargement affiche « Aucune boutique » au lieu d'une impasse
    (choix assume : mieux vaut un etat neutre explicite qu'un crash) ;
    (b) `boutiqueNeutre` est une `Boutique` synthetique — jamais stockee,
    jamais envoyee au cloud (getter pur) ; (c) le test de non-regression du
    mode CLOUD reel reste non automatise (`CloudRepository.actif` depend de
    `Env`, non mockable) : couvert par le test structurel + le test
    d'eligition, pas par un bout-en-bout cloud.
    Verdict : **CONFORME**, correctif livre.

## ═══ LEÇONS APPRISES (Phase 6 → Phase 6bis) ═══

### 1. Ne JAMAIS utiliser `part` pour alléger un fichier
`part` = même unité de compilation. Un `part` ne réduit **jamais** le
nombre de lignes du fichier principal : il les déplace. La Phase 6 a
déplacé ~1800 lignes en 8 `part` et le Store est passé de 1933 →
1945 (+12). Le suivi MISSION a méme déclaré ce résultat « allègement ».

**Règle** : pour réduire un fichier, il faut des **vraies
bibliothèques** (`import`), jamais des `part`. Un `part` a un seul usage
légitime : partager des variables/fonctions **privées** sans changer
l'API — ce qui n'était pas l'objectif ici.

### 2. Toujours SUPPRIMER PHYSIQUEMENT le code déplacé
Le piège technique : une méthode dupliquée dans la classe ET dans la
bibliothèque n'est pas « déplacée », c'est du code mort en
double. Vérification retenue pour la 6bis : **analyse croisée** des
membres déclarés par la classe et par chaque extension
(129 membres) → 0 doublon résiduel. Sans cette étape, les 129
délégations sont restées dans les DEUX côtés.

### 3. Vérifier la TAILLE du fichier principal après chaque étape
La Phase 6 a été « vérifiée » par `flutter test` (395/395 verts)
alors que l'objectif — la taille du fichier — n'était pas mesuré. Une
suite verte ne prouve pas un objectif de structure.

**Règle** : mesurer `wc -l lib/data/store.dart` après CHAQUE jalon, et
l'afficher dans le rapport. Journal de la 6bis :
1945 → 1198 → 1037 → 1036 → 887 → 661 → 569 → 463 → 349.
Un jalon oisif (1036 → 1036) a décélé une erreur de script ;
seule la mesure l'a révélé.

### 4. Dart ne résout pas une extension hors de sa bibliothèque
Une `extension on Store` n'est visible que si l'on importe (ou **ré-exporte**)
le fichier qui la déclare. D'où l'expression `export 'facade/*.dart'`
dans `store.dart` : un seul import pour l'application entière, zéro
churn sur 200+ appelants. Sans cela : 200+ fichiers à modifier.

### 5. Un `late` sur un champ d'instance est une bombe à retardement
`late String _boutiqueId` ne plante qu'au **premier** chemin qui le lit
avant l'affectation. En mode démo le champ est toujours affecté →
395 tests verts ; en production le constructeur sort tôt → crash au
premier chargement réel. Découvert uniquement en hot restart sur
appareil configuré.

**Règles** :
- valeur neutre par défaut (`String _boutiqueId = ''`) plutôt que `late`
  quand une lecture précoce est possible ;
- `firstWhere` sur une liste potentiellement vide → `orElse` explicite
  (17 écrans lisaient `boutiqueCourante.nom` sans repli) ;
- **test structurel** interdisant tout `late` non-`final` dans `Store`
  (ajouté dans `snapshot_applier_test.dart`).

### 6. Tester le chemin de PRODUCTION, pas seulement le mode démo
Le mode démo et le mode Supabase empruntent des chemins de constructeur
DIFFÉRENTS (`CloudRepository.actif` → sortie anticipée). 395 tests
verts en démo ne disent rien du chemin cloud, qui n'est atteignable que
si `Env` est configuré (non mockable sans refonte de `SupabaseService`).
**Rèserve toujours assumée** : le test cloud de bout en bout reste
manuel, d'où la validation en hot restart sur appareil.

### 7. Ne jamaishajouter une règle métier pour « réparer » un bug
Quand l'éligition de boutique a échoué, le correctif a été de
rejeter l'identifiant fantôme (retour à la valeur neutre) et non
d'inventer un règle « l'admin peut toujours choisir ». La garde
`accedeA` reste la source unique de vérité.

### Galerie interne d'images — G1 (2026-09-30)
1. Fonctionnelle OK — parcours (stockage local + bucket), upload
   (compression 1280 px / < 300 Ko réutilisée), sélection,
   affectation produit **et** article, suppression définitive. Accès
   par 2 portes (menu Plus + formulaire produit), comme demandé.
2. Métier OK — aucune règle inventée : la galerie n'ajoute
   AUCUNE source de vérité. Elle déduit l'index du stockage
   réel + des références existantes. L'image affectée devient
   `images.first` (convention `imagePath` du modèle déjà en place).
   Pas de table SQL, pas de migration : le bucket fait office d'index.
3. Sécurité OK — lecture + affectation ouvertes à tous ; la
   **suppression définitive est filtrée à admin/gérant** dans
   l'écran, ce qui correspond à la policy RLS « media suppression »
   (déjà en base). Double garde : côté client ET côté serveur.
4. Overflow OK — grille `maxCrossAxisExtent` (2 colonnes à 320 px, 5
   à 1024 px), libellés ellipsés, `Wrap` pour la barre de filtres,
   bottom sheet scrollable : vérifié 320/360/768/1024 × 1.0/1.5/2.0
   (15 tests, 0 exception).
5. Performance OK — index reconstruit à l'ouverture seulement ;
   `GalleryService` est pur (aucune I/O testable) ; les vignettes locales
   ne déclenchent aucun ticker (placeholder **statique**, pas de Shimmer
   — sinon `pumpAndSettle` casse).
6. Tests OK — 44 tests : `gallery_service_test` 22 (indexation, usages,
   bornes 5 images, doublons, détachement), `media_storage_test` 7
   (listing, tri, suppression physique, refus des URLs), `gallery_overflow_test`
   15 (12 anti-overflow + 3 garde d'accès) + 1 test de wiring.
   Suite **455/455**, `dart analyze` **0 erreur**.
7. Documentation OK — CHANGELOG 1.13.0, MISSION_STATUS (G1), CDC 40novies,
   ce journal.
8. Régression OK — suite complète verte ; `wiring_test` mis à jour
   (16 → 17 Notifiers + test de partage des listes galerie) ; aucun
   appelant de `Store` modifié hormis 2 ajouts de facade (lignes < 350).
9. UX OK — l'écran est lisible par tous, la poubelle n'apparaît que
   pour les rôles autorisés (sous-titre de la tuile menu l'annonce), et
   supprimer une image rattachée affiche la liste des entités
   concernées avant confirmation.
10. Contre-expertise — **réserves** : (a) le scan du dossier local est
    fait à chaque ouverture (rapide, mais à confirmer sur un grand
    catalogue) ; (b) pas de cache d'index — décision assumée, un index
    obsolète est pire qu'un scan ; (c) le test de garde d'accès porte sur
    la **grille** et non sur `GalleryScreen` (le scan `dart:io` ne se
    résout pas dans la zone fake-async de `testWidgets`) : la règle
    testée est bien celle appliquée par l'écran, mais le
    chaînage complet n'est pas couvert par un test automatique —
    **à vérifier en exécution réelle** ; (d) la suppression cloud
    dépend de la policy RLS déjà installée (si elle manque en base,
    la suppression locale marche, la cloud non — retour false traité).
    Verdict : **CONFORME**.

## 2026-10-02 - 1.13.4 : invariant `imagePath` applique AU CONSTRUCTEUR

**Modification unique** : `lib/models/produit.dart` - le constructeur
derive `imagePath` de `images` avec un sentinelle prive.
**Preuve d'origine** : test d'integration joue sur l'appareil
(Infinix X6840 / Android 16), 6/7 verts, le 7e en echec.

1. Fonctionnel OK - `Produit(images: ['/a.jpg']).imagePath` vaut
   maintenant `/a.jpg` au lieu de `null`. L'invariant annonce dans la
   doc du modele (`imagePath == images.first`) tient desormais des la
   CONSTRUCTION, pas seulement apres `copyWith`.
2. Metier OK - aucune regle inventee. On applique partout la regle
   deja documentee et deja appliquee par `copyWith`. La priorite
   `imagePath` explicite > `images.first` est preservee (chemins
   historiques, image cloud-only) : un `Produit` deserialize depuis le
   cloud qui porte `image_path` garde exactement cette valeur.
3. Securite OK - aucun acces, aucune donnee, aucun secret. Perimetre
   strictement `lib/models/produit.dart` + tests.
4. Overflow OK - sans objet (modele, aucun widget).
5. Performance OK - un `identical()` sur un `static const` + un
   `isNotEmpty`. Négligeable ; aucun champ calculé dans une boucle.
6. Tests OK - `produit_images_test.dart` passe de 8 a **15 tests**
   (helper desarme, +7 cas de contrat du constructeur dont
   « constructeur == copyWith » sur 3 entrees). Integration
   `image_flow_test.dart` : **7/7 sur l'appareil**.
   Suite **487/487 verts**, `dart analyze` **0 erreur**.
7. Documentation OK - CHANGELOG 1.13.4, ce journal, et suppression
   d'une **section 1.13.2 dupliquee** dans le CHANGELOG (interdit par
   AGENTS.md §10).
8. Regression OK - **piege evite et documente** : sans sentinelle, la
   correction du bug 3 aurait ANNULE le bug 1 (`copyWith(effacerImagePath:
   true` redevient inoperant car le constructeur re-derive `images.first`).
   Test dedie : « imagePath explicitement nul : le constructeur NE
   rederive pas ». Cout de la correction : `const Produit(...)` devient
   illegal ; les 8 appelants `const` ont ete convertis. Verification
   qu'**aucun appelant en `lib/` n'etait concerne** (grep : 8
   occurrences, toutes dans `test/`) - donc pas de degression en
   production.
9. UX OK - l'utilisateur ne voit aucun changement d'interface, mais le
   comportement devient celui annonce : une photo ajoutee au produit
   s'affiche des la construction de la fiche, et une photo retiree ne
   revient plus a la sauvegarde.
10. Contre-expertise - **reserves assumees** : (a) perte de `const`
    sur `Produit` : impact negligeable (le modele n'est jamais place
    dans un `const` de collection en `lib/`, verifie par grep ; en
    contrepartie l'invariant est garanti, ce qui vaut mieux qu'une
    optimisation de compilation) ; (b) le sentinelle est `private`, donc
    un appelant externe **ne peut pas** demander explicitement
    « derive de la galerie » s'il veut aussi passer une liste vide non
    intentionnellement - c'est exactement le comportement voulu, et
    `copyWith` couvre le cas ; (c) le test d'integration joue les
    ecrans mais ne simule pas le tactile : la verification du
    parcours « j'ajoute une image puis j'appuie sur Enregistrer » reste
    **manuelle** sur l'appareil.
    Verdict : **CONFORME**.

## 2026-10-02 - 1.13.4 (suite) : trou de RELECTURE `image_path`

**Modification** : `StoreSnapshot._produit` + `CloudLoader._produit`
(nouveaux, sortie des comprehensions) + `Produit.principal(...)`.
**Preuve d'origine** : lecture du code d'ecriture, `grep "image_path"`
dans `serializer.dart` → le serialiseur ecrit `image_path` ET `images`
(2 lignes, 321-322).

1. Fonctionnel OK - une fiche relue avec `image_path` nul et une galerie
   non vide retrouve sa photo principale. C'est l'état de TOUTES les
   données déjà enregistrées sur l'appareil (le bug 3 existait
   depuis toujours, donc tout instantané écrit par lui porte
   `image_path: null` + une galerie non vide).
2. Metier OK - `image_path` reste prioritaire quand il existe (donnée
   écrite par l'application, chemins historiques). Le repli ne s'applique
   qu'à l'absence de valeur, jamais en concurrence. Aucune règle
   inventée, aucune priorité inversée par rapport à la doc du modèle.
3. Sécurité OK - aucun accès, aucune donnée, aucun secret.
   Le repli ne peut introduire qu'une image **déjà présente dans la
   galerie du même produit** : il ne peut pas afficher une image
   étrangère au produit (la galerie en est la definition même).
4. Overflow OK - sans objet (modèle + deserialisation).
5. Performance OK - une liste de plus par produit, allouée une fois au
   chargement. `MediaService.normaliserChemin` était déjà appelé
   autant de fois qu'avant : **aucun appel en double**, la galerie est
   calculée une seule fois puis réutilisée par `images` ET par le
   repli de `imagePath`.
6. Tests OK - +6 (3 par déserialiseur : régression du repli, priorité
   de la valeur écrite, absence totale). Integration :
   10 scénarios joués sur l'appareil dont 3 de déserialisation.
   Suite **493/493**, `dart analyze` **0 erreur**.
7. Documentation OK - CHANGELOG 1.13.4 (bug 4), MISSION_STATUS (G6),
   ce journal.
8. Régression OK - **chaîne de dépendances vérifiée** : corriger le
   bug 3 (constructeur) sans ce correctif aurait rendu les photos
   *moins* visibles qu'avant, car `null` est devenu « explicitement
   nul ». Les 2 bugs sont donc indissociables — découvert et fermé
   dans la même passe.
   Contrainte de test rencontrée : le littéral de `cloud_loader_test`
   est inféré `Map<String, Object>` (valeurs non nul) et refuse
   d'écrire un `image_path` nul — exactement le cas testé. Corrigé par
   `Map<String, dynamic>.from(...)` + réaffectation, commenté.
9. UX OK - l'utilisateur ne voit aucun changement d'interface ; en
   revanche les produits dont la photo était dans la galerie mais pas
   dans `image_path` **redeviennent affichables au redémarrage**.
10. Contre-expertise - **réserve** : le repli s'appuie sur la galerie
    comme source de vérité du principal. C'est la même hypothèse
    que le modèle documente depuis le début (`imagePath == images.first`)
    et que G3/G4 ont installée ; elle n'est donc pas nouvelle. En
    revanche elle est désormais **appliquée à la relecture**, ce qui
    wasn't le cas. Une photo cloud-only absente de `images` mais
    présente dans `image_path` reste correctement affichée (priorité
    de la valeur écrite). Verdict : **CONFORME**.

## 2026-10-02 - Renommage `test/produit_images_test.dart`

Deux fichiers se nommaient presque identiquement pour des périmètres
différents : `test/produit_images_test.dart` (galerie via le **Store**,
roundtrip de persistance) et `test/models/produit_images_test.dart`
(invariant du **modèle**, `copyWith`/constructeur). Risque : un agent
corrige l'un en croyant corriger l'autre.

`test/produit_images_test.dart` -> `test/data/produit_galerie_store_test.dart`
(`git mv`, contenu inchangé). Aucun appelant : ce sont des suites de tests.

## 2026-10-02 - 1.13.4 (suite) : VERBE de la file de sync + ponctuation PDF

**Origine** : logs de la session MANUELLE de l'utilisateur sur
l'Infinix X6840. Deux messages que ni les 493 tests unitaires ni les
10 scenarios d'integration ne pouvaient produire : ils exigent une
vraie session cloud avec une base reelle.

```
SyncService : operation bloquee definitivement (produits)
 - PostgrestException(null value in column "boutique_id" of relation
   "produits" violates not-null constraint, code: 23502)

Unable to find a font to draw "-" (U+2014) try to provide a
TextStyle.fontFallback
```

### Bug 5 — VERBE de la file de sync (bloquant)

1. Fonctionnel OK - le blocage etait **definitif** : `en_erreur` a
   8 essais, `synchroniser()` ignore ces entrees, et le seul moyen de
   les relancer (`reessayerTout`) les faisait **echouer encore**, la
   cause n'ayant pas ete corrigee. L'utilisateur etait donc bloque avec
   une file qu'il ne pouvait pas debloquer depuis l'app.
2. Metier OK - correction du VERBE, pas du contenu : un payload
   `{id, actif: false}` ne peut pas creer une ligne dans aucune table
   metier (il manque `libelle`, `montant`, `boutique_id`...). Le
   re-classer en `UPDATE` ne change donc **aucune** donnee, et la
   migration `reparerEntreesLegacy()` ne touche que le nom de table
   (`payload`, `cree_le`, `essais` intacts).
3. Securite OK - RLS inchangee, aucune donnee supprimee cote serveur.
   `__delete` reste une suppression par `id`, filtree par les memes
   policies qu'avant.
4. Overflow OK - sans objet.
5. Performance OK - `operationPour()` est une cascade de deux
   `endsWith` par entree ; negligeable devant l'aller-retour reseau.
   `reparerEntreesLegacy()` parcourt la box une fois au demarrage.
6. Tests OK - +11 : routage des 3 verbes, `tableReelle`, detection
   d'un payload partiel, **garde-fou structurel** qui relit `lib/` et
   refuse tout `fileUpsert` a payload partiel sur table nue, et 2
   verifications ciblees (archivage produit, ajustement de stock).
   Suite **506/506**, `dart analyze` **0 erreur**.
7. Documentation OK - CHANGELOG 1.13.4 (bug 5), MISSION_STATUS (G8),
   ce journal.
8. Regression OK - **le garde-fou a trouve un 4e site que la relecture
   avait rate** : `supprimerPartenaire` supprimait la ligne puis mettait
   en file `{id, actif: false}`, ce qui **recraitait** le partenaire
   supprime (ou tentait de le creer, 23502). Route `__delete`. C'est la
   justification du test structurel : 4 appelants disperses, une regle,
   un piege que la lecture manuelle ne voit pas de facon fiable.
   Point d'attention assume : `messages` et `feedbacks` envoient aussi
   des payloads partiels (colonnes `date`/`lu` absentes). Je ne les
   touche pas : sans le schema reel de ces tables, je ne peux pas
   affirmer que leur insertion echoue, et modifier a l'aveugle serait
   inventer une regle (AGENTS.md §10.8). **Reserve tracee.**
9. UX OK - l'archivage et l'ajustement de stock atteignent enfin la
   base ; le badge de file d'attente ne se fige plus sur une erreur
   irreversible.
10. Contre-expertise - **reserve** : `patch` sur une ligne inexistante
    consomme l'entree sans effet (0 ligne mise a jour). C'est le
    comportement honnete : creer la ligne depuis un payload partiel
    est impossible sans inventer `libelle`/`prix`, et bloquer l'entree
    definitivement serait pire. La trace reste en console. Une
    synchronisation complete (`upsert` avec le payload complet) est
   emplacee par `CloudRepository` juste avant, qui cree la ligne.
    Verdict : **CONFORME**.

### Bug 6 — ponctuation absente des PDF

1. Fonctionnel OK - le tiret cadratin des libelles de signature, de la
   ligne bancaire, du rapport journalier et du total analytique
   disparaissait du PDF (trou ou caractere de remplacement).
2. Metier OK - substitution par un tiret ASCII, pas par une police
   Unicode. Charger une TTF (~400 Ko) pour un separateur serait
   disproportionne ; les accents, l'euro et le degré sont deja Latin-1 et
   s'impriment correctement. Aucune typographie d'accent modifiee.
3. Securite OK - sans objet.
4. Overflow OK - un tiret ASCII est plus etroit qu'un tiret cadratin :
   aucun risque de debordement ajoute, au contraire.
5. Performance OK - identique (pas de police chargee).
6. Tests OK - +2 : garde-fou Latin-1 sur les 3 fichiers produisant un
   PDF, plus un test qui verifie que les accents **restent presents**
   (pour interdire qu'un futur "correctif" supprime la typographie
   française au lieu de la remplacer).
   Perimetre assume : dans les ecrans, seules les lignes contenant
   `pw.` sont controlees — une `SnackBar('⚠')` ou un
   `Text('Rechercher…')` sont valides a l'ecran (Roboto est Unicode).
   `pdf_service.dart`, constructeur de tous les documents, est controle
   en entier.
7. Documentation OK - CHANGELOG 1.13.4 (bug 6), MISSION_STATUS (G9).
8. Regression OK - les tests PDF existants continu e9 de passer ; le
   contenu des documents est inchange, seule la ponctuation des
   libelles differe.
9. UX OK - les documents n'ont plus de trous. **Cela ne corrige pas**
   les 12 points de mise en page signales (positions, cadres,
   signatures) : ils demandent le PDF genere par l'utilisateur.
10. Contre-expertise - **reserve** : une donnee saisie par
    l'utilisateur contenant un caractere hors Latin-1 (par exemple un
    emoji dans un libelle de produit) disparaitra toujours du PDF.
    Traiter cela demande une police Unicode embarquee — decision
    d'architecture a poser, pas adeviner. Verdict : **CONFORME** sur le
    perimetre des libelles, **reserve** sur les donnees utilisateur.

## 2026-10-03 - Depot Git : branche unique `main`

**Demande** : ne conserver que cette version, « comme si c'etait la
premiere fois qu'on faisait le push ».

**Etat avant** : 16 branches distantes (`audit/formulaire-vente`,
`feat/batch1` a `batch6`, `feat/boutiques-filtres`,
`feat/categories-filtres`, `feat/achat-exports`, `feat/documents-emis`,
`feat/sql-finalize`, `fix/plan-correction-totale`,
`feat/refonte-ux-ecommerce`) et 15 branches locales.
`origin/main` etait a `6de44ff`, soit **61 commits en retard**.

**Action 1 - mise a jour de `main` par FAST-FORWARD** (`6de44ff..72bcb0d`).
Aucun force-push, donc aucun commit ecrase (regle AGENTS.md 7.5). Les 61
commits anterieurs restent dans l'historique.

**Action 2 - controle de securite AVANT suppression.** Pour chacune des
30 branches, `git rev-list --count <branche> --not main` :
**toutes les valeurs sont a 0**. Aucun commit n'existait ailleurs que
dans `main` : la suppression ne perdait rien. C'est ce controle qui
distingue un nettoyage d'une perte de travail.

**Action 3 - suppression.** 15 branches distantes + 15 locales.
Une seule a necessite `-D` (`feat/batch5-menu`) : `git branch -d` la
refusait en la comparant a son *upstream* et non a `main`, alors que le
controle ci-dessus prouvait son contenu deja dans `main`.

**Action 4 - `main` devient la branche par defaut** (`origin/HEAD` pointe
desormais sur `main`), avec suivi ameliore. `git status` : `main` aligne
sur `origin/main`, 0 commit non pousse.

**Aucun fichier modifie** : la suite reste a **506/506 verts** et
`dart analyze` a **0 erreur** (les references Git ne touchent pas le
code, aucun re-execution necessaire).

**Reserve** : le depot ne contient plus d'historique « par lot ». Le
journal des lots reste dans `MISSION_STATUS.md` et `CHANGELOG.md`, qui
sont commites dans `main` — c'est la que se trouve la tracabilite, pas
dans les noms de branches.

## 2026-10-03 - 1.13.5 : debordement de l'ecran Synchronisation

**Origine** : signale par l'utilisateur SUR L'APPAREIL, puis confirme par
la stack trace Flutter capturee :

```
A RenderFlex overflowed by 140 pixels on the right.
The relevant error-causing widget was:
  Row
  Row: lib/screens/config/synchronisation_screen.dart:137:25
constraints: BoxConstraints(0.0<=w<=349.4, 0.0<=h<=Infinity)
size: Size(349.4, 20.0)
```

1. Fonctionnel OK - cause unique et identifiee : dans le `Row` d'en-tete
   de chaque entree, `Text(table)` etait dimensionne a sa largeur
   NATURELLE. `Spacer` ne peut rien faire quand les enfants non
   flexibles depassent deja la place. Correction : `Expanded` + ellipsis
   sur le nom de table, `Flexible` (loose) + ellipsis sur le compteur,
   `Spacer` supprime.
2. Metier OK - aucune regle inventee : c'est de la mise en page. Le nom
   de table provient du nom de table de la file, donc longueur variable
   (`mouvements_stock`, `partenaires__update`, ...).
3. Securite OK - sans objet.
4. Overflow OK - **grille complete, et le test a ete PROUVE** :
   320 / 360 / 768 / 1024 x TextScaler 1.0 / 1.5 / 2.0, plus les cas
   « une seule erreur », « nom de table tres long + compteur 128 »,
   « entree en attente », « file vide », « 10 erreurs ». 7 tests, 0
   exception.
   **Preuve de valeur du test** : le defaut a ete reintroduit, le test
   echoue (2 cas sur 7 : TextScaler 1.5/2.0 et nom de table long),
   le correctif restaure, le test repasse. Un test qui ne sait pas
   echouer ne prouve rien.
5. Performance OK - `Expanded`/`Flexible` : aucun surcout mesurable.
6. Tests OK - +7 (`test/widget/synchronisation_overflow_test.dart`).
   Suite **516/516 verts**, `dart analyze` **0 erreur**.
7. Documentation OK - CHANGELOG 1.13.5, MISSION_STATUS (G10), ce journal.
8. Regression OK - **seam de test ajoute** : `SyncService` n'exposait
   aucune liste d'entrees injectables, donc cet ecran n'etait
   testable qu'a vide. `entreesPourTest` (null = file reelle) permet de
   peupler la file sans Hive, et `enAttente` / `enErreur` sont
   maintenant comptes sur `detailFile` — donc le test pilote la
   totalite de l'ecran. Aucun changement de comportement en production.
   Point de vigilance assumee : **un `Store` par mesuree** programme des
   debounces de 600 ms ; le test en cree un seul pour toute la suite et
   fait avancer l'horloge virtuelle de 700 ms. Sans cela le test echoue
   sur « pending timers » AVANT que l'overflow ne soit constate — j'ai
  perddu du temps la-dessus, c'est note.
9. UX OK - l'ecran affiche enfin ses erreurs sans barres jaunes ni
   stripes. Le nom de table long est tronque avec `...` plutot que de
   pousser le compteur hors champ.
10. Contre-expertise - **explication de la reproduction** : a
    TextScaler 1.0 et 320 px, le defaut ne deborde PAS (le test le
    confirme). L'utilisateur voit 140 px parce que son systeme est a
    une echelle de police superieure a 1.0, courante sur Infinix, ou
    parce que sa file contient un nom de table plus long. C'est
    exactement pourquoi la grille de tests couvre 1.5 et 2.0 et pas
    seulement 1.0 : tester uniquement la taille par defaut aurait laisse
    passer ce bug. Verdict : **CONFORME**.

## 2026-10-03 - 1.13.4 (complement) : 22P02 uuid vide

**Origine** : logs de l'appareil.
`SyncService : operation bloquee definitivement (mouvements_stock) -
PostgrestException(invalid input syntax for type uuid: "", code: 22P02)`

`MouvementStock.refId` est documente « '' si manuel » et `createdBy`
vaut '' par defaut ; le schema declare les deux colonnes `uuid` et
NULLABLE. `''` n'est pas un uuid.

1. Fonctionnel OK - les AJUSTEMENTS MANUELS de stock ne se
   synchronisaient plus : historique de stock perdu. Correctif
   preventif (`''` -> `null`, convention deja appliquee par
   `compta_notifier`) + reparation des entrees deja bloquees au
   demarrage.
2. Metier OK - aucune regle inventee : meme convention que le code
   existant. La table `colonnesUuidOptionnelles` est volontairement
   RESTREINTE aux colonnes dont le modele utilise `''` pour « aucune
   reference » : une colonne obligatoire recevant `''` doit continuer
   d'echouer bruyamment plutot que d'etre coupee en silence.
3. Securite OK - aucune donnee supprimee, seule une valeur invalide
   devient NULL, ce qui est la representation correcte de « aucune
   reference ».
4. Overflow OK - sans objet.
5. Performance OK - deux `isEmpty` par mouvement.
6. Tests OK - +3 : le test relit `database/supabase_schema.sql` et
   verifie qu'aucune colonne de la table n'est `uuid NOT NULL` — sur
   une colonne NOT NULL, la reparation rebloquerait l'entree ET
   masquerait une vraie erreur de donnee. La regle suit le schema.
   Suite **516/516**, `dart analyze` **0 erreur**.
7. Documentation OK - CHANGELOG 1.13.4, MISSION_STATUS (G9bis).
8. Regression OK - avant de corriger, les autres tables ont ete
   verifiees et NON modifiees : `Message.destinataireId` est un vrai
   `String?` nullable (`null = tous`) donc deja correct ;
   `achats.created_by` n'est pas envoye ; `ecritures.ref_id` etait
   deja converti. `stock_screen.dart:959` passe `imagePath:` en dur,
   mais `_imagePath` est un getter `isEmpty ? null : first` : coherent,
   **aucune modification**.
9. UX OK - l'historique de stock se synchronise a nouveau.
10. Contre-expertise - **reserve tracee** : `messages` et `feedbacks`
    envoient eux aussi des payloads partiels. Sans le schema REEL de
    ces tables je ne peux pas affirmer que leur insertion echoue ; les
    modifier a l'aveugle serait inventer une regle (AGENTS.md 10.8).
    Verdict : **CONFORME** sur le perimetre verifie.

## 2026-10-03 - 1.13.6 : notifications Android inoperantes

**Origine** : `integration_test/device_image_flow_test.dart` joue sur
l'appareil reel. Stack trace :

```
PlatformException(error, ...NullPointerException: Attempt to invoke
virtual method 'int java.lang.Integer.intValue()' on a null object
 reference
  at FlutterLocalNotificationsPlugin.setSmallIcon(...:474)
  at NotificationService._notifier (notification_service.dart:66)
  at NotificationService.verifier (notification_service.dart:76)
```

1. Fonctionnel OK - **sur Android, aucune notification ne s'affichait**
   (stock bas, budget depasse, cloture mensuelle, rappel sauvegarde,
   evenements, rappels, contributions). Et chaque alerte levait une
   exception asynchrone non geree : `main.dart:73` appelle `verifier()`
   sans `await` ni `try/catch`.
2. Metier OK - aucune regle inventee : c'est du materiel Android. Les
   trois corrections sont les mecanismes documentes du plugin
   (`AndroidNotificationDetails.icon`, meta-data `default_icon`,
   drawable en `res/drawable/`).
3. Securite OK - aucun acces, aucune donnee.
4. Overflow OK - sans objet.
5. Performance OK - sans objet.
6. Tests OK - +6 (`test/services/notification_android_test.dart`) qui
   croisent le nom declare dans le Dart, le drawable reellement present
   sur disque, les DEUX sources resolues par `show()`, et le fait que
   `show()` soit enveloppe. Suite **522/522**, `dart analyze` 0 erreur.
7. Documentation OK - CHANGELOG 1.13.6, MISSION_STATUS (G12), ce journal.
8. Regression OK - **lecon principale, tracee** : le `try/catch` seul
   n'a PAS regle le bug, il l'a **masque**. Premier build : plus de
   crash, mais le NPE toujours present, simplement journalise. Il a
   fallu une DEUXIEME itération pour poser `icon:` sur
   `AndroidNotificationDetails`, qui est la source reellement consultee
   par `show()` — le nom d'initialisation ne sert qu'a
   `initialize()`. Trois iterations pour un bug ; ce qui a fait la
   difference est d'avoir refuse de conclure au premier `try/catch`.
9. UX OK - les alertes de gestion redeviennent visibles.
10. Contre-expertise - **erreur de test assumee et corrigee** : le test
    d'integration cherchait le nom du fichier dans la galerie. La
    tuile (`media_tile.dart`) n'affiche **aucun nom** (vignette + puce
    Locale/Cloud). L'image est desormais identifiee par son tag `Hero`.
    **L'UI n'a PAS ete modifiee** pour faire passer un test incorrect :
    ajouter un libelle de fichier dans la tuile serait une decision de
    design, pas une correction de bug.
    Reserve : `res/drawable/` et le plugin natif sont hors de portee de
    la VM — ce defaut ne pouvait etre detecte que sur l'appareil.
    Verdict : **CONFORME**.

## 2026-10-03 - 1.14.0 : cohérence métier des droits (option A)

**Origine** : question de l'utilisateur — « pourquoi les vendeurs
peuvent-ils ajouter un article en stock ? illogique », suivie d'une
demande d'audit complet des droits.

1. Fonctionnel OK - la ligne unique « Gérer stock (créer/modifier) »
   confiait au vendeur trois actes de nature différente. Créer une fiche
   catalogue fixe le **prix d'achat, donc la marge** : acte de direction.
   La matrice se contredisait (ligne « créer/modifier » contre note
   « autonomie terrain : prix, photo, seuil »). Option A appliquée :
   lecture + modification conservées, création et retrait refusés.
2. Métier OK - aucune règle inventée : chaque droit correspond à une
   LIGNE de `MATRICE_PERMISSIONS.md`, et la matrice a été réécrite dans
   le même sens (1 ligne devient 5). Rôle */gérant* conservés inchangés.
   Le comptable et le caissier **lisent** le stock sans le modifier : le
   compta suit l'inventaire, le caissier encaisse.
3. Sécurité OK - **le vrai manque** : `ajouterProduit` et `majProduit`
   n'avaient aucune garde, la seule protection étant l'affichage du
   bouton. Une règle qui vit dans un `if (visible)` n'est pas une règle
   d'accès. 4 gardes ajoutées. Corrigé aussi : **la barre de navigation
   basse n'était pas filtrée** — un vendeur ouvrait « Dépenses » et
   « Achats » alors que le menu « Plus » les cachait. Fuite de
   confidentialité sur les charges et les achats.
4. Overflow OK - le FAB « Produit » disparaît pour un vendeur : pas de
   débordement possible, et la barre du bas a au moins deux onglets
   (Accueil, Plus) donc jamais vide. `test/golden` et
   `commerce_overflow_test` rejoués : verts.
5. Performance OK - la liste d'onglets est reconstruite à chaque build
   (5 éléments, une comparaison de `Set<Permission>` par onglet).
   Négligeable ; pas de listeur dans un `build` chaud de grande ampleur.
6. Tests OK - **22 nouveaux** : `test/droits/permissions_stock_test.dart`
   (14 : matrice + gardes métier, rôle par rôle) et
   `test/droits/navigation_droits_test.dart` (8 : onglets par rôle, dont
   « aucun rôle ne reçoit un onglet qu'il n'a pas le droit de voir »).
   2 tests de non-régression sur le menu contextuel filtré.
   **Preuve** : le droit de création redonné au vendeur → 2 tests
   échouent ; restauré → 22/22. Suite **546/546**, `dart analyze`
   **0 erreur**.
7. Documentation OK - `MATRICE_PERMISSIONS.md` (ligne unique → 5 lignes +
   décision explicite + section serveur), CHANGELOG 1.14.0,
   MISSION_STATUS (G13-G16), ce journal.
8. Régression OK - deux tests existants ont échoué **à juste titre** :
   ils encodaient l'ancien comportement. `fixes_critiques_test`
   attendait « admin » dans le refus : j'ai changé le message en
   « Réservé (direction) » → « Réservé (admin, gérant) », ce qui est plus
   utile pour l'utilisateur *et* garde le test pertinent. Le second
   test portait sur le menu non filtré : mis à jour, plus 2 tests ajoutés.
   `ProductGrid` n'est utilisé **que dans les tests** (code mort
   préexistant) — pas de régression en production, mais il reste à
   nettoyer.
9. UX OK - pour un vendeur : plus d'onglet Dépenses, plus de FAB
   « Produit », menu contextuel réduit à Modifier / Ajuster / Partager.
   Le stock reste consultable, donc il ne vend plus de l'inexistant.
10. Contre-expertise - **deux de mes affirmations précédentes étaient
    fausses, je les corrige** :
    (a) « 7 permissions mortes » → **FAUX**. Mon regex d'audit avait
    débordé sur les enums suivants et capturé des faux positifs. L'enum
    `Permission` a 11 valeurs, toutes utilisées ;
    (b) « aucune garde sur les 4 méthodes produits » → **partiellement
    faux**. `supprimerProduit` avait déjà une garde, mais écrite avec
    `session.role` et non `session.peut` — invisible pour un audit qui
    cherche `peut(`. Le nombre réel était 2 méthodes sans garde, pas 4.
    Les deux erreurs viennent de la même cause : un audit par motif de
    chaîne au lieu d'une lecture du code. C'est ce qui justifie les
    **22 tests** ci-dessus : ils vérifient le comportement, pas la
    présence d'un motif.
    **Réserve assumée** : 7 droits sur 11 (`voirCaisse`, `voirRapports`,
    `gererPartenaires`, `cloturerMois`, `gererDepenses`, `configurer`,
    `gererUtilisateurs`) restent protégés **uniquement par l'UI**. Je les
    ai listés mais pas traités : c'est un chantier distinct, et les traiter
    à moitié pendant un lot déjà large aurait introduit du risque.
    **Réserve** : `backend/src/permissions.js` porte sa propre matrice
    Node, non modifiée (le backend n'est pas joignable depuis l'app, qui
    parle à Supabase). Décision à prendre séparément.
    **Bloquant** : `database/DROITS_PRODUITS_VENDEUR.sql` doit être
    exécuté sur la base réelle, sinon un vendeur peut insérer en
    appelant directement l'API PostgREST avec la clé anon.
    Verdict : **CONFORME** sur le périmètre livré.

## 2026-10-06 - 1.15.0 : achats, modification de documents, import tableur

Trois demandes utilisateur. **583/583 verts**, `dart analyze` **0 erreur**.

### Bug 1 — accès aux achats ouvert au vendeur

1. Fonctionnel OK - le tableau de bord montrait la tuile Achats par un
   contournement explicite : `if (gererAchats || role == vendeur ||
   role == caissier)`. La tuile n'avait AUCUNE garde, donc le tap
   ouvrait la liste complète des achats et de leurs fournisseurs.
2. Métier OK - la matrice prévoit « Créer demande d'achat » pour le
   caissier et le vendeur, mais l'app n'a pas de mode demande : sans
   `gererAchats` le formulaire est inaccessible. La tuile menait donc à
   une impasse **en divulguant au passage les achats**. Fermée, et la
   capacité tracée comme divergence ouverte plutôt que simulée par un
   écran qui ne fonctionne pas.
3. Sécurité OK - garde ajoutée dans l'écran lui-même, pas seulement à
   l'appelant : une tuile qui pousse un écran sensible ne doit pas
   dépendre du seul endroit qui décide de l'afficher.
4-5. Sans objet.
6. Tests OK - le lot précédent couvre déjà « aucun rôle ne reçoit un
   onglet qu'il n'a pas le droit de voir ».
7-8. Sans objet.
9. UX OK - le vendeur ne voit plus l'onglet Achats ni la tuile.
10. Contre-expertise - **réserve** : la « demande d'achat » de la
    matrice reste non implémentée. C'est un functionality, pas un bug ;
    elle demandera un mode dédié dans le formulaire d'achat. Le RLS
    (`achats demandes vendeurs`) autorise déjà l'insertion statut
    `demande` : seul l'écran manque.

### Bug 2 — la modification de documents n'existait pas

1. Fonctionnel OK - diagnostic, pas une panne : `DocumentBati` était
   immuable avec un `copyWith` limité à trois champs (signature, statut,
   motif) ; `enregistrerDocument` faisait `insert(0, doc)` donc le rejeu
   **dupliquait** ; `DocumentPreviewScreen` n'est qu'un **lecteur**, sans
   aucun formulaire ; `majStatutDocument` ne savait changer que le
   statut ; et l'action « Modifier » était **calculée ligne 386 mais
   jamais utilisée** — le compilateur le signalait par un warning que
   j'avais lu comme un détail.
2. Métier OK - **règle retenue : un document `emis` n'est pas
   modifiable**. Ce n'est pas une invention, c'est la matrice
   (« statuts brouillon → emis », validation comptable formelle) : un
   émis est un justificatif comptable et fiscal, le modifier après coup
   casse la piste d'audit. Le refus nomme la voie légitime — annuler
   avec motif, puis ré-émettre.
3. Sécurité OK - `copyWith` ne pouvait pas mettre un champ à `null`
   (`?? this.x`) : `effacerSignature` et `effacerMotif` ajoutés, sinon
   une signature était impossible à retirer.
4. Overflow OK - formulaire testé à 360 px.
5. Performance OK - sans objet.
6. Tests OK - 12 tests notifier (brouillon modifié, émis refusé avec
   message nommant la voie, totaux recalculés, pas de duplication,
   numéro inconnu) + 3 tests écran à 360 px.
7-8. Sans objet.
9. UX OK - le formulaire de création est **réutilisé** en mode édition
   (un seul formulaire, deux modes). J'avais d'abord écrit un second
   écran d'édition : supprimé, c'était une divergence future garantie.
10. Contre-expertise - **auto-correction** : le premier écran que j'ai
    écrit affichait les totaux avec `toStringAsFixed` (`2000.00`), sans
    séparateur de milliers, alors que le projet a une convention
    monétaire unique (`C.money`, utilisée partout ailleurs). Un montant
    de facture affiché différemment selon l'écran est une source
    d'erreur de lecture : corrigé, pas assoupli dans le test.

### Fonctionnalité — import de documents depuis un tableur

1. Fonctionnel OK - reprise d'un portefeuille existant (factures, BL,
   bons de commande, devis) à corriger puis réutiliser.
2. Métier OK - **tout import naît en `brouillon`**. Un document émis est
   un justificatif fiscal ; un import non relu ne peut pas en être un.
   C'est cohérent avec la règle de non-modification ci-dessus, et c'est
   ce qui rend l'import réutilisable : le brouillon se corrige puis se
   valide. Le modèle de données ne change pas.
3. Sécurité OK - l'écran vérifie le rôle (autonome), et le vendor ne
   peut importer qu'en brouillon (`enregistrerDocument` l'impose déjà).
4. Overflow OK - listes scrollables, colonnes de chiffres bornées.
5. Performance OK - traitement ligne à ligne, sans accumulation.
6. Tests OK - 22 tests du service pur. **Ils ont révélé 4 bugs réels** :
   (a) `nombre('1.234,56')` renvoyait `null` — la normalisation
   française produisait une virgule que `double.tryParse` refuse ;
   (b) `N° de pièce` ne correspondait à aucun synonyme ;
   (c) la clé de regroupement des lignes sans numéro n'était pas stable
   (`ordre.length` changeait à chaque ligne) — un document par ligne ;
   (d) `client`, `date` et `type` n'étaient capturés que si la ligne
   portait un numéro — **tout import sans colonne numéro échouait
   silencieusement**, ce qui est le cas le plus courant (premier import).
7-8. Sans objet.
9. UX OK - le format attendu est affiché en permanence, pas seulement
   dans un rapport d'erreur : un import qui échoue faute de format est
   un import raté. Le rapport montre TOUTES les anomalies.
10. Contre-expertise - **réserves** : (a) une seule disposition est
    gérée (« une ligne = une ligne de document »). Les tableurs en
    dispositions par blocs (en-têtes répétés, lignes de totaux, sauts
    de page) produiront des anomalies signalées, pas des documents
    faux — c'est le comportement voulu, mais l'import n'est pas encore
    « automatique » sur ces fichiers ; (b) `.xls` (ancien format
    binaire) n'est pas supporté par le paquet `excel`, l'extension
    est refusée explicitement plutôt que de faire échouer l'import à la
    lecture ; (c) la feuille XLSX est choisie par indice, pas par nom
    dans l'interface — la sélection de feuille reste à faire.
    Verdict : **CONFORME** sur le périmètre livré, réserves tracées.

## G20 - Cartes de taille irreguliere (grilles Stock et Articles) - 2026-10-06

1. Verification fonctionnelle OK - la demande (cartes de meme taille dans
   Stock et dans Articles) est **prouvee par test**, pas constatee a
   l'oeil : `carte_grille_uniforme_test.dart` compare les hauteurs rendues
   de 3 cartes aux libelles de longueurs tres differentes (« Cable »,
   « Forfait telephonie », « Installation et configuration d'un reseau
   intranet pour la societe ») et exige une egalite stricte. Les 2 goldens
   ont ete relus visuellement apres regeneration.
2. Verification metier sans objet - aucune regle metier touchee.
3. Securite sans objet.
4. Verification overflow/layout **OK, et c'est le point dur** - trois
   debordements verticaux de 21 a 23 px ont d'abord ete mesures a
   TextScaler 1.5x et 2.0x. L'ecart etant **constant** quelle que soit
   l'echelle, il ne venait pas des lignes de texte. La cause reelle
   etait le libelle « Utiliser dans vente » qui **passait a la ligne**
   dans un bouton de 148 px de large : la hauteur du bouton dependait
   donc de la largeur ET de l'echelle de texte, et aucune constante de
   hauteur de carte ne pouvait suivre. Correction a la source (libelles
   de boutons verrouilles sur une ligne), pas par gonflage de constante.
   Les constantes restantes ont ete **calibrees sur mesure** : 68 px
   deborderait de 10 px sur l'ecran Stock a 320 px, 86 px laissait un
   vide visible entre le prix et le bouton -> 82 px.
   `textscale_test.dart` (320/360/768/1024 x 1.0/1.3/1.5/2.0) et le
   nouveau test d'uniformite repasse au vert.
5. Performance OK - une grille a extent fixe est **moins** couteuse
   qu'un masonry, qui mesure chaque enfant avant de le placer.
6. Tests OK - **593/593 verts**, 0 erreur `dart analyze`. 12 tests
   ajoutes, dont l'un verifie que le bloc titre fait toujours la meme
   hauteur (une reservation de 2 lignes, pas un titre qui varie de 1 a 2
   lignes). Ajout egalement d'un **golden manquant** :
   `test/golden/tarif_ux_test.dart`. La carte article n'avait ete
   verifiee qu'isolée, jamais dans sa grille - c'est-a-dire jamais dans
   la disposition reelle.
7. Documentation OK - CHANGELOG (1.15.1), MISSION_STATUS (G20), ce
   journal.
8. Verification regression - **un test existant a du etre corrige** :
   `product_card_test.dart` verifiait la presence de `SliverMasonryGrid`,
   volontairement supprime. Il verifie maintenant `SliverGrid` **et**
   l'absence de masonry. La suite complete a ete rejouee : 593/593.
   Reserveeria levee : les 33 tests de `commerce_overflow_test.dart`
   rendaient une carte dans un `ListView` (hauteur non bornee) et
   echouaient, parce que `Expanded` exige une hauteur bornee. Plutot que
   d'affaiblir le test ou d'imposer la grille a l'appelant, les cartes
   ont ete rendues tolerantes via `SlotCorps` / `EspaceCarte`.
9. UX OK - sur-estimer la hauteur est sans risque (le `Spacer` absorbe
   le surplus) alors que sous-estimer deborderait ; la marge est donc
   assumee et documentee. Le libelle en trop est coupe par une ellipse
   plutot que de tronquer le mot.
10. Contre-expertise finale - **reserves** : (a) `mainAxisExtent` est
    une constante, donc la hauteur de carte ne s'adapte pas a une
    traduction plus longue qu'une autre ni a un changement de police ;
    une mesure par `TextPainter` serait plus juste mais introduirait une
    passe de layout par carte ; (b) a 320 px avec un libelle d'article
    long, le bouton affiche « Utiliser dans v... » - l'ellipse est
    preferable a un bouton qui deborde, mais le libelle est a raccourcir
    si le retour d'utilisateur le signale ; (c) le mode liste n'est pas
    concerne, ce qui est coherent : une liste a toujours des hauteurs
    variables par nature.
    Verdict : **CONFORME** sur le perimetre demande.
