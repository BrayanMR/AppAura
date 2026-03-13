import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import 'pacientes_screen.dart';
import 'citas_psicologo_screen.dart';
import 'notas_clinicas_screen.dart';
import 'foro_psicologo_screen.dart';


class HomePsicologoScreen extends StatefulWidget {
  const HomePsicologoScreen({super.key});

  @override
  State<HomePsicologoScreen> createState() => _HomePsicologoScreenState();
}

class _HomePsicologoScreenState extends State<HomePsicologoScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _DashboardPsicologo(),
    PacientesScreen(),
    CitasPsicologoScreen(),
    NotasClinicasScreen(),
    ForoPsicologoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Pacientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt_outlined),
            activeIcon: Icon(Icons.note_alt),
            label: 'Notas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Foro',
          ),
        ],
      ),
    );
  }
}

// ── Dashboard rápido del psicólogo ────────────────────────────────────────────
class _DashboardPsicologo extends StatelessWidget {
  const _DashboardPsicologo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AurApp'),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.rolePsicologo,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.perfil),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.rolePsicologo, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, Psicólogo/a 👋',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 4),
                  Text('¿Cómo va tu día hoy?',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Resumen rápido', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            // Cards de estadísticas
            Row(
              children: [
                _StatCard(
                  icon: Icons.people,
                  label: 'Pacientes',
                  value: '—',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.calendar_today,
                  label: 'Citas hoy',
                  value: '—',
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.note_alt,
                  label: 'Notas',
                  value: '—',
                  color: AppColors.info,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.forum,
                  label: 'Posts foro',
                  value: '—',
                  color: AppColors.success,
                ),
              ],
            ),
          ],
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

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value,
                style:
                    AppTextStyles.displayMedium.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
