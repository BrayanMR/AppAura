import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import 'solicitar_cita_screen.dart';
import 'chat_screen.dart';
import 'foro_usuario_screen.dart';


class HomeUsuarioScreen extends StatefulWidget {
  const HomeUsuarioScreen({super.key});

  @override
  State<HomeUsuarioScreen> createState() => _HomeUsuarioScreenState();
}

class _HomeUsuarioScreenState extends State<HomeUsuarioScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _DashboardUsuario(),
    SolicitarCitaScreen(),
    ChatScreen(),
    ForoUsuarioScreen(),
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
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

class _DashboardUsuario extends StatelessWidget {
  const _DashboardUsuario();

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
              backgroundColor: AppColors.roleUsuario,
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
            // Banner de bienvenida
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Hola! 👋',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Recuerda: cuidar tu salud mental\nes un acto de valentía.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Accesos rápidos', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.calendar_today,
                  label: 'Solicitar\ncita',
                  color: AppColors.secondary,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.chat_bubble,
                  label: 'Chat con\npsicólogo',
                  color: AppColors.primary,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.forum,
                  label: 'Ver\nforo',
                  color: AppColors.success,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Próxima cita', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Center(
                child: Text(
                  'No tienes citas programadas',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: AppTextStyles.bodySmall.copyWith(color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
