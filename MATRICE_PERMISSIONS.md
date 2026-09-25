# MATRICE DES PERMISSIONS — NYCTA

> Référence unique des droits. Toute divergence entre ce document, `lib/models/enums.dart`
> (`rolePermissions`), les écrans Flutter et les policies RLS Supabase est un bug.
> Légende : ✅ plein · 📝 demande uniquement · ❌ aucun.

| Capacité | Admin | Gérant | Comptable | Caissier | Vendeur | Stagiaire | Partenaire |
|---|---|---|---|---|---|---|---|
| Vendre (toutes activités) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | forfaits à son nom |
| Gérer stock (créer/modifier) | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Retirer un article du stock | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Voir caisse / trésorerie | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Voir rapports / analytique | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer partenaires + clôturer | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Gérer dépenses | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer achats (CRUD, valider, recevoir, payer, annuler) | ✅ | ✅ | ✅ | 📝 | 📝 | ❌ | ❌ |
| Créer demande d'achat | ✅ | ✅ | ✅ | 📝 | 📝 | ❌ | ❌ |
| Gérer documents | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Gérer utilisateurs | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Configurer (entreprise, listes) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

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

## Limites assumées

- Mot de passe/email d'un AUTRE compte : impossible avec la clé anon → lien de
  réinitialisation Supabase Auth depuis l'écran Utilisateurs (traçabilité via
  les logs Auth, pas de colonne dédiée).
- Fichiers SQL applicables : `database/supabase_schema_consolide.sql`,
  `database/migration_achats.sql`, `database/migration_mouvements_stock.sql`,
  `database/migration_fixes_critiques_rls.sql` (à exécuter dans cet ordre).
