import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';

class PacientesScreen extends StatefulWidget {
  final String? uid;
  final String? nombreUsuario;
  final String? documentoUsuario;

  const PacientesScreen({
    super.key,
    this.uid,
    this.nombreUsuario,
    this.documentoUsuario,
  });

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
  bool _loading = true;
  String? _error;
  String? _psychologistUid;
  String? _psychologistDocument;
  List<Map<String, dynamic>> _pacientes = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadPacientes();
  }

  Future<void> _loadPacientes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _psychologistUid = widget.uid?.trim().isNotEmpty == true
          ? widget.uid!.trim()
          : FirebaseAuth.instance.currentUser?.uid;
      _psychologistDocument = widget.documentoUsuario?.trim();

      if ((_psychologistDocument == null || _psychologistDocument!.isEmpty) &&
          _psychologistUid != null &&
          _psychologistUid!.isNotEmpty) {
        final currentUser = await AuthService.getCurrentUser();
        _psychologistDocument = currentUser['documento']?.toString().trim();
      }

      if ((_psychologistUid == null || _psychologistUid!.isEmpty) &&
          (_psychologistDocument == null || _psychologistDocument!.isEmpty)) {
        throw Exception('No hay datos del psicólogo para cargar pacientes');
      }

      final chats = await ChatService.fetchChats(
        documento: _psychologistDocument,
        uid: _psychologistUid,
      );

      final pacientesMap = <String, Map<String, dynamic>>{};
      for (final chat in chats) {
        final patientDocument = _readString(chat, const [
          'Documento_usuario',
          'documento_usuario',
          'documentoUsuario',
        ]);
        final patientUid = _readString(chat, const [
          'Uid_usuario',
          'uid_usuario',
          'uidUsuario',
        ]);
        final key = patientDocument.isNotEmpty
            ? patientDocument
            : patientUid.isNotEmpty
            ? patientUid
            : (chat['id'] ?? '').toString();

        if (key.isEmpty) continue;

        final patientName = _readString(chat, const [
          'nombre_usuario',
          'nombreUsuario',
          'Nombre_usuario',
          'Paciente_nombre',
          'pacienteNombre',
        ]);
        final motive = _readString(chat, const ['Motivo', 'motivo', 'Tema']);
        final category = _readString(chat, const [
          'Categoria',
          'categoria',
          'tema',
        ]);
        final assignedPsychologist = _readString(chat, const [
          'nombre_psicologo',
          'nombrePsicologo',
          'Nombre_psicologo',
        ]);

        final existing = pacientesMap[key];
        if (existing == null) {
          pacientesMap[key] = <String, dynamic>{
            'nombre': patientName,
            'documento': patientDocument,
            'uid': patientUid,
            'motivo': motive,
            'categoria': category,
            'psicologo': assignedPsychologist,
            'chatId': (chat['id'] ?? '').toString(),
            'updatedAt': _readString(chat, const [
              'updatedAt',
              'Fecha',
              'fecha',
            ]),
          };
          continue;
        }

        if (existing['chatId'].toString().isEmpty &&
            (chat['id'] ?? '').toString().isNotEmpty) {
          existing['chatId'] = (chat['id'] ?? '').toString();
        }
        if (existing['nombre'].toString().isEmpty && patientName.isNotEmpty) {
          existing['nombre'] = patientName;
        }
        if (existing['motivo'].toString().isEmpty && motive.isNotEmpty) {
          existing['motivo'] = motive;
        }
        if (existing['categoria'].toString().isEmpty && category.isNotEmpty) {
          existing['categoria'] = category;
        }
        if (existing['psicologo'].toString().isEmpty &&
            assignedPsychologist.isNotEmpty) {
          existing['psicologo'] = assignedPsychologist;
        }
      }

      final pacientes = pacientesMap.values.toList()
        ..sort((a, b) {
          final aName = a['nombre'].toString().toLowerCase();
          final bName = b['nombre'].toString().toLowerCase();
          return aName.compareTo(bName);
        });

      if (!mounted) return;
      setState(() {
        _pacientes = pacientes;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Pacientes'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _loadPacientes),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPacientes,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'No se pudieron cargar los pacientes',
                    style: AppTextStyles.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : _pacientes.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 80),
                children: const [_EmptyPacientes()],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _pacientes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final paciente = _pacientes[index];
                  return _PacienteCard(paciente: paciente);
                },
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
        Icon(
          Icons.people_outline,
          size: 72,
          color: AppColors.textHint.withOpacity(0.4),
        ),
        const SizedBox(height: 16),
        Text('Sin pacientes aún', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Los pacientes asignados aparecerán aquí.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PacienteCard extends StatelessWidget {
  final Map<String, dynamic> paciente;

  const _PacienteCard({required this.paciente});

  @override
  Widget build(BuildContext context) {
    final nombre = (paciente['nombre'] ?? '').toString().trim();
    final documento = (paciente['documento'] ?? '').toString().trim();
    final motivo = (paciente['motivo'] ?? '').toString().trim();
    final categoria = (paciente['categoria'] ?? '').toString().trim();
    final psicologo = (paciente['psicologo'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.rolePsicologo.withOpacity(0.12),
                child: const Icon(Icons.person, color: AppColors.rolePsicologo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isNotEmpty ? nombre : 'Paciente sin nombre',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      documento.isNotEmpty
                          ? 'Documento: $documento'
                          : 'Documento no disponible',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (motivo.isNotEmpty)
            Text('Motivo: $motivo', style: AppTextStyles.bodyMedium),
          if (categoria.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Tema: $categoria', style: AppTextStyles.bodyMedium),
          ],
          if (psicologo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Psicólogo: $psicologo', style: AppTextStyles.bodyMedium),
          ],
        ],
      ),
    );
  }
}
