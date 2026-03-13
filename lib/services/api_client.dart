import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Cliente HTTP base que agrega el token de autenticación automáticamente
/// y maneja respuestas/errores de manera uniforme.
class ApiClient {
  static const String _tokenKey = 'auth_token';

  // ── Token ─────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Headers ───────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<dynamic> get(String path, {bool auth = false}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await http.get(uri, headers: await _headers(auth: auth));
    return _parse(res);
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await http.post(
      uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  static Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await http.put(
      uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await http.patch(
      uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String path, {bool auth = false}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await http.delete(uri, headers: await _headers(auth: auth));
    return _parse(res);
  }

  // ── Parser de respuesta ───────────────────────────────────────────────────
  static dynamic _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = (body is Map && body['error'] != null)
        ? body['error']
        : 'Error ${res.statusCode}';
    throw Exception(msg);
  }
}
