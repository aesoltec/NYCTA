import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistance de session Supabase dans le **keystore chiffré** du
/// téléphone (Keychain iOS / Keystore Android) au lieu du stockage partagé
/// en clair. Les jetons d'accès et de rafraîchissement ne sont jamais
/// lisibles par une autre application.
class SecureSessionStorage implements LocalStorage {
  static const _cle = 'sb_session';
  final FlutterSecureStorage _stockage;

  // Le constructeur par défaut d'AndroidOptions chiffre déjà fortement
  // (AES-GCM + clé RSA-OAEP protégée par le Keystore) — plus besoin de
  // encryptedSharedPreferences, supprimé dans flutter_secure_storage 11.
  SecureSessionStorage()
      : _stockage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  // Malgré son nom, le contrat LocalStorage.accessToken() attend le JSON
  // COMPLET de la session (Supabase fait ensuite en interne
  // Session.fromJson(json.decode(...)) dessus pour restaurer currentUser à
  // l'ouverture de l'app) — pas le seul champ access_token. C'est aussi
  // exactement ce que persistSession() a stocké ci-dessous : on le renvoie
  // tel quel, sans le reparser.
  @override
  Future<String?> accessToken() => _stockage.read(key: _cle);

  @override
  Future<void> persistSession(String json) =>
      _stockage.write(key: _cle, value: json);

  @override
  Future<void> removePersistedSession() => _stockage.delete(key: _cle);
}
