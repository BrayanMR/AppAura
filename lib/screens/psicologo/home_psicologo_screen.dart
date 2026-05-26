import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import '../../models/cita_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/cita_service.dart';
import '../../services/foro_service.dart';
import '../../services/session_service.dart';
import '../../widgets/nav_usuario.dart';
import 'chats_psicologo_screen.dart';
import 'pacientes_screen.dart';
import 'citas_psicologo_screen.dart';
import 'notas_clinicas_screen.dart';
import 'foro_psicologo_screen.dart';

class HomePsicologoScreen extends StatefulWidget {
  final String? uid;
  final String? nombreUsuario;
  final String? documentoUsuario;

  const HomePsicologoScreen({
    super.key,
    this.uid,
    this.nombreUsuario,
    this.documentoUsuario,
  });

  @override
  State<HomePsicologoScreen> createState() => _HomePsicologoScreenState();
}

class _HomePsicologoScreenState extends State<HomePsicologoScreen> {
  int _currentIndex = 0;
  String? _uid;
  String? _nombreUsuario;
  String? _documentoUsuario;
  late List<Widget> _tabs;
  bool _tabsInitialized = false;

  void _selectTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabsInitialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;

    _uid = widget.uid ?? _readString(mapArgs, const ['uid']);
    _nombreUsuario =
        widget.nombreUsuario ?? _readString(mapArgs, const ['nombreUsuario']);
    _documentoUsuario =
        widget.documentoUsuario ??
        _readString(mapArgs, const ['documentoUsuario']);

    _tabs = [
      _DashboardPsicologo(
        uid: _uid,
        nombreUsuario: _nombreUsuario,
        documentoUsuario: _documentoUsuario,
        onOpenTab: _selectTab,
      ),
      PacientesScreen(
        uid: _uid,
        nombreUsuario: _nombreUsuario,
        documentoUsuario: _documentoUsuario,
      ),
      ChatsPsicologoScreen(
        uid: _uid,
        nombreUsuario: _nombreUsuario,
        documentoUsuario: _documentoUsuario,
      ),
      const CitasPsicologoScreen(),
      const NotasClinicasScreen(),
      const ForoPsicologoScreen(),
    ];
    _tabsInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await SessionService.handleBackPressToExit();
      },
      child: Scaffold(
        body: _tabs[_currentIndex],
        bottomNavigationBar: LiquidBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            LiquidNavItem(
              icon: Icons.dashboard_outlined,
              semanticLabel: 'Inicio',
            ),
            LiquidNavItem(
              icon: Icons.people_outline,
              semanticLabel: 'Pacientes',
            ),
            LiquidNavItem(
              icon: Icons.chat_bubble_outline,
              semanticLabel: 'Chats',
            ),
            LiquidNavItem(
              icon: Icons.calendar_today_outlined,
              semanticLabel: 'Citas',
            ),
            LiquidNavItem(
              icon: Icons.note_alt_outlined,
              semanticLabel: 'Notas',
            ),
            LiquidNavItem(icon: Icons.forum_outlined, semanticLabel: 'Foro'),
          ],
        ),
      ),
    );
  }

  String _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

// ── Dashboard rápido del psicólogo ────────────────────────────────────────────
class _DashboardPsicologo extends StatefulWidget {
  final String? uid;
  final String? nombreUsuario;
  final String? documentoUsuario;
  final ValueChanged<int>? onOpenTab;

  const _DashboardPsicologo({
    this.uid,
    this.nombreUsuario,
    this.documentoUsuario,
    this.onOpenTab,
  });

  @override
  State<_DashboardPsicologo> createState() => _DashboardPsicologoState();
}

class _DashboardPsicologoState extends State<_DashboardPsicologo> {
  late Future<_DashboardStats> _futureStats;

  void _openTab(int index) {
    widget.onOpenTab?.call(index);
    final homeState = context
        .findAncestorStateOfType<_HomePsicologoScreenState>();
    homeState?._selectTab(index);
  }

  @override
  void initState() {
    super.initState();
    _futureStats = _loadStats();
  }

