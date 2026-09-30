import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/produit.dart';
import '../../models/tarif.dart';
import '../../services/cloud_repository.dart';
import '../../services/media_service.dart';
import '../gallery/gallery_service.dart';
import '../models/media_item.dart';

/// Galerie interne : index des images disponibles et bascule d'affectation
/// vers les produits du stock et les articles du catalogue.
///
/// Volontairement **mince** : toute la logique de décision est dans
/// `GalleryService` (pur, testé) ; ce Notifier ne fait que l'accès disque /
/// cloud et la persistance via les Notifiers existants. C'est le 17e
/// Notifier, branché par `NotifierWiring` comme les 16 autres.
class GalleryNotifier extends ChangeNotifier {
  final List<Produit> produits;
  final List<Tarif> catalogue;
  final Future<String?> Function(Produit p) majProduitLocal;
  final Future<void> Function(Tarif t) majTarifLocal;

  /// Média affiché en cours d'upload (feedback UI).
  bool _occupe = false;
  bool get occupe => _occupe;

  /// Dernière erreur (message prêt à afficher), vidée à chaque action.
  String? erreur;
  String? succes;

  GalleryNotifier({
    required this.produits,
    required this.catalogue,
    required this.majProduitLocal,
    required this.majTarifLocal,
  });

  /// Reconstruction complète de l'index : scan du stockage local
  /// (banque + copies d'affectation) + listing du bucket, puis fusion
  /// avec les images référencées par les entités.
  Future<List<MediaItem>> charger() async {
    erreur = null;
    try {
      final stockes = <MediaItem>[];
      for (final dossier in MediaService.dossiersGalerie) {
        for (final f in await MediaService.listerImages(dossier)) {
          stockes.add(MediaItem(
            cle: f.path,
            cheminLocal: f.path,
            dossier: dossier,
            modifieLe: f.statSync().modified,
          ));
        }
      }
      // Cloud : la banque survit au reinstall / changement d'appareil.
      for (final chemin in await CloudRepository.listerMedia()) {
        final url = CloudRepository.urlMedia(chemin);
        if (url.isEmpty) continue;
        final dejaVu = stockes.indexWhere(
            (m) => m.cheminCloud != null && m.cheminCloud == chemin.split('/').last);
        if (dejaVu >= 0) {
          stockes[dejaVu] = stockes[dejaVu].copyWith(urlCloud: url);
        } else {
          stockes.add(MediaItem(
            cle: chemin,
            urlCloud: url,
            dossier: 'galerie',
          ));
        }
      }
      return GalleryService.indexer(
        stockes: stockes,
        produits: produits,
        tarifs: catalogue,
      );
    } catch (e) {
      erreur = 'Galerie illisible : $e';
      return const [];
    }
  }

  /// Usages d'une image (produits / articles qui la référencent).
  List<MediaUsage> usagesDe(MediaItem item) =>
      GalleryService.usages(produits: produits, tarifs: catalogue)[item.cle] ??
      const [];

  /// Upload dans la banque (bucket `media/galerie/` + copie locale).
  /// [source] est le fichier déjà compressé par `MediaService`. Retourne
  /// la clé créée, ou null (erreur renseignée dans [erreur]).
  Future<String?> televerser(File source) async {
    erreur = null;
    succes = null;
    if (_occupe) return null;
    _occupe = true;
    notifyListeners();
    try {
      final chemin = await MediaService.copierDansApp(source,
          entite: 'galerie', id: 'banque', compresserImage: false);
      await CloudRepository.televerserMedia(File(chemin));
      succes = 'Image ajoutée à la galerie';
      return chemin;
    } catch (e) {
      erreur = 'Envoi impossible : $e';
      return null;
    } finally {
      _occupe = false;
      notifyListeners();
    }
  }

