class NotaClinicaModel {
  final String id;
  final String psicologoUid;
  final String pacienteUid;
  final String pacienteNombre;
  final String categoria; // Tema mental: Ansiedad, Depresión, etc.
  final String diagnostico;
  final String sintomas;
  final String planTratamiento;
  final String observaciones;
  final DateTime fecha;
  final String? citaId;

  const NotaClinicaModel({
    required this.id,
    required this.psicologoUid,
    required this.pacienteUid,
    required this.pacienteNombre,
    required this.categoria,
    required this.diagnostico,
    required this.sintomas,
    required this.planTratamiento,
    required this.observaciones,
    required this.fecha,
    this.citaId,
  });

  factory NotaClinicaModel.fromMap(String id, Map<String, dynamic> map) {
    return NotaClinicaModel(
      id: id,
      psicologoUid: map['psicologoUid'] as String,
      pacienteUid: map['pacienteUid'] as String,
      pacienteNombre: map['pacienteNombre'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      diagnostico: map['diagnostico'] as String? ?? '',
      sintomas: map['sintomas'] as String? ?? '',
      planTratamiento: map['planTratamiento'] as String? ?? '',
      observaciones: map['observaciones'] as String? ?? '',
      fecha: DateTime.parse(map['fecha'] as String),
      citaId: map['citaId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'psicologoUid': psicologoUid,
    'pacienteUid': pacienteUid,
    'pacienteNombre': pacienteNombre,
    'categoria': categoria,
    'diagnostico': diagnostico,
    'sintomas': sintomas,
    'planTratamiento': planTratamiento,
    'observaciones': observaciones,
    'fecha': fecha.toIso8601String(),
    if (citaId != null) 'citaId': citaId,
  };
}
