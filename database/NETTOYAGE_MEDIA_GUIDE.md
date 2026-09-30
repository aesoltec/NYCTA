# Nettoyage des médias en double — procédure pas à pas

> Contexte : la galerie affichait **133 entrées pour 19 images réelles**.
> Trois causes cumulées, corrigées dans le code (v1.13.1). Ce document
> nettoie **les données déjà présentes** — le code n'empêche plus la
> création de doublons, mais ne peut pas défaire l'historique.

## Pourquoi 133 pour 19

| # | Cause | Effet |
|---|---|---|
| 1 | `upsertProduit` recréait un objet cloud `produits/<millisecondes>.jpg` **à chaque enregistrement** | ~9 images → ~114 objets |
| 2 | La galerie ne listait que le préfixe `galerie/`, alors que les images sont dans `produits/` | images invisibles côté galerie |
| 3 | La déduplication comparait le chemin local complet au nom cloud | chaque image comptée 2 fois |

Les trois sont corrigées dans le code (`9adf1fb`). Le nettoyage ci-dessous
supprime les objets devenus orphelins.

---

## ⚠️ AVANT DE COMMENCER

1. **Sauvegarde la base** — Supabase → `Database` → `Backups`, ou :
   ```bash
   supabase db dump --file avant_nettoyage.sql
   ```
2. **Ferme l'application** et ne rouvre pas l'app pendant l'opération.
   Enregistrer un produit pendant le nettoyage recréerait un objet.
3. **Note le nombre d'images** de référence :
   - bucket `media`, dossier `produits` → **9**
   - bucket `produits`, dossier `produits` → **10**

---

## Étape 1 — Diagnostic (lecture seule, ne modifie rien)

Ouvre **Supabase → SQL Editor** et colle le contenu de
[`DIAGNOSTIC_DOUBLONS_MEDIA.sql`](DIAGNOSTIC_DOUBLONS_MEDIA.sql), puis *Run*.

**Ce que tu dois voir** : une ligne par objet du bucket, avec

- `utilise` = `OUI - NE PAS SUPPRIMER` → image rattachée à un produit, un
  article, un client ou l'entreprise → **elle reste**
- `utilise` = `NON - ORPHELIN (supprimable)` → personne ne la référence
- `format_fichier` = `ancien format (millisecondes)` → trace du bug corrigé

**Point d'arrêt** : compare le nombre de lignes marquées
`OUI - NE PAS SUPPRIMER` avec ton relevé (9 + 10 = 19).

- **Si c'est 19** → le script est cohérent, passe à l'étape 2.
- **Si c'est ≠ 19** → **arrête-toi** et dis-moi le nombre. Cela signifierait
  qu'une table référence des images que je n'ai pas liste (signature
  client, documents, purchases…), et le script serait incomplet.

### Compte rapide (facultatif)

Le script contient une 2ᵉ requête commentée pour compter par bucket et
par format. Décommente-la pour un résumé chiffré.

---

## Étape 2 — Installer la fonction de nettoyage

Dans le même SQL Editor, colle **la fonction seule** de
[`NETTOYAGE_MEDIA_ORPHELINS.sql`](NETTOYAGE_MEDIA_ORPHELINS.sql)
(de la ligne `create or replace function` à son `$$;` final), puis *Run*.

Elle **ne supprime rien** à ce stade : elle installe la fonction
`public.nettoyer_media_orphelins(seuil_confirmation, dry_run)`.

---

## Étape 3 — Lister sans rien supprimer

```sql
select * from public.nettoyer_media_orphelins(-1, true);
```

- Le seuil `-1` ne peut **jamais** correspondre au nombre d'orphelins
  détectés : la fonction s'arrête et se contente de lister.
- Chaque ligne doit dire `ORPHELIN (conserve : seuil = -1)`.
- **Recompte les lignes** : c'est ton nombre `N`.

---

## Étape 4 — Valider le nombre (simulation)

```sql
select * from public.nettoyer_media_orphelins(N, true);   -- N = ton compte
```

Cette fois le seuil correspond. Chaque ligne doit dire
`SUPPRIMER (simulation)` — **rien n'est encore supprimé** (`dry_run = true`).

C'est la dernière occasion de t'arrêter : relis la liste.

---

## Étape 5 — Exécuter

```sql
select * from public.nettoyer_media_orphelins(N, false);  -- dry_run = false
```

- Chaque ligne doit dire `SUPPRIME`.
- Une ligne `ERREUR : …` signale un problème sur **cette** image seulement :
  les autres sont traitées normalement. Note le message et signale-le moi.
- La fonction exclut les images de marque (`logo`, `cachet`, `signature`)
  même si elles semblaient orphelines.

---

## Étape 6 — Vérifier

Rejoue le diagnostic de l'étape 1. Il ne doit plus rester **aucune** ligne
`NON - ORPHELIN (supprimable)`.

Ouvre ensuite l'application → menu Plus → **Galerie d'images** : le compte
doit maintenant correspondre à tes images réelles.

---

## Étape 7 — Nettoyage final (facultatif)

La fonction n'a plus sa raison d'être :

```sql
drop function if exists public.nettoyer_media_orphelins(integer, boolean);
```

---

## Si le nettoyage échoue

| Symptôme | Cause probable | Solution |
|---|---|---|
| `ERREUR : ... does not exist` sur `storage.delete_object` | API storage non exposée | Le repli `delete from storage.objects` est automatique. Si les deux échouent, supprime depuis le Dashboard → Storage. |
| Aucune ligne `SUPPRIME` | Seuil `N` différent du compte de l'étape 3 | Rejouer l'étape 3 et utiliser le nouveau nombre |
| Les images disparaissent de la galerie après nettoyage | Un objet encore référencé a été supprimé | Restaure le backup, et donne-moi le nom du fichier concerné |
| Le compte ne revient pas à 19 | Des doublons **locaux** subsistent | Les fichiers locaux sont sur l'appareil, pas en base : vide le dossier `media/produit` de l'app ou réinstalle l'app |

---

## Et après : que reste-t-il à faire ?

Le nettoyage ne fait que supprimer les orphelins. Les **~9 images de
format ancien** qui sont encore référencées gardent leur URL en base — elles
fonctionnent, mais leur nom ne suit pas la convention actuelle.

Pour les réaligner, il suffit d'**enregistrer chaque produit** une fois
depuis l'app : `upsertProduit` republie le fichier sous son nom d'origine
avec `upsert: true` et met à jour l'URL. Le nom actuel apparaît alors dans
le diagnostic (`format_fichier` = `format actuel`).

C'est une opération manuelle, volontaire et sans risque — dis-moi si tu
veux que je te fasse un script pour la faire en masse.
