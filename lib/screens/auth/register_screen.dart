import 'package:flutter/material.dart';
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
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      final nombre = _nombreCtrl.text.trim();
      final apellido = _apellidoCtrl.text.trim();

      // 1) Crear usuario en Firebase Auth via backend
      final res = await AuthService.register(
        email: email,
        password: password,
        displayName: '$nombre $apellido',
      );
      final uid = res['uid'] as String;

      // 2) Login automático en el cliente Firebase
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3) Verificar token con el backend
      final idToken = await cred.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el token');
      }
      await AuthService.verifyToken(idToken);

      // 4) Calcular edad
      int? edad;
      if (_fechaNacimiento != null) {
        final hoy = DateTime.now();
        edad = hoy.year - _fechaNacimiento!.year;
        if (hoy.month < _fechaNacimiento!.month ||
            (hoy.month == _fechaNacimiento!.month &&
                hoy.day < _fechaNacimiento!.day)) {
          edad--;
        }
      }

      // 5) Guardar perfil completo en Firestore colección 'usuarios'
      await FirestoreService.setDocument('usuarios', uid, {
        'uid': uid,
        'nombre': nombre,
        'apellido': apellido,
        'documento': _documentoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'correo': email,
        'fechaNacimiento': _fechaNacimiento?.toIso8601String(),
        'edad': edad,
        'imagenUrl': '',
        'reporte': '',
        'role': 'usuario',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.homeUsuario);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al registrarse';
      if (e.code == 'email-already-in-use')
        msg = 'El correo ya está registrado';
      if (e.code == 'weak-password')
        msg = 'La contraseña es muy débil (mínimo 6 caracteres)';
      if (e.code == 'invalid-email') msg = 'Correo inválido';
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
          // ── Decoración diagonal superior ──────────────────────────────────
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
          // ── Decoración diagonal inferior ──────────────────────────────────
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
          // ── Contenido ─────────────────────────────────────────────────────
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
                            children: [
                              // Título
                              Text(
                                'Crear Cuenta',
                                style: AppTextStyles.displayMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Logo
                              SizedBox(
                                width: 110,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.primary,
                                    size: 64,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Nombre + Apellido
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
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                      decoration: _fieldDecoration('Apellido'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Documento
                              TextFormField(
                                controller: _documentoCtrl,
                                style: fieldStyle,
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                                decoration: _fieldDecoration('Documento'),
                              ),
                              const SizedBox(height: 12),
                              // Fecha de nacimiento + Teléfono
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _fechaCtrl,
                                      style: fieldStyle,
                                      readOnly: true,
                                      onTap: _seleccionarFecha,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                      decoration:
                                          _fieldDecoration(
                                            'fecha de nacimiento',
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
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                      decoration: _fieldDecoration('Telefono'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Correo
                              TextFormField(
                                controller: _emailCtrl,
                                style: fieldStyle,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.email,
                                decoration: _fieldDecoration('correo'),
                              ),
                              const SizedBox(height: 12),
                              // Contraseña
                              TextFormField(
                                controller: _passCtrl,
                                style: fieldStyle,
                                obscureText: true,
                                validator: Validators.password,
                                decoration: _fieldDecoration('contraseña'),
                              ),
                              const SizedBox(height: 12),
                              // Subir autorización
                              TextFormField(
                                style: fieldStyle,
                                readOnly: true,
                                onTap: () {
                                  // TODO: implementar selector de archivo
                                },
                                decoration: _fieldDecoration(
                                  'subir autorizacion de tus padres',
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Botón
                              CustomButton(
                                label: 'INGRESAR',
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
