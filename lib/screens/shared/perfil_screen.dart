import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/styled_alert.dart';
import '../../core/utils/validators.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  bool _loadingProfile = true;
  bool _loading = false;
  String _roleLabel = 'Usuario';
  String _profileCollection = 'usuarios';
  String _profileDocId = '';
  Map<String, dynamic> _profileData = <String, dynamic>{};

  // Variables para la animación de entrada y estado de UI
  double _contentOpacity = 0.0;
  double _contentOffset = 40.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _documentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loadingProfile = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No hay sesión activa.');
      }

      _profileDocId = user.uid;
      _correoCtrl.text = user.email ?? '';

      Map<String, dynamic>? profile;
      const collections = <String>['usuarios', 'Usuarios', 'users', 'Users'];
      for (final collection in collections) {
        try {
          final doc = await FirestoreService.getDocument(collection, user.uid);
          profile = doc;
          _profileCollection = collection;
          break;
        } catch (_) {
          continue;
        }
      }

      final data = profile ?? <String, dynamic>{};
      _profileData = data;

      final displayName = _readString(data, const ['displayName']);
      final nombre = _readString(data, const ['nombre']);
      final apellido = _readString(data, const ['apellido']);

      if (nombre.isNotEmpty) {
        _nombreCtrl.text = nombre;
      } else if (displayName.isNotEmpty) {
        final parts = displayName.split(' ');
        _nombreCtrl.text = parts.first;
      }

      if (apellido.isNotEmpty) {
        _apellidoCtrl.text = apellido;
      } else if (displayName.isNotEmpty) {
        final parts = displayName.split(' ');
        _apellidoCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }

      _telefonoCtrl.text = _readString(data, const ['telefono', 'phone']);
      _documentoCtrl.text = _readString(data, const ['documento', 'Documento']);
      _correoCtrl.text = _readString(data, const ['email']).isNotEmpty
          ? _readString(data, const ['email'])
          : (user.email ?? '');

      final role = _readString(data, const ['role', 'rol']).toLowerCase();
      _roleLabel = role == 'psicologo' ? 'Psicólogo' : 'Usuario';
    } catch (error) {
      if (!mounted) return;
      showStyledSnackbar(
        context,
        'No se pudo cargar el perfil: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });

        // Disparar animación de entrada fluida justo tras terminar la carga
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _contentOpacity = 1.0;
              _contentOffset = 0.0;
            });
          }
        });
      }
    }
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión activa.');

      final updates = <String, dynamic>{
        'uid': user.uid,
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'email': _correoCtrl.text.trim(),
      };

      if (_documentoCtrl.text.trim().isNotEmpty) {
        updates['documento'] = _documentoCtrl.text.trim();
      }

      final displayName =
          '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}'.trim();
      if (displayName.isNotEmpty && displayName != user.displayName) {
        await user.updateDisplayName(displayName);
      }

      try {
        await FirestoreService.updateDocument(
          _profileCollection,
          _profileDocId,
          updates,
        );
      } catch (_) {
        final merged = <String, dynamic>{..._profileData, ...updates};
        await FirestoreService.setDocument(
          _profileCollection,
          _profileDocId,
          merged,
        );
      }

      if (!mounted) return;
      showStyledSnackbar(
        context,
        'Perfil actualizado con éxito',
        isSuccess: true,
      );
    } catch (error) {
      if (!mounted) return;
      showStyledSnackbar(context, 'No se pudo guardar: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    setState(() => _loading = true);
    try {
      await AuthService.signOut();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      showStyledSnackbar(
        context,
        'No se pudo cerrar sesión: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeSpace = MediaQuery.of(context).padding.bottom + 120;
    final isPsychologist = _roleLabel == 'Psicólogo';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7F1FF), Color(0xFFF9F7FC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // ── Círculos Decorativos con Translucidez ─────────────────────────
          Positioned(
            top: 100,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            top: 350,
            left: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4ECFF).withOpacity(0.24),
              ),
            ),
          ),

          // ── Contenido de la Pantalla con Animación ────────────────────────
          _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _contentOpacity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      0.0,
                      _contentOffset,
                      0.0,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafeSpace),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // ── Ficha del Avatar Flotante Superior ────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.94),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(0.08),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Avatar con Anillo de Degradado
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF8B5CF6),
                                              Color(0xFFEC4899),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF8B5CF6,
                                              ).withOpacity(0.24),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 48,
                                          backgroundColor: Colors.white,
                                          child: Text(
                                            _nombreCtrl.text.isNotEmpty
                                                ? _nombreCtrl.text
                                                      .trim()
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                : 'A',
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF8B5CF6),
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Botón Editar Cámara flotante
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(7),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Nombre del Usuario
                                  Text(
                                    _nombreCtrl.text.trim().isEmpty
                                        ? 'Tu Cuenta'
                                        : _nombreCtrl.text.trim(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF223047),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Pastilla del ROL interactiva y brillante
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPsychologist
                                          ? const Color(0xFFF2ECFF)
                                          : const Color.fromARGB(
                                              255,
                                              94,
                                              49,
                                              91,
                                            ),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: isPsychologist
                                            ? const Color(0xFFDCD0FB)
                                            : const Color.fromARGB(
                                                255,
                                                105,
                                                94,
                                                163,
                                              ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPsychologist
                                              ? Icons.verified_user_rounded
                                              : Icons.auto_awesome,
                                          size: 13,
                                          color: isPsychologist
                                              ? const Color(0xFF8B5CF6)
                                              : const Color.fromARGB(
                                                  255,
                                                  184,
                                                  120,
                                                  202,
                                                ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _roleLabel,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isPsychologist
                                                ? const Color(0xFF8B5CF6)
                                                : const Color.fromARGB(
                                                    255,
                                                    196,
                                                    103,
                                                    197,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // ── SECCIÓN 1: INFORMACIÓN PERSONAL ───────────────────
                            _PerfilSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado de la Sección
                                  _buildSectionHeader(
                                    icon: Icons.person_rounded,
                                    title: 'INFORMACIÓN PERSONAL',
                                  ),
                                  const SizedBox(height: 14),
                                  CustomTextField(
                                    label: 'Nombre',
                                    controller: _nombreCtrl,
                                    prefixIcon: Icons.person_outline_rounded,
                                    validator: Validators.nombre,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'Apellido',
                                    controller: _apellidoCtrl,
                                    prefixIcon: Icons.person_outline_rounded,
                                    validator: Validators.nombre,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'Número de Teléfono',
                                    controller: _telefonoCtrl,
                                    prefixIcon: Icons.phone_android_rounded,
                                    keyboardType: TextInputType.phone,
                                    validator: Validators.telefono,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── SECCIÓN 2: DATOS DE ACCESO (PROTEGIDOS) ───────────
                            _PerfilSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado de la Sección
                                  _buildSectionHeader(
                                    icon: Icons.vpn_key_rounded,
                                    title: 'DATOS DE ACCESO',
                                  ),
                                  const SizedBox(height: 14),
                                  // Campo Correo Protegido
                                  CustomTextField(
                                    label: 'Correo Electrónico',
                                    controller: _correoCtrl,
                                    prefixIcon: Icons.mail_outline_rounded,
                                    readOnly: true,
                                    suffix: const Icon(
                                      Icons.lock_rounded,
                                      color: Color(0xFFB5C0CC),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Campo Documento Protegido
                                  CustomTextField(
                                    label: 'Documento de Identificación',
                                    controller: _documentoCtrl,
                                    prefixIcon: Icons.badge_outlined,
                                    readOnly: true,
                                    suffix: const Icon(
                                      Icons.lock_rounded,
                                      color: Color(0xFFB5C0CC),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Leyenda de Campos Bloqueados
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 15,
                                        color: Color(0xFF7C8BA1),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Por seguridad, el correo y documento están bloqueados.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF7C8BA1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── SECCIÓN 3: CONFIGURACIÓN Y SEGURIDAD (PREMIUM) ────

                            // ── SECCIÓN 4: BOTONES DE ACCIÓN PRINCIPALES ─────────
                            // Botón de Guardar Cambios (Grande y Brillante con degradado sutil en UI)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7E68D9,
                                    ).withOpacity(0.24),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CustomButton(
                                label: 'Guardar Cambios',
                                icon: Icons.save_rounded,
                                onPressed: _guardar,
                                isLoading: _loading,
                                color: const Color(0xFF8B5CF6),
                                textColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Botón Cerrar Sesión Outlined Elegante
                            CustomButton(
                              label: 'Cerrar Sesión',
                              icon: Icons.logout_rounded,
                              outlined: true,
                              color: AppColors.error,
                              onPressed: _cerrarSesion,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // Helper para construir encabezados de sección limpios y premium
  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF8B5CF6), size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF5D6F84),
            letterSpacing: 1.1,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _PerfilSectionCard extends StatelessWidget {
  final Widget child;

  const _PerfilSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.93), // Glassmorphism
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _QuickActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF223047),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7C8BA1),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB5C0CC),
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}
