import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class NotasClinicasScreen extends StatelessWidget {
  const NotasClinicasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notas Clínicas')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: AppColors.textHint.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text('Sin notas aún', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Escribe notas clínicas sobre tus pacientes\ndespués de cada sesión.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {}, // TODO: nueva nota
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
