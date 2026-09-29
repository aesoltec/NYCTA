// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../store_sync.dart';
import '../../core/validators.dart';
import '../../models/tarif.dart';
import '../../services/cloud_repository.dart';

/// Façade StoreCatalogueFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreCatalogueFacade on Store {
  // ---------- Catégories (délégué à `categories`, Phase 5) ----------

  Future<String?> ajouterCategorie(String nom,
          {required bool produit}) =>
      categories.ajouterCategorie(nom, produit: produit);

  Future<String?> renommerCategorie(String ancien, String nouveau,
          {required bool produit}) =>
      categories.renommerCategorie(ancien, nouveau, produit: produit);

  Future<String?> supprimerCategorie(String nom,
          {required bool produit}) =>
      categories.supprimerCategorie(nom, produit: produit);

  Future<String?> ajouterValeurListe(String type, String nom) =>
      categories.ajouterValeurListe(type, nom);

  Future<String?> renommerValeurListe(
          String type, String ancien, String nouveau) =>
      categories.renommerValeurListe(type, ancien, nouveau);

  Future<String?> supprimerValeurListe(String type, String nom) =>
      categories.supprimerValeurListe(type, nom);

  List<Tarif> get tarifsActifs => catalogue.where((t) => t.actif).toList();

  Future<String?> ajouterTarif(Tarif t) async {
    final e = V.texte(t.libelle, 2, 'Libellé');
    if (e != null) return e;
    if (t.prix <= 0) return 'Le prix doit être > 0';
    if (catalogue.any((x) =>
        x.actif &&
            Store.memeCategorie(x.libelle, t.libelle.trim()))) {
      return 'Un article du même nom existe déjà';
    }
    final tarif = Tarif(
      id: genererId(), libelle: t.libelle, categorie: t.categorie,
      prix: t.prix, description: t.description, actif: t.actif,
      images: t.images,
      dateAjout: t.dateAjout ?? DateTime.now(),
    );
    catalogue.add(tarif);
    notifyListeners();
    await CloudRepository.upsertTarif(tarif);
    await fileUpsert('tarifs', StoreSync.payloadTarif(tarif));
    return null;
  }

  Future<String?> majTarif(Tarif t) async {
    final i = catalogue.indexWhere((x) => x.id == t.id);
    if (i < 0) return 'Article introuvable';
    if (t.prix <= 0) return 'Le prix doit être > 0';
    // Date d'ajout d'origine conservée (badge Nouveau stable en modif).
    catalogue[i] =
        t.dateAjout == null && catalogue[i].dateAjout != null
            ? t.copyWith(dateAjout: catalogue[i].dateAjout)
            : t;
    notifyListeners();
    await CloudRepository.upsertTarif(t);
    await fileUpsert('tarifs', StoreSync.payloadTarif(t));
    return null;
  }

  Future<void> supprimerTarif(String id) async {
    final i = catalogue.indexWhere((t) => t.id == id);
    if (i >= 0) {
      catalogue[i] = catalogue[i].copyWith(actif: false);
      notifyListeners();
      await CloudRepository.upsertTarif(catalogue[i]);
      await fileUpsert('tarifs', StoreSync.payloadTarif(catalogue[i]));
    }
  }

}
