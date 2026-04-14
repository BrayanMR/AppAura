import '../models/cita_model.dart';
import 'firestore_service.dart';

class CitaService {
  static const String _collection = 'Citas';

  static Future<List<CitaModel>> fetchCitasUsuario({
    String? pacienteUid,
    String? pacienteDocumento,
  }) async {
    final docs = await FirestoreService.getCollection(_collection);
    final normalizedUid = pacienteUid?.trim() ?? '';
    final normalizedDocumento = pacienteDocumento?.trim() ?? '';
    final hasFilter =
        normalizedUid.isNotEmpty || normalizedDocumento.isNotEmpty;

    final citas = docs
        .map((doc) => CitaModel.fromMap(doc['id'].toString(), doc))
        .where((cita) {
          if (!hasFilter) {
            return true;
          }

          final matchesUid =
              normalizedUid.isNotEmpty && cita.pacienteUid == normalizedUid;
          final matchesDocumento =
              normalizedDocumento.isNotEmpty &&
              cita.pacienteDocumento == normalizedDocumento;

          return matchesUid || matchesDocumento;
        })
        .toList();

    citas.sort((a, b) => b.fecha.compareTo(a.fecha));
    return citas;
  }

  static Future<List<CitaModel>> fetchCitas({
    String? psicologoUid,
    String? psicologoNombre,
    String? psicologoDocumento,
  }) async {
    final docs = await FirestoreService.getCollection(_collection);
    final normalizedUid = psicologoUid?.trim() ?? '';
    final normalizedNombre = psicologoNombre?.trim().toLowerCase() ?? '';
    final normalizedDocumento = psicologoDocumento?.trim() ?? '';
    final hasFilter =
        normalizedUid.isNotEmpty ||
        normalizedNombre.isNotEmpty ||
        normalizedDocumento.isNotEmpty;

    final citas = docs
        .map((doc) => CitaModel.fromMap(doc['id'].toString(), doc))
        .where((cita) {
          if (!hasFilter) {
            return true;
          }

          final matchesUid =
              normalizedUid.isNotEmpty &&
              (cita.psicologoUid == normalizedUid ||
                  cita.pacienteUid == normalizedUid);
          final matchesNombre =
              normalizedNombre.isNotEmpty &&
              (cita.psicologo.toLowerCase().contains(normalizedNombre) ||
                  normalizedNombre.contains(cita.psicologo.toLowerCase()));
          final matchesDocumento =
              normalizedDocumento.isNotEmpty &&
              (cita.psicologoDocumento == normalizedDocumento ||
                  cita.pacienteDocumento == normalizedDocumento);

          return matchesUid || matchesNombre || matchesDocumento;
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
