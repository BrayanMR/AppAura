import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SolicitarCitaScreen extends StatelessWidget {
  const SolicitarCitaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Solicitar Cita')),
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
            Text('Agenda tu sesión', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Selecciona un psicólogo disponible\ny elige tu horario.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {}, // TODO: flujo de solicitud
              icon: const Icon(Icons.add),
              label: const Text('Nueva solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}
