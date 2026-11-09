import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Minimal REST client shared by both apps.
///
/// The base URL can change at runtime (entered on the login/pairing screen),
/// because a phone cannot reach the developer's `localhost`.
class ApiClient {
  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  static const _timeout = Duration(seconds: 20);

  String _baseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  bool get hasToken => _token != null;

  void setToken(String? token) => _token = token;

  void setBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    _baseUrl = u;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path) =>
      _send(() => http.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
      () => http.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(
      () => http.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(0, 'Server did not respond ($_baseUrl)');
    } catch (e) {
      throw ApiException(0, 'Cannot reach server ($_baseUrl)');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic data;
    try {
      data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } on FormatException {
      data = null;
    }
    if (res.statusCode >= 400) {
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  /// Token expired/invalid — the app should sign in (or pair) again.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}
