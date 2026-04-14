import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Controladores para autorización de padres
  final _documentoUrlCtrl = TextEditingController();
  final _nombrePadreCtrl = TextEditingController();
  final _documentoPadreCtrl = TextEditingController();
  final _parentescoPadreCtrl = TextEditingController();
  final _observacionesPadresCtrl = TextEditingController();

  bool _loading = false;
  DateTime? _fechaNacimiento;

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
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _documentoCtrl.dispose();
    _fechaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _documentoUrlCtrl.dispose();
    _nombrePadreCtrl.dispose();
    _documentoPadreCtrl.dispose();
    _parentescoPadreCtrl.dispose();
    _observacionesPadresCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(hoy.year - 18),
      firstDate: DateTime(1920),
      lastDate: hoy,
      locale: const Locale('es', 'ES'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDark,
            onPrimary: Colors.white,
            primaryContainer: AppColors.primaryDark,
            onPrimaryContainer: Colors.white,
            secondary: AppColors.secondaryDark,
            onSecondary: Colors.white,
            surface: AppColors.background,
            onSurface: AppColors.textPrimary,
            onSurfaceVariant: AppColors.textPrimary,
            outline: AppColors.primaryDark,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _fechaNacimiento = picked;
        _fechaCtrl.text = DateFormat('dd/MM/yyyy', 'es').format(picked);
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String? _validateOnlyDigits(
    String? value, {
    required String field,
    int minLength = 0,
  }) {
    final requiredError = Validators.required(value, field: field);
    if (requiredError != null) return requiredError;

    final normalized = value!.trim();
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      return '$field debe contener solo números';
    }
    if (minLength > 0 && normalized.length < minLength) {
      return '$field debe tener al menos $minLength dígitos';
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaNacimiento == null) {
      await _showMessageDialog(
        title: 'Dato faltante',
        message: 'Debes seleccionar tu fecha de nacimiento.',
        icon: Icons.warning_amber_rounded,
        color: AppColors.secondaryDark,
        actionLabel: 'Entendido',
      );
      return;
    }

    final edad = _calculateAge(_fechaNacimiento!);

    // 🔒 Bloqueo si es menor de 13
    if (edad < 13) {
      await _showMessageDialog(
        title: 'Registro no permitido',
        message: 'Debes tener al menos 13 años para registrarte.',
        icon: Icons.block,
        color: AppColors.error,
        actionLabel: 'Entendido',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      final nombre = _nombreCtrl.text.trim();
      final apellido = _apellidoCtrl.text.trim();

      // 🔥 REGISTRO
      final registerRes = await AuthService.register(
        email: email,
        password: password,
        displayName: '$nombre $apellido',
      );

      final uid = registerRes['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        throw Exception('No se pudo obtener el UID del usuario creado');
      }

      final requiereAutorizacion = edad < 18;

      // ✅ GUARDAR EN FIRESTORE (no depende de login en cliente)
      await FirestoreService.setDocument('usuarios', uid, {
        'uid': uid,
        'nombre': nombre,
        'apellido': apellido,
        'documento': _documentoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'correo': email,
        'fechaNacimiento': _fechaNacimiento!.toIso8601String(),
        'edad': edad,
        'imagenUrl': '',
        'reporte': '',
        'role': 'usuario',
        'activo': false,
        'autorizacionPadres': {
          'estado': requiereAutorizacion
              ? 'pendiente_revision'
              : 'no_requerida',
          'requiereAutorizacion': requiereAutorizacion,
        },
        // Campos individuales fuera de la lista
        'documentoUrl': _documentoUrlCtrl.text
            .trim(), // URL del documento de autorización
        'nombrePadre': _nombrePadreCtrl.text
            .trim(), // Nombre del padre/madre/acudiente
        'documentoPadre': _documentoPadreCtrl.text
            .trim(), // Documento del padre/madre/acudiente
        'parentescoPadre': _parentescoPadreCtrl.text
            .trim(), // Parentesco (padre, madre, acudiente)
        'observacionesPadres': _observacionesPadresCtrl.text
            .trim(), // Observaciones
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      await _showSuccessDialog(
        email: email,
        nombre: nombre,
        uid: uid,
        requiereAutorizacion: requiereAutorizacion,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        await _showMessageDialog(
          title: 'No se pudo crear la cuenta',
          message: _registerErrorMessage(e.code, e.message),
          icon: Icons.error_outline,
          color: AppColors.error,
          actionLabel: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showMessageDialog(
          title: 'Error',
          message: _registerErrorMessage(null, e.toString()),
          icon: Icons.error_outline,
          color: AppColors.error,
          actionLabel: 'Entendido',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _registerErrorMessage(String? code, String? rawMessage) {
    final message = (rawMessage ?? '').toLowerCase();

    if (code == 'email-already-in-use' || message.contains('already in use')) {
      return 'El correo ya está registrado. Usa otro correo o inicia sesión.';
    }

    if (code == 'weak-password' || message.contains('weak password')) {
      return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
    }

    if (code == 'invalid-email' || message.contains('invalid email')) {
      return 'El correo no es válido. Revisa que esté bien escrito.';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed to fetch')) {
      return 'No se pudo conectar con el servidor. Intenta de nuevo.';
    }

    return 'Hubo un problema al crear la cuenta. Intenta de nuevo.';
  }

  Future<void> _showSuccessDialog({
    required String email,
    required String nombre,
    required String uid,
    required bool requiereAutorizacion,
  }) async {
    final title = requiereAutorizacion
        ? 'Cuenta creada'
        : 'Registro completado';
    final message = requiereAutorizacion
        ? 'Tu cuenta y el correo $email ya fueron creados. Solo falta la autorización de tu acudiente para continuar.'
        : 'Tu cuenta quedó registrada. Debes esperar la autorización del administrador para ingresar.';
    final accentColor = requiereAutorizacion
        ? AppColors.primary
        : AppColors.secondary;
    final icon = requiereAutorizacion
        ? Icons.verified_user_outlined
        : Icons.check_circle_outline;

    await _showMessageDialog(
      title: title,
      message: message,
      icon: icon,
      color: accentColor,
      actionLabel: requiereAutorizacion ? 'Continuar' : 'Ir a iniciar sesión',
      email: email,
      onActionPressed: () {
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          requiereAutorizacion ? AppRoutes.autorizacionPadres : AppRoutes.login,
          arguments: requiereAutorizacion
              ? <String, dynamic>{'uid': uid, 'nombreUsuario': nombre}
              : null,
        );
      },
    );
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required String actionLabel,
    String? email,
    VoidCallback? onActionPressed,
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
                            if (email != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                email,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  onActionPressed?.call();
                                },
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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      labelText: hint,
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.secondaryDark,
      ),
      floatingLabelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.secondary,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.30),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.secondaryDark,
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
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

    final fieldStyle = AppTextStyles.bodyMedium.copyWith(
      color: AppColors.secondaryDark,
    );

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
                      vertical: 12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Crear Cuenta',
                                style: AppTextStyles.displayMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Completa tus datos para registrarte',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: 110,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.primary,
                                    size: 64,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nombreCtrl,
                                      style: fieldStyle,
                                      validator: Validators.nombre,
                                      decoration: _fieldDecoration('Nombre'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _apellidoCtrl,
                                      style: fieldStyle,
                                      validator: (value) => Validators.required(
                                        value,
                                        field: 'El apellido',
                                      ),
                                      decoration: _fieldDecoration('Apellido'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _documentoCtrl,
                                style: fieldStyle,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) => _validateOnlyDigits(
                                  value,
                                  field: 'El documento',
                                  minLength: 6,
                                ),
                                decoration: _fieldDecoration('Documento'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _fechaCtrl,
                                      style: fieldStyle,
                                      readOnly: true,
                                      onTap: _seleccionarFecha,
                                      validator: (value) => Validators.required(
                                        value,
                                        field: 'La fecha de nacimiento',
                                      ),
                                      decoration:
                                          _fieldDecoration(
                                            'Fecha de nacimiento',
                                          ).copyWith(
                                            suffixIcon: const Icon(
                                              Icons.calendar_month_outlined,
                                              color: AppColors.secondaryDark,
                                              size: 20,
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _telefonoCtrl,
                                      style: fieldStyle,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (value) => _validateOnlyDigits(
                                        value,
                                        field: 'El telefono',
                                        minLength: 7,
                                      ),
                                      decoration: _fieldDecoration('Telefono'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailCtrl,
                                style: fieldStyle,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.email,
                                decoration: _fieldDecoration(
                                  'Correo electronico',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                style: fieldStyle,
                                obscureText: true,
                                validator: Validators.password,
                                decoration: _fieldDecoration('Contraseña'),
                              ),
                              const SizedBox(height: 24),
                              CustomButton(
                                label: 'CREAR CUENTA',
                                onPressed: _register,
                                isLoading: _loading,
                                color: AppColors.secondaryDark,
                                textColor: Colors.white,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
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
