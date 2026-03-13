import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ForoPsicologoScreen extends StatelessWidget {
  const ForoPsicologoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Foro')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: AppColors.textHint.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text('Foro de bienestar', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Comparte recursos y guía a tus pacientes\ndesde aquí.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.rolePsicologo,
        onPressed: () {}, // TODO: crear post
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
