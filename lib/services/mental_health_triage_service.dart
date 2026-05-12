import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'firestore_service.dart';

class MentalHealthTriageResult {
  final String category;
  final String label;
  final String reply;
  final String recommendedSpecialty;
  final bool crisis;
  final String memory;
  final PsychologistMatch? psychologist;
  final EmotionsAnalysis emotions;
  final List<TherapyRecommendation> therapies;
  final TriageMetrics metrics;

  const MentalHealthTriageResult({
    required this.category,
    required this.label,
    required this.reply,
    required this.recommendedSpecialty,
    required this.crisis,
    required this.memory,
    required this.emotions,
    required this.therapies,
    required this.metrics,
    this.psychologist,
  });
}

class EmotionsAnalysis {
  final String primary;
  final double intensity;
  final String? secondary;

  const EmotionsAnalysis({
    required this.primary,
    required this.intensity,
    this.secondary,
  });

  String get primaryEmoji {
    switch (primary.toLowerCase()) {
      case 'alegria':
        return '😊';
      case 'tristeza':
        return '😢';
      case 'ira':
        return '😠';
      case 'miedo':
        return '😨';
      case 'ansiedad':
        return '😰';
      case 'culpa':
        return '😔';
      case 'vergüenza':
        return '😳';
      case 'soledad':
        return '😞';
      case 'esperanza':
        return '🌟';
      case 'frustracion':
        return '😤';
      case 'confianza':
        return '🤝';
      case 'desesperanza':
        return '😔';
      default:
        return '😐';
    }
  }

  String get intensityLabel {
    if (intensity >= 0.8) return 'Muy alta';
    if (intensity >= 0.6) return 'Alta';
    if (intensity >= 0.4) return 'Moderada';
    if (intensity >= 0.2) return 'Baja';
    return 'Muy baja';
  }
}

class TherapyRecommendation {
  final String name;
  final String description;
  final double suitability;

  const TherapyRecommendation({
    required this.name,
    required this.description,
    required this.suitability,
  });

  String get suitabilityLabel {
    if (suitability >= 0.8) return 'Muy recomendada';
    if (suitability >= 0.6) return 'Recomendada';
    if (suitability >= 0.4) return 'Considerar';
    return 'Opcional';
  }

  String get fullName {
    switch (name.toUpperCase()) {
      case 'CBT':
        return 'Terapia Cognitivo-Conductual';
      case 'DBT':
        return 'Terapia Dialéctica Conductual';
      case 'EMDR':
        return 'Desensibilización y Reprocesamiento por Movimientos Oculares';
      case 'ACT':
        return 'Terapia de Aceptación y Compromiso';
      case 'MBCT':
        return 'Terapia Cognitiva Basada en Mindfulness';
      case 'IPT':
        return 'Terapia Interpersonal';
      case 'EFT':
        return 'Terapia Centrada en Emociones';
      case 'GESTALT':
        return 'Terapia Gestalt';
      case 'PSICODINAMICA':
        return 'Terapia Psicodinámica';
      case 'HUMANISTA':
        return 'Terapia Humanista';
      default:
        return name;
    }
  }
}

class TriageMetrics {
  final double confidence;
  final int processingTime;
  final double sentimentScore;

  const TriageMetrics({
    required this.confidence,
    required this.processingTime,
    required this.sentimentScore,
  });

  String get confidenceLabel {
    if (confidence >= 0.8) return 'Muy confiable';
    if (confidence >= 0.6) return 'Confiable';
    if (confidence >= 0.4) return 'Moderadamente confiable';
    return 'Baja confianza';
  }

  String get sentimentLabel {
    if (sentimentScore >= 0.5) return 'Positivo';
    if (sentimentScore >= 0.1) return 'Ligeramente positivo';
    if (sentimentScore >= -0.1) return 'Neutral';
    if (sentimentScore >= -0.5) return 'Ligeramente negativo';
    return 'Negativo';
  }

  String get processingTimeLabel {
    if (processingTime < 1000) return 'ms';
    return 's';
  }
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
    bool forceMatchPsychologist = false,
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
          ? 'Sí, me dijiste que te llamas ${rememberedName.trim()}.'
          : 'Aún no tengo tu nombre guardado con claridad. Dime \"me llamo ...\" y lo recuerdo.';

