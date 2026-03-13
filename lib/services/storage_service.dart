import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../config/api_config.dart';

/// Servicio Storage — comunica con /api/storage del backend Node.js
class StorageService {
  // ── Subir archivo desde bytes ─────────────────────────────────────────────
  /// [bytes]: contenido del archivo
  /// [fileName]: nombre original del archivo
  /// [destination]: ruta dentro del bucket (ej: 'fotos/perfil.jpg')
  /// [mimeType]: tipo MIME (ej: 'image/jpeg')
  static Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String destination,
    String mimeType = 'application/octet-stream',
  }) async {
    final token = await ApiClient.getToken();
    final uri = Uri.parse('$kBaseUrl/api/storage/upload');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['destination'] = destination;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception(body['error'] ?? 'Error al subir archivo');
  }

  // ── Obtener URL firmada de descarga ──────────────────────────────────────
  static Future<String> getDownloadUrl(String path) async {
    final data = await ApiClient.get(
      '/api/storage/url?path=${Uri.encodeComponent(path)}',
      auth: true,
    );
    return data['url'] as String;
  }

  // ── Eliminar archivo ─────────────────────────────────────────────────────
  static Future<void> deleteFile(String path) async {
    await ApiClient.delete(
      '/api/storage/file?path=${Uri.encodeComponent(path)}',
      auth: true,
    );
  }
}
