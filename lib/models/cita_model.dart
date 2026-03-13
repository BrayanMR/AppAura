enum EstadoCita { pendiente, confirmada, cancelada, realizada }

class CitaModel {
  final String id;
  final String usuarioUid;
  final String usuarioNombre;
  final String psicologoUid;
  final String psicologoNombre;
  final DateTime fecha;
  final String hora;
  final EstadoCita estado;
  final String? motivo;
  final String? notas;

  const CitaModel({
    required this.id,
    required this.usuarioUid,
    required this.usuarioNombre,
    required this.psicologoUid,
    required this.psicologoNombre,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.motivo,
    this.notas,
  });

  factory CitaModel.fromMap(String id, Map<String, dynamic> map) {
    return CitaModel(
      id: id,
      usuarioUid: map['usuarioUid'] as String,
      usuarioNombre: map['usuarioNombre'] as String? ?? '',
      psicologoUid: map['psicologoUid'] as String,
      psicologoNombre: map['psicologoNombre'] as String? ?? '',
      fecha: DateTime.parse(map['fecha'] as String),
      hora: map['hora'] as String,
      estado: EstadoCita.values.firstWhere(
        (e) => e.name == (map['estado'] as String? ?? 'pendiente'),
        orElse: () => EstadoCita.pendiente,
      ),
      motivo: map['motivo'] as String?,
      notas: map['notas'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'usuarioUid': usuarioUid,
    'usuarioNombre': usuarioNombre,
    'psicologoUid': psicologoUid,
    'psicologoNombre': psicologoNombre,
    'fecha': fecha.toIso8601String(),
    'hora': hora,
    'estado': estado.name,
    if (motivo != null) 'motivo': motivo,
    if (notas != null) 'notas': notas,
  };
}
