import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Vignette tolérante : chemin local **ou** URL cloud, placeholder sinon.
///
/// `AppImage` ne sait lire qu'un fichier local (il teste
/// `File.existsSync()`), alors que la galerie doit aussi montrer les
/// images encore cloud-only. D'où ce widget dédié, au même contrat visuel
/// (jamais d'exception, jamais de boîte vide).
class MediaThumb extends StatelessWidget {
  final String? chemin;
  final double taille;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final Color fond;

  const MediaThumb(
    this.chemin, {
    super.key,
    this.taille = 96,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fallbackIcon = Icons.image_outlined,
    this.fond = const Color(0xFFECEFF3),
  });

  bool get _estUrl => chemin != null && chemin!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final c = chemin;
    Widget child;
    if (c == null || c.isEmpty) {
      child = _placeholder();
    } else if (_estUrl) {
      child = CachedNetworkImage(
        imageUrl: c,
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        // Placeholder STATIQUE (pas de Shimmer) : la galerie est
        // rechargée souvent et un shimmer permanent casserait
        // `pumpAndSettle` des tests d'overflow.
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
        fadeInDuration: const Duration(milliseconds: 200),
      );
    } else {
      final f = File(c);
      child = f.existsSync()
          ? Image.file(f, width: taille, height: taille, fit: BoxFit.cover)
          : _placeholder();
    }
    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _placeholder() => Container(
        width: taille,
        height: taille,
        color: fond,
        child: Icon(fallbackIcon, size: taille * 0.4, color: const Color(0xFF90A4AE)),
      );
}
