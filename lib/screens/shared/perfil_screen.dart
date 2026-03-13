import 'package:flutter/material.dart';
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
  final _nombreCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _bioCtrl      = TextEditingController();
  bool _loading       = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1)); // TODO: actualizar en Firestore
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.card,
                  child: const Icon(
                    Icons.person,
                    size: 52,
                    color: AppColors.textHint,
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Badge de rol
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Text(
                'Usuario', // TODO: mostrar rol real
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primaryLight),
              ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              label: 'Nombre completo',
              controller: _nombreCtrl,
              prefixIcon: Icons.person_outline,
              validator: Validators.nombre,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Teléfono',
              controller: _telefonoCtrl,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: Validators.telefono,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Bio',
              hint: 'Cuéntanos algo sobre ti...',
              controller: _bioCtrl,
              prefixIcon: Icons.info_outline,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Guardar cambios',
              onPressed: _guardar,
              isLoading: _loading,
            ),
            const SizedBox(height: 16),
            CustomButton(
              label: 'Cerrar sesión',
              outlined: true,
              color: AppColors.error,
              onPressed: () {
                // TODO: cerrar sesión
              },
            ),
          ],
        ),
      ),
    );
  }
}
