import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PacientesScreen extends StatelessWidget {
  const PacientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Pacientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: _EmptyPacientes(),
        ),
      ),
    );
  }
}

class _EmptyPacientes extends StatelessWidget {
  const _EmptyPacientes();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.people_outline,
            size: 72, color: AppColors.textHint.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text('Sin pacientes aún', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Text('Los pacientes asignados aparecerán aquí.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center),
      ],
    );
  }
}