  Future<_DashboardStats> _loadStats() async {
    var documento = widget.documentoUsuario;
    if ((documento == null || documento.trim().isEmpty) &&
        widget.uid != null &&
        widget.uid!.isNotEmpty) {
      final currentUser = await AuthService.getCurrentUser();
      documento = currentUser['documento']?.toString().trim();
    }

    final chats = await ChatService.fetchChats(
      uid: widget.uid,
      documento: documento,
    );

    final pacientes = <String>{};
    for (final chat in chats) {
      final documento = _readString(chat, const [
        'Documento_usuario',
        'documento_usuario',
        'documentoUsuario',
      ]);
      final uid = _readString(chat, const [
        'Uid_usuario',
        'uid_usuario',
        'uidUsuario',
      ]);
      final key = documento.isNotEmpty ? documento : uid;
      if (key.isNotEmpty) {
        pacientes.add(key);
      }
    }

    final publicaciones = await ForoService.fetchPublicaciones();
    final citas = await CitaService.fetchCitas(
      psicologoUid: widget.uid,
      psicologoNombre: widget.nombreUsuario,
      psicologoDocumento: widget.documentoUsuario,
    );

    final now = DateTime.now();
    final citasPendientes = citas
        .where((cita) => cita.estado == EstadoCita.pendiente)
        .length;
    final citasConfirmadas = citas
        .where((cita) => cita.estado == EstadoCita.confirmada)
        .length;
    final citasHoy = citas
        .where((cita) => DateUtils.isSameDay(cita.fecha, now))
        .length;

    return _DashboardStats(
      pacientes: pacientes.length,
      postsForo: publicaciones.length,
      citasTotales: citas.length,
      citasPendientes: citasPendientes,
      citasConfirmadas: citasConfirmadas,
      citasHoy: citasHoy,
    );
  }

  Future<void> _refreshStats() async {
    setState(() {
      _futureStats = _loadStats();
    });
    await _futureStats;
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardStats>(
      future: _futureStats,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Panel del psicólogo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: snapshot.connectionState == ConnectionState.waiting
                    ? null
                    : _refreshStats,
              ),
              IconButton(
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.rolePsicologo,
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.perfil),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshStats,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A5CFF), Color(0xFF3C99FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x336A5CFF),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_saludoPorHora()}, ${_displayName()}',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu resumen clínico del día en un solo vistazo.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniPill(
                            icon: Icons.schedule_outlined,
                            text:
                                'Hoy: ${snapshot.connectionState == ConnectionState.waiting ? '...' : (stats?.citasHoy ?? 0)}',
                            onTap: () => _openTab(3),
                          ),
                          _MiniPill(
                            icon: Icons.pending_actions_outlined,
                            text:
                                'Pendientes: ${snapshot.connectionState == ConnectionState.waiting ? '...' : (stats?.citasPendientes ?? 0)}',
                            onTap: () => _openTab(3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.hasError)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFC5C5)),
                    ),
                    child: Text(
                      'No se pudieron cargar las métricas. Desliza para refrescar.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF9B2C2C),
                      ),
                    ),
                  ),
                if (snapshot.hasError) const SizedBox(height: 18),
                Text('Citas', style: AppTextStyles.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.calendar_month_outlined,
                      label: 'Totales',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.citasTotales ?? 0).toString(),
                      color: AppColors.primary,
                      onTap: () => _openTab(3),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.pending_actions_outlined,
                      label: 'Pendientes',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.citasPendientes ?? 0).toString(),
                      color: AppColors.warning,
                      onTap: () => _openTab(3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Confirmadas',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.citasConfirmadas ?? 0).toString(),
                      color: AppColors.success,
                      onTap: () => _openTab(3),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.today_outlined,
                      label: 'Hoy',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.citasHoy ?? 0).toString(),
                      color: AppColors.info,
                      onTap: () => _openTab(3),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Actividad', style: AppTextStyles.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.people_outline,
                      label: 'Pacientes activos',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.pacientes ?? 0).toString(),
                      color: AppColors.secondary,
                      onTap: () => _openTab(1),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.forum_outlined,
                      label: 'Posts foro',
                      value: snapshot.connectionState == ConnectionState.waiting
                          ? '...'
                          : (stats?.postsForo ?? 0).toString(),
                      color: AppColors.rolePsicologo,
                      onTap: () => _openTab(5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayName() {
    final name = widget.nombreUsuario?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Psicólogo/a';
  }

  String _saludoPorHora() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Buenos días';
    }
    if (hour >= 12 && hour < 19) {
      return 'Buenas tardes';
    }
    return 'Buenas noches';
  }
}

class _DashboardStats {
  final int pacientes;
  final int postsForo;
  final int citasTotales;
  final int citasPendientes;
  final int citasConfirmadas;
  final int citasHoy;

  const _DashboardStats({
    required this.pacientes,
    required this.postsForo,
    required this.citasTotales,
    required this.citasPendientes,
    required this.citasConfirmadas,
    required this.citasHoy,
  });
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _MiniPill({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2D9F5), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 28),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: value.trim() == '—'
                            ? const Color(0xFFF0ECF8)
                            : color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: value.trim() == '—'
                              ? const Color(0xFFD5CCE5)
                              : color.withOpacity(0.28),
                        ),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: value.trim() == '—'
                              ? AppColors.textHint
                              : color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
