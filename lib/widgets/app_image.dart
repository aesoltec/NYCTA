import 'dart:io';
import 'package:flutter/material.dart';

/// Image fichier avec fallback élégant (jamais d'erreur, jamais de box vide).
class AppImage extends StatelessWidget {
  final String? path;
  final double size;
  final double? width, height;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final Color fallbackBackground;

  const AppImage(
    this.path, {
    super.key,
    this.size = 48,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor = const Color(0xFF90A4AE),
    this.fallbackBackground = const Color(0xFFECEFF3),
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final ok = path != null && path!.isNotEmpty && File(path!).existsSync();
    return ClipRRect(
      borderRadius: borderRadius,
      child: ok
          ? Image.file(File(path!), width: w, height: h, fit: BoxFit.cover)
          : Container(
              width: w,
              height: h,
              color: fallbackBackground,
              child: Icon(fallbackIcon, size: size * 0.5, color: fallbackColor),
            ),
    );
  }
}
