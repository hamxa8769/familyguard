import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Handles register/login and token persistence. Shared by both apps.
class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  static const _tokenKey = 'auth_token';

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role, // 'parent' or 'child'
    String? displayName,
  }) async {
    final res = await _api.post('/api/auth/register', {
      'email': email,
      'password': password,
      'role': role,
      'displayName': displayName,
    });
    await _persistToken(res['token']);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    await _persistToken(res['token']);
    return Map<String, dynamic>.from(res);
  }

  Future<void> loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _api.setToken(prefs.getString(_tokenKey));
  }

  Future<void> logout() async {
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> _persistToken(String token) async {
    _api.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
}
