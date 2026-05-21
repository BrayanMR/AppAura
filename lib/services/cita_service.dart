import '../models/cita_model.dart';
import 'firestore_service.dart';

class CitaService {
  static const String _collection = 'Citas';

  static Future<List<CitaModel>> fetchCitasUsuario({
    String? pacienteUid,
    String? pacienteDocumento,
  }) async {
    final normalizedUid = pacienteUid?.trim() ?? '';
    final normalizedDocumento = pacienteDocumento?.trim() ?? '';
    List<Map<String, dynamic>> docs;

    if (normalizedUid.isNotEmpty) {
      docs = await FirestoreService.query(
        _collection,
        field: 'pacienteUid',
        operator: '==',
        value: normalizedUid,
      );
    } else if (normalizedDocumento.isNotEmpty) {
      docs = await FirestoreService.query(
        _collection,
        field: 'pacienteDocumento',
        operator: '==',
        value: normalizedDocumento,
      );
    } else {
      docs = await FirestoreService.getCollection(_collection);
    }

    final citas = docs
        .map((doc) => CitaModel.fromMap(doc['id'].toString(), doc))
        .toList();

    citas.sort((a, b) => b.fecha.compareTo(a.fecha));
    return citas;
  }

  static Future<List<CitaModel>> fetchCitas({
    String? psicologoUid,
    String? psicologoNombre,
    String? psicologoDocumento,
  }) async {
    final normalizedUid = psicologoUid?.trim() ?? '';
    final normalizedNombre = psicologoNombre?.trim().toLowerCase() ?? '';
    final normalizedDocumento = psicologoDocumento?.trim() ?? '';
    List<Map<String, dynamic>> docs;

    if (normalizedUid.isNotEmpty) {
      docs = await FirestoreService.query(
        _collection,
        field: 'psicologoUid',
        operator: '==',
        value: normalizedUid,
      );
    } else if (normalizedDocumento.isNotEmpty) {
      docs = await FirestoreService.query(
        _collection,
        field: 'psicologoDocumento',
        operator: '==',
        value: normalizedDocumento,
      );
    } else {
      docs = await FirestoreService.getCollection(_collection);
    }

    final citas = docs
        .map((doc) => CitaModel.fromMap(doc['id'].toString(), doc))
        .where((cita) {
          if (normalizedNombre.isEmpty) {
            return true;
          }

          final matchesNombre = cita.psicologo.toLowerCase().contains(
            normalizedNombre,
          );
          return matchesNombre;
        })
        .toList();

    citas.sort((a, b) => b.fecha.compareTo(a.fecha));
    return citas;
  }

  static Future<String> addCita({
    required String paciente,
    required String psicologo,
    required DateTime fecha,
    required String motivo,
    String estado = 'pendiente',
    String? pacienteUid,
    String? psicologoUid,
    String? pacienteDocumento,
    String? psicologoDocumento,
  }) async {
    final payload = <String, dynamic>{
      'paciente': paciente,
      'psicologo': psicologo,
      'fecha': fecha.toIso8601String(),
      'motivo': motivo,
      'estado': estado,
      if (pacienteUid != null && pacienteUid.trim().isNotEmpty)
        'pacienteUid': pacienteUid.trim(),
      if (psicologoUid != null && psicologoUid.trim().isNotEmpty)
        'psicologoUid': psicologoUid.trim(),
      if (pacienteDocumento != null && pacienteDocumento.trim().isNotEmpty)
        'pacienteDocumento': pacienteDocumento.trim(),
      if (psicologoDocumento != null && psicologoDocumento.trim().isNotEmpty)
        'psicologoDocumento': psicologoDocumento.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    return FirestoreService.addDocument(_collection, payload);
  }

  static Future<void> updateCitaEstado(String id, String estado) async {
    await FirestoreService.updateDocument(_collection, id, {'estado': estado});
  }

  static Future<void> confirmCita(String id) async {
    await updateCitaEstado(id, 'confirmada');
  }

  static Future<void> deleteCita(String id) async {
    await FirestoreService.deleteDocument(_collection, id);
  }
}
