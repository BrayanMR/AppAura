import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shared/foro_screen.dart';

class ForoPsicologoScreen extends StatelessWidget {
  const ForoPsicologoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ForoScreen(
      title: 'Foro',
      subtitle: 'Comparte recursos y guía a tus pacientes desde aquí.',
      accentColor: AppColors.rolePsicologo,
      heroIcon: Icons.forum_outlined,
      userRole: 'psicologo',
    );
  }
}
