import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';

/// Couche d'accès à l'API REST (backend/ — Node + MySQL + JWT).
/// Mode actuel : le Store local reste la source (démo hors-ligne).
/// Branchage : remplacer les méthodes du Store par des appels à cette classe.
class ApiService {
  static String get _base => Env.apiBaseUrl;
  static String? _token; // TODO P7 : persister dans flutter_secure_storage

  static void setToken(String token) => _token = token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>?> login(String email, String mdp) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'motDePasse': mdp}),
      );
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      setToken(data['token'] as String);
      return data['user'] as Map<String, dynamic>;
    } catch (_) {
      return null; // hors-ligne : fallback sur le mode démo local
    }
  }

  static Future<List<dynamic>?> get_(String route, {String? boutiqueId}) async {
    try {
      final suffix = boutiqueId != null ? '?boutique_id=$boutiqueId' : '';
      final r = await http.get(Uri.parse('$_base$route$suffix'),
          headers: _headers);
      return r.statusCode == 200 ? jsonDecode(r.body) as List<dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> post(String route, Map body) async {
    try {
      final r = await http.post(Uri.parse('$_base$route'),
          headers: _headers, body: jsonEncode(body));
      return r.statusCode < 300 ? jsonDecode(r.body) as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  // Helpers typés — prêts pour le branchement du Store
  static Future<List<dynamic>?> transactions(String boutiqueId) =>
      get_('/transactions', boutiqueId: boutiqueId);
  static Future<List<dynamic>?> produits(String boutiqueId) =>
      get_('/produits', boutiqueId: boutiqueId);
  static Future<Map<String, dynamic>?> cloturerPartage(
          String partenaireId, String boutiqueId, String mois) =>
      post('/partages/cloturer',
          {'partenaire_id': partenaireId, 'boutique_id': boutiqueId, 'mois': mois});
}
