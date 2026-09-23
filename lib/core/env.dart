import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Accès typé aux variables du fichier .env (complété après déploiement).
/// Chaque accesseur a une valeur de secours : l'app démarre même sans .env.
class Env {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env absent (ex : premier lancement) → valeurs de secours utilisées.
    }
  }

  static String get appName => _get('APP_NAME', 'PME Gestion');
  static String get appEnv => _get('APP_ENV', 'development');
  static String get apiBaseUrl => _get('API_BASE_URL', 'http://localhost:3000/api');
  static String get storageUrl => _get('STORAGE_URL', 'http://localhost:3000/uploads');
  static int get maxUploadMb => int.tryParse(_get('MAX_UPLOAD_MB', '5')) ?? 5;

  static String get supabaseUrl => _get('SUPABASE_URL', '');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY', '');
  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get firebaseConfigured =>
      _get('FIREBASE_API_KEY', '').isNotEmpty &&
      _get('FIREBASE_PROJECT_ID', '').isNotEmpty;

  static String _get(String key, String fallback) {
    // dotenv.maybeGet() lève NotInitializedError si load() n'a jamais été
    // appelé (ex. widget test qui monte l'UI sans passer par main()) — ce
    // garde-fou honore la promesse de cette classe : accès sûr même sans .env.
    if (!dotenv.isInitialized) return fallback;
    return dotenv.maybeGet(key, fallback: fallback) ?? fallback;
  }
}
