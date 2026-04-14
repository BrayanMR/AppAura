import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shared/foro_screen.dart';

class ForoUsuarioScreen extends StatelessWidget {
  const ForoUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ForoScreen(
      title: 'Foro de Bienestar',
      subtitle:
          'Explora las publicaciones y comparte tu apoyo con un comentario.',
      accentColor: AppColors.roleUsuario,
      heroIcon: Icons.forum_outlined,
    );
  }
}
