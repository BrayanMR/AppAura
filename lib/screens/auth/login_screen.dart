import 'package:aurapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../config/firebase_initializer.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

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

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'si';
    }
    return false;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ensureFirebaseInitialized();

      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('no se pudo iniciar sesion');

      try {
        await AuthService.login(email: email, password: password);
      } catch (error) {
        debugPrint('Backend login falló, continuando con FirebaseAuth: $error');
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) {
        throw Exception('No se encontró el perfil en Firestore');
      }
      final profile = profileDoc.data()!;
      final activo = _isTruthy(profile['activo']);
      final roleValue = _normalizeRoleValue(profile['role'] ?? profile['rol']);
      final autorizacion = profile['autorizacionPadres'];
      final requiereAutorizacion =
          autorizacion is Map && autorizacion['requiereAutorizacion'] == true;
      final documentoUrl = autorizacion is Map
          ? (autorizacion['documentoUrl'] as String?)
          : null;
      final tieneDocumentoEnviado =
          documentoUrl != null && documentoUrl.trim().isNotEmpty;

      if (!activo) {
        if (requiereAutorizacion && !tieneDocumentoEnviado) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.autorizacionPadres,
            arguments: <String, dynamic>{
              'uid': user.uid,
              'nombreUsuario': profile['nombre'] as String?,
              'documentoUsuario': profile['documento'] as String?,
            },
          );
          return;
        }

        await AuthService.signOut();
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        await _showLoginAlert(
          title: 'Cuenta inactiva',
          message:
              'Tu cuenta aún no está activa. Espera la validación del equipo. Si tienes dudas, contacta soporte.',
          icon: Icons.info_outline,
          color: AppColors.error,
          actionLabel: 'Entendido',
        );
        return;
      }

      // este es mi test para saber si esta fincionando mi bakend en  auth

      if (!mounted) return;
      await _showLoginAlert(
        title: 'Inicio de sesión correcto',
        message: 'Iniciaste sesión correctamente. Ya puedes continuar.',
        icon: Icons.check_circle_outline,
        color: AppColors.secondaryDark,
        actionLabel: 'Continuar',
      );
      Navigator.pushReplacementNamed(
        context,
        roleValue == 'psicologo'
            ? AppRoutes.homePsicologo
            : AppRoutes.homeUsuario,
        arguments: <String, dynamic>{
          'uid': user.uid,
          'nombreUsuario':
              profile['nombre'] as String? ?? user.displayName ?? email,
          'documentoUsuario': profile['documento'] as String?,
          'role': roleValue,
        },
      );
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        await _showLoginAlert(
          title: 'No se pudo iniciar sesión',
          message: _loginErrorMessage(null, e.toString()),
          icon: Icons.info_outline,
          color: AppColors.error,
          actionLabel: 'Entendido',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _loginErrorMessage(String? code, String? rawMessage) {
    final detail = _normalizeErrorDetail(rawMessage);
    final message = detail.toLowerCase();

    if (code == 'wrong-password' ||
        message.contains('wrong password') ||
        message.contains('invalid login credentials') ||
        message.contains('password is invalid') ||
        message.contains('incorrect password') ||
        message.contains('contraseña') && message.contains('incorrecta')) {
      return 'La contraseña es incorrecta. Revisa e inténtalo otra vez.';
    }

    if (code == 'user-not-found' ||
        message.contains('usuario no encontrado') ||
        message.contains('user-not-found') ||
        message.contains('there is no user record') ||
        message.contains('no user record')) {
      return 'No hay una cuenta registrada con ese correo.';
    }

    if (message.contains('documento no encontrado') ||
        message.contains('error 404') ||
        message.contains('not found')) {
      return 'Se inició sesión, pero no existe tu perfil en la colección usuarios. Contacta al administrador.';
    }

    if (code == 'invalid-credential' || message.contains('credential')) {
      return 'Correo o contraseña incorrectos. Verifica e inténtalo de nuevo.';
    }

    if (code == 'invalid-email' ||
        message.contains('correo inválido') ||
        message.contains('invalid email')) {
      return 'El correo no es válido. Revisa que esté bien escrito.';
    }

    if (message.contains('no firebase app') ||
        message.contains('firebase.initializeapp') ||
        message.contains('default app has not been created')) {
      return 'Firebase no estaba inicializado al arrancar la app. Reinicia la app y vuelve a intentar.';
    }

    if (message.contains('network') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('backend') ||
        message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('failed to fetch') ||
        message.contains('socket')) {
      return 'No se pudo conectar con el servidor. Revisa internet o la URL del backend.';
    }

    if (message.contains('token inválido o expirado') ||
        message.contains('id token') ||
        message.contains('verify-token')) {
      return 'El token de sesión no fue aceptado por el backend. Vuelve a iniciar sesión.';
    }

    return 'No se pudo iniciar sesión. Detalle: $detail';
  }

  String _normalizeErrorDetail(String? rawMessage) {
    final raw = (rawMessage ?? '').trim();
    if (raw.isEmpty) return 'error desconocido';

    // Los errores de ApiClient llegan como "Exception: ...".
    const prefix = 'Exception:';
    if (raw.startsWith(prefix)) {
      final cleaned = raw.substring(prefix.length).trim();
      return cleaned.isEmpty ? 'error desconocido' : cleaned;
    }
    return raw;
  }

  String _normalizeRoleValue(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'psicologo' || text == 'psicóloga' || text == 'psicologa') {
      return 'psicologo';
    }
    if (text == 'admin') return 'admin';
    return 'usuario';
  }

  Future<void> _showLoginAlert({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required String actionLabel,
  }) async {
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -12,
                        bottom: -12,
                        child: Transform.rotate(
                          angle: -0.55,
                          child: Container(
                            width: 120,
                            height: 90,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -40,
                        bottom: -54,
                        child: Transform.rotate(
                          angle: -0.56,
                          child: Container(
                            width: 240,
                            height: 120,
                            color: const Color(0xFFA68BC8),
                          ),
                        ),
                      ),
                      Container(
                        color: const Color(0xFFE8DFF2),
                        padding: const EdgeInsets.fromLTRB(24, 72, 24, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.displayMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.88,
                                ),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Text(actionLabel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 54),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(curvedAnimation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
    );
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
                                errorBuilder: (_, _, _) => const Icon(
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
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  );
                                },
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
