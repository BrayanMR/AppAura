import 'api_client.dart';

/// Servicio Cloud Messaging — comunica con /api/messaging del backend Node.js
class MessagingService {
  // ── Enviar a un dispositivo ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendToDevice({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final res = await ApiClient.post('/api/messaging/send', {
      'token': token,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    }, auth: true);
    return Map<String, dynamic>.from(res);
  }

  // ── Enviar a múltiples dispositivos ─────────────────────────────────────
  static Future<Map<String, dynamic>> sendToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final res = await ApiClient.post('/api/messaging/send-multiple', {
      'tokens': tokens,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    }, auth: true);
    return Map<String, dynamic>.from(res);
  }

  // ── Suscribir a un topic ─────────────────────────────────────────────────
  static Future<void> subscribeToTopic({
    required List<String> tokens,
    required String topic,
  }) async {
    await ApiClient.post('/api/messaging/subscribe', {
      'tokens': tokens,
      'topic': topic,
    }, auth: true);
  }

  // ── Enviar a un topic ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final res = await ApiClient.post('/api/messaging/send-topic', {
      'topic': topic,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    }, auth: true);
    return Map<String, dynamic>.from(res);
  }
}
