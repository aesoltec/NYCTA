import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../models/charge.dart';
import '../../models/produit.dart';
import '../../services/cloud_repository.dart';
import '../normalisation.dart';

/// Catégories dynamiques + listes du formulaire de vente
/// (Phase 1 — découpage Store).
/// Rôle : catsProduit/catsCharge, opérateurs, domaines, durées forfait.
/// Dépendances : listes `produits` et `depenses` (renommage en cascade,
/// garde-fou suppression) — injectées par la façade (Phase 5 : vraies
/// listes partagées).
/// Extrait à l'identique de `Store` (l.758-883), `memeCategorie` via
/// `Normalisation` (mêmes règles casse + accents, point 35).
class CategorieNotifier extends ChangeNotifier {
  final List<Produit> produits;
  final List<Charge> depenses;

  final List<String> catsProduit;
  final List<String> catsCharge;
  final List<String> opsMobileMoney;
  final List<String> opsCredit;
  final List<String> domainesPresta;
  final List<String> dureesForfaitListe;

  CategorieNotifier({
    required this.produits,
    required this.depenses,
    List<String>? catsProduit,
    List<String>? catsCharge,
    List<String>? opsMobileMoney,
    List<String>? opsCredit,
    List<String>? domainesPresta,
    List<String>? dureesForfaitListe,
  })  : catsProduit = catsProduit ?? List<String>.of(C.categoriesProduit),
        catsCharge = catsCharge ?? List<String>.of(categoriesCharge),
        opsMobileMoney = opsMobileMoney ?? List<String>.of(C.operateurs),
        opsCredit = opsCredit ?? List<String>.of(C.operateursCredit),
        domainesPresta = domainesPresta ?? List<String>.of(C.domaines),
        dureesForfaitListe =
            dureesForfaitListe ?? List<String>.of(C.dureesForfait);

  Future<String?> ajouterCategorie(String nom,
      {required bool produit}) async {
    final n = nom.trim();
    if (n.length < 2) return 'Nom trop court (2 caractères min.)';
    final liste = produit ? catsProduit : catsCharge;
    final existant =
        liste.where((c) => Normalisation.memeCategorie(c, n)).firstOrNull;
    if (existant != null) {
      return 'Cette catégorie existe déjà (« $existant »)';
    }
    liste.add(n);
    notifyListeners();
    await CloudRepository.upsertCategorie(
        produit ? 'produit' : 'charge', n);
    return null;
  }

  Future<String?> renommerCategorie(String ancien, String nouveau,
      {required bool produit}) async {
    final liste = produit ? catsProduit : catsCharge;
    final n = nouveau.trim();
    if (n.length < 2) return 'Nom trop court';
    if (liste.any(
        (c) => c != ancien && Normalisation.memeCategorie(c, n))) {
      return 'Cette catégorie existe déjà';
    }
    final i = liste.indexOf(ancien);
    if (i < 0) return 'Catégorie introuvable';
    liste[i] = n;
    // Renommage en cascade sur les fiches existantes.
    if (produit) {
      for (var j = 0; j < produits.length; j++) {
        if (produits[j].categorie == ancien) {
          final p = produits[j];
          produits[j] = Produit(
            id: p.id,
            boutiqueId: p.boutiqueId,
            libelle: p.libelle,
            categorie: n,
            prixAchat: p.prixAchat,
            prixVente: p.prixVente,
            stock: p.stock,
            seuil: p.seuil,
            imagePath: p.imagePath,
            images: p.images,
          );
        }
      }
    } else {
      for (var j = 0; j < depenses.length; j++) {
        if (depenses[j].categorie == ancien) {
          final c = depenses[j];
          depenses[j] = Charge(
            id: c.id,
            boutiqueId: c.boutiqueId,
            categorie: n,
            libelle: c.libelle,
            montant: c.montant,
            date: c.date,
            recurrente: c.recurrente,
          );
        }
      }
    }
    notifyListeners();
    await CloudRepository.upsertCategorie(
        produit ? 'produit' : 'charge', n);
    await CloudRepository.supprimerCategorie(
        produit ? 'produit' : 'charge', ancien);
    return null;
  }

  /// Suppression avec garde-fou : catégorie en cours d'utilisation.
  Future<String?> supprimerCategorie(String nom,
      {required bool produit}) async {
    final utilisee = produit
        ? produits.any((p) => p.categorie == nom)
        : depenses.any((c) => c.categorie == nom);
    if (utilisee) {
      return 'Catégorie utilisée par des fiches existantes — renommez-la '
          'pour préserver l\'historique.';
    }
    (produit ? catsProduit : catsCharge).remove(nom);
    notifyListeners();
    await CloudRepository.supprimerCategorie(
        produit ? 'produit' : 'charge', nom);
    return null;
  }

  List<String> _listeDynamique(String type) => switch (type) {
        'operateur_momo' => opsMobileMoney,
        'operateur_credit' => opsCredit,
        'domaine_prestation' => domainesPresta,
        'duree_forfait' => dureesForfaitListe,
        _ => throw ArgumentError('Type de liste inconnu : $type'),
      };

  Future<String?> ajouterValeurListe(String type, String nom) async {
    final n = nom.trim();
    if (n.isEmpty) return 'Valeur requise';
    final liste = _listeDynamique(type);
    if (liste.any((v) => v.toLowerCase() == n.toLowerCase())) {
      return 'Cette valeur existe déjà';
    }
    liste.add(n);
    notifyListeners();
    await CloudRepository.upsertCategorie(type, n);
    return null;
  }

  Future<String?> renommerValeurListe(
      String type, String ancien, String nouveau) async {
    final liste = _listeDynamique(type);
    final n = nouveau.trim();
    if (n.isEmpty) return 'Valeur requise';
    if (liste.any(
        (v) => v != ancien && v.toLowerCase() == n.toLowerCase())) {
      return 'Cette valeur existe déjà';
    }
    final i = liste.indexOf(ancien);
    if (i < 0) return 'Valeur introuvable';
    liste[i] = n;
    notifyListeners();
    await CloudRepository.upsertCategorie(type, n);
    await CloudRepository.supprimerCategorie(type, ancien);
    return null;
  }

  Future<String?> supprimerValeurListe(String type, String nom) async {
    _listeDynamique(type).remove(nom);
    notifyListeners();
    await CloudRepository.supprimerCategorie(type, nom);
    return null;
  }
}
