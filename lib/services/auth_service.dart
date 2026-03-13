import 'api_client.dart';

/// Servicio de autenticación — comunica con /api/auth del backend Node.js
class AuthService {
  // ── Registrar usuario ────────────────────────────────────────────────────
  /// Crea un usuario en Firebase Auth a través del backend.
  /// Retorna el uid del nuevo usuario.
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await ApiClient.post('/api/auth/register', {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    });
    return Map<String, dynamic>.from(data);
  }

  // ── Obtener usuario ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUser(String uid) async {
    final data = await ApiClient.get('/api/auth/user/$uid');
    return Map<String, dynamic>.from(data);
  }

  // ── Actualizar usuario ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateUser(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final data = await ApiClient.put('/api/auth/user/$uid', fields, auth: true);
    return Map<String, dynamic>.from(data);
  }

  // ── Eliminar usuario ─────────────────────────────────────────────────────
  static Future<void> deleteUser(String uid) async {
    await ApiClient.delete('/api/auth/user/$uid', auth: true);
  }

  // ── Verificar token ──────────────────────────────────────────────────────
  /// Verifica el idToken de Firebase y devuelve { uid, email }.
  static Future<Map<String, dynamic>> verifyToken(String idToken) async {
    final data = await ApiClient.post('/api/auth/verify-token', {
      'idToken': idToken,
    });
    // Guardar el token para peticiones autenticadas
    await ApiClient.saveToken(idToken);
    return Map<String, dynamic>.from(data);
  }

  // ── Crear Custom Token ───────────────────────────────────────────────────
  static Future<String> createCustomToken(
    String uid, {
    Map<String, dynamic>? claims,
  }) async {
    final data = await ApiClient.post('/api/auth/custom-token', {
      'uid': uid,
      if (claims != null) 'claims': claims,
    });
    return data['customToken'] as String;
  }

  // ── Cerrar sesión (local) ────────────────────────────────────────────────
  static Future<void> signOut() async {
    await ApiClient.clearToken();
  }
}
