import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/firebase_initializer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_button.dart';

class AutorizacionPadresScreen extends StatefulWidget {
  const AutorizacionPadresScreen({super.key});

  @override
  State<AutorizacionPadresScreen> createState() =>
      _AutorizacionPadresScreenState();
}

class _AutorizacionPadresScreenState extends State<AutorizacionPadresScreen> {
  static const String _permisoUrl =
      'https://mrarvcfgtnrdrepzzfnp.supabase.co/storage/v1/object/sign/Aura/permiso/permiso.docx?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV8xM2YxYTAyMy1kNTk4LTQ0OTAtYTg4Zi0xYWQ0NTE4M2JiOGMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJBdXJhL3Blcm1pc28vcGVybWlzby5kb2N4IiwiaWF0IjoxNzc1MzM5MTMwLCJleHAiOjE4MDY4NzUxMzB9.ZeBXc9GUIgCt_1briZYuPh-Ru4Sz0pfpCKirpSUioHg';

  final _formKey = GlobalKey<FormState>();
  final _nombreAcudienteCtrl = TextEditingController();
  final _documentoAcudienteCtrl = TextEditingController();
  final _telefonoAcudienteCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  final List<String> _parentescos = const [
    'Madre',
    'Padre',
    'Tutor legal',
    'Otro',
  ];

  String? _parentesco;
  PlatformFile? _archivoDocumento;
  bool _aceptaDeclaracion = false;
  bool _loading = false;

