import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import '../../services/firestore_service.dart';
import '../../services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _resolveSession();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(SessionService.tokenKey);
    final currentUser = await _waitForRestoredUser();

    if (currentUser == null || token == null || token.trim().isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    await SessionService.scheduleTokenExpiryLogout(token);

    try {
      final profile = await FirestoreService.getDocument(
        'usuarios',
        currentUser.uid,
      );
      final activo =
          profile['activo'] == true ||
          profile['activo'] == 'true' ||
          profile['activo'] == 1;

      if (!activo) {
        await SessionService.forceLogout(redirect: false);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final role = _normalizeRole(profile['role'] ?? profile['rol']);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        role == 'psicologo' ? AppRoutes.homePsicologo : AppRoutes.homeUsuario,
        arguments: <String, dynamic>{
          'uid': currentUser.uid,
          'nombreUsuario':
              profile['nombre'] as String? ??
              currentUser.displayName ??
              currentUser.email ??
              '',
          'documentoUsuario': profile['documento'] as String?,
          'role': role,
        },
      );
    } on Exception catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('token inválido') ||
          message.contains('token no proporcionado') ||
          message.contains('token expirado') ||
          message.contains('no autenticado') ||
          message.contains('401') ||
          message.contains('403')) {
        await SessionService.forceLogout(redirect: false);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.homeUsuario,
        arguments: <String, dynamic>{
          'uid': currentUser.uid,
          'nombreUsuario': currentUser.displayName ?? currentUser.email ?? '',
          'documentoUsuario': null,
          'role': 'usuario',
        },
      );
    }
  }

  Future<User?> _waitForRestoredUser() async {
    final immediateUser = FirebaseAuth.instance.currentUser;
    if (immediateUser != null) return immediateUser;

    try {
      return await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  String _normalizeRole(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'psicologo' || text == 'psicóloga' || text == 'psicologa') {
      return 'psicologo';
    }
    return 'usuario';
  }

  @override
  Widget build(BuildContext context) {
    //mis variables  de tamaños
    final screenWidth = MediaQuery.of(context).size.width;
    final bandLong = screenWidth * 1.05;
    final bandShort = screenWidth * 0.92;
    final bandGap = screenWidth * 0.03;
    final thickBand = screenWidth * 0.30;
    final thinBand = screenWidth * 0.065;
    final offset = screenWidth * 0.34;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          //mi esquinita
          Positioned(
            top: -offset,
            right: -offset,
            child: Transform.rotate(
              angle: 0.78,
              child: Column(
                children: [
                  Container(
                    width: bandLong,
                    height: thickBand,
                    color: const Color.fromARGB(255, 165, 133, 200),
                  ),
                  SizedBox(height: bandGap),
                  Container(
                    width: bandShort,
                    height: thinBand,
                    color: const Color(0xFF87C7D8),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -offset,
            left: -offset,
            child: Transform.rotate(
              angle: 0.78,
              child: Column(
                children: [
                  Container(
                    width: bandLong,
                    height: thinBand,
                    color: const Color(0xFF87C7D8),
                  ),
                  SizedBox(height: bandGap),
                  Container(
                    width: bandShort,
                    height: thickBand,
                    color: const Color.fromARGB(255, 165, 133, 200),
                  ),
                ],
              ),
            ),
          ),

          // este  nuestro centro
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    SizedBox(
                      width: 220,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.primary,
                          size: 96,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('AURA', style: AppTextStyles.displayLarge),
                    const SizedBox(height: 8),
                    Text(
                      '#Un lugar seguro para ti',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
