import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Photos produits, logo, cachet : import galerie ou appareil photo,
/// puis copie dans le stockage privé de l'app (chemin stable).
class MediaService {
  static final _picker = ImagePicker();

  static Future<String?> pickImage({bool camera = false}) async {
    try {
      final x = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (x == null) return null;
      // CRITIQUE : le chemin retourné pointe vers le CACHE (effacé par le
      // système). On COPIE l'image dans le stockage privé de l'app pour
      // qu'elle survive aux redémarrages.
      return await copierDansApp(File(x.path));
    } catch (_) {
      return null; // permission refusée ou indisponible : fallback icône
    }
  }

  /// Copie un fichier image vers <docs>/images/ — chemin stable, persistant.
  static Future<String> copierDansApp(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final dossier = Directory('${dir.path}/images');
    if (!dossier.existsSync()) await dossier.create(recursive: true);
    final dest = File('${dossier.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await source.copy(dest.path);
    return dest.path;
  }

  /// Persiste des octets PNG (ex : signature manuscrite) dans l'app.
  static Future<String> savePng(Uint8List bytes, String nom) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$nom.png');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  static bool existe(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();
}