  /// Rattache une image de la banque à un produit. null si refusé.
  Future<String?> affecterProduit(String produitId, MediaItem item) async {
    erreur = null;
    succes = null;
    final i = produits.indexWhere((p) => p.id == produitId);
    if (i < 0) {
      erreur = 'Produit introuvable';
      return erreur;
    }
    final maj = GalleryService.affecterProduit(
        produits[i], item.cle, produits: produits);
    if (maj == null) {
      erreur = produits[i].images.contains(item.cle)
          ? 'Cette image est déjà sur ce produit'
          : 'Galerie pleine (${Produit.maxImages} images maximum)';
      return erreur;
    }
    await majProduitLocal(maj);
    succes = 'Image ajoutée à « ${maj.libelle} »';
    return null;
  }

  /// Retire une image d'un produit (le fichier reste dans la banque).
  Future<String?> retirerProduit(String produitId, MediaItem item) async {
    erreur = null;
    succes = null;
    final i = produits.indexWhere((p) => p.id == produitId);
    if (i < 0) return erreur = 'Produit introuvable';
    final maj = GalleryService.retirerProduit(
        produits[i], item.cle, produits: produits);
    if (maj == null) return erreur = 'Image non attachée à ce produit';
    await majProduitLocal(maj);
    succes = 'Image retirée de « ${maj.libelle} »';
    return null;
  }

  /// Rattache une image à un article du catalogue.
  Future<String?> affecterTarif(String tarifId, MediaItem item) async {
    erreur = null;
    succes = null;
    final i = catalogue.indexWhere((t) => t.id == tarifId);
    if (i < 0) return erreur = 'Article introuvable';
    final maj =
        GalleryService.affecterTarif(catalogue[i], item.cle, tarifs: catalogue);
    if (maj == null) {
      erreur = catalogue[i].images.contains(item.cle)
          ? 'Cette image est déjà sur cet article'
          : 'Galerie pleine (${Produit.maxImages} images maximum)';
      return erreur;
    }
    await majTarifLocal(maj);
    succes = 'Image ajoutée à « ${maj.libelle} »';
    return null;
  }

  /// Retire une image d'un article du catalogue.
  Future<String?> retirerTarif(String tarifId, MediaItem item) async {
    erreur = null;
    succes = null;
    final i = catalogue.indexWhere((t) => t.id == tarifId);
    if (i < 0) return erreur = 'Article introuvable';
    final maj =
        GalleryService.retirerTarif(catalogue[i], item.cle, tarifs: catalogue);
    if (maj == null) return erreur = 'Image non attachée à cet article';
    await majTarifLocal(maj);
    succes = 'Image retirée de « ${maj.libelle} »';
    return null;
  }

  /// SUPPRESSION DÉFINITIVE : détache l'image de tous les produits et
  /// articles qui la référencent (en ne persistant QUE ceux-là), puis
  /// efface le fichier local et l'objet du bucket.
  ///
  /// Réservé à l'admin / gérant (garde vérifiée dans l'écran, pas ici :
  /// le Notifier ne connaît pas les permissions). Retourne un message
  /// d'erreur, ou null si l'opération est passée.
  Future<String?> supprimerDefinitif(MediaItem item) async {
    erreur = null;
    succes = null;
    final detaches =
        GalleryService.detacher(item.cle, produits: produits, tarifs: catalogue);
    final n = detaches.produits.length + detaches.tarifs.length;
    // Persister les entités détachées AVANT de perdre la référence.
    for (final id in detaches.produits) {
      final i = produits.indexWhere((p) => p.id == id);
      if (i >= 0) await majProduitLocal(produits[i]);
    }
    for (final id in detaches.tarifs) {
      final i = catalogue.indexWhere((t) => t.id == id);
      if (i >= 0) await majTarifLocal(catalogue[i]);
    }
    final localSupprime = await MediaService.supprimerFichier(item.cheminLocal);
    final cheminCloud = item.cheminCloud;
    if (cheminCloud != null) await CloudRepository.supprimerMedia(cheminCloud);
    succes = [
      if (n > 0) 'détachée de $n entité(s) ;',
      if (localSupprime) 'fichier effacé'
      else if (item.cheminLocal != null) 'fichier local NON effacé (protégé)'
      else 'aucun fichier local',
    ].join(' ');
    return null;
  }

  /// Vide les messages (à l'ouverture de l'écran).
  void razMessages() {
    erreur = null;
    succes = null;
  }
}
