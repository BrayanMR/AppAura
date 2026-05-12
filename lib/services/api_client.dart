import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Cliente HTTP base que agrega el token de autenticación automáticamente
/// y maneja respuestas/errores de manera uniforme.
class ApiClient {
  static const String _tokenKey = 'auth_token';
  static const Duration _requestTimeout = Duration(seconds: 20);

  // ── Token ─────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint('[TOKEN] Token guardado: ${token.substring(0, 20)}...');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    debugPrint('[TOKEN] Token obtenido: ${token != null ? token.substring(0, 20) + '...' : 'null'}');
    return token;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    debugPrint('[TOKEN] Token eliminado');
  }

  // ── Headers ───────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('[HEADERS] Auth header agregado');
      } else {
        debugPrint('[HEADERS] ⚠️ Auth solicitado pero no hay token');
        throw Exception('No se encontró token de autenticación. Inicia sesión de nuevo.');
      }
    }
    return headers;
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<dynamic> get(String path, {bool auth = false}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    try {
      final res = await http
          .get(uri, headers: await _headers(auth: auth))
          .timeout(_requestTimeout);
      return _parse(res);
    } on SocketException {
      throw Exception(
        'Sin conexión con el backend. Verifica internet y API_BASE_URL.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el backend. Revisa la URL de la API.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    try {
      final res = await http
          .post(
            uri,
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _parse(res);
    } on SocketException {
      throw Exception(
        'Sin conexión con el backend. Verifica internet y API_BASE_URL.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el backend. Revisa la URL de la API.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    }
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  static Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final url = Uri.parse('$kBaseUrl$path');
    final headers = await _headers(auth: auth);
    final jsonBody = json.encode(body ?? {});
    try {
      debugPrint('[API][PUT] $url');
      debugPrint('[API][PUT] Headers: ' + headers.toString());
      debugPrint('[API][PUT] Body: ' + jsonBody);
      final response = await http.put(url, headers: headers, body: jsonBody);
      debugPrint('[API][PUT] Status: ${response.statusCode}');
      debugPrint('[API][PUT] Response: ${response.body}');
      return response;
    } catch (e, st) {
      debugPrint('[API][PUT][ERROR] $e');
      debugPrint(st.toString());
      rethrow;
    } on SocketException {
      throw Exception(
        'Sin conexión con el backend. Verifica internet y API_BASE_URL.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el backend. Revisa la URL de la API.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    }
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    try {
      final res = await http
          .patch(
            uri,
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _parse(res);
    } on SocketException {
      throw Exception(
        'Sin conexión con el backend. Verifica internet y API_BASE_URL.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el backend. Revisa la URL de la API.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String path, {bool auth = false}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    try {
      final res = await http
          .delete(uri, headers: await _headers(auth: auth))
          .timeout(_requestTimeout);
      return _parse(res);
    } on SocketException {
      throw Exception(
        'Sin conexión con el backend. Verifica internet y API_BASE_URL.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el backend. Revisa la URL de la API.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    }
  }

  // ── Multipart POST ───────────────────────────────────────────────────────
  static Future<dynamic> uploadFile(
    String path, {
    required Uint8List bytes,
    required String fileName,
    required String fileFieldName,
    Map<String, String>? fields,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    if (auth) {
      final token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (fields != null) request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(fileFieldName, bytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _parse(response);
  }

  // ── Parser de respuesta ───────────────────────────────────────────────────
  static dynamic _parse(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = res.body;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = (body is Map && body['error'] != null)
        ? body['error']
        : (body is Map && body['message'] != null)
        ? body['message']
        : 'Error ${res.statusCode}: ${res.reasonPhrase ?? 'respuesta inválida'}';
    throw Exception(msg);
  }
}
