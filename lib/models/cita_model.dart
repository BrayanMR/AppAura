enum EstadoCita { pendiente, confirmada, cancelada }

class CitaModel {
  final String id;
  final String paciente;
  final String psicologo;
  final DateTime fecha;
  final String motivo;
  final EstadoCita estado;
  final String? pacienteUid;
  final String? psicologoUid;
  final String? pacienteDocumento;
  final String? psicologoDocumento;
  final DateTime? createdAt;

  const CitaModel({
    required this.id,
    required this.paciente,
    required this.psicologo,
    required this.fecha,
    required this.motivo,
    required this.estado,
    this.pacienteUid,
    this.psicologoUid,
    this.pacienteDocumento,
    this.psicologoDocumento,
    this.createdAt,
  });

  factory CitaModel.fromMap(String id, Map<String, dynamic> map) {
    return CitaModel(
      id: id,
      paciente: _readString(map, const [
        'paciente',
        'pacienteNombre',
        'usuarioNombre',
        'usuario',
      ]),
      psicologo: _readString(map, const [
        'psicologo',
        'psicologoNombre',
        'nombre_psicologo',
      ]),
      fecha:
          _parseDate(map['fecha'] ?? map['Fecha'] ?? map['datetime']) ??
          DateTime.now(),
      motivo: _readString(map, const ['motivo', 'Motivo', 'reason']),
      estado: EstadoCita.values.firstWhere(
        (estado) =>
            estado.name ==
            _readString(map, const ['estado', 'Estado']).toLowerCase(),
        orElse: () => EstadoCita.pendiente,
      ),
      pacienteUid: _readString(map, const ['pacienteUid', 'usuarioUid']),
      psicologoUid: _readString(map, const ['psicologoUid', 'uidPsicologo']),
      pacienteDocumento: _readString(map, const [
        'pacienteDocumento',
        'documentoPaciente',
      ]),
      psicologoDocumento: _readString(map, const [
        'psicologoDocumento',
        'documentoPsicologo',
      ]),
      createdAt: _parseDate(map['createdAt'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'paciente': paciente,
    'psicologo': psicologo,
    'fecha': fecha.toIso8601String(),
    'motivo': motivo,
    'estado': estado.name,
    if (pacienteUid != null && pacienteUid!.trim().isNotEmpty)
      'pacienteUid': pacienteUid,
    if (psicologoUid != null && psicologoUid!.trim().isNotEmpty)
      'psicologoUid': psicologoUid,
    if (pacienteDocumento != null && pacienteDocumento!.trim().isNotEmpty)
      'pacienteDocumento': pacienteDocumento,
    if (psicologoDocumento != null && psicologoDocumento!.trim().isNotEmpty)
      'psicologoDocumento': psicologoDocumento,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  static String _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static DateTime? _parseDate(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
