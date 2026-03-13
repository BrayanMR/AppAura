import 'api_client.dart';

/// Servicio Realtime Database — comunica con /api/rtdb del backend Node.js
class RtdbService {
  // ── Leer nodo ────────────────────────────────────────────────────────────
  static Future<dynamic> read(String path) async {
    return ApiClient.get('/api/rtdb/$path', auth: true);
  }

  // ── Escribir nodo ────────────────────────────────────────────────────────
  static Future<void> set(String path, Map<String, dynamic> data) async {
    await ApiClient.put('/api/rtdb/$path', data, auth: true);
  }

  // ── Actualizar campos ────────────────────────────────────────────────────
  static Future<void> update(String path, Map<String, dynamic> data) async {
    await ApiClient.patch('/api/rtdb/$path', data, auth: true);
  }

  // ── Agregar elemento a lista (push) ──────────────────────────────────────
  static Future<String> push(String path, Map<String, dynamic> data) async {
    final res = await ApiClient.post('/api/rtdb/$path', data, auth: true);
    return res['key'] as String;
  }

  // ── Eliminar nodo ────────────────────────────────────────────────────────
  static Future<void> remove(String path) async {
    await ApiClient.delete('/api/rtdb/$path', auth: true);
  }
}
