import 'firestore_service.dart';

class ForoComentario {
  final String autor;
  final String texto;
  final String? autorUid;
  final DateTime? fecha;
  final bool reportado;
  final String? respuestaTexto;

  const ForoComentario({
    required this.autor,
    required this.texto,
    this.autorUid,
    required this.fecha,
    required this.reportado,
    this.respuestaTexto,
  });

  factory ForoComentario.fromMap(Map<String, dynamic> map) {
    final respuestas = map['respuestas'];
    return ForoComentario(
      autor: _stringFrom(map, const [
        'autor',
        'autorNombre',
        'nombre',
        'author',
      ]),
      texto: _stringFrom(map, const [
        'texto',
        'contenido',
        'comentario',
        'mensaje',
      ]),
      autorUid: map['autorUid'] as String?,
      fecha: _safeParseDate(
        _firstValue(map, const ['fecha', 'createdAt', 'updatedAt']),
      ),
      reportado: _boolFrom(_firstValue(map, const ['reportado', 'reported'])),
      respuestaTexto: _responseTextFromDynamic(
        respuestas,
        nestedKeys: const ['texto', 'contenido', 'mensaje'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'autor': autor,
      'texto': texto,
      'reportado': reportado,
    };
    if (autorUid != null && autorUid!.isNotEmpty) {
      data['autorUid'] = autorUid;
    }
    if (fecha != null) {
      data['fecha'] = fecha!.toIso8601String();
    }
    if (respuestaTexto != null && respuestaTexto!.trim().isNotEmpty) {
      data['respuestas'] = <String, dynamic>{'texto': respuestaTexto};
    } else {
      data['respuestas'] = <String, dynamic>{};
    }
    return data;
  }
}

class ForoPublicacion {
  final String collection;
  final String id;
  final String autor;
  final String titulo;
  final String contenido;
  final DateTime? fecha;
  final DateTime? updatedAt;
  final int likes;
  final List<String> likedBy;
  final String likesKey;
  final String likedByKey;
  final List<ForoComentario> comentarios;
  final String comentariosKey;
  final Map<String, dynamic> raw;

  const ForoPublicacion({
    required this.collection,
    required this.id,
    required this.autor,
    required this.titulo,
    required this.contenido,
    required this.fecha,
    required this.updatedAt,
    required this.likes,
    required this.likedBy,
    required this.likesKey,
    required this.likedByKey,
    required this.comentarios,
    required this.comentariosKey,
    required this.raw,
  });

  factory ForoPublicacion.fromMap(String collection, Map<String, dynamic> map) {
    final rawComentarios =
        map['comentarios'] ?? map['Comentarios'] ?? map['comments'];
    final comentarios = rawComentarios is List
        ? rawComentarios
              .whereType<Map>()
              .map(
                (item) =>
                    ForoComentario.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ForoComentario>[];

    return ForoPublicacion(
      collection: collection,
      id: map['id'] as String,
      autor: _stringFrom(map, const [
        'autor',
        'autorNombre',
        'Nombre_psicologo',
        'Nombre_psicologa',
        'Nombre',
      ]),
      titulo: _stringFrom(map, const ['titulo', 'Titulo', 'asunto', 'tema']),
      contenido: _stringFrom(map, const [
        'contenido',
        'Contenido',
        'texto',
        'descripcion',
      ]),
      fecha: _safeParseDate(
        _firstValue(map, const [
          'fecha',
          'createdAt',
          'Fecha_publicacion',
          'updatedAt',
        ]),
      ),
      updatedAt: _safeParseDate(_firstValue(map, const ['updatedAt'])),
      likes: _intFrom(_firstValue(map, const ['likes', 'Likes', 'meGusta'])),
      likedBy: _stringListFrom(
        _firstValue(map, const ['likedBy', 'LikedBy', 'meGustaPor']),
      ),
      likesKey: map.containsKey('likes')
          ? 'likes'
          : map.containsKey('Likes')
          ? 'Likes'
          : map.containsKey('meGusta')
          ? 'meGusta'
          : 'likes',
      likedByKey: map.containsKey('likedBy')
          ? 'likedBy'
          : map.containsKey('LikedBy')
          ? 'LikedBy'
          : map.containsKey('meGustaPor')
          ? 'meGustaPor'
          : 'likedBy',
      comentarios: comentarios,
      comentariosKey: map.containsKey('comentarios')
          ? 'comentarios'
          : map.containsKey('Comentarios')
          ? 'Comentarios'
          : 'comentarios',
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> comentariosToPayload(
    List<ForoComentario> comentariosActualizados,
  ) {
    // Forzar el nombre del campo a 'Comentarios' para compatibilidad backend
    return {
      'Comentarios': comentariosActualizados
          .map((comentario) => comentario.toMap())
          .toList(),
    };
  }

  ForoPublicacion copyWith({
    int? likes,
    List<String>? likedBy,
    List<ForoComentario>? comentarios,
  }) {
    return ForoPublicacion(
      collection: collection,
      id: id,
      autor: autor,
      titulo: titulo,
      contenido: contenido,
      fecha: fecha,
      updatedAt: updatedAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      likesKey: likesKey,
      likedByKey: likedByKey,
      comentarios: comentarios ?? this.comentarios,
      comentariosKey: comentariosKey,
      raw: raw,
    );
  }
}

class ForoService {
  /// Agrega una nueva publicación al foro
  static Future<void> crearPublicacion({
    required String autor,
    required String rol,
    required String titulo,
    required String contenido,
  }) async {
    final now = DateTime.now().toUtc();
    final doc = <String, dynamic>{
      'autor': autor,
      'rol': rol,
      'titulo': titulo,
      'contenido': contenido,
      'fecha': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'comentarios': [],
    };
    await FirestoreService.addDocument('ForoPublicaciones', doc);
  }

  ForoService._();

  static const List<String> _collections = <String>[
    'ForoPublicaciones',
    'Publicaciones',
  ];

  static const Duration _cacheTtl = Duration(seconds: 45);
  static List<ForoPublicacion>? _cachePublicaciones;
  static DateTime? _cacheUpdatedAt;

  static bool get _isCacheValid {
    final cache = _cachePublicaciones;
    final updatedAt = _cacheUpdatedAt;
    if (cache == null || updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <= _cacheTtl;
  }

  static void _updateCache(List<ForoPublicacion> publicaciones) {
    _cachePublicaciones = List<ForoPublicacion>.from(publicaciones);
    _cacheUpdatedAt = DateTime.now();
  }

  static void _upsertCachedPost(
    String postId,
    ForoPublicacion Function(ForoPublicacion current) updater,
  ) {
    final cache = _cachePublicaciones;
    if (cache == null) return;

    final index = cache.indexWhere((post) => post.id == postId);
    if (index == -1) return;

    cache[index] = updater(cache[index]);
    _cacheUpdatedAt = DateTime.now();
  }

  static Future<List<ForoPublicacion>> fetchPublicaciones({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid) {
      return List<ForoPublicacion>.from(_cachePublicaciones!);
    }

    Object? lastError;

    for (final collection in _collections) {
      try {
        final docs = await FirestoreService.getCollection(collection);
        if (docs.isEmpty) continue;

        final publicaciones =
            docs
                .where((doc) => doc['id'] != null)
                .map((doc) => ForoPublicacion.fromMap(collection, doc))
                .toList()
              ..sort((a, b) {
                final aDate =
                    a.updatedAt ??
                    a.fecha ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bDate =
                    b.updatedAt ??
                    b.fecha ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });

        _updateCache(publicaciones);

        return publicaciones;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError!;
    }

    return <ForoPublicacion>[];
  }

  static Future<void> addComentario({
    required ForoPublicacion publicacion,
    required String autor,
    required String texto,
    String? autorUid,
  }) async {
    final comentariosActuales =
        List<ForoComentario>.from(publicacion.comentarios)..add(
          ForoComentario(
            autor: autor,
            texto: texto,
            autorUid: autorUid,
            fecha: DateTime.now(),
            reportado: false,
          ),
        );

    await FirestoreService.updateDocument(
      publicacion.collection,
      publicacion.id,
      publicacion.comentariosToPayload(comentariosActuales),
    );

    _upsertCachedPost(
      publicacion.id,
      (current) => current.copyWith(comentarios: comentariosActuales),
    );
  }

  static Future<Map<String, dynamic>> toggleLike({
    required ForoPublicacion publicacion,
    required String actorId,
    required int currentLikes,
    required List<String> currentLikedBy,
  }) async {
    final normalizedActor = actorId.trim();
    if (normalizedActor.isEmpty) {
      return <String, dynamic>{
        'likes': currentLikes,
        'likedBy': currentLikedBy,
      };
    }

    final likedBy = List<String>.from(currentLikedBy);
    final alreadyLiked = likedBy.contains(normalizedActor);

    if (alreadyLiked) {
      likedBy.remove(normalizedActor);
    } else {
      likedBy.add(normalizedActor);
    }

    final likes = likedBy.length;

    await FirestoreService.updateDocument(
      publicacion.collection,
      publicacion.id,
      <String, dynamic>{
        publicacion.likesKey: likes,
        publicacion.likedByKey: likedBy,
      },
    );

    _upsertCachedPost(
      publicacion.id,
      (current) => current.copyWith(likes: likes, likedBy: likedBy),
    );

    return <String, dynamic>{'likes': likes, 'likedBy': likedBy};
  }
}

dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) {
      return map[key];
    }
  }
  return null;
}

String _stringFrom(Map<String, dynamic> map, List<String> keys) {
  return _stringFromDynamic(_firstValue(map, keys), const []);
}

String _stringFromDynamic(dynamic value, List<String> nestedKeys) {
  final text = _responseTextFromDynamic(value, nestedKeys: nestedKeys);
  return text ?? '';
}

String? _responseTextFromDynamic(
  dynamic value, {
  List<String> nestedKeys = const [],
}) {
  if (value == null) return null;

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  if (value is num || value is bool) {
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  if (value is Map) {
    final mapValue = Map<String, dynamic>.from(value);

    for (final key in nestedKeys) {
      if (mapValue.containsKey(key)) {
        final nested = _responseTextFromDynamic(mapValue[key]);
        if (nested != null) return nested;
      }
    }

    const directCandidates = <String>['texto', 'contenido', 'mensaje'];
    for (final key in directCandidates) {
      if (mapValue.containsKey(key)) {
        final nested = _responseTextFromDynamic(mapValue[key]);
        if (nested != null) return nested;
      }
    }

    for (final entry in mapValue.entries) {
      final nested = _responseTextFromDynamic(entry.value);
      if (nested != null) return nested;
    }

    return null;
  }

  if (value is List) {
    for (final item in value) {
      final nested = _responseTextFromDynamic(item);
      if (nested != null) return nested;
    }
    return null;
  }

  final text = value.toString().trim();
  if (text.isEmpty || text == '[]' || text == '{}' || text == 'null') {
    return null;
  }

  return text;
}

DateTime? _safeParseDate(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  if (value is Map) {
    final mapValue = Map<String, dynamic>.from(value);
    if (mapValue.containsKey('_seconds')) {
      final seconds = mapValue['_seconds'];
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
  }

  return DateTime.tryParse(value.toString());
}

int _intFrom(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

List<String> _stringListFrom(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return <String>[];
}

bool _boolFrom(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'si';
  }
  return false;
}
