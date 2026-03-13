class PostForoModel {
  final String id;
  final String autorUid;
  final String autorNombre;
  final String autorRole; // 'usuario' | 'psicologo'
  final String titulo;
  final String contenido;
  final DateTime fecha;
  final int likes;
  final List<String> likedBy;

  const PostForoModel({
    required this.id,
    required this.autorUid,
    required this.autorNombre,
    required this.autorRole,
    required this.titulo,
    required this.contenido,
    required this.fecha,
    this.likes = 0,
    this.likedBy = const [],
  });

  factory PostForoModel.fromMap(String id, Map<String, dynamic> map) {
    return PostForoModel(
      id: id,
      autorUid: map['autorUid'] as String,
      autorNombre: map['autorNombre'] as String? ?? '',
      autorRole: map['autorRole'] as String? ?? 'usuario',
      titulo: map['titulo'] as String,
      contenido: map['contenido'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      likes: (map['likes'] as int?) ?? 0,
      likedBy: List<String>.from(map['likedBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'autorUid': autorUid,
    'autorNombre': autorNombre,
    'autorRole': autorRole,
    'titulo': titulo,
    'contenido': contenido,
    'fecha': fecha.toIso8601String(),
    'likes': likes,
    'likedBy': likedBy,
  };
}
