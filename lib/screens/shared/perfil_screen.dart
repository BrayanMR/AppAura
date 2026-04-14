import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/utils/validators.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  bool _loadingProfile = true;
  bool _loading = false;
  String _roleLabel = 'Usuario';
  String _profileCollection = 'usuarios';
  String _profileDocId = '';
  Map<String, dynamic> _profileData = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _documentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
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

      _nombreCtrl.text = _readString(data, const ['nombre', 'displayName']);
      _telefonoCtrl.text = _readString(data, const ['telefono', 'phone']);
      _documentoCtrl.text = _readString(data, const ['documento', 'Documento']);
      _correoCtrl.text = _readString(data, const ['email']).isNotEmpty
          ? _readString(data, const ['email'])
          : (user.email ?? '');

      final role = _readString(data, const ['role', 'rol']).toLowerCase();
      _roleLabel = role == 'psicologo' ? 'Psicólogo' : 'Usuario';
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el perfil: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
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
        'telefono': _telefonoCtrl.text.trim(),
        'email': _correoCtrl.text.trim(),
      };

      if (_documentoCtrl.text.trim().isNotEmpty) {
        updates['documento'] = _documentoCtrl.text.trim();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $error')),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.primary.withOpacity(0.06),
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.16),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -60,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.12),
                ),
              ),
            ),
            _loadingProfile
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSafeSpace),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white,
                          labelStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                          hintStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint.withOpacity(0.9),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.22),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.55),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.86),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(
                                                0.9,
                                              ),
                                              AppColors.secondary.withOpacity(
                                                0.9,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: const CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color(0xFFF4ECFF),
                                          child: Icon(
                                            Icons.person,
                                            size: 52,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _nombreCtrl.text.trim().isEmpty
                                        ? 'Tu perfil'
                                        : _nombreCtrl.text.trim(),
                                    style: AppTextStyles.headlineMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(
                                          0.32,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _roleLabel,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PerfilSectionCard(
                              child: Column(
                                children: [
                                  CustomTextField(
                                    label: 'Nombre completo',
                                    controller: _nombreCtrl,
                                    prefixIcon: Icons.person_outline,
                                    validator: Validators.nombre,
                                  ),
                                  const SizedBox(height: 14),
                                  CustomTextField(
                                    label: 'Teléfono',
                                    controller: _telefonoCtrl,
                                    prefixIcon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    validator: Validators.telefono,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PerfilSectionCard(
                              child: Column(
                                children: [
                                  CustomTextField(
                                    label: 'Correo',
                                    controller: _correoCtrl,
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'Documento',
                                    controller: _documentoCtrl,
                                    prefixIcon: Icons.badge_outlined,
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Correo y documento son campos protegidos.',
                                          style: AppTextStyles.caption,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            CustomButton(
                              label: 'Guardar cambios',
                              onPressed: _guardar,
                              isLoading: _loading,
                              color: const Color(0xFF7E68D9),
                              textColor: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            CustomButton(
                              label: 'Cerrar sesión',
                              outlined: true,
                              color: AppColors.error,
                              onPressed: _cerrarSesion,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
      ),
      child: child,
    );
  }
}
