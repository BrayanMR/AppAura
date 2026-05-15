import 'api_client.dart';

/// Servicio Firestore — comunica con /api/firestore del backend Node.js
class FirestoreService {
  // ── Obtener colección ────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCollection(
    String collection,
  ) async {
    final data = await ApiClient.get('/api/firestore/$collection', auth: true);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  // ── Obtener documento ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDocument(
    String collection,
    String docId,
  ) async {
    final data = await ApiClient.get(
      '/api/firestore/$collection/$docId',
      auth: true,
    );
    return Map<String, dynamic>.from(data);
  }

  // ── Crear documento (auto-id) ─────────────────────────────────────────────
  static Future<String> addDocument(
    String collection,
    Map<String, dynamic> fields,
  ) async {
    final data = await ApiClient.post(
      '/api/firestore/$collection',
      fields,
      auth: true,
    );
    return data['id'] as String;
  }

  // ── Crear/Sobreescribir documento con ID ──────────────────────────────────
  static Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> fields,
  ) async {
    await ApiClient.put(
      '/api/firestore/$collection/$docId',
      fields,
      auth: true,
    );
  }

  // ── Actualizar campos ────────────────────────────────────────────────────
  static Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> fields,
  ) async {
    await ApiClient.patch(
      '/api/firestore/$collection/$docId',
      fields,
      auth: true,
    );
  }

  // ── Eliminar documento ───────────────────────────────────────────────────
  static Future<void> deleteDocument(String collection, String docId) async {
    await ApiClient.delete('/api/firestore/$collection/$docId', auth: true);
  }

  // ── Consulta con filtro ───────────────────────────────────────────────────
  /// [operator]: '==', '>', '<', '>=', '<=', '!='
  static Future<List<Map<String, dynamic>>> query(
    String collection, {
    required String field,
    required String operator,
    required dynamic value,
  }) async {
    final data = await ApiClient.post('/api/firestore/$collection/query', {
      'field': field,
      'operator': operator,
      'value': value,
    }, auth: true);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }
}
