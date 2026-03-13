class NotaClinicaModel {
  final String id;
  final String psicologoUid;
  final String pacienteUid;
  final String pacienteNombre;
  final String contenido;
  final DateTime fecha;
  final String? citaId;

  const NotaClinicaModel({
    required this.id,
    required this.psicologoUid,
    required this.pacienteUid,
    required this.pacienteNombre,
    required this.contenido,
    required this.fecha,
    this.citaId,
  });

  factory NotaClinicaModel.fromMap(String id, Map<String, dynamic> map) {
    return NotaClinicaModel(
      id: id,
      psicologoUid: map['psicologoUid'] as String,
      pacienteUid: map['pacienteUid'] as String,
      pacienteNombre: map['pacienteNombre'] as String? ?? '',
      contenido: map['contenido'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      citaId: map['citaId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'psicologoUid': psicologoUid,
    'pacienteUid': pacienteUid,
    'pacienteNombre': pacienteNombre,
    'contenido': contenido,
    'fecha': fecha.toIso8601String(),
    if (citaId != null) 'citaId': citaId,
  };
}
