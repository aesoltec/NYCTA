import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Carrousel multi-images (max 5) avec pagination par points.
/// Local d'abord, URL cloud ensuite, placeholder sinon.
/// Tap → galerie plein écran ([PhotoViewGallery]).
class ImageCarousel extends StatefulWidget {
  final List<String> images;
  final double height;
  final BorderRadius borderRadius;

  const ImageCarousel(
    this.images, {
    super.key,
    this.height = 150,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(14)),
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controleur = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  List<String> get _liste => widget.images.take(5).toList();

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    if (liste.isEmpty) return _placeholder();
    return GestureDetector(
      onTap: () => _pleinEcran(context, liste),
      child: Stack(children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controleur,
            itemCount: liste.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: widget.borderRadius,
              child: _image(liste[i]),
            ),
          ),
        ),
        if (liste.length > 1)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < liste.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                ]),
          ),
      ]),
    );
  }

  Widget _image(String chemin) {
    if (chemin.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: chemin,
        width: double.infinity,
        height: widget.height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
        fadeInDuration: const Duration(milliseconds: 250),
      );
    }
    final fichier = File(chemin);
    if (fichier.existsSync()) {
      return Image.file(fichier,
          width: double.infinity, height: widget.height, fit: BoxFit.cover);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF3),
          borderRadius: widget.borderRadius,
        ),
        child: const Icon(Icons.image_outlined,
            size: 44, color: Color(0xFF90A4AE)),
      );

  void _pleinEcran(BuildContext context, List<String> liste) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black),
              body: PhotoViewGallery.builder(
                itemCount: liste.length,
                builder: (_, i) {
                  final c = liste[i];
                  final provider = c.startsWith('http')
                      ? CachedNetworkImageProvider(c)
                      : FileImage(File(c)) as ImageProvider;
                  return PhotoViewGalleryPageOptions(
                      imageProvider: provider,
                      heroAttributes:
                          PhotoViewHeroAttributes(tag: 'img_$i'));
                },
                pageController: PageController(initialPage: _page),
              ),
            )));
  }
}