  String? _safeFirebaseUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _seleccionarDocumento() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.bytes == null) {
      await _showStyledAlert(
        title: 'Archivo inválido',
        message: 'No se pudo leer el archivo seleccionado.',
        icon: Icons.error_outline,
        color: AppColors.error,
        actionLabel: 'Entendido',
      );
      return;
    }

    setState(() {
      _archivoDocumento = picked;
    });
  }

  @override
  void initState() {
    super.initState();
    ensureFirebaseInitialized();
  }

  @override
  void dispose() {
    _nombreAcudienteCtrl.dispose();
    _documentoAcudienteCtrl.dispose();
    _telefonoAcudienteCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      labelText: hint,
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.secondaryDark,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.30),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.secondaryDark,
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Future<void> _showStyledAlert({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required String actionLabel,
    VoidCallback? onActionPressed,
  }) async {
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -12,
                        bottom: -12,
                        child: Transform.rotate(
                          angle: -0.55,
                          child: Container(
                            width: 120,
                            height: 90,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -40,
                        bottom: -54,
                        child: Transform.rotate(
                          angle: -0.56,
                          child: Container(
                            width: 240,
                            height: 120,
                            color: const Color(0xFFA68BC8),
                          ),
                        ),
                      ),
                      Container(
                        color: const Color(0xFFE8DFF2),
                        padding: const EdgeInsets.fromLTRB(24, 72, 24, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.displayMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.88,
                                ),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  onActionPressed?.call();
                                },
                                child: Text(actionLabel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 54),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(curvedAnimation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirPermiso() async {
    final uri = Uri.parse(_permisoUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await _showStyledAlert(
        title: 'No se pudo abrir',
        message: 'No se pudo abrir el enlace del permiso en este dispositivo.',
        icon: Icons.link_off,
        color: AppColors.error,
        actionLabel: 'Entendido',
      );
    }
  }

  Future<void> _copiarPermiso() async {
    await Clipboard.setData(const ClipboardData(text: _permisoUrl));
    await _showStyledAlert(
      title: 'Enlace copiado',
      message: 'El enlace del permiso se copió al portapapeles.',
      icon: Icons.content_copy,
      color: AppColors.secondary,
      actionLabel: 'Perfecto',
    );
  }

  Future<void> _guardarAutorizacion(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    if (_archivoDocumento == null || _archivoDocumento!.bytes == null) {
      await _showStyledAlert(
        title: 'Falta documento',
        message: 'Debes adjuntar el documento de autorización.',
        icon: Icons.attach_file,
        color: AppColors.warning,
        actionLabel: 'Entendido',
      );
      return;
    }
    if (!_aceptaDeclaracion) {
      await _showStyledAlert(
        title: 'Confirmación requerida',
        message: 'Debes aceptar la declaración para continuar.',
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
        actionLabel: 'Entendido',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final archivo = _archivoDocumento!;
      final ext = _extensionFromName(archivo.name);
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
      final destination =
          'documento/$uid/documento_firmado_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix${ext.isEmpty ? '' : '.$ext'}';
      final mimeType = _mimeTypeFromName(archivo.name);
      final uploadedAt = DateTime.now().toIso8601String();

      final subida = await ApiClient.uploadFile(
        '/api/storage/upload',
        bytes: archivo.bytes!,
        fileName: archivo.name,
        fileFieldName: 'file',
        fields: {'destination': destination, 'mimeType': mimeType},
      );

      await FirestoreService.updateDocument('usuarios', uid, {
        'autorizacionPadres': {
          'estado': 'pendiente_revision',
          'requiereAutorizacion': true,
          'nombreAcudiente': _nombreAcudienteCtrl.text.trim(),
          'documentoAcudiente': _documentoAcudienteCtrl.text.trim(),
          'telefonoAcudiente': _telefonoAcudienteCtrl.text.trim(),
          'parentesco': _parentesco,
          'observaciones': _observacionesCtrl.text.trim(),
          'aceptaDeclaracion': _aceptaDeclaracion,
          'documento': {
            'storageProvider': 'supabase',
            'bucket': subida['bucket'],
            'path': subida['path'],
            'nombre': archivo.name,
            'mimeType': mimeType,
            'sizeBytes': archivo.size,
            'cargadoEn': uploadedAt,
          },
          'documentoUrl': subida['url'],
          'actualizadoEn': uploadedAt,
        },
        // También guardar los datos principales fuera del map
        'nombrePadre': _nombreAcudienteCtrl.text.trim(),
        'documentoPadre': _documentoAcudienteCtrl.text.trim(),
        'parentescoPadre': _parentesco ?? '',
        'observacionesPadres': _observacionesCtrl.text.trim(),
        'documentoUrl': subida['url'],
        'activo': false,
      });

      if (!mounted) return;
      await _showStyledAlert(
        title: 'Autorización enviada',
        message:
            'Tu autorización fue enviada. Tu cuenta queda en revisión hasta aprobación del administrador.',
        icon: Icons.check_circle_outline,
        color: AppColors.secondary,
        actionLabel: 'Ir a iniciar sesión',
        onActionPressed: () async {
          try {
            await AuthService.signOut();
          } catch (_) {}

          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
      );
    } catch (e) {
      if (!mounted) return;
      await _showStyledAlert(
        title: 'No se pudo enviar',
        message: e.toString(),
        icon: Icons.error_outline,
        color: AppColors.error,
        actionLabel: 'Entendido',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;
    final uidFromArgs = mapArgs?['uid'] as String?;
    final nombreUsuario = mapArgs?['nombreUsuario'] as String?;
    final uid = uidFromArgs ?? _safeFirebaseUid();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Autorización de Padres',
          style: TextStyle(color: Color.fromARGB(255, 240, 240, 245)),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Necesitamos autorización de tu acudiente',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nombreUsuario == null
                      ? 'Como eres menor de edad, completa esta información para habilitar tu cuenta.'
                      : 'Hola $nombreUsuario, como eres menor de edad, completa esta información para habilitar tu cuenta.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondaryDark),
                  ),
                  child: Text(
                    'Aquí registrarás los datos del padre, madre o tutor legal. La revisión de la autorización será validada por el equipo.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const SizedBox(height: 18),
                TextFormField(
                  controller: _nombreAcudienteCtrl,
                  decoration: _fieldDecoration('Nombre del acudiente'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documentoAcudienteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Documento del acudiente'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parentesco,
                  isExpanded: true,
                  menuMaxHeight: 260,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.secondaryDark,
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration('Parentesco'),
                  items: _parentescos
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _parentesco = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una opción' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _loading ? null : _seleccionarDocumento,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      'Documento de autorización (PDF o imagen)',
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          color: AppColors.secondaryDark,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _archivoDocumento?.name ?? 'Seleccionar archivo',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondaryDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formato de permiso para firmar',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Descárgalo, fírmalo y luego súbelo en el campo de documento.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _abrirPermiso,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Abrir'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _aceptaDeclaracion,
                  activeColor: AppColors.secondaryDark,
                  title: Text(
                    'Declaro que la información es verídica y autorizo el tratamiento de datos.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _aceptaDeclaracion = value ?? false);
                  },
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'ENVIAR AUTORIZACIÓN',
                  isLoading: _loading,
                  color: AppColors.secondaryDark,
                  textColor: Colors.white,
                  onPressed: uid == null
                      ? null
                      : () => _guardarAutorizacion(uid),
                ),
                if (uid == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'No se encontró la sesión para guardar la autorización. Inicia sesión de nuevo.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
