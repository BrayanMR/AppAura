import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';

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
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
