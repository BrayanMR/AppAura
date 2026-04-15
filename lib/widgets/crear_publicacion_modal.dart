import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/foro_service.dart';

class CrearPublicacionModal extends StatefulWidget {
  final Color accentColor;
  const CrearPublicacionModal({Key? key, required this.accentColor})
    : super(key: key);

  @override
  State<CrearPublicacionModal> createState() => _CrearPublicacionModalState();
}

class _CrearPublicacionModalState extends State<CrearPublicacionModal> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  bool _loading = false;

  Future<void> _publicar() async {
    final titulo = _tituloController.text.trim();
    final contenido = _contenidoController.text.trim();
    if (titulo.isEmpty || contenido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final autor = user?.displayName ?? user?.email ?? 'Usuario';
      // Puedes ajustar el rol según la lógica de tu app
      final rol = 'usuario';
      await ForoService.crearPublicacion(
        autor: autor,
        rol: rol,
        titulo: titulo,
        contenido: contenido,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // true para indicar éxito
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text('Crear publicación', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _tituloController,
                    maxLength: 25,
                    decoration: InputDecoration(
                      labelText: 'Título de tu publicación',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: widget.accentColor,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _contenidoController,
                    maxLength: 200,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Comparte tu experiencia o pregunta...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: widget.accentColor,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _loading ? null : _publicar,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Publicar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
