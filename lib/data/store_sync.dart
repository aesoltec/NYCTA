import '../models/charge.dart';
import '../models/produit.dart';
import '../models/tarif.dart';
import '../models/transaction.dart';
import '../services/cloud_repository.dart';
import '../services/sync_service.dart';
import 'helpers.dart';
import 'store.dart';

/// Aides cloud/fichier du Store (Phase 6bis) : hors de la classe pour
/// que `store.dart` reste une façade. Toutes prennent le [Store] en
/// argument — aucune n'a d'état propre.
class StoreSync {
  const StoreSync._();

  /// Passage d'un produit en catalogue (même libellé, prix = prix de
  /// vente) : la vente sans stock et les documents le réutilisent sans
  /// double saisie. Ne duplique jamais une entrée existante.
  static Future<void> catalogueDepuisProduit(Store s, Produit p) async {
    final i = s.catalogue.indexWhere(
        (t) => t.actif && StoreHelpers.memeLibelle(t.libelle, p.libelle));
    if (i >= 0) {
      if (s.catalogue[i].prix != p.prixVente ||
          s.catalogue[i].categorie != p.categorie) {
        s.catalogue[i] = s.catalogue[i]
            .copyWith(prix: p.prixVente, categorie: p.categorie);
        s.notifier();
        await CloudRepository.upsertTarif(s.catalogue[i]);
        await fileUpsert(s, 'tarifs', payloadTarif(s.catalogue[i]));
      }
      return;
    }
    final t = Tarif(
      id: s.genererId(),
      libelle: p.libelle.trim(),
      categorie: p.categorie,
      prix: p.prixVente,
      description: 'Depuis le stock',
      actif: true,
      dateAjout: DateTime.now(),
    );
    s.catalogue.add(t);
    s.notifier();
    await CloudRepository.upsertTarif(t);
    await fileUpsert(s, 'tarifs', payloadTarif(t));
  }

  /// Mouvement de stock tracé (vente, réception, retour, ajustement).
  static Future<void> journaliser(
    Store s, {
    required String produitId,
    required String produitNom,
    required String type,
    required int quantite,
    required int stockApres,
    required String boutiqueId,
    String motif = '',
    String refId = '',
    DateTime? date,
  }) =>
      s.stockMouvements.journaliser(
        produitId: produitId,
        produitNom: produitNom,
        type: type,
        quantite: quantite,
        stockApres: stockApres,
        boutiqueId: boutiqueId,
        motif: motif,
        refId: refId,
        date: date,
      );

  /// Vente atomique depuis le stock : transaction + compta. Pont utilisé
  /// par `ProduitNotifier` (le Notifier stock n'a pas le Notifier ventes).
  static Future<String> venteProduit(
    Store s, {
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    DateTime? date,
    Map<String, dynamic> details = const {},
  }) =>
      s.transaction.ajouterTransaction(
        type: type,
        montant: montant,
        cout: cout,
        clientNom: clientNom,
        date: date,
        details: details,
      );

  /// Élit la boutique courante d'un profil : première boutique réellement
  /// accessible, sinon la première du jeu. Utilisé par le repli hors-ligne
  /// (`chargerSnapshotLocal`), où aucun snapshot ne porte d'identifiant
  /// courant — sans cet appel, l'app démarrerait avec une boutique neutre
  /// et TOUTES les listes vides alors que les données locales existent.
  static void elireBoutiqueAccessible(Store s) {
    if (s.boutiques.isEmpty) return;
    final accessibles = s.boutiques.where((b) => s.user.accedeA(b.id));
    s.definirBoutiqueCourante(
        accessibles.isNotEmpty ? accessibles.first.id : s.boutiques.first.id);
  }

  /// Propage la boutique courante aux Notifiers qui filtrent par boutique.
  static void synchroniserBoutique(Store s, String boutiqueId) {
    s.boutique.boutiqueId = boutiqueId;
    s.transaction.boutiqueId = boutiqueId;
    s.charge.boutiqueId = boutiqueId;
    s.produit.boutiqueId = boutiqueId;
    s.achat.boutiqueId = boutiqueId;
    s.document.boutiqueId = boutiqueId;
    s.compta.boutiqueId = boutiqueId;
    s.analytique.boutiqueId = boutiqueId;
    s.client.boutiqueId = boutiqueId;
  }

  /// File d'attente hors-ligne (SyncService) : no-op sans cloud.
  static Future<void> fileUpsert(
      Store s, String table, Map<String, dynamic> payload) async {
    if (!CloudRepository.actif) return;
    await SyncService().mettreEnFile(payload, table: table);
  }

  static Map<String, dynamic> payloadProduit(Produit p) => {
        'id': p.id,
        'boutique_id': p.boutiqueId,
        'libelle': p.libelle,
        'categorie': p.categorie,
        'prix_achat': p.prixAchat,
        'prix_vente': p.prixVente,
        'quantite_stock': p.stock,
        'seuil_alerte': p.seuil,
        'date_ajout': p.dateAjout?.toIso8601String(),
        'actif': true,
      };

  static Map<String, dynamic> payloadTarif(Tarif t) => {
        'id': t.id,
        'libelle': t.libelle,
        'categorie': t.categorie,
        'prix': t.prix,
        'description': t.description,
        'actif': t.actif,
        'images': t.images,
        'date_ajout': t.dateAjout?.toIso8601String(),
      };

  static Map<String, dynamic> payloadCharge(Charge c) => {
        'id': c.id,
        'boutique_id': c.boutiqueId,
        'categorie': c.categorie,
        'libelle': c.libelle,
        'montant': c.montant,
        'date_charge': c.date.toIso8601String(),
        'recurrente': c.recurrente,
      };

  static Map<String, dynamic> payloadTransaction(Tx tx) => {
        'id': tx.id,
        'boutique_id': tx.boutiqueId,
        'employe_id': tx.employeId,
        'type': CloudTx.dbValue(tx.type),
        'montant': tx.montant,
        'cout': tx.cout,
        'statut': tx.statut.name,
        'client_nom': tx.clientNom,
        'partenaire_id': tx.partenaireId,
        'details': tx.details,
        'date_transaction': tx.date.toIso8601String(),
      };

  /// Numérotation atomique des documents (compteur). Cloud : RPC
  /// séquentielle (atomique côté serveur) ; sinon compteur local porté
  /// par le profil entreprise.
  static Future<String> numeroDocument(Store s, String prefixe) async {
    if (CloudRepository.actif) {
      final numero = await CloudRepository.prochainNumero(prefixe);
      if (numero != null) return numero;
    }
    final (numero, nouveauProfile) = s.profile.prochainNumero(prefixe);
    s.profile = nouveauProfile;
    s.notifier();
    return numero;
  }

  /// Re-télécharge une signature client (chemin storage → fichier
  /// temporaire local) pour l'aperçu et la régénération PDF après
  /// rechargement. Null si absente ou inaccessible.
  static Future<String?> signatureLocale(String? chemin) async {
    if (chemin == null || chemin.isEmpty) return null;
    if (!CloudRepository.actif) return null;
    return CloudRepository.telechargerSignature(chemin);
  }
}
