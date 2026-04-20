import 'api_client.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class MentalHealthTriageResult {
  final String category;
  final String label;
  final String reply;
  final String recommendedSpecialty;
  final bool crisis;
  final String memory;
  final PsychologistMatch? psychologist;

  const MentalHealthTriageResult({
    required this.category,
    required this.label,
    required this.reply,
    required this.recommendedSpecialty,
    required this.crisis,
    required this.memory,
    required this.psychologist,
  });
}

class PsychologistMatch {
  final String collection;
  final String id;
  final String uid;
  final String documento;
  final String name;
  final String specialty;
  final String? phone;
  final Map<String, dynamic> raw;

  const PsychologistMatch({
    required this.collection,
    required this.id,
    required this.uid,
    required this.documento,
    required this.name,
    required this.specialty,
    required this.phone,
    required this.raw,
  });

  String get displaySubtitle {
    final cleanSpecialty = specialty.trim();
    if (cleanSpecialty.isNotEmpty) {
      return cleanSpecialty;
    }
    return 'Psicólogo/a disponible';
  }
}

class MentalHealthTriageService {
  MentalHealthTriageService._();

  static const List<String> _collections = <String>[
    'usuarios',
    'Usuarios',
    'users',
    'Users',
    'Psicologos',
    'psicologos',
    'Profesionales',
  ];

