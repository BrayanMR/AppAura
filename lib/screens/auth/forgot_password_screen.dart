import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Correo enviado',
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          content: const Text(
            'Revisa tu correo para restablecer tu contraseña.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'user-not-found'
          ? 'No existe una cuenta con ese correo.'
          : 'Error al enviar el correo: ${e.message}';
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Error',
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.error,
              ),
            ),
            content: Text(
              msg,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    final topHeight = (h * 0.16).clamp(100.0, 170.0);
    final stripeHeight = (h * 0.028).clamp(12.0, 22.0);
    final bottomHeight = (h * 0.22).clamp(120.0, 230.0);
    final horizontalBleed = w * 0.22;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        title: Text(
          'Restablecer contraseña',
          style: AppTextStyles.headlineMedium,
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -topHeight * 0.99,
            left: -horizontalBleed,
            right: -horizontalBleed,
            child: Transform.rotate(
              angle: 0.60,
              child: Container(
                height: topHeight * 0.62,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Positioned(
            top: topHeight * -0.20,
            left: -horizontalBleed,
            right: -horizontalBleed,
            child: Transform.rotate(
              angle: 0.60,
              child: Container(
                height: stripeHeight,
                color: AppColors.secondary.withOpacity(0.55),
              ),
            ),
          ),
          Positioned(
            bottom: -bottomHeight * 0.99,
            left: -horizontalBleed,
            right: -horizontalBleed,
            child: Transform.rotate(
              angle: 0.50,
              child: Container(
                height: bottomHeight,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Positioned(
            bottom: bottomHeight * 0.15,
            left: -horizontalBleed,
            right: -horizontalBleed,
            child: Transform.rotate(
              angle: 0.50,
              child: Container(
                height: stripeHeight,
                color: AppColors.secondary.withOpacity(0.6),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.primary,
                              size: 72,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'AURA',
                          style: AppTextStyles.displayLarge.copyWith(
                            letterSpacing: 4,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: '#',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.secondaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: 'Un lugar seguro para ti'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          '¿Olvidaste tu contraseña?',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                          style: AppTextStyles.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.secondaryDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.secondaryDark,
                            ),
                            floatingLabelStyle: AppTextStyles.bodySmall
                                .copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.35),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.secondaryDark,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.secondary,
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          label: 'ENVIAR',
                          onPressed: _sendResetEmail,
                          isLoading: _loading,
                          color: AppColors.secondaryDark,
                          textColor: Colors.white,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
