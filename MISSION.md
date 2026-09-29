# MISSION.md — PLAN DE CORRECTION TOTALE 100 % — NYCTA / PME Gestion

Document d'exécution autonome pour openCode. Objectif : corriger tous les points terrain constatés + résoudre la dette architecturale (Store monolithe) + atteindre 100 % de conformité fonctionnelle. Règle absolue : traiter tous les points ci-dessous sans poser de question, de façon professionnelle, efficace et autonome. Après chaque phase : flutter analyze = 0 erreur et flutter test vert. Date : 2026-09-26.

---

## PRÉAMBULE — LECTURE OBLIGATOIRE

Avant toute action, lis INTÉGRALEMENT :
- AGENTS.md (règles de qualité, 10 passes d'audit, preuves obligatoires)
- MISSION_STATUS.md (état d'avancement des points)
- PASSES_AUDIT.md (journal des décisions)
- CAHIER_DES_CHARGES.md (périmètre officiel)
- MATRICE_PERMISSIONS.md (rôles et permissions)

Ce plan s'exécute EN COMPLÉMENT des règles déjà définies dans AGENTS.md.

Après CHAQUE point traité :
- Mets à jour MISSION_STATUS.md (statut ✅ + preuve + date).
- Documente les 10 passes d'audit dans PASSES_AUDIT.md.
- Mets à jour CHANGELOG.md.
- Fournis 3 preuves minimum (code + test + capture).
- flutter analyze = 0 erreur, flutter test = 100% vert.
- Commit atomique + push.

---

## CRITÈRES D'ARRÊT

Tu t'arrêtes et rapportes UNIQUEMENT si :
1. Blocage matériel (SQL à exécuter sur Supabase réel, émulateur requis, clé API manquante).
2. Décision métier critique nécessitant validation (SYSCOHADA, RLS, sécurité).
3. Impossibilité technique absolue (dépendance manquante impossible à installer).

Pour tout le reste, tu continues sans m'interrompre.

---

## RÈGLES D'EXÉCUTION OBLIGATOIRES

1. Lire intégralement ce document avant toute modification.
2. Ne jamais supprimer de code fonctionnel avant d'avoir créé l'équivalent.
3. Chaque phase doit laisser l'application démarrable et les parcours critiques opérationnels (login → vente → journal → stock → documents).
4. Conserver le mode démo (sans Supabase) et le mode cloud.
5. Toute image (logo, signature, cachet, produits, articles d'achat) doit survivre au redémarrage (copie locale + URL cloud stable).
6. Tous les exports PDF / Excel (CSV) / CSV doivent contenir des données réelles (jamais de cadre vide).
7. Les filtres (période, intervalle, catégorie, sous-catégorie, type, client, montant…) doivent être cohérents d'un écran à l'autre.
8. Respecter la matrice de permissions existante (MATRICE_PERMISSIONS.md / rolePermissions).
9. Commits clairs par phase : fix(domaine): description.
10. Ne pas toucher aux dossiers android/, ios/, database/ sauf si une migration SQL est explicitement requise et documentée.

---

## PARTIE A — CORRECTIONS FONCTIONNELLES TERRAIN

### A1. Réorganisation menu « Plus » et navigation

Problèmes :
- Bouton Journal actuellement mal placé.
- Ordre des boutons du menu Plus non professionnel.

Actions :
1. Dans l'écran shell / bottom navigation / menu Plus :
   - Déplacer le bouton Journal dans l'onglet Plus.
   - Mettre le bouton Achats à la place libérée (navigation principale ou position proéminente selon le design actuel).
2. Réordonner les entrées de l'onglet Plus de façon professionnelle et logique :
   1. Tableau de bord / Accueil (si présent)
   2. Achats & Fournisseurs
   3. Journal des opérations
   4. Stock & Inventaire
   5. Documents commerciaux
   6. Clients & Relances
   7. Partenaires hotspot
   8. Charges & Dépenses
   9. Trésorerie
   10. Comptabilité
   11. Rapports financiers
   12. Analytique CA & Dépenses
   13. Statistiques & Graphiques
   14. Tarifs & Catégories
   15. Boutiques
   16. Utilisateurs
   17. Configuration entreprise
   18. Sauvegardes & Exports
   19. À propos / Aide
3. Masquer les entrées selon la matrice de permissions (déjà en place — vérifier que le nouvel ordre ne casse pas le masquage).

Après ce point : flutter analyze = 0 erreur, flutter test = 100% vert. Vérifier anti-overflow (petits écrans + TextScaler 2.0). Commit : feat(menu): réorganisation onglet Plus + déplacement Journal/Achats. Mise à jour MISSION_STATUS.md.

---

### A2. Images persistantes (critique)

Problèmes :
- Logo, signature, cachet entreprise et images produits disparaissent après redémarrage.
- Images ajoutées dans les buckets Supabase non rechargées.
- Produits et articles d'achat doivent accepter jusqu'à 5 images (optionnel).

Actions :

1. Modèle de données
   - Produit : remplacer imagePath (String?) par List<String> imagePaths (max 5).
   - Articles d'achat (lignes d'achat) : ajouter List<String> imagePaths (max 5, optionnel).
   - CompanyProfile : conserver logoPath, cachetPath, signaturePath mais garantir le rechargement.

2. MediaService — Stratégie de persistance (règle absolue) :
   1. TOUJOURS copier l'image localement d'abord (path_provider).
   2. Sauvegarder le chemin local dans le modèle.
   3. ENSUITE, si mode cloud, uploader vers Supabase Storage (bucket media).
   4. Si l'upload réussit, stocker aussi l'URL cloud.
   5. Si l'upload échoue, garder uniquement le local (l'image reste visible).
   6. Au chargement : essayer le local d'abord ; si absent, essayer le cloud ; si les deux absents, afficher placeholder.
   7. Ne JAMAIS dépendre uniquement du cloud.

3. UI
   - Formulaire produit : sélecteur multi-images (max 5) avec aperçu + suppression individuelle.
   - Formulaire article d'achat : idem (images optionnelles).
   - Affichage liste stock / détail : carousel ou grille des images.

4. Migration douce
   - Si une ancienne donnée a encore imagePath (string unique), la convertir en imagePaths: [imagePath] au chargement.

5. Test de non-régression
   - Ajouter une image à un produit → redémarrer l'app (mode démo) → l'image doit être visible.
   - Même test en mode cloud après chargerDuCloud.

Après ce point : flutter analyze = 0 erreur, flutter test = 100% vert. Commit : fix(images): persistance locale + cloud + multi-images (max 5). Mise à jour MISSION_STATUS.md.

---

### A3. Exports PDF / Excel (CSV) / CSV — Réutilisation et correction

VÉRIFICATION PRÉALABLE :
- lib/services/export_service.dart existe déjà (créé dans le batch 1).
- lib/widgets/filtre_panel.dart existe déjà (créé dans le batch 1).
- RÉUTILISE-LES. Ne duplique PAS.
- Si une méthode manque (ex. exportExcel), ENRICHIS l'existant.

Problème récurrent : impression / export PDF affiche un cadre vide ; formats Excel/CSV manquants sur plusieurs écrans.

Actions transverses :
1. Vérifier que ExportService couvre :
   - exporterPdf({required String titre, required List<List<String>> lignes, List<String>? enTetes, CompanyProfile? profil}).
   - exportCsv({required String nomFichier, required List<List<String>> lignes, List<String>? enTetes}) → BOM UTF-8 + séparateur ; + protection formules Excel (préfixe ').
   - exportExcelCompat = alias de CSV (les fichiers s'ouvrent dans Excel).
2. Vérifier que ExportService inclut : en-tête entreprise (nom, RCCM, IFU, logo si disponible), date de génération, filtres appliqués, message « Aucune donnée pour la période sélectionnée » si vide.
3. Jamais de PDF vide :
   - Vérifier que les listes de données ne sont pas vides avant génération.
   - Inclure en-tête entreprise.
   - Inclure date et filtres.
   - Si aucune donnée : afficher un message « Aucune donnée » dans le PDF (pas un cadre blanc).
4. Brancher ce service sur tous les écrans listés ci-dessous (A4 → A14).

Après ce point : flutter analyze = 0 erreur, flutter test = 100% vert. Commit : fix(exports): service central + correction PDF vides. Mise à jour MISSION_STATUS.md.

---

### A4. Journal

- Bouton déplacé vers Plus (voir A1).
- Vérifier que l'export PDF journalier (clôture de caisse) fonctionne et n'est pas vide.
- Conserver les filtres existants ; s'assurer que période / activité / client sont opérationnels.

Après ce point : commit + MISSION_STATUS.md.

---

### A5. Achats & Fournisseurs

Actions :
1. Filtres : période (du/au), intervalle prédéfini (7j / 30j / mois / année), catégorie, sous-catégorie, statut (demande / validé / reçu / payé / annulé), fournisseur.
2. Export : boutons PDF + CSV/Excel dans l'écran Achats (et historique).
3. Images sur articles achetés : max 5 images optionnelles par ligne d'achat (voir A2).
4. PDF vide : corriger la génération (utiliser ExportService + données réelles des achats filtrés).
5. Écran Fournisseurs :
   - Filtre par spécialité + barre de recherche (nom, téléphone, email).
   - Export PDF + CSV/Excel de la liste fournisseurs.

Après ce point : commit feat(achats): filtres + exports + images articles + MISSION_STATUS.md.

---

### A6. Stock

Actions :
1. Filtres : catégorie, sous-catégorie, seuil d'alerte (stock bas), boutique, recherche libellé.
2. Export PDF + CSV/Excel (inventaire valorisé + quantités).
3. Images multiples (max 5) + persistance (A2).
4. Vérifier que les mouvements de stock restent tracés après les modifications.

Après ce point : commit + MISSION_STATUS.md.

---

### A7. Dépenses / Charges

Actions :
1. Filtres : catégorie, sous-catégorie, période, intervalle, boutique, récurrente oui/non.
2. Export PDF + CSV/Excel des dépenses filtrées.

Après ce point : commit + MISSION_STATUS.md.

---

### A8. Partenaires hotspot

Actions :
1. Export PDF + CSV/Excel (liste partenaires + parts du mois / historique clôtures).
2. Vérifier que la clôture mensuelle et le calcul des parts restent corrects.

Après ce point : commit + MISSION_STATUS.md.

---

### A9. Trésorerie

Actions :
1. Filtres : catégorie, sous-catégorie, type (fonds / encaissement / dépense), période, intervalle.
2. Export PDF + CSV/Excel (solde, mouvements, fonds de roulement).

Après ce point : commit + MISSION_STATUS.md.

---

### A10. Rapport financier + Analytique CA & Dépenses + Statistiques & Graphiques

Actions communes :
1. Filtres unifiés : catégorie, sous-catégorie, type, période exacte, intervalle (7j / 30j / mois / année / personnalisé).
2. Export PDF + CSV/Excel sur chaque écran (données filtrées + graphiques en tableau pour le PDF si pertinent).
3. Vérifier que les agrégats (CA, marge, dépenses, CAGR…) correspondent aux filtres appliqués.

Après ce point : commit + MISSION_STATUS.md.

---

### A11. Comptabilité

Problèmes :
- Module non terminé / non branché → aucune donnée n'apparaît.
- Manque export et filtres.

Actions :
1. Brancher les données :
   - S'assurer que chaque transaction / charge / paiement génère bien les écritures comptables (partie double) dans le Store / cloud.
   - Charger les écritures au chargerDuCloud et en mode local.
   - Afficher journal, balance, compte de résultat, TVA, rapprochement pointé avec les données réelles.
2. Filtres : période, intervalle de temps, type d'écriture (VT/AC/BQ/OD), boutique.
3. Export PDF + CSV/Excel (journal, balance, résultat).
4. Si le module est structurellement incomplet : finaliser le minimum viable (journal + balance + résultat) avant d'ajouter des exports.

Après ce point : commit fix(compta): branchement + filtres + exports + MISSION_STATUS.md.

---

### A12. Tarifs & Catégories + Formulaire article / produit

Actions :
1. Filtres / recherche sur la liste des catégories.
2. Formulaire ajouter / modifier article (produit) :
   - Champ Catégorie :
     - Liste déroulante des catégories existantes (depuis catsProduit / table catégories Supabase).
     - Champ de saisie libre si la catégorie n'existe pas.
     - À la validation : si nouvelle catégorie → l'ajouter en base (local + Supabase) en évitant les doublons (comparaison insensible à la casse / trim).
   - Champ Images : multi-sélection jusqu'à 5 images (A2).
3. Même logique de catégorie pour les charges si applicable.

Après ce point : commit feat(tarifs): formulaire catégorie intelligente + images + MISSION_STATUS.md.

---

### A13. Documents commerciaux

Actions :
1. Audit de conformité :
   - En-tête (nom, RCCM, IFU, adresse, contacts, logo).
   - Numérotation atomique.
   - Totaux HT / TVA / TTC.
   - Signature + cachet entreprise.
   - Types : facture, devis, BC, ticket, BL (sans prix).
   - Workflow brouillon → émis → payé / annulé.
2. Signatures :
   - Signature entreprise (et cachet) : position à gauche.
   - Prévoir un espace vide à droite intitulé « Signature client » (cadre + mention) pour signature manuscrite au stylo une fois le document imprimé.
   - La signature client capturée dans l'app (si utilisée) reste supportée en plus de l'espace papier.
3. Historique des documents (documents émis) :
   - Corriger le bottom overflowed by 33 pixels (ListView / Expanded / padding / SafeArea).
   - Ajouter filtres : période, intervalle, type de document, client, date, montant (min/max), statut, boutique.
   - Export PDF / CSV de l'historique filtré.

Après ce point : commit fix(documents): signatures + overflow + filtres + MISSION_STATUS.md.

---

### A14. Boutiques / Catégories / Clients / Liste formulaire de vente

Boutiques :
- Ajouter barre de recherche + filtres (actif/inactif, siège).

Catégories :
- Ajouter barre de recherche + filtre par type (produit / charge / opérateur…).

Clients :
- Recherche + filtres (boutique, avec/sans crédit…).
- Formulaire client : ajouter champs optionnels :
  - Coordonnées complètes (adresse détaillée)
  - Logo client (image optionnelle)
  - Références commerciales : RIB, RCCM, IFU, coordonnées bancaires
- Export PDF + CSV/Excel de la liste clients.

Liste du formulaire de vente :
- Audit de conformité : champs dynamiques par activité, validations, permissions, multi-boutiques, offline.
- Corriger tout écart constaté (validation montants, catégories, images si matériel, etc.).

Après ce point : commit feat(modules): boutiques + catégories + clients + vente + MISSION_STATUS.md.

---

## PARTIE B — DETTE ARCHITECTURALE (STORE MONOLITHE) — OPTIONNELLE

IMPORTANT : Le découpage complet du Store est un chantier lourd (5 phases, plusieurs semaines). Il NE DOIT PAS bloquer la livraison du 100% fonctionnel.

DÉCISION :
- Priorité 1 : Terminer la Partie A (100% fonctionnel).
- Priorité 2 : Livrer le 100% avec le Store actuel.
- Priorité 3 (optionnelle) : Découpage du Store, en branche séparée refactor/store-decoupage, après validation de la Partie A.

Vérifie l'existence de PLAN_DECOUPAGE_STORE.md.
- S'il existe ET que la Partie A est terminée : commence le découpage.
- Sinon : IGNORE la Partie B.

Ordre imposé (si tu commences) :
B0. Phase 0 — Services purs (StockService, CaisseService, PartageService, AnalytiqueService) + tests
B1. Phase 1 — SessionNotifier + BoutiqueNotifier + ProfileNotifier + façade Store
B2. Phase 2 — StockNotifier + CaisseNotifier + VenteAtomiqueUseCase
B3. Phase 3 — ChargesNotifier + AchatsNotifier + DocumentsNotifier
B4. Phase 4 — PartenairesNotifier + ClientsNotifier + UsersNotifier + CollabNotifier
B5. Phase 5 — Nettoyage façade + suppression progressive du monolithe store.dart
B6. (Optionnel) Migration Riverpod

Contrainte : les corrections de la Partie A doivent être appliquées sur le code actuel puis reportées dans les nouveaux Notifiers au fur et à mesure du découpage.

---

## PARTIE C — POINTS TRANSVERSES AUDIT

1. Persistance images (A2) — priorité absolue.
2. Exports non vides (A3) — priorité absolue.
3. Filtres homogènes sur tous les écrans listés.
4. Comptabilité branchée (A11).
5. Overflow historique documents (A13).
6. Menu Plus réordonné (A1).
7. Formulaire catégorie intelligente (A12).
8. Multi-images produits + articles d'achat (A2).
9. Champs clients enrichis (A14).
10. Espace signature client papier sur PDF documents (A13).

---

## ORDRE D'EXÉCUTION GLOBAL (openCode)

Exécuter dans cet ordre strict, sans demander de confirmation :
Étape 1  → A2  (Images persistantes + multi-images max 5)
Étape 2  → A3  (ExportService central + correction PDF vides)
Étape 3  → A1  (Réorganisation menu Plus + déplacement Journal / Achats)
Étape 4a → A5  (Achats + Fournisseurs)
Étape 4b → A6  (Stock)
Étape 4c → A7  (Dépenses)
Étape 4d → A8  (Partenaires)
Étape 4e → A9  (Trésorerie)
Étape 4f → A10 (Rapport + Analytique + Stats)
Étape 4g → A11 (Comptabilité)
Étape 4h → A14 (Boutiques + Catégories + Clients + Vente)
Étape 5  → A12 (Tarifs & Catégories + formulaire catégorie intelligente + images)
Étape 6  → A13 (Documents + signatures gauche/droite + overflow historique + filtres)
Étape 7  → A4  (Journal — vérifications finales)
Étape 8  → B0 → B5 (Découpage Store — OPTIONNEL, seulement si PLAN_DECOUPAGE_STORE.md existe)
Étape 9  → Vérification globale (checklist ci-dessous)

---

## CHECKLIST DE VALIDATION FINALE 100 %

Navigation & UX
- [ ] Journal déplacé dans Plus
- [ ] Achats en position proéminente
- [ ] Ordre professionnel des boutons Plus
- [ ] Permissions toujours respectées

Images
- [ ] Logo / signature / cachet visibles après redémarrage (démo + cloud)
- [ ] Images produits visibles après redémarrage
- [ ] Jusqu'à 5 images par produit
- [ ] Jusqu'à 5 images par article d'achat (optionnel)

Exports
- [ ] Aucun PDF vide (données ou message explicite)
- [ ] CSV/Excel (BOM UTF-8, ;) sur : Achats, Stock, Dépenses, Partenaires, Trésorerie, Rapport financier, Analytique, Statistiques, Comptabilité, Documents historique, Fournisseurs, Clients
- [ ] En-tête entreprise présent sur les PDF

Filtres
- [ ] Période + intervalle + catégorie + sous-catégorie (et type/client/montant selon écran) sur tous les modules listés

Modules spécifiques
- [ ] Comptabilité affiche des données réelles
- [ ] Formulaire produit/catégorie : sélection + saisie libre + anti-doublon + création auto
- [ ] Documents : signature entreprise à gauche + espace « Signature client » à droite
- [ ] Historique documents : plus d'overflow + filtres complets
- [ ] Clients : champs RIB/RCCM/banque/logo optionnels + recherche/filtre + export
- [ ] Boutiques & Catégories : recherche + filtre
- [ ] Fournisseurs : filtre spécialité + recherche + export

Architecture
- [ ] Store découpé selon PLAN_DECOUPAGE_STORE.md (phases B0–B5) — si PLAN_DECOUPAGE_STORE.md existe
- [ ] flutter analyze = 0 erreur
- [ ] flutter test = 100 % vert
- [ ] Mode démo + mode cloud + offline/sync opérationnels

Parcours critiques manuels
- [ ] Login → vente → journal
- [ ] Ajout produit avec 3 images → redémarrage → images présentes
- [ ] Création achat → réception → export PDF non vide
- [ ] Document facture PDF : logo + signature gauche + cadre signature client droite
- [ ] Clôture partenaire + export

---

## NOTES TECHNIQUES POUR OPENCODE

- Réutiliser au maximum pdf + printing + share_plus déjà présents.
- Réutiliser ExportService et FiltrePanel existants (ne pas dupliquer).
- Pour le multi-images : stocker une liste de chemins/URLs ; UI avec ListView horizontal d'aperçus + bouton « + ».
- Pour la catégorie intelligente : DropdownButtonFormField + TextFormField conditionnel, ou Autocomplete / recherche ; à la sauvegarde, upsert catégorie (trim + toLowerCase pour unicité).
- Overflow 33 px : inspecter le widget fautif dans documents_history_screen.dart (probablement Row/Column sans Expanded ou padding insuffisant sous SafeArea).
- Ne pas inventer de nouvelles règles métier : se caler sur le comportement actuel de store.dart et des services existants.
- Toute migration de modèle (imagePath → imagePaths) doit être rétro-compatible au chargement.
- Après chaque point : mise à jour MISSION_STATUS.md, PASSES_AUDIT.md, CHANGELOG.md, commit atomique, push.

---

## RAPPEL FINAL

Ta réputation d'expert senior en dépend. Aucune supposition. Aucune complaisance. Aucune négligence. Chaque point compte. Chaque preuve compte. Chaque test compte. Honnêteté sur les limites (documenter ce qui est hors périmètre, ne pas masquer).

COMMENCE MAINTENANT par l'Étape 1 (A2 — Images persistantes). ENCHAÎNE SANS T'ARRÊTER JUSQU'À LA CHECKLIST 100% VALIDÉE.

---

Fin du plan. Ce document est autonome. openCode doit l'exécuter intégralement, phase par phase, sans question intermédiaire, jusqu'à la checklist 100 % validée.