  static Future<MentalHealthTriageResult> analyze(
    String message, {
    List<Map<String, String>> recentConversation =
        const <Map<String, String>>[],
    String conversationMemory = '',
  }) async {
    final normalizedInput = _normalizeAndCorrect(message);

    // Respuesta determinista para memoria de identidad.
    // Evita que el backend devuelva una frase genérica en este caso.
    if (_isAskNameIntent(normalizedInput)) {
      final rememberedName = _extractRememberedName(
        conversationMemory,
        recentConversation,
      );
      final reply = (rememberedName != null && rememberedName.trim().isNotEmpty)
          ? 'Sí, me dijiste que te llamas $rememberedName.'
          : 'Aún no tengo tu nombre guardado con claridad. Dime "me llamo ..." y lo recuerdo.';

      return MentalHealthTriageResult(
        category: 'general',
        label: 'recordatorio de identidad',
        reply: reply,
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    if (_isPersonalDataRecallIntent(normalizedInput)) {
      final reply = _buildPersonalDataRecallReply(
        normalizedInput,
        conversationMemory,
        recentConversation,
      );
      return MentalHealthTriageResult(
        category: 'general',
        label: 'recordatorio de datos personales',
        reply: reply,
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    // Si el usuario comparte su nombre, confirmamos y lo guardamos de inmediato.
    final introducedName = _extractNameFromMessage(message);
    if (introducedName != null && introducedName.isNotEmpty) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _pickResponseVariant(
          [
            'Gracias por contármelo, $introducedName. Ya lo guardé y lo voy a recordar en nuestras siguientes conversaciones.',
            'Listo, $introducedName. Ya registré tu nombre y lo tendré presente en adelante.',
            'Perfecto, $introducedName. Ya quedó guardado y voy a recordarlo para acompañarte mejor.',
          ],
          message,
          recentConversation,
        ),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    final introducedProfession = _extractProfessionFromMessage(message);
    if (introducedProfession != null && introducedProfession.isNotEmpty) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _pickResponseVariant(
          [
            'Perfecto, ya guardé tu profesión: $introducedProfession. La voy a recordar para las siguientes conversaciones.',
            'Listo, ya registré que te dedicas a: $introducedProfession. Lo tendré en cuenta en adelante.',
            'Genial, ya quedó guardada tu profesión ($introducedProfession) y la recordaré para próximas charlas.',
          ],
          message,
          recentConversation,
        ),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    final introducedHobbies = _extractHobbiesFromMessage(message);
    if (introducedHobbies.isNotEmpty) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _pickResponseVariant(
          [
            'Listo, ya guardé tus hobbies: ${introducedHobbies.join(', ')}. Los voy a tener en cuenta en adelante.',
            'Perfecto, anoté tus hobbies (${introducedHobbies.join(', ')}). Los recordaré para próximas conversaciones.',
            'Gracias, ya registré eso que te gusta (${introducedHobbies.join(', ')}).',
          ],
          message,
          recentConversation,
        ),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    final introducedRelatives = _extractRelativesFromMessage(message);
    if (introducedRelatives.isNotEmpty) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _pickResponseVariant(
          [
            'Gracias, ya guardé esos datos de tu familia y los voy a recordar para apoyarte mejor.',
            'Listo, ya registré la información de tu familia. La tendré presente en adelante.',
            'Perfecto, esos datos familiares ya quedaron guardados para darte mejor continuidad.',
          ],
          message,
          recentConversation,
        ),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    if (_isOutOfScopeIntent(normalizedInput)) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'fuera de alcance',
        reply: _pickResponseVariant(
          [
            'Oye, solo estoy para ayudarte con temas psicológicos, traumas y temas familiares. Si quieres, cuéntame cómo te sientes o qué te preocupa y ahí sí te acompaño.',
            'Ese tema se sale de mi enfoque. Yo te apoyo en temas psicológicos, traumas y familia. Si quieres, dime cómo te estás sintiendo y lo vemos juntos.',
            'No soy para deportes o temas generales; estoy para acompañarte en lo emocional, traumas y familia. Si quieres, seguimos por ahí.',
          ],
          message,
          recentConversation,
        ),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    try {
      final data = await ApiClient.post('/api/ai/triage', <String, dynamic>{
        'message': message,
        'conversationContext': recentConversation,
        'conversationMemory': conversationMemory,
      }, auth: true);

      if (data is Map<String, dynamic>) {
        final category = _readString(data, const ['category']).trim();
        final label = _readString(data, const ['label']).trim();
        final reply = _readString(data, const ['reply']).trim();
        final specialty = _readString(data, const [
          'recommendedSpecialty',
        ]).trim();
        final memory = _readString(data, const ['memory']).trim();
        final crisis = data['crisis'] == true;

        if (category.isNotEmpty &&
            reply.isNotEmpty &&
            !_isTooSimilarReply(reply, message)) {
          final psychologist = await _findBestPsychologist(
            category,
            specialty.isNotEmpty ? specialty : _recommendedSpecialty(category),
          );

          return MentalHealthTriageResult(
            category: category,
            label: label.isNotEmpty ? label : _categoryLabel(category),
            reply: reply,
            recommendedSpecialty: specialty.isNotEmpty
                ? specialty
                : _recommendedSpecialty(category),
            crisis: crisis,
            memory: memory.isNotEmpty
                ? memory
                : _mergeMemory(conversationMemory, message),
            psychologist: psychologist,
          );
        }
      }
    } catch (_) {
      // Fallback local si Gemini o el backend fallan.
    }

    final normalized = _normalizeAndCorrect(message);
    if (_isSummaryIntent(normalized)) {
      final summaryReply = _buildSummaryReply(
        recentConversation,
        conversationMemory,
      );
      return MentalHealthTriageResult(
        category: 'general',
        label: 'resumen de conversación',
        reply: summaryReply,
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        psychologist: null,
      );
    }

    final category = _detectCategory(normalized);
    final label = _categoryLabel(category);
    final specialty = _recommendedSpecialty(category);
    final reply = _buildReply(
      category,
      label,
      message,
      recentConversation: recentConversation,
      conversationMemory: conversationMemory,
    );
    final psychologist = await _findBestPsychologist(category, specialty);

    return MentalHealthTriageResult(
      category: category,
      label: label,
      reply: reply,
      recommendedSpecialty: specialty,
      crisis: category == 'crisis',
      memory: _mergeMemory(conversationMemory, message),
      psychologist: psychologist,
    );
  }

  static Future<List<PsychologistMatch>> fetchPsychologists() async {
    final matches = <String, PsychologistMatch>{};

    for (final collection in _collections) {
      try {
        final docs = await FirestoreService.getCollection(collection);
        for (final doc in docs) {
          final role = _readString(doc, const ['role', 'rol']).toLowerCase();
          final collectionLooksPsychological =
              collection.toLowerCase().contains('psicolog') ||
              collection.toLowerCase().contains('profesional');

          if (role.isNotEmpty && role != 'psicologo') {
            continue;
          }

          if (role.isEmpty && !collectionLooksPsychological) {
            continue;
          }

          final psychologist = await _mapPsychologist(collection, doc);
          if (psychologist.documento.isNotEmpty) {
            matches[psychologist.documento] = psychologist;
          } else if (psychologist.uid.isNotEmpty) {
            matches[psychologist.uid] = psychologist;
          } else {
            matches['${collection}:${psychologist.id}'] = psychologist;
          }
        }
      } catch (_) {
        continue;
      }
    }

    return matches.values.toList();
  }

  static Future<PsychologistMatch?> _findBestPsychologist(
    String category,
    String specialty,
  ) async {
    final psychologists = await fetchPsychologists();
    if (psychologists.isEmpty) return null;

    final normalizedCategory = _normalize(category);
    final normalizedSpecialty = _normalize(specialty);

    PsychologistMatch? bestMatch;
    int bestScore = -1;

    for (final psychologist in psychologists) {
      final keywords = <String>{
        _normalize(psychologist.specialty),
        ..._collectKeywords(psychologist.raw),
      }.where((item) => item.isNotEmpty).toSet();

      var score = 0;
      for (final keyword in keywords) {
        if (keyword.contains(normalizedCategory) ||
            normalizedCategory.contains(keyword)) {
          score += 3;
        }
        if (keyword.contains(normalizedSpecialty) ||
            normalizedSpecialty.contains(keyword)) {
          score += 4;
        }
        for (final token in _categoryTokens(category)) {
          if (keyword.contains(token)) {
            score += 1;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = psychologist;
      }
    }

    return bestMatch ?? psychologists.first;
  }

  static Future<PsychologistMatch> _mapPsychologist(
    String collection,
    Map<String, dynamic> doc,
  ) async {
    final uid = _readString(doc, const ['uid']).trim();
    final docId = _readString(doc, const ['id']).trim();
    final resolvedUid = uid.isNotEmpty ? uid : docId;
    final name = await _resolvePsychologistName(doc, resolvedUid);
    final specialty = _readString(doc, const [
      'especialidad',
      'especialidades',
      'areas',
      'area',
      'tags',
      'tema',
    ]);

    final phone = _readString(doc, const ['telefono', 'phone']).trim();

    return PsychologistMatch(
      collection: collection,
      id: docId,
      uid: resolvedUid,
      documento: _readString(doc, const [
        'documento',
        'Documento',
        'Documento_psicologo',
      ]).trim(),
      name: name,
      specialty: specialty,
      phone: phone.isEmpty ? null : phone,
      raw: Map<String, dynamic>.from(doc),
    );
  }

  static Future<String> _resolvePsychologistName(
    Map<String, dynamic> doc,
    String uid,
  ) async {
    final candidate = _displayName(doc);
    if (!_isPlaceholderName(candidate)) {
      return candidate;
    }

    if (uid.isEmpty) {
      return candidate;
    }

    try {
      final authUser = await AuthService.getUser(uid);
      final authName = _readString(authUser, const [
        'displayName',
        'nombreCompleto',
        'nombre',
      ]);
      if (!_isPlaceholderName(authName)) {
        return authName;
      }
    } catch (_) {
      // Si Auth no responde, se conserva el valor de Firestore.
    }

    return candidate;
  }

  static String _displayName(Map<String, dynamic> doc) {
    final direct = _readString(doc, const [
      'displayName',
      'nombreCompleto',
      'nombre',
      'Nombre_psicologo',
      'Nombre_psicologa',
      'Nombre',
    ]);
    final apellido = _readString(doc, const ['apellido']);

    final isPlaceholderName = _isPlaceholderName(direct);

    final fullName = [
      isPlaceholderName ? '' : direct,
      apellido,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    return fullName.isEmpty ? 'Psicólogo/a disponible' : fullName;
  }

  static bool _isPlaceholderName(String value) {
    final normalized = _normalize(value);
    return normalized.isEmpty ||
        normalized == 'el nombre' ||
        normalized == 'nombre' ||
        normalized == 'name' ||
        normalized == 'psicologo' ||
        normalized == 'psicologa' ||
        normalized == 'psicólogo' ||
        normalized == 'psicóloga';
  }

  static String _detectCategory(String normalizedMessage) {
    if (_isFeelingBadIntent(normalizedMessage) ||
        normalizedMessage.contains('me siento triste') ||
        normalizedMessage.contains('estoy mal')) {
      return 'tristeza';
    }

    final scoredCategories = <String, int>{
      'crisis': _score(normalizedMessage, const [
        'suicid',
        'matarme',
        'quitarme la vida',
        'hacerme daño',
        'autoles',
        'no quiero vivir',
        'emergencia',
      ]),
      'ansiedad': _score(normalizedMessage, const [
        'ansiedad',
        'angustia',
        'nervios',
        'panic',
        'panico',
        'ataque',
        'me falta el aire',
      ]),
      'estres': _score(normalizedMessage, const [
        'estres',
        'estrés',
        'agotado',
        'sobrecarga',
        'presion',
        'presión',
        'burnout',
      ]),
      'tristeza': _score(normalizedMessage, const [
        'triste',
        'deprim',
        'llorar',
        'vacío',
        'vacio',
        'sin ganas',
        'duelo',
      ]),
      'familiar': _score(normalizedMessage, const [
        'familia',
        'pareja',
        'hijo',
        'padre',
        'madre',
        'relacion',
        'relación',
      ]),
      'sueno': _score(normalizedMessage, const [
        'insomnio',
        'dormir',
        'sueño',
        'sueno',
        'descansar',
      ]),
    };

    final best = scoredCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (best.isEmpty || best.first.value <= 0) {
      return 'general';
    }

    return best.first.key;
  }

  static String _categoryLabel(String category) {
    switch (category) {
      case 'crisis':
        return 'posible situación de crisis';
      case 'ansiedad':
        return 'ansiedad o angustia';
      case 'estres':
        return 'estrés o saturación';
      case 'tristeza':
        return 'tristeza o bajón emocional';
      case 'familiar':
        return 'conflicto familiar o relacional';
      case 'sueno':
        return 'problemas de sueño';
      default:
        return 'orientación general';
    }
  }

  static String _recommendedSpecialty(String category) {
    switch (category) {
      case 'crisis':
        return 'Atención en crisis';
      case 'ansiedad':
        return 'Ansiedad y regulación emocional';
      case 'estres':
        return 'Estrés y manejo de carga mental';
      case 'tristeza':
        return 'Estado de ánimo y acompañamiento emocional';
      case 'familiar':
        return 'Terapia familiar o de pareja';
      case 'sueno':
        return 'Sueño, descanso y ansiedad';
      default:
        return 'Bienestar emocional';
    }
  }

  static String _buildReply(
    String category,
    String label,
    String originalMessage, {
    List<Map<String, String>> recentConversation =
        const <Map<String, String>>[],
    String conversationMemory = '',
  }) {
    final normalized = _normalize(originalMessage);
    final hasViolenceInHome =
        (normalized.contains('padre') &&
        normalized.contains('madre') &&
        (normalized.contains('pega') ||
            normalized.contains('golpea') ||
            normalized.contains('maltrata') ||
            normalized.contains('agrede')));

    switch (category) {
      case 'crisis':
        return 'Lo que cuentas me preocupa. Si hay peligro ahora mismo, busca a una persona de confianza o emergencias ya mismo; si quieres, me quedo contigo para pensar el siguiente paso.';
      case 'ansiedad':
        return 'Eso suena muy cargado por dentro. Cuéntame en qué momentos se pone peor y qué notas en tu cuerpo para ubicarlo mejor.';
      case 'estres':
        return 'Parece que traes demasiado encima. Si me dices qué es lo que más te está agotando hoy, lo ordenamos juntos sin prisa.';
      case 'tristeza':
        return 'Se siente pesado lo que estás contando. Si quieres, dime qué fue lo que más te golpeó hoy y lo vemos paso a paso.';
      case 'familiar':
        if (hasViolenceInHome) {
          return 'Lo que cuentas es serio. Si ahora mismo hay golpes o riesgo en casa, busca a un adulto de confianza, sal a un lugar seguro si puedes y pide ayuda de inmediato. ¿Tu mamá está a salvo ahora mismo?';
        }

        return 'Lo que pasa en tu casa suena duro. Si quieres, dime qué ocurrió primero y qué es lo que más te preocupa ahora para ayudarte a ordenar el siguiente paso.';
      case 'sueno':
        return 'Dormir mal te puede dejar todo más cuesta arriba. Dime si te cuesta dormirte, te despiertas mucho o te levantas sin energía, y te respondo más fino.';
      default:
        return _buildGeneralReply(
          originalMessage,
          recentConversation: recentConversation,
          conversationMemory: conversationMemory,
        );
    }
  }

  static String _buildGeneralReply(
    String originalMessage, {
    List<Map<String, String>> recentConversation =
        const <Map<String, String>>[],
    String conversationMemory = '',
  }) {
    final normalized = _normalizeAndCorrect(originalMessage);
    final lastUserMessage = _lastUserMessage(recentConversation);
    final contextHint =
        lastUserMessage.isNotEmpty && _normalize(lastUserMessage) != normalized
        ? lastUserMessage
        : '';

    if (_isAskNameIntent(normalized)) {
      final rememberedName = _extractRememberedName(
        conversationMemory,
        recentConversation,
      );
      if (rememberedName != null && rememberedName.trim().isNotEmpty) {
        return 'Sí, me dijiste que te llamas $rememberedName.';
      }
      return 'Aún no tengo tu nombre guardado con claridad. Si quieres, dime "me llamo ..." y lo recuerdo.';
    }

    final introducedName = _extractNameFromMessage(originalMessage);
    if (introducedName != null && introducedName.isNotEmpty) {
      return 'Gracias por contármelo, $introducedName. Voy a recordarlo para acompañarte mejor.';
    }

    if (_isGreeting(normalized)) {
      return _pickResponseVariant(
        [
          'Te leo. Cuéntame qué te trae por acá hoy y voy contigo paso a paso, sin responderte en automático.',
          'Aquí estoy contigo. Si quieres, cuéntame qué te está pasando hoy y lo vamos ordenando.',
          'Gracias por escribir. Dime qué te está pesando ahora y lo trabajamos juntos.',
        ],
        originalMessage,
        recentConversation,
      );
    }

    if (_isFeelingBadIntent(normalized) ||
        normalized.contains('estoy mal') ||
        normalized.contains('no me siento bien')) {
      return _pickToneAwareResponse(
        normalizedMessage: normalized,
        seed: originalMessage,
        recentConversation: recentConversation,
        intenseOptions: const [
          'Gracias por decírmelo. Vamos paso a paso: ¿qué fue lo primero que pasó y qué te pegó más fuerte?',
          'Te leo, y no estás solo/a en esto. Empecemos por una parte: ¿qué fue lo más pesado de hoy?',
        ],
        lowMoodOptions: const [
          'Gracias por decirlo con claridad. Si quieres, cuéntame qué parte te pesó más hoy y lo ordenamos juntos.',
          'Está bien decir que te sientes mal. Cuéntame qué fue lo que más te bajó hoy.',
        ],
        neutralOptions: const [
          'Gracias por decírmelo con claridad. Vamos a aterrizarlo: ¿qué pasó primero y qué parte te pesó más hoy?',
          'Gracias por abrirte. Si me cuentas qué pasó primero, te ayudo a ordenarlo mejor.',
        ],
      );
    }

    if (normalized.contains('problema') ||
        normalized.contains('discusion') ||
        normalized.contains('pelea') ||
        normalized.contains('conflicto')) {
      return _pickToneAwareResponse(
        normalizedMessage: normalized,
        seed: originalMessage,
        recentConversation: recentConversation,
        intenseOptions: const [
          'Suena fuerte lo que estás viviendo. Enfoquémonos en una parte: ¿qué te preocupa más ahora mismo?',
          'Entiendo que esto te esté cargando. Dime qué fue lo más difícil y lo resolvemos por partes.',
        ],
        lowMoodOptions: const [
          'Suena a algo que te viene pesando bastante. Si quieres, cuéntame qué te preocupa más y lo ordenamos.',
          'Parece un tema que te ha desgastado. Cuéntame qué parte te duele más y empezamos por ahí.',
        ],
        neutralOptions: const [
          'Suena a algo que te está cargando bastante. Si me cuentas qué pasó y qué te preocupa más, lo ordenamos juntos sin hacerlo más grande de lo necesario.',
          'Entiendo. Si me cuentas qué ocurrió y qué te preocupa más ahora, te ayudo a aterrizarlo.',
        ],
      );
    }

    if (normalized.contains('me pegaron') ||
        normalized.contains('me golpearon') ||
        normalized.contains('me pego') ||
        normalized.contains('me golpeo') ||
        normalized.contains('me maltratan') ||
        normalized.contains('me maltrataron') ||
        normalized.contains('violencia') ||
        normalized.contains('abuso') ||
        normalized.contains('me agredieron') ||
        (normalized.contains('padre') &&
            normalized.contains('madre') &&
            (normalized.contains('pega') ||
                normalized.contains('golpea') ||
                normalized.contains('maltrata') ||
                normalized.contains('agrede')))) {
      return 'Lo que cuentas es serio. Si ahora mismo hay golpes o riesgo en casa, busca a un adulto de confianza, sal a un lugar seguro si puedes y pide ayuda de inmediato. ¿Tu mamá está a salvo ahora mismo?';
    }

    if (normalized.contains('mi papa') ||
        normalized.contains('mi papá') ||
        normalized.contains('mi mama') ||
        normalized.contains('mi mamá') ||
        normalized.contains('mis papás') ||
        normalized.contains('mis papas')) {
      if (normalized.contains('pega') ||
          normalized.contains('golpea') ||
          normalized.contains('maltrata') ||
          normalized.contains('agrede')) {
        return 'Lo que cuentas es serio. Si ahora mismo hay golpes o riesgo en casa, busca a un adulto de confianza, sal a un lugar seguro si puedes y pide ayuda de inmediato. ¿Tu mamá está a salvo ahora mismo?';
      }

      return 'Lo que pasa en tu casa suena duro. Si quieres, dime qué ocurrió primero y qué es lo que más te pesa ahora para ayudarte a ordenar el siguiente paso.';
    }

    if (normalized.contains('freefire') ||
        normalized.contains('juego') ||
        normalized.contains('gaming')) {
      return 'Eso también puede pegar emocionalmente más de lo que parece. Cuéntame qué ocurrió en concreto y qué parte te dejó más incómodo/a.';
    }

    if (_wantsHumanSupport(normalized)) {
      return _pickToneAwareResponse(
        normalizedMessage: normalized,
        seed: originalMessage,
        recentConversation: recentConversation,
        intenseOptions: const [
          'Claro, te acompaño y te conecto con apoyo humano ahora mismo. Mientras tanto, me quedo contigo por aquí.',
          'Gracias por pedirlo. Vamos a buscar apoyo humano de inmediato y yo sigo aquí contigo.',
        ],
        lowMoodOptions: const [
          'Claro, te acompaño y te conecto con apoyo humano. Si quieres, seguimos por aquí mientras preparo la derivación.',
          'Me parece buena decisión. Te ayudo a conectar con una persona de apoyo y seguimos hablando aquí.',
        ],
        neutralOptions: const [
          'Claro, te acompaño y te conecto con apoyo humano. Si quieres, seguimos por aquí mientras preparo la derivación.',
          'Perfecto, te apoyo para pasar con una persona y te acompaño en el proceso.',
        ],
      );
    }

    if (contextHint.isNotEmpty) {
      return 'Te sigo el hilo. Lo que mencionas ahora conecta con lo de antes, y eso me ayuda a entender mejor el cuadro. Si quieres, dime qué cambió desde ese momento.';
    }

    return _pickResponseVariant(
      [
        'Te leo. Cuéntame un poco más de lo que pasó y te respondo con algo más útil y directo.',
        'Estoy contigo. Si me das un poco más de contexto, te respondo de forma más concreta.',
        'Gracias por abrir el tema. Cuéntame un poco más para ayudarte con algo realmente útil.',
      ],
      '$originalMessage|$contextHint',
      recentConversation,
    );
  }

  static bool _isGreeting(String normalizedMessage) {
    const greetings = <String>[
      'hola',
      'buenas',
      'buenos dias',
      'buenas tardes',
      'buenas noches',
      'como estas',
      'que tal',
      'holi',
    ];
    return greetings.any(normalizedMessage.contains);
  }

  static bool _isFeelingBadIntent(String normalizedMessage) {
    return _matchesAnyFlexible(normalizedMessage, const [
      'me siento mal',
      'me he sentido mal',
      'me eh sentido mal',
      'me e sentido mal',
      'me sentido mal',
      'me siento triste',
      'no me siento bien',
      'me siento muy mal',
      'me he sentido triste',
    ]);
  }

  static bool _wantsHumanSupport(String normalizedMessage) {
    return normalizedMessage.contains('quiero hablar con una persona') ||
        normalizedMessage.contains('quiero hablar con alguien') ||
        normalizedMessage.contains('quiero hablar con un psicologo') ||
        normalizedMessage.contains('quiero hablar con psicologo') ||
        normalizedMessage.contains('quiero hablar con una psicologa') ||
        normalizedMessage.contains('quiero hablar con psicologa') ||
        normalizedMessage.contains('con una persona') ||
        normalizedMessage.contains('con alguien') ||
        normalizedMessage.contains('pasame con una persona') ||
        normalizedMessage.contains('pasame con alguien') ||
        normalizedMessage.contains('pasame con el psicologo') ||
        normalizedMessage.contains('pasame con la psicologa') ||
        normalizedMessage.contains('derivame con un psicologo') ||
        normalizedMessage.contains('derivame con una persona') ||
        normalizedMessage.contains('necesito una persona') ||
        normalizedMessage.contains('necesito hablar con alguien');
  }

  static String _lastUserMessage(List<Map<String, String>> recentConversation) {
    for (var index = recentConversation.length - 1; index >= 0; index--) {
      final entry = recentConversation[index];
      if (entry['role'] == 'user') {
        return (entry['text'] ?? '').trim();
      }
    }
    return '';
  }

  static bool _isAskNameIntent(String normalizedMessage) {
    return _matchesAnyFlexible(normalizedMessage, const [
      'como me llamo',
      'como me llamas',
      'cual es mi nombre',
      'te acuerdas de mi nombre',
    ]);
  }

  static bool _isPersonalDataRecallIntent(String normalizedMessage) {
    return _matchesAnyFlexible(normalizedMessage, const [
      'que sabes de mi',
      'que recuerdas de mi',
      'recuerdas de mi',
      'cuentame sobre mi',
      'cuentame de mi',
      'dime sobre mi',
      'hablame de mi',
      'como soy',
      'que sabes sobre mi',
      'que sabes acerca de mi',
      'como es mi nombre',
      'como es mi profesion',
      'como es mi hobby',
      'como es mi trabajo',
      'cuentame sobre mi nombre',
      'cuentame sobre mi profesion',
      'cual es mi profesion',
      'a que me dedico',
      'en que trabajo',
      'cual es mi hobby',
      'cuales son mis hobbies',
      'que hobby tengo',
      'como se llama mi mama',
      'como se llama mi papa',
      'como se llama mi hermano',
      'como se llama mi hermana',
      'como se llama mi esposa',
      'como se llama mi esposo',
      'como se llama mi hijo',
      'como se llama mi hija',
      'nombres de mis familiares',
    ]);
  }

  static bool _isOutOfScopeIntent(String normalizedMessage) {
    final psychSignals = [
      'emocion',
      'emocional',
      'sentir',
      'siento',
      'ansiedad',
      'estres',
      'triste',
      'deprim',
      'llorar',
      'familia',
      'padre',
      'madre',
      'mama',
      'papa',
      'pareja',
      'hijo',
      'hija',
      'hermano',
      'hermana',
      'trauma',
      'traumas',
      'abuso',
      'violencia',
      'crisis',
      'suicid',
      'dormir',
      'sueño',
      'sueno',
    ];

    final offTopicSignals = [
      'jugar',
      'juego',
      'juega',
      'free fire',
      'free firee',
      'freefire',
      'colombia juega',
      'que dia juega',
      'partido',
      'futbol',
      'baloncesto',
      'tenis',
      'formula 1',
      'clima',
      'temperatura',
      'noticias',
      'politica',
      'politico',
      'musica',
      'cancion',
      'pelicula',
      'serie',
      'videojuego',
      'gaming',
      'codigo',
      'programar',
      'matematic',
      'tarea',
      'examen',
      'escuela',
      'colegio',
      'trabajo',
    ];

    final isPsychRelated = _containsAnyFlexibleKeywords(
      normalizedMessage,
      psychSignals,
    );
    if (isPsychRelated) {
      return false;
    }

    return _containsAnyFlexibleKeywords(normalizedMessage, offTopicSignals);
  }

  static String _buildPersonalDataRecallReply(
    String normalizedMessage,
    String conversationMemory,
    List<Map<String, String>> recentConversation,
  ) {
    final name = _extractRememberedName(conversationMemory, recentConversation);
    final profession = _extractRememberedProfession(conversationMemory);
    final hobbies = _extractRememberedHobbies(conversationMemory);
    final relatives = _extractRememberedRelatives(conversationMemory);

    if (_matchesAnyFlexible(normalizedMessage, const [
      'cual es mi profesion',
      'a que me dedico',
      'en que trabajo',
      'cual es mi trabajo',
      'cual es mi ocupacion',
      'mi profesion',
    ])) {
      if (profession != null && profession.isNotEmpty) {
        return 'Me dijiste que tu profesion es $profession.';
      }
      return 'Aun no tengo tu profesion guardada. Si quieres, dime "mi profesion es ..." y la recuerdo.';
    }

    if (_matchesAnyFlexible(normalizedMessage, const [
      'cual es mi hobby',
      'cuales son mis hobbies',
      'que hobby tengo',
      'cuales son mis gustos',
      'que me gusta',
      'cual es mi pasatiempo',
    ])) {
      if (hobbies.isNotEmpty) {
        return 'Recuerdo que tus hobbies incluyen ${hobbies.join(', ')}.';
      }
      return 'Aun no tengo hobbies guardados. Si quieres, dime "mi hobby es ..." o "me gusta ...".';
    }

    if (_matchesAnyFlexible(normalizedMessage, const [
      'como se llama mi mama',
      'como se llama mi papa',
      'como se llama mi hermano',
      'como se llama mi hermana',
      'como se llama mi esposa',
      'como se llama mi esposo',
      'como se llama mi hijo',
      'como se llama mi hija',
      'nombres de mis familiares',
      'nombre de mi familia',
    ])) {
      if (relatives.isNotEmpty) {
        final parts = <String>[];
        relatives.forEach((relation, personName) {
          parts.add('tu $relation se llama $personName');
        });
        return 'Recuerdo esto de tu familia: ${parts.join('; ')}.';
      }
      return 'Aun no tengo nombres de familiares guardados. Puedes decirme, por ejemplo: "mi mama se llama Ana".';
    }

    final profileSummary = _buildPersonalProfileSummary(
      name: name,
      profession: profession,
      hobbies: hobbies,
      relatives: relatives,
    );

    if (profileSummary.isEmpty) {
      return 'Por ahora solo tengo pocos datos tuyos. Si quieres, comparte tu profesion, hobbies o nombres de familiares y los voy guardando.';
    }

    return 'Si, esto es lo que recuerdo de ti: $profileSummary.';
  }

  static String _buildPersonalProfileSummary({
    String? name,
    String? profession,
    List<String> hobbies = const [],
    Map<String, String> relatives = const {},
  }) {
    final parts = <String>[];

    if (name != null && name.isNotEmpty) {
      parts.add('te llamas $name');
    }

    if (profession != null && profession.isNotEmpty) {
      parts.add('tu profesion es $profession');
    }

    if (hobbies.isNotEmpty) {
      parts.add('te gustan ${_joinNaturalList(hobbies)}');
    }

    if (relatives.isNotEmpty) {
      final relativeParts = <String>[];
      relatives.forEach((relation, personName) {
        relativeParts.add('$relation $personName');
      });
      parts.add('tu familia incluye ${_joinNaturalList(relativeParts)}');
    }

    return _joinNaturalList(parts);
  }

  static String _joinNaturalList(List<String> items) {
    final cleaned = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) return cleaned.first;
    if (cleaned.length == 2) return '${cleaned[0]} y ${cleaned[1]}';
    return '${cleaned.sublist(0, cleaned.length - 1).join(', ')}, y ${cleaned.last}';
  }

  static String _pickResponseVariant(
    List<String> options,
    String seed,
    List<Map<String, String>> recentConversation,
  ) {
    if (options.isEmpty) return '';
    final normalizedSeed = _normalize(seed);
    final hash = normalizedSeed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    var index = hash % options.length;
    var candidate = options[index];

    final lastAssistant = _lastAssistantMessage(recentConversation);
    if (options.length > 1 &&
        lastAssistant.isNotEmpty &&
        candidate == lastAssistant) {
      index = (index + 1) % options.length;
      candidate = options[index];
    }

    return candidate;
  }

  static String _pickToneAwareResponse({
    required String normalizedMessage,
    required String seed,
    required List<Map<String, String>> recentConversation,
    required List<String> intenseOptions,
    required List<String> lowMoodOptions,
    required List<String> neutralOptions,
  }) {
    final tone = _detectTone(normalizedMessage);
    late final String raw;
    if (tone == 'intense' && intenseOptions.isNotEmpty) {
      raw = _pickResponseVariant(intenseOptions, seed, recentConversation);
      return _adaptResponseLengthByTone(raw, tone);
    }
    if (tone == 'low_mood' && lowMoodOptions.isNotEmpty) {
      raw = _pickResponseVariant(lowMoodOptions, seed, recentConversation);
      return _adaptResponseLengthByTone(raw, tone);
    }
    raw = _pickResponseVariant(neutralOptions, seed, recentConversation);
    return _adaptResponseLengthByTone(raw, tone);
  }

  static String _adaptResponseLengthByTone(String text, String tone) {
    final clean = text.trim();
    if (clean.isEmpty) return clean;

    if (tone == 'intense') {
      return _shortenToNaturalBoundary(clean, 125);
    }

    if (tone == 'low_mood') {
      return _shortenToNaturalBoundary(clean, 190);
    }

    return clean;
  }

  static String _shortenToNaturalBoundary(String text, int maxLength) {
    if (text.length <= maxLength) return text;

    final cut = text.substring(0, maxLength);
    final punctuationIndex = [
      cut.lastIndexOf('.'),
      cut.lastIndexOf('?'),
      cut.lastIndexOf('!'),
      cut.lastIndexOf(';'),
    ].reduce((a, b) => a > b ? a : b);

    if (punctuationIndex >= 60) {
      return cut.substring(0, punctuationIndex + 1).trim();
    }

    final wordIndex = cut.lastIndexOf(' ');
    if (wordIndex >= 50) {
      return '${cut.substring(0, wordIndex).trim()}...';
    }

    return '${cut.trim()}...';
  }

  static String _detectTone(String normalizedMessage) {
    final intenseSignals = [
      'panico',
      'ataque',
      'no puedo',
      'desesper',
      'urgente',
      'crisis',
      'me ahogo',
      'me falta el aire',
      'ayuda ya',
    ];
    if (_containsAnyFlexibleKeywords(normalizedMessage, intenseSignals)) {
      return 'intense';
    }

    final lowMoodSignals = [
      'triste',
      'deprim',
      'depre',
      'ansieda',
      'sin ganas',
      'vacio',
      'vacío',
      'cansado',
      'cansada',
      'agotado',
      'agotada',
      'llorar',
    ];
    if (_containsAnyFlexibleKeywords(normalizedMessage, lowMoodSignals)) {
      return 'low_mood';
    }

    return 'neutral';
  }

  static String _lastAssistantMessage(
    List<Map<String, String>> recentConversation,
  ) {
    for (var i = recentConversation.length - 1; i >= 0; i--) {
      final entry = recentConversation[i];
      if ((entry['role'] ?? '').toLowerCase() == 'assistant') {
        return (entry['text'] ?? '').trim();
      }
    }
    return '';
  }

  static bool _matchesAnyFlexible(
    String normalizedMessage,
    List<String> phrases,
  ) {
    for (final phrase in phrases) {
      if (_matchesFlexiblePhrase(normalizedMessage, phrase)) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesFlexiblePhrase(String normalizedMessage, String phrase) {
    final normalizedPhrase = _normalize(phrase);
    if (normalizedMessage.contains(normalizedPhrase)) {
      return true;
    }

    final messageTokens = normalizedMessage
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final phraseTokens = normalizedPhrase
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (phraseTokens.isEmpty || messageTokens.isEmpty) {
      return false;
    }

    if (phraseTokens.length == 1) {
      return messageTokens.any(
        (token) => _levenshteinDistance(token, phraseTokens.first) <= 1,
      );
    }

    if (messageTokens.length < phraseTokens.length) {
      return _levenshteinDistance(normalizedMessage, normalizedPhrase) <= 2;
    }

    for (var i = 0; i <= messageTokens.length - phraseTokens.length; i++) {
      final window = messageTokens
          .sublist(i, i + phraseTokens.length)
          .join(' ');
      if (_levenshteinDistance(window, normalizedPhrase) <= 2) {
        return true;
      }
    }

    return _levenshteinDistance(normalizedMessage, normalizedPhrase) <= 2;
  }

  static int _levenshteinDistance(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;

    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);

    for (var i = 1; i <= left.length; i++) {
      current[0] = i;
      for (var j = 1; j <= right.length; j++) {
        final substitutionCost = left[i - 1] == right[j - 1] ? 0 : 1;
        final insertion = current[j - 1] + 1;
        final deletion = previous[j] + 1;
        final substitution = previous[j - 1] + substitutionCost;
        current[j] = insertion < deletion
            ? (insertion < substitution ? insertion : substitution)
            : (deletion < substitution ? deletion : substitution);
      }

      for (var j = 0; j < previous.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[right.length];
  }

  static String? _extractNameFromMessage(String message) {
    final cleaned = message.trim();
    if (cleaned.isEmpty) return null;

    final match = RegExp(
      r'\b(?:me\s+llamo|mi\s+nombre\s+es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (match == null) return null;
    final rawName = (match.group(1) ?? '').trim();
    if (rawName.isEmpty) return null;

    final lowered = rawName.toLowerCase();
    if (lowered == 'yo' || lowered == 'nadie') return null;

    final parts = rawName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final titleCased = parts
        .map((part) {
          final p = part.trim();
          if (p.isEmpty) return p;
          return '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
        })
        .join(' ')
        .trim();

    return titleCased.isEmpty ? null : titleCased;
  }

  static String? _extractRememberedName(
    String conversationMemory,
    List<Map<String, String>> recentConversation,
  ) {
    for (final line in conversationMemory.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('identidad: nombre=')) {
        final value = trimmed.substring('identidad: nombre='.length).trim();
        if (value.isNotEmpty) return value;
      }

      final fact = _parseStructuredFact(trimmed);
      if (fact != null && fact['category'] == 'identidad') {
        final content = (fact['content'] as String? ?? '').trim();
        if (content.startsWith('nombre=')) {
          final value = content.substring('nombre='.length).trim();
          if (value.isNotEmpty) return value;
        }
      }
    }

    for (var i = recentConversation.length - 1; i >= 0; i--) {
      final entry = recentConversation[i];
      if ((entry['role'] ?? '').toLowerCase() != 'user') continue;
      final text = (entry['text'] ?? '').trim();
      final extracted = _extractNameFromMessage(text);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }

    return null;
  }

  static String? _extractRememberedProfession(String conversationMemory) {
    for (final line in conversationMemory.split('\n')) {
      final fact = _parseStructuredFact(line);
      if (fact == null) continue;
      final category = (fact['category'] as String? ?? '').trim();
      final content = (fact['content'] as String? ?? '').trim();
      if (category == 'identidad' && content.startsWith('profesion=')) {
        final value = content.substring('profesion='.length).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static List<String> _extractRememberedHobbies(String conversationMemory) {
    final hobbies = <String>{};
    for (final line in conversationMemory.split('\n')) {
      final fact = _parseStructuredFact(line);
      if (fact == null) continue;
      final category = (fact['category'] as String? ?? '').trim();
      final content = (fact['content'] as String? ?? '').trim();
      if (category == 'identidad' && content.startsWith('hobby=')) {
        final value = content.substring('hobby='.length).trim();
        if (value.isNotEmpty) hobbies.add(value);
      }
    }
    return hobbies.toList();
  }

  static Map<String, String> _extractRememberedRelatives(
    String conversationMemory,
  ) {
    final relatives = <String, String>{};
    for (final line in conversationMemory.split('\n')) {
      final fact = _parseStructuredFact(line);
      if (fact == null) continue;
      final category = (fact['category'] as String? ?? '').trim();
      final content = (fact['content'] as String? ?? '').trim();
      if (category == 'identidad' && content.startsWith('familiar:')) {
        final payload = content.substring('familiar:'.length).trim();
        final idx = payload.indexOf('=');
        if (idx <= 0 || idx == payload.length - 1) continue;
        final relation = payload.substring(0, idx).trim();
        final name = payload.substring(idx + 1).trim();
        if (relation.isNotEmpty && name.isNotEmpty) {
          relatives[relation] = name;
        }
      }
    }
    return relatives;
  }

  static String? _extractProfessionFromMessage(String message) {
    final cleaned = message.trim();
    if (cleaned.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(
        r'\btrabajo\s+como\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]{3,50})',
        caseSensitive: false,
      ),
      RegExp(
        r'\bmi\s+profe(?:s|c)ion\s+(?:es|en)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]{3,50})',
        caseSensitive: false,
      ),
      RegExp(
        r'\bme\s+dedico\s+a\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]{3,50})',
        caseSensitive: false,
      ),
      RegExp(
        r'\bsoy\s+(?:un|una)?\s*([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]{3,50})',
        caseSensitive: false,
      ),
    ];

    RegExpMatch? match;
    for (final pattern in patterns) {
      match = pattern.firstMatch(cleaned);
      if (match != null) break;
    }

    if (match == null) return null;
    final raw = (match.group(1) ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _extractHobbiesFromMessage(String message) {
    final hobbies = <String>[];
    final cleaned = message.trim();
    if (cleaned.isEmpty) return hobbies;

    final hobbyMatch = RegExp(
      r'\b(?:mi\s+hobby\s+es|mis\s+hobbies\s+son|me\s+gusta|me\s+encanta)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s,]{3,80})',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (hobbyMatch != null) {
      final raw = (hobbyMatch.group(1) ?? '').trim();
      final pieces = raw
          .split(RegExp(r',| y '))
          .map((p) => p.trim())
          .where((p) => p.length >= 3)
          .toList();
      hobbies.addAll(pieces);
    }

    return hobbies;
  }

  static Map<String, String> _extractRelativesFromMessage(String message) {
    final data = <String, String>{};
    final cleaned = message.trim();
    if (cleaned.isEmpty) return data;

    final patterns = <String, String>{
      'mama':
          r'\b(?:mi\s+mama|mi\s+mamá|madre)\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'papa':
          r'\b(?:mi\s+papa|mi\s+papá|padre)\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'hermano':
          r'\bmi\s+hermano\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'hermana':
          r'\bmi\s+hermana\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'esposa':
          r'\bmi\s+esposa\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'esposo':
          r'\bmi\s+esposo\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'hijo':
          r'\bmi\s+hijo\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
      'hija':
          r'\bmi\s+hija\s+(?:se\s+llama|es)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,})?)',
    };

    patterns.forEach((relation, pattern) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(cleaned);
      if (match == null) return;
      final rawName = (match.group(1) ?? '').trim();
      if (rawName.isEmpty) return;
      data[relation] = rawName.replaceAll(RegExp(r'\s+'), ' ');
    });

    return data;
  }

  static bool _isSummaryIntent(String normalizedMessage) {
    return normalizedMessage.contains('resumen') ||
        normalizedMessage.contains('resumir') ||
        normalizedMessage.contains('resumeme') ||
        normalizedMessage.contains('hazme un resumen') ||
        normalizedMessage.contains('resume lo que') ||
        normalizedMessage.contains('que te conte') ||
        normalizedMessage.contains('que te dije');
  }

  static String _buildSummaryReply(
    List<Map<String, String>> recentConversation,
    String conversationMemory,
  ) {
    final memoryLines = conversationMemory
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.toLowerCase().startsWith('perfil:'))
        .toList();

    final structuredFacts = memoryLines
        .map(_parseStructuredFact)
        .whereType<Map<String, dynamic>>()
        .toList();

    final summaryFacts = structuredFacts
        .where((fact) => (fact['score'] as int) >= 2)
        .take(4)
        .map(_humanizeStructuredFact)
        .where((text) => text.trim().isNotEmpty)
        .toList();

    final memorySummary = summaryFacts.isNotEmpty
        ? summaryFacts.join('; ')
        : memoryLines
              .where((line) => !line.toLowerCase().startsWith('ultimo tema:'))
              .take(3)
              .join('; ');

    final userMessages = recentConversation
        .where((entry) => (entry['role'] ?? '').toLowerCase() == 'user')
        .map((entry) => (entry['text'] ?? '').trim())
        .where((text) => text.isNotEmpty)
        .where((text) => !_isSummaryIntent(_normalize(text)))
        .toList();

    if (memoryLines.isEmpty && userMessages.isEmpty) {
      return 'Todavía no tengo suficiente contexto para resumirte bien. Si quieres, dime exactamente qué parte quieres que resuma y lo hago en breve.';
    }

    final lastTopics = userMessages.length <= 2
        ? userMessages.join(' | ')
        : userMessages.sublist(userMessages.length - 2).join(' | ');

    final combined =
        '${memorySummary.toLowerCase()} ${lastTopics.toLowerCase()}';
    final hasFamilyContext =
        combined.contains('familiar') ||
        combined.contains('mama') ||
        combined.contains('mamá') ||
        combined.contains('papa') ||
        combined.contains('papá') ||
        combined.contains('casa');
    final hasViolenceContext =
        combined.contains('violencia') ||
        combined.contains('maltrato') ||
        combined.contains('golpe') ||
        combined.contains('agred');
    final hasNightContext = combined.contains('noche');

    if (memorySummary.isNotEmpty && lastTopics.isNotEmpty) {
      final intro = hasViolenceContext || hasFamilyContext
          ? 'Sí, me acuerdo. Sé que este tema te duele.'
          : 'Sí, me acuerdo de lo que venimos hablando.';
      final followUp = hasNightContext
          ? 'Si quieres, retomemos desde esa noche: ¿qué fue lo más difícil para ti en ese momento?'
          : 'Si quieres, retomemos por la parte que más te pesa ahora para ayudarte con algo concreto.';
      return '$intro En resumen, me contaste: $memorySummary. Lo último que mencionaste fue: $lastTopics. $followUp';
    }

    final base = memorySummary.isNotEmpty ? memorySummary : lastTopics;
    final intro = hasViolenceContext || hasFamilyContext
        ? 'Sí, me acuerdo. Sé que este tema te duele.'
        : 'Sí, me acuerdo de lo que venimos hablando.';
    return '$intro En resumen, me contaste: $base. Si quieres, lo bajamos a un siguiente paso concreto para hoy.';
  }

  static String _mergeMemory(String currentMemory, String message) {
    final updatedFacts = _extractMemoryFacts(message);
    final byKey = <String, Map<String, dynamic>>{};

    void mergeLine(String line) {
      final parsed = _parseStructuredFact(line);
      if (parsed == null) {
        final fallback = line.trim();
        if (fallback.isEmpty) return;
        final key = 'legacy:${fallback.toLowerCase()}';
        byKey[key] = {'category': 'contexto', 'score': 1, 'content': fallback};
        return;
      }

      final category = parsed['category'] as String;
      final content = parsed['content'] as String;
      final score = parsed['score'] as int;
      final key = _memoryKeyForFact(category, content);
      final prev = byKey[key];
      if (prev == null || score > (prev['score'] as int)) {
        byKey[key] = parsed;
      }
    }

    for (final line in currentMemory.split('\n')) {
      mergeLine(line);
    }

    for (final line in updatedFacts) {
      mergeLine(line);
    }

    if (!byKey.values.any((fact) => fact['category'] == 'perfil')) {
      byKey['perfil:seguimiento'] = {
        'category': 'perfil',
        'score': 1,
        'content': 'usuario con seguimiento continuo',
      };
    }

    final ordered = byKey.values.toList()
      ..sort((a, b) {
        final scoreCmp = (b['score'] as int).compareTo(a['score'] as int);
        if (scoreCmp != 0) return scoreCmp;
        return (a['category'] as String).compareTo(b['category'] as String);
      });

    final limited = ordered.take(12).map(_toStructuredLine).toList();
    return limited.join('\n');
  }

  static String _memoryKeyForFact(String category, String content) {
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedContent = content.trim().toLowerCase();

    if (normalizedCategory == 'identidad') {
      if (normalizedContent.startsWith('nombre=')) {
        return 'identidad:nombre';
      }

      if (normalizedContent.startsWith('profesion=')) {
        return 'identidad:profesion';
      }

      if (normalizedContent.startsWith('hobby=')) {
        final hobbyValue = normalizedContent.substring('hobby='.length).trim();
        return hobbyValue.isEmpty
            ? 'identidad:hobby'
            : 'identidad:hobby:$hobbyValue';
      }

      if (normalizedContent.startsWith('familiar:')) {
        final payload = normalizedContent.substring('familiar:'.length).trim();
        final relation = payload.split('=').first.trim();
        return relation.isEmpty
            ? 'identidad:familiar'
            : 'identidad:familiar:$relation';
      }
    }

    return '$normalizedCategory:$normalizedContent';
  }

  static List<String> _extractMemoryFacts(String message) {
    final normalized = _normalize(message);
    final facts = <String>[];

    final name = _extractNameFromMessage(message);
    if (name != null && name.isNotEmpty) {
      facts.add(_fact('identidad', 5, 'nombre=$name'));
    }

    final profession = _extractProfessionFromMessage(message);
    if (profession != null && profession.isNotEmpty) {
      facts.add(_fact('identidad', 4, 'profesion=$profession'));
    }

    final hobbies = _extractHobbiesFromMessage(message);
    for (final hobby in hobbies) {
      if (hobby.trim().isNotEmpty) {
        facts.add(_fact('identidad', 3, 'hobby=${hobby.trim()}'));
      }
    }

    final relatives = _extractRelativesFromMessage(message);
    relatives.forEach((relation, personName) {
      if (relation.trim().isEmpty || personName.trim().isEmpty) return;
      facts.add(
        _fact('identidad', 4, 'familiar:$relation=${personName.trim()}'),
      );
    });

    if (normalized.contains('me pegaron') ||
        normalized.contains('me golpearon') ||
        normalized.contains('me pego') ||
        normalized.contains('me golpeo') ||
        normalized.contains('me maltratan') ||
        normalized.contains('me maltrataron') ||
        normalized.contains('violencia') ||
        normalized.contains('abuso') ||
        normalized.contains('me agredieron')) {
      facts.add(_fact('riesgo', 5, 'reporta violencia o maltrato'));
    }

    if (normalized.contains('mi papa') ||
        normalized.contains('mi papá') ||
        normalized.contains('mi mama') ||
        normalized.contains('mi mamá') ||
        normalized.contains('mis papas') ||
        normalized.contains('mis papás') ||
        normalized.contains('padre') ||
        normalized.contains('madre')) {
      facts.add(_fact('contexto', 4, 'situación familiar cercana'));
    }

    if (normalized.contains('quiero hablar con una persona') ||
        normalized.contains('quiero hablar con alguien') ||
        normalized.contains('quiero hablar con un psicologo') ||
        normalized.contains('quiero hablar con psicologo') ||
        normalized.contains('quiero hablar con una psicologa') ||
        normalized.contains('quiero hablar con psicologa') ||
        normalized.contains('necesito hablar con alguien') ||
        normalized.contains('necesito una persona') ||
        normalized.contains('pasame con una persona') ||
        normalized.contains('conectame con el psicologo')) {
      facts.add(_fact('preferencia', 4, 'quiere apoyo humano o derivación'));
    }

    if (normalized.contains('no quiero hablar con psicologo') ||
        normalized.contains('no quiero hablar con psicólogo') ||
        normalized.contains('no quiero con un psicologo') ||
        normalized.contains('no quiero con un psicólogo')) {
      facts.add(
        _fact('preferencia', 4, 'evita derivación a psicólogo por ahora'),
      );
    }

    if (normalized.contains('ansiedad') ||
        normalized.contains('angustia') ||
        normalized.contains('nervios') ||
        normalized.contains('panic') ||
        normalized.contains('panico')) {
      facts.add(_fact('estado', 3, 'ansiedad o angustia'));
    }

    if (normalized.contains('triste') ||
        normalized.contains('deprim') ||
        normalized.contains('llorar') ||
        normalized.contains('sin ganas')) {
      facts.add(_fact('estado', 3, 'tristeza o bajón emocional'));
    }

    if (normalized.contains('escuela') ||
        normalized.contains('colegio') ||
        normalized.contains('clase') ||
        normalized.contains('examen') ||
        normalized.contains('tarea')) {
      facts.add(_fact('contexto', 2, 'situación escolar o académica'));
    }

    if (normalized.contains('trabajo') ||
        normalized.contains('laboral') ||
        normalized.contains('jefe') ||
        normalized.contains('empleo')) {
      facts.add(_fact('contexto', 2, 'situación laboral'));
    }

    if (normalized.contains('ayuda') ||
        normalized.contains('respirar') ||
        normalized.contains('caminar') ||
        normalized.contains('escuchar musica') ||
        normalized.contains('escuchar música')) {
      facts.add(_fact('apoyo', 2, 'le sirven estrategias cortas y concretas'));
    }

    if (normalized.contains('pareja') ||
        normalized.contains('novio') ||
        normalized.contains('novia') ||
        normalized.contains('relacion') ||
        normalized.contains('relación')) {
      facts.add(_fact('contexto', 2, 'relación de pareja'));
    }

    if (facts.isEmpty && message.trim().isNotEmpty) {
      final shortText = message.trim().replaceAll(RegExp(r'\s+'), ' ');
      facts.add(_fact('contexto', 1, 'ultimo tema: $shortText'));
    }

    return facts;
  }

  static String _fact(String category, int score, String content) {
    final safeCategory = category.trim().toLowerCase();
    final safeScore = score.clamp(1, 5);
    final safeContent = content.trim();
    return '$safeCategory|$safeScore|$safeContent';
  }

  static Map<String, dynamic>? _parseStructuredFact(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'^([a-z_]+)\|(\d+)\|(.+)$').firstMatch(trimmed);
    if (match == null) return null;

    final category = (match.group(1) ?? '').trim();
    final score = int.tryParse(match.group(2) ?? '') ?? 1;
    final content = (match.group(3) ?? '').trim();
    if (category.isEmpty || content.isEmpty) return null;

    return {
      'category': category,
      'score': score.clamp(1, 5),
      'content': content,
    };
  }

  static String _toStructuredLine(Map<String, dynamic> fact) {
    final category = (fact['category'] as String? ?? 'contexto').trim();
    final score = (fact['score'] as int? ?? 1).clamp(1, 5);
    final content = (fact['content'] as String? ?? '').trim();
    return '$category|$score|$content';
  }

  static String _humanizeStructuredFact(Map<String, dynamic> fact) {
    final category = (fact['category'] as String? ?? '').trim();
    final content = (fact['content'] as String? ?? '').trim();
    if (content.isEmpty) return '';

    if (category == 'identidad' && content.startsWith('nombre=')) {
      final value = content.substring('nombre='.length).trim();
      return value.isEmpty ? '' : 'te llamas $value';
    }

    if (category == 'identidad' && content.startsWith('profesion=')) {
      final value = content.substring('profesion='.length).trim();
      return value.isEmpty ? '' : 'tu profesion es $value';
    }

    if (category == 'identidad' && content.startsWith('hobby=')) {
      final value = content.substring('hobby='.length).trim();
      return value.isEmpty ? '' : 'te gusta $value';
    }

    if (category == 'identidad' && content.startsWith('familiar:')) {
      final payload = content.substring('familiar:'.length).trim();
      final idx = payload.indexOf('=');
      if (idx > 0 && idx < payload.length - 1) {
        final relation = payload.substring(0, idx).trim();
        final value = payload.substring(idx + 1).trim();
        if (relation.isNotEmpty && value.isNotEmpty) {
          return 'tu $relation se llama $value';
        }
      }
      return '';
    }

    return content;
  }

  static int _score(String normalizedMessage, List<String> keywords) {
    var total = 0;
    for (final keyword in keywords) {
      if (_containsKeywordFlexible(normalizedMessage, _normalize(keyword))) {
        total += 1;
      }
    }
    return total;
  }

  static bool _containsAnyFlexibleKeywords(
    String normalizedMessage,
    List<String> keywords,
  ) {
    for (final keyword in keywords) {
      if (_containsKeywordFlexible(normalizedMessage, _normalize(keyword))) {
        return true;
      }
    }
    return false;
  }

  static bool _containsKeywordFlexible(
    String normalizedMessage,
    String normalizedKeyword,
  ) {
    if (normalizedKeyword.isEmpty || normalizedMessage.isEmpty) {
      return false;
    }

    if (normalizedMessage.contains(normalizedKeyword)) {
      return true;
    }

    final messageTokens = normalizedMessage
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final keywordTokens = normalizedKeyword
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (keywordTokens.isEmpty || messageTokens.isEmpty) {
      return false;
    }

    if (keywordTokens.length == 1) {
      final target = keywordTokens.first;
      return messageTokens.any((token) {
        if (token == target) return true;
        if ((target.length - token.length).abs() > 1) return false;
        if (target.length < 5 || token.length < 5) return false;
        return _levenshteinDistance(token, target) <= 1;
      });
    }

    return _matchesFlexiblePhrase(normalizedMessage, normalizedKeyword);
  }

  static List<String> _categoryTokens(String category) {
    switch (category) {
      case 'crisis':
        return const ['crisis', 'urgencia', 'emergencia'];
      case 'ansiedad':
        return const ['ansiedad', 'angustia', 'panic'];
      case 'estres':
        return const ['estres', 'sobrecarga', 'burnout'];
      case 'tristeza':
        return const ['tristeza', 'depresion', 'duelo'];
      case 'familiar':
        return const ['familia', 'pareja', 'relacion'];
      case 'sueno':
        return const ['sueno', 'insomnio', 'dormir'];
      default:
        return const [];
    }
  }

  static Set<String> _collectKeywords(Map<String, dynamic> doc) {
    final keywords = <String>{};
    for (final key in const [
      'especialidad',
      'especialidades',
      'areas',
      'area',
      'tags',
      'tema',
      'servicios',
      'enfoque',
      'motivo',
    ]) {
      final value = doc[key];
      if (value is String) {
        keywords.add(_normalize(value));
      } else if (value is List) {
        for (final item in value) {
          keywords.add(_normalize(item.toString()));
        }
      }
    }
    return keywords;
  }

  static String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeAndCorrect(String value) {
    final base = _normalize(value);
    if (base.isEmpty) return base;

    final phraseCorrections = <String, String>{
      'me e sentido': 'me he sentido',
      'me eh sentido': 'me he sentido',
      'q siento': 'que siento',
      'q me pasa': 'que me pasa',
      'free firee': 'free fire',
      'freefiree': 'freefire',
    };

    var corrected = base;
    phraseCorrections.forEach((wrong, right) {
      corrected = corrected.replaceAll(RegExp('\\b$wrong\\b'), right);
    });

    const tokenCorrections = <String, String>{
      'sientoo': 'siento',
      'sienti': 'siento',
      'ansieda': 'ansiedad',
      'ansiedda': 'ansiedad',
      'deprecion': 'depresion',
      'depre': 'deprim',
      'profecion': 'profesion',
      'profecionn': 'profesion',
      'sicologico': 'psicologico',
      'psicolojico': 'psicologico',
      'trauam': 'trauma',
      'traumaa': 'trauma',
      'famila': 'familia',
      'familar': 'familiar',
      'estresadooo': 'estresado',
      'trsite': 'triste',
      'deprmido': 'deprimido',
      'juegar': 'jugar',
      'futbool': 'futbol',
    };

    final correctedTokens = corrected
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => tokenCorrections[token] ?? token)
        .toList();

    return correctedTokens.join(' ').trim();
  }

  static bool _isTooSimilarReply(String reply, String message) {
    final normalizedReply = _normalize(reply);
    final normalizedMessage = _normalize(message);
    if (normalizedReply.isEmpty || normalizedMessage.isEmpty) return false;

    if (normalizedReply.contains(normalizedMessage) ||
        normalizedMessage.contains(normalizedReply)) {
      return true;
    }

    final replyWords = normalizedReply
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toSet();
    final messageWords = normalizedMessage
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toSet();

    if (replyWords.isEmpty || messageWords.isEmpty) return false;

    final overlap = replyWords.intersection(messageWords).length;
    final ratio = overlap / messageWords.length;
    return ratio >= 0.6;
  }

  static String _readString(Map<String, dynamic> doc, List<String> keys) {
    for (final key in keys) {
      final value = doc[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
