import '../models/user_model.dart';
import 'firestore_service.dart';

class UserService {
  static const String collection = 'usuarios';

  // Obtener todos los pacientes (usuarios con rol 'usuario')
  static Future<List<UserModel>> getPacientes() async {
    try {
      // Primero intentamos obtener todos los usuarios de la colección
      final docs = await FirestoreService.getCollection('usuarios');

      // Convertir a UserModel y filtrar por rol 'usuario'
      final pacientes = docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc);
            } catch (e) {
              print('Error al convertir usuario: $e, doc: $doc');
              return null;
            }
          })
          .whereType<UserModel>()
          .where(
            (user) =>
                user.role == UserRole.usuario || user.role.name == 'usuario',
          )
          .toList();

      print('Pacientes cargados: ${pacientes.length}');
      return pacientes;
    } catch (e) {
      print('Error en getPacientes: $e');
      rethrow;
    }
  }

  // Obtener paciente por UID
  static Future<UserModel?> getPacienteByUid(String uid) async {
    try {
      final doc = await FirestoreService.getDocument(collection, uid);
      return UserModel.fromMap(doc);
    } catch (e) {
      return null;
    }
  }

  // Obtener TODOS los usuarios sin filtro
  static Future<List<UserModel>> getTodosUsuarios() async {
    try {
      final docs = await FirestoreService.getCollection(collection);
      final usuarios = docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc);
            } catch (e) {
              print('Error al convertir usuario: $e, doc: $doc');
              return null;
            }
          })
          .whereType<UserModel>()
          .toList();

      print('Total de usuarios: ${usuarios.length}');
      return usuarios;
    } catch (e) {
      print('Error en getTodosUsuarios: $e');
      rethrow;
    }
  }

  // Buscar pacientes por nombre o documento
  static Future<List<UserModel>> searchPacientes(String query) async {
    final docs = await FirestoreService.getCollection(collection);
    final pacientes = docs
        .map((doc) => UserModel.fromMap(doc))
        .where((user) => user.role == UserRole.usuario)
        .where(
          (user) =>
              user.displayName.toLowerCase().contains(query.toLowerCase()) ||
              user.documento.toLowerCase().contains(query.toLowerCase()) ||
              user.email.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return pacientes;
  }
}
