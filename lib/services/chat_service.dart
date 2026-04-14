import 'api_client.dart';
import 'firestore_service.dart';

class ChatService {
  ChatService._();

  static DateTime? _parseHistoryTimestamp(Map<String, dynamic> item) {
    final raw = item['fecha'] ?? item['timestamp'] ?? item['Fecha'];
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static List<Map<String, dynamic>> _dedupeHistory(
    List<Map<String, dynamic>> source,
  ) {
    final result = <Map<String, dynamic>>[];

    for (final item in source) {
      final text = (item['texto'] ?? item['Mensaje'] ?? '').toString().trim();
      if (text.isEmpty) continue;

      final authorUid = (item['autorUid'] ?? '').toString().trim();
      final authorRole = (item['autor'] ?? '').toString().trim();
      final timestamp = _parseHistoryTimestamp(item) ?? DateTime.now();

      if (result.isNotEmpty) {
        final last = result.last;
        final lastText = (last['texto'] ?? '').toString().trim().toLowerCase();
        final lastUid = (last['autorUid'] ?? '').toString().trim();
        final lastRole = (last['autor'] ?? '').toString().trim();
        final lastTime = _parseHistoryTimestamp(last) ?? timestamp;

        final sameText = lastText == text.toLowerCase();
        final sameAuthor =
            (authorUid.isNotEmpty &&
                lastUid.isNotEmpty &&
                authorUid == lastUid) ||
            (authorUid.isEmpty && lastUid.isEmpty && authorRole == lastRole);
        final closeTime = timestamp.difference(lastTime).inSeconds.abs() <= 10;

        if (sameText && sameAuthor && closeTime) {
          continue;
        }
      }

      result.add(<String, dynamic>{
        'texto': text,
        'autor': authorRole,
        'autorUid': authorUid,
        'fecha': timestamp.toIso8601String(),
      });
    }

    return result;
  }

  static Future<Map<String, dynamic>> getChatById(String chatId) async {
    final data = await ApiClient.get('/api/chats/$chatId', auth: true);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{};
  }

  static Future<String> createReferralChat({
    required String documentoUsuario,
    required String documentoPsicologo,
    String? uidPsicologo,
    String? motivo,
    String? categoria,
    String? mensajeInicial,
    String? nombrePsicologo,
    String? nombreUsuario,
  }) async {
    final data = await ApiClient.post('/api/chats', <String, dynamic>{
      'Documento_usuario': documentoUsuario,
      'Documento_psicologo': documentoPsicologo,
      if (uidPsicologo != null && uidPsicologo.trim().isNotEmpty)
        'Uid_psicologo': uidPsicologo.trim(),
      if (motivo != null && motivo.trim().isNotEmpty) 'Motivo': motivo.trim(),
      if (categoria != null && categoria.trim().isNotEmpty)
        'Categoria': categoria.trim(),
      if (mensajeInicial != null && mensajeInicial.trim().isNotEmpty)
        'Mensaje': mensajeInicial.trim(),
      if (nombrePsicologo != null && nombrePsicologo.trim().isNotEmpty)
        'nombre_psicologo': nombrePsicologo.trim(),
      if (nombreUsuario != null && nombreUsuario.trim().isNotEmpty)
        'nombre_usuario': nombreUsuario.trim(),
    }, auth: true);

    if (data is Map<String, dynamic> && data['id'] is String) {
      return data['id'] as String;
    }

    return '';
  }

  static Future<List<Map<String, dynamic>>> fetchChats({
    String? documento,
    String? uid,
  }) async {
    final queryParameters = <String, String>{};
    if (documento != null && documento.trim().isNotEmpty) {
      queryParameters['documento'] = documento.trim();
    }
    if (uid != null && uid.trim().isNotEmpty) {
      queryParameters['uid'] = uid.trim();
    }

    final uri = Uri(
      path: '/api/chats',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final data = await ApiClient.get(uri.toString(), auth: true);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  static Future<void> updateChatMessage({
    required String chatId,
    required String message,
    String? authorUid,
    String? authorRole,
  }) async {
    final normalizedText = message.trim();
    if (normalizedText.isEmpty) return;

    await ApiClient.patch('/api/chats/$chatId/mensaje', <String, dynamic>{
      'Mensaje': normalizedText,
      if (authorUid != null && authorUid.trim().isNotEmpty)
        'autorUid': authorUid.trim(),
      if (authorRole != null && authorRole.trim().isNotEmpty)
        'autor': authorRole.trim(),
      'fecha': DateTime.now().toIso8601String(),
    }, auth: true);
  }

  static Future<void> appendMessageToHistory({
    required String chatId,
    required String message,
    required String authorUid,
    required String authorRole,
  }) async {
    final normalizedText = message.trim();
    if (normalizedText.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final chat = await FirestoreService.getDocument('Chats', chatId);
    final raw = chat['Mensajes'];

    final history = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          history.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final entry = <String, dynamic>{
      'texto': normalizedText,
      'autor': authorRole,
      'autorUid': authorUid,
      'fecha': now,
    };

    final normalizedHistory = _dedupeHistory(history);

    // Evita duplicar entrada cuando el último mensaje ya coincide.
    if (normalizedHistory.isNotEmpty) {
      final last = normalizedHistory.last;
      final lastText = (last['texto'] ?? last['Mensaje'] ?? '')
          .toString()
          .trim();
      final lastAuthor = (last['autorUid'] ?? '').toString().trim();
      if (lastText.toLowerCase() == normalizedText.toLowerCase() &&
          lastAuthor == authorUid) {
        return;
      }
    }

    normalizedHistory.add(entry);
    final finalHistory = _dedupeHistory(normalizedHistory);

    await FirestoreService.updateDocument('Chats', chatId, <String, dynamic>{
      'Mensajes': finalHistory,
      'Mensaje': normalizedText,
      'UltimoAutorUid': authorUid,
      'updatedAt': now,
    });
  }
}
