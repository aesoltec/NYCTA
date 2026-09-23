import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../core/secure_session.dart';

/// Couche Supabase : base + auth + stockage images, SANS serveur.
/// Si SUPABASE_URL n'est pas renseigné dans .env → désactivé, l'app
/// fonctionne en mode local démo (Store en mémoire), comme avant.
class SupabaseService {
  static bool get _configure =>
      Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty;

  static Future<void> init() async {
    if (!_configure) return; // mode local démo
    // Stockage de session chiffré UNIQUEMENT là où le keystore existe
    // (Android/iOS/macOS). Web/Desktop → stockage navigateur par défaut.
    final sessionSecurisee = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        // Rafraîchissement automatique du jeton avant expiration.
        autoRefreshToken: true,
        // Session persistée dans le keystore CHIFFRÉ quand supporté.
        localStorage: sessionSecurisee ? SecureSessionStorage() : null,
      ),
    );
  }

  static SupabaseClient? get client =>
      _configure ? Supabase.instance.client : null;

  static User? get utilisateur => client?.auth.currentUser;

  // ---------- Auth ----------
  /// `signInWithPassword` lève une exception (AuthApiException) sur
  /// identifiants invalides — elle ne renvoie jamais un utilisateur null.
  /// Avant ce correctif, rien ne l'attrapait ici ni dans LoginScreen : un
  /// mauvais mot de passe faisait planter le Future en silence, le bouton
  /// restait bloqué sur son indicateur de chargement indéfiniment, sans
  /// aucun message d'erreur (rien dans l'UI, juste une exception perdue
  /// dans la console). Le try/catch restaure le contrat `Future<bool>` :
  /// false = échec de connexion, quelle qu'en soit la cause (identifiants
  /// invalides, réseau, projet Supabase injoignable).
  static Future<bool> connexion(String email, String mdp) async {
    final c = client;
    if (c == null) return false;
    try {
      final res = await c.auth.signInWithPassword(email: email, password: mdp);
      return res.user != null;
    } catch (e) {
      debugPrint('❌ SupabaseService.connexion : $e');
      return false;
    }
  }

  /// Profil métier de l'utilisateur connecté (rôle, nom).
  static Future<Map<String, dynamic>?> monProfil() async {
    final c = client;
    final uid = utilisateur?.id;
    if (c == null || uid == null) return null;
    final rows = await c.from('users').select().eq('id', uid).limit(1);
    return rows.isNotEmpty ? rows.first : null;
  }

  // ---------- CRUD typés ----------
  static Future<List<Map<String, dynamic>>> transactions(String boutiqueId) =>
      client!.from('transactions').select()
          .eq('boutique_id', boutiqueId)
          .order('date_transaction', ascending: false)
          .limit(500);

  static Future<List<Map<String, dynamic>>> produits(String boutiqueId) =>
      client!.from('produits').select().eq('boutique_id', boutiqueId);

  static Future<void> ajouterTransaction(Map<String, dynamic> tx) =>
      client!.from('transactions').insert(tx);

  // ---------- Stockage images (bucket « media ») ----------
  /// Upload une image locale → retourne l'URL publique (ou null si échec).
  static Future<String?> uploadImage(File fichier, String dossier) async {
    final c = client;
    if (c == null) return null;
    try {
      final nom = '$dossier/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await c.storage.from('media').upload(nom, fichier);
      return c.storage.from('media').getPublicUrl(nom);
    } catch (_) {
      return null;
    }
  }

  // ---------- Profil entreprise ----------
  static Future<Map<String, dynamic>?> profile() async {
    final rows = await client!.from('company_profile').select().limit(1);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> majProfile(Map<String, dynamic> data) =>
      client!.from('company_profile').update(data).eq('id', 1);

  // ---------- Clôture mensuelle ----------
  static Future<Map<String, dynamic>?> cloturerPartage({
    required String partenaireId,
    required String boutiqueId,
    required String mois,
  }) async {
    final rows = await client!.rpc('cloturer_partage', params: {
      'p_partenaire': partenaireId,
      'p_boutique': boutiqueId,
      'p_mois': mois,
    }) as List<dynamic>;
    return rows.isNotEmpty ? rows.first as Map<String, dynamic> : null;
  }
}
