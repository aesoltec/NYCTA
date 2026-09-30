import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';
import '../../../data/notifiers/gallery_notifier.dart';
import '../../../services/media_service.dart';
import 'cible_gallery_sheet.dart';
import 'media_dialogs.dart';

/// Actions de la galerie : téléverser, affecter, supprimer (unitaire et
/// lot). Isolées de l'écran (règle « widgets < 200 lignes »).
///
/// Dépendances injectées : l'écran ne transmet que le contexte, le
/// Notifier, le rappel de rechargement et le diffuseur de messages. Chaque
/// action renvoie `true` si l'index doit être reconstruit.
class GalleryActions {
  final BuildContext _context;
  final GalleryNotifier _gallery;
  final Future<void> Function() onRafraichir;
  final void Function(String?) onMessage;

  const GalleryActions({
    required BuildContext context,
    required GalleryNotifier gallery,
    required this.onRafraichir,
    required this.onMessage,
  })  : _context = context,
        _gallery = gallery;

  /// Téléverse jusqu'à 10 images dans la banque.
  Future<bool> televerser() async {
    final chemins =
        await MediaService.pickImages(max: 10, entite: 'galerie');
    if (chemins.isEmpty || !_context.mounted) return false;
    for (final c in chemins) {
      await _gallery.televerser(File(c));
    }
    await onRafraichir();
    return true;
  }

  /// Rattache l'image à un produit du stock ou à un article du catalogue.
  Future<bool> affecter(MediaItem m) async {
    if (!_context.mounted) return false;
    final erreur = await choisirCible(
      _context,
      titre: 'Affecter l\'image à…',
      action: 'Affecter',
      item: m,
      action_: (type, id) => type == 'produit'
          ? _gallery.affecterProduit(id, m)
          : _gallery.affecterTarif(id, m),
    );
    if (erreur != null) {
      onMessage(erreur);
      return false;
    }
    await onRafraichir();
    return true;
  }

  /// Suppression définitive d'une image (confirmation détaillée).
  Future<bool> supprimer(MediaItem m) async {
    if (!await confirmerSuppressionMedia(_context, m, _gallery.usagesDe(m))) {
      return false;
    }
    final err = await _gallery.supprimerDefinitif(m);
    if (err != null) {
      onMessage(err);
      return false;
    }
    await onRafraichir();
    return true;
  }

  /// Suppression en LOT : une confirmation, puis chaque image.
  Future<bool> supprimerLot(List<MediaItem> choisies) async {
    if (choisies.isEmpty) return false;
    if (!await confirmerSuppressionLot(_context, choisies, _gallery.usagesDe)) {
      return false;
    }
    var echecs = 0;
    for (final m in choisies) {
      if (await _gallery.supprimerDefinitif(m) != null) echecs++;
    }
    await onRafraichir();
    onMessage(echecs == 0
        ? '${choisies.length} image(s) supprimée(s)'
        : '${choisies.length - echecs} supprimée(s), $echecs échec(s)');
    return true;
  }
}
