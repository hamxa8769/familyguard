import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// One signed-in session, shared by both apps.
///
///  - Parent app: email/password login → parent token.
///  - Child app: one-time pairing code → device token scoped to one device.
///
/// Token, server URL and (for devices) the device id survive restarts.
class AuthService {
  AuthService(this.api);

  /// The single API client both apps use.
  static final AuthService instance = AuthService(ApiClient());

  final ApiClient api;

  static const _tokenKey = 'auth_token';
  static const _baseUrlKey = 'api_base_url';
  static const _deviceIdKey = 'device_id';
  static const _childNameKey = 'child_name';
  static const _displayNameKey = 'display_name';

  String? _deviceId;
  String? _childName;
  String? _displayName;

  bool get isSignedIn => api.hasToken;

  /// Set in the child app once paired.
  String? get deviceId => _deviceId;
  String? get childName => _childName;

  /// Parent's display name (parent app).
  String? get displayName => _displayName;

  /// Restores the saved session. Call once at app start.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_baseUrlKey);
    if (url != null && url.isNotEmpty) api.setBaseUrl(url);
    api.setToken(prefs.getString(_tokenKey));
    _deviceId = prefs.getString(_deviceIdKey);
    _childName = prefs.getString(_childNameKey);
    _displayName = prefs.getString(_displayNameKey);
  }

  Future<void> setBaseUrl(String url) async {
    api.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, api.baseUrl);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await api.post('/api/auth/register', {
      'email': email,
      'password': password,
      'role': 'parent',
      'displayName': displayName,
    });
    await _saveParent(res);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    if (res['user']?['role'] != 'parent') {
      throw ApiException(403, 'This is not a parent account');
    }
    await _saveParent(res);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Child app: redeem the code shown in the parent app.
  Future<void> pairDevice({
    required String code,
    required String platform,
    String? deviceName,
  }) async {
    final res = await api.post('/api/pair', {
      'code': code.trim().toUpperCase(),
      'platform': platform,
      'deviceName': deviceName,
    });
    final prefs = await SharedPreferences.getInstance();
    _deviceId = res['device']['id'].toString();
    _childName = res['child']?['displayName']?.toString();
    api.setToken(res['token'] as String);
    await prefs.setString(_tokenKey, res['token'] as String);
    await prefs.setString(_deviceIdKey, _deviceId!);
    if (_childName != null) await prefs.setString(_childNameKey, _childName!);
  }

  Future<void> logout() async {
    api.setToken(null);
    _deviceId = null;
    _childName = null;
    _displayName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_childNameKey);
    await prefs.remove(_displayNameKey);
  }

  Future<void> _saveParent(dynamic res) async {
    api.setToken(res['token'] as String);
    _displayName = res['user']?['displayName']?.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, res['token'] as String);
    if (_displayName != null) {
      await prefs.setString(_displayNameKey, _displayName!);
    }
  }
}
