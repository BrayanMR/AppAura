import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ForoUsuarioScreen extends StatelessWidget {
  const ForoUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Foro de Bienestar')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 72, color: AppColors.textHint.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Foro de bienestar', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text('Lee consejos de tus psicólogos\ny comparte tu experiencia.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.roleUsuario,
        onPressed: () {}, // TODO: crear post
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
