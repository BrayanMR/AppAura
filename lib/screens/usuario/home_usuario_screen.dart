import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import 'chat_screen.dart';
import 'foro_usuario_screen.dart';
import '../shared/perfil_screen.dart';
import '../../widgets/nav_usuario.dart';

class HomeUsuarioScreen extends StatefulWidget {
  const HomeUsuarioScreen({super.key});

  @override
  State<HomeUsuarioScreen> createState() => _HomeUsuarioScreenState();
}

class _HomeUsuarioScreenState extends State<HomeUsuarioScreen> {
  int _currentIndex = 0;
  Timer? _activoTimer;

  @override
  void initState() {
    super.initState();
    _checkUserActivo();
    _startActivoPolling();
  }

  @override
  void dispose() {
    _activoTimer?.cancel();
    super.dispose();
  }

  void _startActivoPolling() {
    _activoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkUserActivo();
    });
  }

  Future<void> _checkUserActivo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await FirestoreService.getDocument('usuarios', user.uid);
      final activo =
          profile['activo'] == true ||
          profile['activo'] == 'true' ||
          profile['activo'] == 1;
      if (!activo && mounted) {
        await AuthService.signOut();
        await FirebaseAuth.instance.signOut();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (_) {}
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _DashboardUsuario(
          onGoForo: () => setState(() => _currentIndex = 1),
          onGoChat: () => setState(() => _currentIndex = 2),
          onGoPerfil: () => setState(() => _currentIndex = 3),
        );
      case 1:
        return const ForoUsuarioScreen();
      case 2:
        return const ChatScreen();
      case 3:
      default:
        return const PerfilScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCurrentTab()),
          Align(
            alignment: Alignment.bottomCenter,
            child: LiquidBottomNav(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                LiquidNavItem(
                  icon: Icons.home_outlined,
                  semanticLabel: 'Inicio',
                ),
                LiquidNavItem(
                  icon: Icons.forum_outlined,
                  semanticLabel: 'Foro',
                ),
                LiquidNavItem(
                  icon: Icons.chat_bubble_outline,
                  semanticLabel: 'Chats',
                ),
                LiquidNavItem(
                  icon: Icons.person_outline,
                  semanticLabel: 'Perfil',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardUsuario extends StatefulWidget {
  final VoidCallback onGoForo;
  final VoidCallback onGoChat;
  final VoidCallback onGoPerfil;

  const _DashboardUsuario({
    required this.onGoForo,
    required this.onGoChat,
    required this.onGoPerfil,
  });

  @override
  State<_DashboardUsuario> createState() => _DashboardUsuarioState();
}

class _DashboardUsuarioState extends State<_DashboardUsuario> {
  static const String _kMoodDateKey = 'usuario_mood_date';
  static const String _kMoodValueKey = 'usuario_mood_value';
  static const String _kMoodPhraseKey = 'usuario_mood_phrase';
  static const String _kMoodHistoryDatesKey = 'usuario_mood_history_dates';
  static const String _kMoodHistoryEntriesKey = 'usuario_mood_history_entries';

  static const List<String> _dailyQuestions = [
    'Como te sientes en este momento?',
    'Que palabra describe mejor tu energia hoy?',
    'Como estuvo tu estado emocional durante la manana?',
    'Que te ayudaria a sentirte mejor ahora?',
    'Tu mente esta en calma o muy activa hoy?',
    'Como va tu nivel de estres hoy?',
    'Que necesitas para cerrar el dia con tranquilidad?',
  ];

  String? _selectedMood;
  String? _moodPhrase;
  String _moodEmoji = '✨';
  int _emojiRainTick = 0;
  String _currentQuestion = _dailyQuestions.first;
  bool _hasDailySelection = false;
  Map<String, String> _moodHistoryByDate = <String, String>{};
  late final PageController _contentPageController;
  int _contentPageIndex = 0;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _currentQuestion = _dailyQuestionFor(DateTime.now());
    _contentPageController = PageController(viewportFraction: 0.86);
    _loadDailyMoodState();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _contentPageController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyMoodState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final savedDate = prefs.getString(_kMoodDateKey);
    final savedMood = prefs.getString(_kMoodValueKey);
    final savedPhrase = prefs.getString(_kMoodPhraseKey);
    final historyEntries =
        prefs.getStringList(_kMoodHistoryEntriesKey) ?? const <String>[];
    final legacyDates =
        prefs.getStringList(_kMoodHistoryDatesKey) ?? const <String>[];
    final historyMap = _decodeMoodHistory(historyEntries, legacyDates);

    final question = _dailyQuestionFor(now);
    final todayKey = _dateKey(now);

    if (!mounted) return;
    setState(() {
      _currentQuestion = question;
      if (savedDate == todayKey && savedMood != null) {
        _selectedMood = savedMood;
        _moodPhrase = savedPhrase ?? _phraseForMood(savedMood);
        _moodEmoji = _emojiForMood(savedMood);
        _hasDailySelection = true;
      } else {
        _selectedMood = null;
        _moodPhrase = null;
        _moodEmoji = '✨';
        _hasDailySelection = false;
      }
      _moodHistoryByDate = historyMap;
    });
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);

    _midnightTimer = Timer(delay, () async {
      if (!mounted) return;
      await _clearMoodSelection(persist: true);
      _scheduleMidnightReset();
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _emojiForMood(String mood) {
    switch (mood) {
      case 'En calma':
        return '🌿';
      case 'Con ansiedad':
        return '💙';
      case 'Con energia':
        return '⚡';
      default:
        return '✨';
    }
  }

  String _phraseForMood(String mood) {
    final phrases = switch (mood) {
      'En calma' => const [
        'Ese flow tranquilo tuyo esta top. Sigue asi, un paso a la vez 🌿',
        'Tu paz hoy es un power-up real. Cuidala como oro ✨',
        'Modo zen activado. Tu mente lo esta haciendo genial 💫',
      ],
      'Con ansiedad' => const [
        'Respira: no tienes que poder con todo hoy. Vamos contigo 💙',
        'Bajemos una marcha, tu bienestar va primero siempre 🫶',
        'Todo se ordena paso a paso. Ya diste el primero y vale mucho 🌙',
      ],
      'Con energia' => const [
        'Esa energia esta en nivel dios. Aprovechala para algo que te sume ⚡',
        'Hoy vienes encendido, crack. Canaliza esa vibra en algo pro 🚀',
        'Mood imparable detectado. Dale con toda, pero con balance 🔥',
      ],
      _ => const ['Vas bien. Un dia a la vez ✨'],
    };

    final index = DateTime.now().millisecondsSinceEpoch % phrases.length;
    return phrases[index];
  }

  String _dailyQuestionFor(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final index = dayOfYear % _dailyQuestions.length;
    return _dailyQuestions[index];
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Buenos dias';
    if (hour >= 12 && hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _onMoodSelected(String mood) {
    if (_hasDailySelection) return;

    setState(() {
      _selectedMood = mood;
      _moodPhrase = _phraseForMood(mood);
      _moodEmoji = _emojiForMood(mood);
      _emojiRainTick++;
      _hasDailySelection = true;
    });

    SharedPreferences.getInstance().then((prefs) {
      final now = DateTime.now();
      prefs.setString(_kMoodDateKey, _dateKey(now));
      prefs.setString(_kMoodValueKey, mood);
      prefs.setString(_kMoodPhraseKey, _moodPhrase ?? _phraseForMood(mood));
    });

    _recordTodayInStreak(mood);
  }

  Future<void> _clearMoodSelection({bool persist = false}) async {
    setState(() {
      _selectedMood = null;
      _moodPhrase = null;
      _moodEmoji = '✨';
      _hasDailySelection = false;
    });

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kMoodDateKey);
      await prefs.remove(_kMoodValueKey);
      await prefs.remove(_kMoodPhraseKey);
    }
  }

  Map<String, String> _decodeMoodHistory(
    List<String> entries,
    List<String> legacyDates,
  ) {
    final map = <String, String>{};

    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      final date = parts[0].trim();
      final mood = parts[1].trim();
      if (date.isEmpty || mood.isEmpty) continue;
      map[date] = mood;
    }

    for (final date in legacyDates) {
      final key = date.trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => 'completado');
    }

    return map;
  }

  List<String> _encodeMoodHistory(Map<String, String> map) {
    final keys = map.keys.toList()..sort();
    return keys.map((date) => '$date|${map[date]}').toList();
  }

  List<_StreakDayData> _currentWeekStreak() {
    final now = DateTime.now();
    final sundayStart = now.subtract(Duration(days: now.weekday % 7));
    const labels = <String>['D', 'L', 'Ma', 'Mi', 'J', 'V', 'S'];

    return List<_StreakDayData>.generate(7, (index) {
      final date = DateTime(
        sundayStart.year,
        sundayStart.month,
        sundayStart.day + index,
      );
      final key = _dateKey(date);
      final todayKey = _dateKey(now);
      final mood = _moodHistoryByDate[key];
      return _StreakDayData(
        label: labels[index],
        completed: mood != null,
        isToday: key == todayKey,
        mood: mood,
      );
    });
  }

  int _currentStreakCount() {
    var date = DateTime.now();
    var count = 0;
    while (_moodHistoryByDate.containsKey(_dateKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _recordTodayInStreak(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final historyEntries =
        prefs.getStringList(_kMoodHistoryEntriesKey) ?? <String>[];
    final legacyDates =
        prefs.getStringList(_kMoodHistoryDatesKey) ?? <String>[];
    final history = _decodeMoodHistory(historyEntries, legacyDates);
    final today = _dateKey(DateTime.now());

    history[today] = mood;

    final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 60)));
    history.removeWhere((date, _) => date.compareTo(cutoff) < 0);

    final encoded = _encodeMoodHistory(history);
    final onlyDates = history.keys.toList()..sort();
    await prefs.setStringList(_kMoodHistoryEntriesKey, encoded);
    await prefs.setStringList(_kMoodHistoryDatesKey, onlyDates);

    if (!mounted) return;
    setState(() {
      _moodHistoryByDate = history;
    });
  }

  void _showStreakDetailsModal() {
    final week = _currentWeekStreak();
    final streak = _currentStreakCount();
    final completedDays = week.where((day) => day.completed).length;
    final progress = completedDays / 7;
    final progressLabel = '$completedDays/7';

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Racha semanal',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.92, end: 1).animate(fade);

        return FadeTransition(
          opacity: fade,
          child: Center(
            child: ScaleTransition(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFF),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFF472B6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu racha de bienestar',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: const Color(0xFF223047),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Historial de esta semana',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFF5D6F84),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF516377),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 164,
                          height: 164,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 164,
                                height: 164,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 13,
                                  backgroundColor: const Color(0xFFE3EAF1),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8B5CF6),
                                      ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    progressLabel,
                                    style: AppTextStyles.displayMedium.copyWith(
                                      color: const Color(0xFF223047),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$streak dia${streak == 1 ? '' : 's'} seguidos',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: const Color(0xFF5D6F84),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Esta semana',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: const Color(0xFF223047),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: week
                            .map(
                              (day) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: day.completed
                                          ? const Color(0xFFF2ECFF)
                                          : day.isToday
                                          ? const Color(0xFFEFF4FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: day.completed
                                            ? const Color(0xFF8B5CF6)
                                            : day.isToday
                                            ? const Color(0xFF90A4C2)
                                            : const Color(0xFFE0E7EF),
                                        width: day.completed || day.isToday
                                            ? 1.2
                                            : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          day.label,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: const Color(0xFF5B6B7C),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        day.completed
                                            ? Text(
                                                _emojiForMood(
                                                  day.mood ?? 'completado',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              )
                                            : day.isToday
                                            ? const Icon(
                                                Icons.auto_awesome,
                                                color: Color(0xFF8B5CF6),
                                                size: 20,
                                              )
                                            : const Icon(
                                                Icons
                                                    .radio_button_unchecked_rounded,
                                                color: Color(0xFFB5C0CC),
                                                size: 17,
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;
    final accountName = (mapArgs?['nombreUsuario'] as String?)?.trim();
    final displayName = (accountName != null && accountName.isNotEmpty)
        ? accountName
        : 'Tu cuenta';
    final greeting = _timeGreeting();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -35,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    231,
                    164,
                    231,
                  ).withOpacity(0.20),
                  borderRadius: BorderRadius.circular(95),
                ),
              ),
            ),
            Positioned(
              top: 140,
              left: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    88,
                    188,
                    210,
                  ).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(85),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 233, 166, 235),
                              Color.fromARGB(255, 179, 147, 237),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.primaryLight.withOpacity(0.45),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, $displayName',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: const Color(0xFF24334F),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Tu espacio de bienestar hoy',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF4B5F82),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showStreakDetailsModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8E8F3),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFF3C6DE),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFFEC4899),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_currentStreakCount()}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: const Color(0xFF7A3452),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.solicitarCita,
                              );
                            },
                            icon: const Icon(Icons.event_available_outlined),
                            color: const Color.fromARGB(255, 122, 59, 177),
                            tooltip: 'Solicitar cita',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 171, 105, 181),
                          Color.fromARGB(255, 133, 53, 185),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x331D4ED8),
                          blurRadius: 22,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedMood == null) ...[
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final offset = Tween<Offset>(
                                begin: const Offset(0.18, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _currentQuestion,
                              key: ValueKey(_currentQuestion),
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.96,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _selectedMood == null
                              ? Wrap(
                                  key: const ValueKey('mood-options'),
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MoodChip(
                                      label: 'En calma',
                                      icon: Icons.spa,
                                      isSelected: false,
                                      onTap: () => _onMoodSelected('En calma'),
                                    ),
                                    _MoodChip(
                                      label: 'Con ansiedad',
                                      icon: Icons.psychology_alt_outlined,
                                      isSelected: false,
                                      onTap: () =>
                                          _onMoodSelected('Con ansiedad'),
                                    ),
                                    _MoodChip(
                                      label: 'Con energia',
                                      icon: Icons.bolt_outlined,
                                      isSelected: false,
                                      onTap: () =>
                                          _onMoodSelected('Con energia'),
                                    ),
                                  ],
                                )
                              : Container(
                                  key: ValueKey(_selectedMood),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _moodEmoji,
                                            style: const TextStyle(
                                              fontSize: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Estas $_selectedMood',
                                              style: AppTextStyles.bodyLarge
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 450,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          final offset = Tween<Offset>(
                                            begin: const Offset(0.08, 0),
                                            end: Offset.zero,
                                          ).animate(animation);
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: offset,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          _moodPhrase ?? '',
                                          key: ValueKey(_moodPhrase),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    'Contenido para ti',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: const Color(0xFF24334F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Si no te gusta una tarjeta, desliza para ver la siguiente.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF516377),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 286,
                    child: PageView.builder(
                      controller: _contentPageController,
                      physics: const BouncingScrollPhysics(),
                      padEnds: false,
                      allowImplicitScrolling: true,
                      itemCount: _swipeContents.length,
                      onPageChanged: (index) {
                        setState(() => _contentPageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final content = _swipeContents[index];
                        return AnimatedBuilder(
                          animation: _contentPageController,
                          child: _SwipeContentCard(content: content),
                          builder: (context, child) {
                            final page = _contentPageController.hasClients
                                ? (_contentPageController.page ??
                                      _contentPageIndex.toDouble())
                                : _contentPageIndex.toDouble();
                            final distance = (page - index).abs().clamp(
                              0.0,
                              1.0,
                            );
                            final scale = 1 - (distance * 0.07);
                            final opacity = 1 - (distance * 0.18);
                            return Transform.scale(
                              scale: scale,
                              child: Opacity(opacity: opacity, child: child),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_swipeContents.length, (index) {
                      final active = index == _contentPageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: _EmojiRain(emoji: _moodEmoji, burstTick: _emojiRainTick),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContenido extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _CardContenido({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white24,
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.34)
              : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiRain extends StatelessWidget {
  final String emoji;
  final int burstTick;

  const _EmojiRain({required this.emoji, required this.burstTick});

  @override
  Widget build(BuildContext context) {
    if (burstTick == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: List.generate(12, (index) {
          final seed = (burstTick * 97) + (index * 37);
          final left = (seed % 90) / 100;
          final durationMs = 760 + ((seed % 6) * 120);
          final size = 18.0 + ((seed % 4) * 3);
          return _EmojiDrop(
            key: ValueKey('emoji-rain-$burstTick-$index'),
            emoji: emoji,
            leftFactor: left,
            duration: Duration(milliseconds: durationMs),
            size: size,
          );
        }),
      ),
    );
  }
}

class _EmojiDrop extends StatelessWidget {
  final String emoji;
  final double leftFactor;
  final Duration duration;
  final double size;

  const _EmojiDrop({
    super.key,
    required this.emoji,
    required this.leftFactor,
    required this.duration,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = (leftFactor * 2) - 1;
    final wave = math.sin((leftFactor + 0.2) * math.pi * 2) * 0.12;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -0.2, end: 1.2),
      duration: duration,
      curve: Curves.easeIn,
      builder: (context, value, child) {
        final opacity = (1 - value).clamp(0.0, 1.0);
        final x = (horizontal + (wave * value)).clamp(-1.0, 1.0);
        final y = (value * 2) - 1;

        return Align(
          alignment: Alignment(x, y),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(angle: value * 0.6, child: child),
          ),
        );
      },
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              color: const Color(0xFF24334F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF4B5F82),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 9,
              backgroundColor: const Color(0xFFE6EEF9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakDayData {
  final String label;
  final bool completed;
  final bool isToday;
  final String? mood;

  const _StreakDayData({
    required this.label,
    required this.completed,
    required this.isToday,
    this.mood,
  });
}

class _SwipeContentData {
  final String title;
  final String quote;
  final String caption;
  final String badge;
  final IconData icon;
  final List<Color> backgroundColors;

  _SwipeContentData({
    required this.title,
    required this.quote,
    required this.caption,
    required this.badge,
    required this.icon,
    required this.backgroundColors,
  });
}

final List<_SwipeContentData> _swipeContents = [
  _SwipeContentData(
    title: 'No te quedes con lo primero',
    quote: 'Si esta tarjeta no te vibra, desliza a la siguiente.',
    caption: 'A veces la calma llega en la tercera tarjeta.',
    badge: 'Desliza',
    icon: Icons.swipe_rounded,
    backgroundColors: [Color(0xFF0EA5A4), Color(0xFF7DD3FC)],
  ),
  _SwipeContentData(
    title: 'Un paso a la vez',
    quote: 'Lo que no te guste, lo pasas. Lo que si, te lo quedas.',
    caption: 'Tu ritmo vale mas que ir rapido.',
    badge: 'Respira',
    icon: Icons.self_improvement,
    backgroundColors: [Color(0xFF8B5CF6), Color(0xFFF472B6)],
  ),
  _SwipeContentData(
    title: 'Vuelve a ti',
    quote: 'Desliza hasta encontrar la frase que te sostenga hoy.',
    caption: 'La idea es que algo encaje contigo.',
    badge: 'Tu momento',
    icon: Icons.favorite_rounded,
    backgroundColors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  ),
  _SwipeContentData(
    title: 'Hoy también cuenta',
    quote: 'No tienes que hacerlo perfecto, solo seguir avanzando.',
    caption: 'Lo pequeño también construye bienestar.',
    badge: 'Sigue',
    icon: Icons.star_rounded,
    backgroundColors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
  ),
  _SwipeContentData(
    title: 'Tu mente merece calma',
    quote: 'Si algo pesa, suelta un poco y vuelve a intentarlo.',
    caption: 'Estar presente ya es un logro.',
    badge: 'Pausa',
    icon: Icons.spa,
    backgroundColors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
  ),
  _SwipeContentData(
    title: 'Celebra tu avance',
    quote: 'Cada tarjeta que pasas te recuerda que sigues aquí.',
    caption: 'El progreso real también se siente suave.',
    badge: 'Avanza',
    icon: Icons.emoji_events_rounded,
    backgroundColors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  ),
];

class _SwipeContentCard extends StatelessWidget {
  final _SwipeContentData content;

  const _SwipeContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: content.backgroundColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -28,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(58),
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Text(
                      content.badge,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    content.quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.swipe_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          content.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
