# MATRICE DES PERMISSIONS — NYCTA

> Référence unique des droits. Toute divergence entre ce document, `lib/models/enums.dart`
> (`rolePermissions`), les écrans Flutter et les policies RLS Supabase est un bug.
> Légende : ✅ plein · 📝 demande uniquement · ❌ aucun.

| Capacité | Admin | Gérant | Comptable | Caissier | Vendeur | Stagiaire | Partenaire |
|---|---|---|---|---|---|---|---|
| Vendre (toutes activités) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | forfaits à son nom |
| Ventes à crédit + encaissement | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Relances clients (impayés) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Gérer stock (créer/modifier) | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
> Décision documentée (exigences #9/#10) : le vendeur modifie les fiches
> (autonomie terrain : prix, photo, seuil) mais ne retire jamais d'article
> (bouton masqué + garde `Store.supprimerProduit` + trigger serveur).
| Retirer un article du stock | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
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
- `produits` : vendeur peut insérer/modifier mais **jamais archiver** — trigger
  `verrouiller_archivage_produit()` (admin/gérant seuls), miroir du garde
  `Store.supprimerProduit` et du bouton masqué dans `StockScreen`.
- `charges` / `documents` (`created_by NOT NULL`) : le client envoie toujours
  l'auteur réel ; défaut serveur `auth.uid()` en garde-fou (plus de 23502).
- `transactions` : écriture par rôle + boutique ; partenaire : forfaits à son nom.
- Journal d'audit : triggers sur toutes les tables métier (`journal_activite`).
- `ecritures` : **insert seul** (aucun update/delete) — corrections par
  contre-écriture applicative ; lecture boutiques accessibles.

## Limites assumées

- Mot de passe/email d'un AUTRE compte : impossible avec la clé anon → lien de
  réinitialisation Supabase Auth depuis l'écran Utilisateurs (traçabilité via
  les logs Auth, pas de colonne dédiée).
- Fichiers SQL applicables (v3.0) : `database/supabase_schema.sql` PUIS
  `database/supabase_fonctions_rls.sql` (base neuve) ; base existante :
  `database/supabase_migration.sql` PUIS `database/supabase_fonctions_rls.sql`.
  Contrôle : `database/VERIFIER_RLS.sql`.
