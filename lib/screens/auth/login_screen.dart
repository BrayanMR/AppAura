import 'package:aurapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool? _hidePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('no se pudo iniciar sesion');

      // voy aqui obtener mi id token
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el token de autenticacion');
      }
      await AuthService.verifyToken(idToken);
      await AuthService.getUser(user.uid);

      // este es mi test para saber si esta fincionando mi bakend en  auth

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.homeUsuario);
    } on FirebaseAuthException catch (e) {
      String msg = 'Error de autenticacion';
      if (e.code == 'user-not-found') msg = 'Usuario no encontrado';
      if (e.code == 'wrong-password') msg = 'Contrasena incorrecta';
      if (e.code == 'invalid-email') msg = 'Correo invalido';
      if (e.code == 'invalid-credential') msg = 'Credenciales invalidas';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      resizeToAvoidBottomInset: false,

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
                color: AppColors.secondary.withValues(alpha: 0.55),
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
                color: AppColors.secondary.withValues(alpha: 0.6),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
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
                              width: 138,
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
                                  const TextSpan(
                                    text: 'Un lugar seguro para ti',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              'Iniciar sesion',
                              style: AppTextStyles.headlineLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.secondaryDark,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Correo electronico',
                                labelStyle: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.secondaryDark,
                                ),
                                floatingLabelStyle: AppTextStyles.bodySmall
                                    .copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.35),
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _hidePassword ?? true,
                              validator: Validators.password,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.secondaryDark,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.secondaryDark,
                                ),
                                floatingLabelStyle: AppTextStyles.bodySmall
                                    .copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.35),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _hidePassword =
                                        !(_hidePassword ?? true),
                                  ),
                                  icon: Icon(
                                    (_hidePassword ?? true)
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.secondaryDark,
                                    size: 20,
                                  ),
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
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CustomButton(
                              label: 'INGRESAR',
                              onPressed: _login,
                              isLoading: _loading,
                              color: AppColors.secondaryDark,
                              textColor: Colors.white,
                              width: 170,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿No tienes cuenta?',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.register,
                                  ),
                                  child: Text(
                                    'Regístrate',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: AppColors.secondaryDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
