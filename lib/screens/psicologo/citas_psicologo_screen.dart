import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CitasPsicologoScreen extends StatelessWidget {
  const CitasPsicologoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mis Citas')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 72,
              color: AppColors.textHint.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text('Sin citas programadas', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Las citas agendadas por tus pacientes\naparecerán aquí.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {}, // TODO: agendar cita manualmente
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
