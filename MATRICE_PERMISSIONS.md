# MATRICE DES PERMISSIONS — NYCTA

> Référence unique des droits. Toute divergence entre ce document, `lib/models/enums.dart`
> (`rolePermissions`), les écrans Flutter et les policies RLS Supabase est un bug.
> Légende : ✅ plein · 📝 demande uniquement · ❌ aucun.

| Capacité | Admin | Gérant | Comptable | Caissier | Vendeur | Stagiaire | Partenaire |
|---|---|---|---|---|---|---|---|
| Vendre (toutes activités) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | forfaits à son nom |
| Ventes à crédit + encaissement | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Relances clients (impayés) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Consulter le stock (lecture) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Créer un article (fiche catalogue) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Modifier un article | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Ajuster une quantité | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
> Décision documentée (exigences #9/#10) : le vendeur modifie les fiches
> (autonomie terrain : prix, photo, seuil) mais ne retire jamais d'article
> (bouton masqué + garde `Store.supprimerProduit` + trigger serveur).
| Retirer / archiver un article | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

> **Décision (option A, 2026-10-03).** La ligne unique « Gérer stock
> (créer/modifier) » confiait au vendeur **trois actes de nature
> différente** : créer une fiche catalogue, modifier une fiche, retirer
> un article. Créer une fiche fixe le **prix d'achat, donc la marge** —
> c'est un acte de direction, pas une autonomie terrain. Le vendeur
> conserve ce qui est justifié :
>
> - la **lecture** du stock — indispensable, il ne doit pas vendre un
>   article inexistant ou absent de son étagère ;
> - la **modification** de ses fiches — autonomie terrain : prix de
>   vente, photo, seuil, quantité constatée ;
> - il ne **crée** pas d'article et ne **retire** rien (action absente du
>   menu, garde métier `ProduitNotifier`, policy RLS, trigger serveur).
| Voir caisse / trésorerie | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Voir rapports / analytique | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer partenaires + clôturer | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Gérer dépenses | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer achats (CRUD, valider, recevoir, payer, annuler) | ✅ | ✅ | ✅ | 📝 | 📝 | ❌ | ❌ |
| Créer demande d'achat | ✅ | ✅ | ✅ | 📝 | 📝 | ❌ | ❌ |
| Gérer documents | ✅ | ✅ | ✅ | ✅ | ciblé* | ❌ | ❌ |
| Valider documents (brouillon→émis) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Pointer écritures (rapprochement) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer utilisateurs | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Configurer (entreprise, listes) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

\* Matrice documentaire (mission §2.9, normes internationales) :

| Document | Admin | Gérant | Comptable | Caissier | Vendeur |
|---|---|---|---|---|---|
| Ticket de caisse (preuve immédiate) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Facture simple (mentions RCCM/IFU/TVA, n° unique) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Devis proforma (offre, sans valeur comptable) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bordereau de livraison (**sans prix**, quantités + signatures livreur/réceptionnaire) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bon de commande fournisseur (engagement d'achat) | ✅ | ✅ | ✅ | ❌ | ❌ |

> Validation comptable formelle et envoi officiel : rôles supérieurs
> (comptable, manager) — suivi applicatif à venir (statuts `brouillon`→`emis`).
> Signature à main levée : `SignaturePad` → profil entreprise → apposée sur
> l'aperçu et intégrée au PDF (base64 via `printing`/`pdf`).

## Règles serveur (RLS Supabase, défense en profondeur)

- `achats` : écriture admin/gérant/comptable + boutique ; **vendeur/caissier : INSERT
  `statut='demande'` uniquement** (policy `achats demandes vendeurs`) — toute demande
  directe en `en_attente`/`valide` est rejetée (42501).
- `produits` : **insertion admin/gérant uniquement** (option A — le vendeur ne
  crée pas de fiche) ; **modification admin/gérant/vendeur** ;
  **archivage refusé** hors admin/gérant — trigger
  `verrouiller_archivage_produit()`, miroir des gardes métier
  `ProduitNotifier.retirerProduit` et de l'absence d'action dans
  `StockScreen`. Migration à appliquer sur la base réelle :
  `database/DROITS_PRODUITS_VENDEUR.sql`.
- **Barre de navigation basse filtrée** : `AppShell.onglets()` dérive les
  onglets des droits du rôle. Avant correction c'était une liste `const`
  de 5 destinations — un vendeur pouvait ouvrir « Achats » et
  « Dépenses » alors que le menu « Plus » les lui cachait. Deux
  entrées, deux traitements : exactement l'écart que ce document
  qualifie de bug.

## Limites assumées

- Mot de passe/email d'un AUTRE compte : impossible avec la clé anon → lien de
  réinitialisation Supabase Auth depuis l'écran Utilisateurs (traçabilité via
  les logs Auth, pas de colonne dédiée).
- Fichiers SQL applicables (v3.0) : `database/supabase_schema.sql` PUIS
  `database/supabase_fonctions_rls.sql` (base neuve) ; base existante :
  `database/supabase_migration.sql` PUIS `database/supabase_fonctions_rls.sql`.
  Contrôle : `database/supabase_verify.sql`.
