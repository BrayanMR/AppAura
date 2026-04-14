import 'firestore_service.dart';
import 'api_client.dart';

class ChatIaService {
  static const String collection = 'chatIa';

  /// Guarda el historial de mensajes y la memoria para un usuario IA
  static Future<void> saveUserChatIa({
    required String userId,
    required List<Map<String, dynamic>> messages,
    required String memory,
  }) async {
    await FirestoreService.setDocument(collection, userId, {
      'messages': messages,
      'memory': memory,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Recupera historial y memoria del usuario IA, y lo crea si no existe
  static Future<Map<String, dynamic>> getOrCreateUserChatIa(String userId) async {
    final doc = await FirestoreService.getDocument(collection, userId);
    if (doc.isEmpty) {
      // Si no existe, lo crea vacío
      await FirestoreService.setDocument(collection, userId, {
        'messages': [],
        'memory': '',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return {
        'messages': [],
        'memory': '',
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
    return doc;
  }

  /// Envía un mensaje al endpoint protegido de IA (triage)
  static Future<Map<String, dynamic>> sendToIaTriage({
    required String message,
    List<Map<String, dynamic>> conversationContext = const [],
    String conversationMemory = "",
  }) async {
    final response = await ApiClient.post(
      '/api/ai/triage',
      {
        'message': message,
        'conversationContext': conversationContext,
        'conversationMemory': conversationMemory,
      },
      auth: true, // Esto agrega el JWT automáticamente
    );
    return response;
  }
}
