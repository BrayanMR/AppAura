import '../models/nota_clinica_model.dart';
import 'firestore_service.dart';

class NotaClinicaService {
  static const String collection = 'notasClinicas';

  // Obtener todas las notas de un psicólogo
  static Future<List<NotaClinicaModel>> getNotasByPsicologo(
    String psicologoUid,
  ) async {
    final docs = await FirestoreService.query(
      collection,
      field: 'psicologoUid',
      operator: '==',
      value: psicologoUid,
    );
    return docs.map((doc) => NotaClinicaModel.fromMap(doc['id'], doc)).toList();
  }

  // Obtener notas de un paciente específico
  static Future<List<NotaClinicaModel>> getNotasByPaciente(
    String pacienteUid,
  ) async {
    final docs = await FirestoreService.query(
      collection,
      field: 'pacienteUid',
      operator: '==',
      value: pacienteUid,
    );
    return docs.map((doc) => NotaClinicaModel.fromMap(doc['id'], doc)).toList();
  }

  static Future<NotaClinicaModel?> getNotaByPsicologoAndPaciente(
    String psicologoUid,
    String pacienteUid,
  ) async {
    final docs = await FirestoreService.query(
      collection,
      field: 'pacienteUid',
      operator: '==',
      value: pacienteUid,
    );
    for (final doc in docs) {
      final docPsicologoUid = (doc['psicologoUid'] ?? '').toString().trim();
      if (docPsicologoUid == psicologoUid.trim()) {
        return NotaClinicaModel.fromMap(doc['id'] as String, doc);
      }
    }
    return null;
  }

  // Crear una nueva nota
  static Future<String> createNota(NotaClinicaModel nota) async {
    return await FirestoreService.addDocument(collection, nota.toMap());
  }

  // Actualizar una nota
  static Future<void> updateNota(
    String notaId,
    Map<String, dynamic> updates,
  ) async {
    await FirestoreService.updateDocument(collection, notaId, updates);
  }

  // Eliminar una nota
  static Future<void> deleteNota(String notaId) async {
    await FirestoreService.deleteDocument(collection, notaId);
  }
}