      return MentalHealthTriageResult(
        category: 'general',
        label: 'recordatorio de identidad',
        reply: reply,
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
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
        memory: conversationMemory,
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
        psychologist: null,
      );
    }

    // Si el usuario comparte su nombre, confirmamos y lo guardamos de inmediato.
    final introducedName = _extractNameFromMessage(message);
    if (introducedName != null && introducedName.isNotEmpty) {
      final template = _pickResponseVariant(
        [
          'Gracias por contármelo, . Ya lo guardé y lo voy a recordar en nuestras siguientes conversaciones.',
          'Listo, . Ya registré tu nombre y lo tendré presente en adelante.',
          'Perfecto, . Ya quedó guardado y voy a recordarlo para acompañarte mejor.',
        ],
        message,
        recentConversation,
      );
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _insertValue(template, introducedName),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        emotions: const EmotionsAnalysis(primary: 'alegria', intensity: 0.4),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.3,
        ),
        psychologist: null,
      );
    }

    final introducedProfession = _extractProfessionFromMessage(message);
    if (introducedProfession != null && introducedProfession.isNotEmpty) {
      final template = _pickResponseVariant(
        [
          'Perfecto, ya guardé tu profesión: . La voy a recordar para las siguientes conversaciones.',
          'Listo, ya registré que te dedicas a: . Lo tendré en cuenta en adelante.',
          'Genial, ya quedó guardada tu profesión () y la recordaré para próximas charlas.',
        ],
        message,
        recentConversation,
      );
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _insertValue(template, introducedProfession),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
        psychologist: null,
      );
    }

    final introducedHobbies = _extractHobbiesFromMessage(message);
    if (introducedHobbies.isNotEmpty) {
      final hobbiesText = introducedHobbies.join(', ');
      final template = _pickResponseVariant(
        [
          'Listo, ya guardé tus hobbies: . Los voy a tener en cuenta en adelante.',
          'Perfecto, anoté tus hobbies (). Los recordaré para próximas conversaciones.',
          'Gracias, ya registré eso que te gusta ().',
        ],
        message,
        recentConversation,
      );
      return MentalHealthTriageResult(
        category: 'general',
        label: 'dato personal guardado',
        reply: _insertValue(template, hobbiesText),
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: _mergeMemory(conversationMemory, message),
        emotions: const EmotionsAnalysis(primary: 'alegria', intensity: 0.4),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.2,
        ),
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
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
        psychologist: null,
      );
    }

    if (_isOutOfScopeIntent(normalizedInput)) {
      return MentalHealthTriageResult(
        category: 'general',
        label: 'fuera de alcance',
        reply:
            'Oye, solo estoy para ayudarte con temas psicológicos, traumas y temas familiares. Si quieres, cuéntame cómo te sientes y ahí sí te acompaño.',
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: conversationMemory,
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [],
        metrics: const TriageMetrics(
          confidence: 0.9,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
        psychologist: null,
      );
    }

    // Llamada al backend de IA
    try {
      final response = await ApiClient.post('/api/ai/triage', {
        'message': message,
        'conversationContext': recentConversation,
        'conversationMemory': conversationMemory,
      }, auth: true);

      final responseMap = response is Map
          ? response as Map
          : <String, dynamic>{};
      final emotionsData = responseMap['emotions'];
      final emotionsMap = emotionsData is Map
          ? emotionsData as Map
          : <String, dynamic>{};

      final therapies = <TherapyRecommendation>[];
      final rawTherapies = responseMap['therapies'];
      if (rawTherapies is List) {
        for (final therapy in rawTherapies) {
          if (therapy is Map) {
            therapies.add(
              TherapyRecommendation(
                name: therapy['name']?.toString() ?? 'CBT',
                description:
                    therapy['description']?.toString() ?? 'Terapia recomendada',
                suitability: _parseDouble(therapy['suitability'], 0.5),
              ),
            );
          }
        }
      }

      final metricsData = responseMap['metrics'];
      final metricsMap = metricsData is Map
          ? metricsData as Map
          : <String, dynamic>{};
      final triageMetrics = TriageMetrics(
        confidence: _parseDouble(metricsMap['confidence'], 0.7),
        processingTime: _parseInt(metricsMap['processingTime'], 0),
        sentimentScore: _parseDouble(metricsMap['sentimentScore'], 0.0),
      );

      final emotionsAnalysis = EmotionsAnalysis(
        primary: emotionsMap['primary']?.toString() ?? 'neutral',
        intensity: _parseDouble(emotionsMap['intensity'], 0.5),
        secondary: emotionsMap['secondary']?.toString(),
      );

      // Buscar psicólogo si es necesario
      final crisisValue = _parseBool(responseMap['crisis'], false);
      PsychologistMatch? psychologist;
      if (forceMatchPsychologist ||
          responseMap['category']?.toString().toLowerCase() != 'general') {
        psychologist = await _findMatchingPsychologist(
          responseMap['recommendedSpecialty']?.toString() ??
              'Bienestar emocional',
        );
      }

      return MentalHealthTriageResult(
        category: responseMap['category']?.toString() ?? 'general',
        label: responseMap['label']?.toString() ?? 'orientación general',
        reply:
            responseMap['reply']?.toString() ??
            'Entiendo lo que me cuentas. ¿Quieres contarme más?',
        recommendedSpecialty:
            responseMap['recommendedSpecialty']?.toString() ??
            'Bienestar emocional',
        crisis: crisisValue,
        memory: responseMap['memory']?.toString() ?? conversationMemory,
        emotions: emotionsAnalysis,
        therapies: therapies,
        metrics: triageMetrics,
        psychologist: psychologist,
      );
    } catch (e, st) {
      debugPrint('[IA][ERROR] $e');
      debugPrint(st.toString());
      // Fallback en caso de error
      final errorMessage = e?.toString() ?? 'error desconocido';
      return MentalHealthTriageResult(
        category: 'general',
        label: 'error temporal',
        reply:
            'Lo siento, no pude conectar con el servicio de IA: $errorMessage. Verifica el backend y vuelve a intentarlo.',
        recommendedSpecialty: 'Bienestar emocional',
        crisis: false,
        memory: conversationMemory,
        emotions: const EmotionsAnalysis(primary: 'neutral', intensity: 0.3),
        therapies: const [
          TherapyRecommendation(
            name: 'CBT',
            description: 'Terapia Cognitivo-Conductual',
            suitability: 0.5,
          ),
        ],
        metrics: const TriageMetrics(
          confidence: 0.3,
          processingTime: 0,
          sentimentScore: 0.0,
        ),
        psychologist: null,
      );
    }
  }

  static double _parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '.').trim();
      return double.tryParse(normalized) ?? fallback;
    }
    return fallback;
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static bool _parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'sí' ||
          normalized == 'si';
    }
    return fallback;
  }

  static Future<PsychologistMatch?> _findMatchingPsychologist(
    String specialty,
  ) async {
    final normalizedSpecialty = _normalizeSpecialty(specialty);
    PsychologistMatch? fallback;

    for (final collection in _collections) {
      try {
        final docs = await FirestoreService.query(
          collection,
          field: 'role',
          operator: '==',
          value: 'psicologo',
        );

        for (final doc in docs) {
          final data = doc as Map<String, dynamic>;
          final specialties =
              data['especialidades'] ?? data['specialties'] ?? [];

          if (fallback == null) {
            fallback = PsychologistMatch(
              collection: collection,
              id: doc['id'] ?? '',
              uid: data['uid'] ?? '',
              documento: data['documento'] ?? '',
              name: data['nombre'] ?? data['name'] ?? 'Psicólogo',
              specialty: specialty,
              phone: data['telefono'] ?? data['phone'],
              raw: data,
            );
          }

          if (specialties is List) {
            for (final item in specialties) {
              final specialtyValue = item?.toString() ?? '';
              if (specialtyValue.trim().isEmpty) continue;

              final normalizedItem = _normalizeSpecialty(specialtyValue);
              if (normalizedItem == normalizedSpecialty ||
                  normalizedItem.contains(normalizedSpecialty) ||
                  normalizedSpecialty.contains(normalizedItem)) {
                return PsychologistMatch(
                  collection: collection,
                  id: doc['id'] ?? '',
                  uid: data['uid'] ?? '',
                  documento: data['documento'] ?? '',
                  name: data['nombre'] ?? data['name'] ?? 'Psicólogo',
                  specialty: specialty,
                  phone: data['telefono'] ?? data['phone'],
                  raw: data,
                );
              }
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    return fallback;
  }

  static String _normalizeSpecialty(String value) {
    return value
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^ -áéíóúüñ]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeAndCorrect(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\sáéíóúüñ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _insertValue(String template, String value) {
    if (template.isEmpty) return value;
    if (template.contains('{value}')) {
      return template.replaceFirst('{value}', value);
    }
    if (template.contains('()')) {
      return template.replaceFirst('()', value);
    }
    final markerIndex = template.indexOf('.');
    if (markerIndex >= 0) {
      return template.replaceFirst('.', value);
    }
    return '$template $value'.trim();
  }

  static bool _isAskNameIntent(String normalizedInput) {
    return normalizedInput.contains('me llamo') ||
        normalizedInput.contains('mi nombre es') ||
        normalizedInput.contains('como me llamo') ||
        normalizedInput.contains('cual es mi nombre') ||
        normalizedInput.contains('te acuerdas de mi nombre');
  }

  static bool _isPersonalDataRecallIntent(String normalizedInput) {
    return normalizedInput.contains('que te conte') ||
        normalizedInput.contains('que te dije') ||
        normalizedInput.contains('recuerdas') ||
        normalizedInput.contains('te acuerdas') ||
        normalizedInput.contains('que sabes de mi');
  }

  static String? _extractRememberedName(
    String memory,
    List<Map<String, String>> recent,
  ) {
    final memoryLines = memory.split('\n');
    for (final line in memoryLines) {
      if (line.toLowerCase().contains('nombre:') ||
          line.toLowerCase().contains('name:')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
    }
    return null;
  }

  static String _buildPersonalDataRecallReply(
    String normalizedInput,
    String memory,
    List<Map<String, String>> recent,
  ) {
    final memoryLines = memory
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (memoryLines.isEmpty) {
      return 'Aún no tengo mucha información guardada sobre ti. Cuéntame más sobre cómo te sientes o qué te preocupa.';
    }

    final relevantInfo = memoryLines.take(3).join('. ');
    return 'De lo que me has contado antes: $relevantInfo. ¿Quieres que profundicemos en algo de esto?';
  }

  static String? _extractNameFromMessage(String message) {
    final patterns = [
      RegExp(r'me llamo\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)', caseSensitive: false),
      RegExp(
        r'mi nombre es\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)',
        caseSensitive: false,
      ),
      RegExp(r'soy\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.groupCount >= 1) {
        final name = match.group(1)?.trim();
        if (name != null && name.length >= 2 && name.length <= 50) {
          return name;
        }
      }
    }
    return null;
  }

  static String? _extractProfessionFromMessage(String message) {
    final patterns = [
      RegExp(
        r'soy\s+(?:un|una)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'me dedico\s+a\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'trabajo\s+(?:de|como)\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)',
        caseSensitive: false,
      ),
      RegExp(r'estudio\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.groupCount >= 1) {
        final profession = match.group(1)?.trim();
        if (profession != null &&
            profession.length >= 3 &&
            profession.length <= 100) {
          return profession;
        }
      }
    }
    return null;
  }

  static List<String> _extractHobbiesFromMessage(String message) {
    final hobbies = <String>[];
    final patterns = [
      RegExp(r'me gusta\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s,]+)', caseSensitive: false),
      RegExp(
        r'me encantan?\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s,]+)',
        caseSensitive: false,
      ),
      RegExp(r'hago\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s,]+)', caseSensitive: false),
      RegExp(r'practico\s+([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s,]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          final hobbyText = match.group(1)?.trim();
          if (hobbyText != null) {
            final extracted = hobbyText
                .split(',')
                .map((h) => h.trim())
                .where((h) => h.length >= 3 && h.length <= 50);
            hobbies.addAll(extracted);
          }
        }
      }
    }

    return hobbies.toSet().toList(); // Eliminar duplicados
  }

  static List<String> _extractRelativesFromMessage(String message) {
    final relatives = <String>[];
    final patterns = [
      RegExp(
        r'(?:tengo|mi)\s+(?:un|una|unos|unas)?\s*([A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s]+)(?:\s+(?:que|quien))?',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          final relativeText = match.group(1)?.trim();
          if (relativeText != null &&
              relativeText.length >= 3 &&
              relativeText.length <= 100) {
            relatives.add(relativeText);
          }
        }
      }
    }

    return relatives;
  }

  static bool _isOutOfScopeIntent(String normalizedInput) {
    final outOfScopeKeywords = [
      'politica',
      'politico',
      'futbol',
      'deporte',
      'clima',
      'tiempo',
      'noticia',
      'noticias',
      'musica',
      'cine',
      'pelicula',
      'serie',
      'videojuego',
      'juego',
      'programacion',
      'codigo',
      'matematicas',
      'tarea',
      'examen',
      'escuela',
      'colegio',
      'universidad',
      'trabajo',
      'empresa',
      'negocio',
      'dinero',
      'economia',
      'religion',
      'iglesia',
    ];

    return outOfScopeKeywords.any(
      (keyword) => normalizedInput.contains(keyword),
    );
  }

  static String _pickResponseVariant(
    List<String> options,
    String message,
    List<Map<String, String>> recent,
  ) {
    if (options.isEmpty) return '';
    final seed = message.hashCode + recent.length;
    return options[seed % options.length];
  }

  static String _mergeMemory(String existingMemory, String newMessage) {
    final existingLines = existingMemory
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final facts = <String, String>{};
    final order = <String>[];

    void addFact(String key, String value) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty || value.trim().isEmpty) return;
      if (!facts.containsKey(normalizedKey)) {
        order.add(normalizedKey);
      }
      facts[normalizedKey] = value.trim();
    }

    for (final line in existingLines) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts.first.trim();
        final value = parts.sublist(1).join(':').trim();
        addFact(key, value);
      } else {
        addFact('Nota', line);
      }
    }

    for (final fact in _extractMemoryFacts(newMessage)) {
      addFact(fact['key']!, fact['value']!);
    }

    if (_extractMemoryFacts(newMessage).isEmpty) {
      addFact('Último tema', newMessage.trim());
    }

    final lines = order
        .where((key) => facts[key]!.isNotEmpty)
        .map((key) => '$key: ${facts[key]}')
        .toList();

    return lines.length <= 10
        ? lines.join('\n')
        : lines.sublist(0, 10).join('\n');
  }

  static List<Map<String, String>> _extractMemoryFacts(String message) {
    final text = message.toLowerCase();
    final facts = <Map<String, String>>[];

    final nameMatch = RegExp(
      r'me llamo\s+([a-záéíóúüñ\s]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (nameMatch != null) {
      facts.add({'key': 'Nombre', 'value': _capitalize(nameMatch[1]!.trim())});
    }

    final professionMatch = RegExp(
      r'(soy|trabajo como|estoy estudiando|estudio)\s+([a-záéíóúüñ\s]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (professionMatch != null) {
      final profession = professionMatch[2]!.trim();
      facts.add({'key': 'Profesión', 'value': _capitalize(profession)});
    }

    final hobbyMatch = RegExp(
      r'me gusta[n]?\s+([a-záéíóúüñ\s]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (hobbyMatch != null) {
      facts.add({'key': 'Hobby', 'value': _capitalize(hobbyMatch[1]!.trim())});
    }

    final familyMatch = RegExp(
      r'vivo con\s+([a-záéíóúüñ\s]+)|mi (mam[áa]|pap[áa]|hermano|hermana|pareja|familia)',
      caseSensitive: false,
    ).firstMatch(message);
    if (familyMatch != null) {
      facts.add({
        'key': 'Situación familiar',
        'value': _capitalize(familyMatch.group(0)!.trim()),
      });
    }

    return facts;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
