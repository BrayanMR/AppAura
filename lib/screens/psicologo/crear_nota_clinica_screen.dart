
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/nota_clinica_model.dart';
import '../../services/nota_clinica_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/styled_alert.dart';

class CrearNotaClinicaScreen extends StatefulWidget {
  final NotaClinicaModel? nota;

  const CrearNotaClinicaScreen({super.key, this.nota});

  @override
  State<CrearNotaClinicaScreen> createState() => _CrearNotaClinicaScreenState();
}

class _CrearNotaClinicaScreenState extends State<CrearNotaClinicaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pacienteUidController = TextEditingController();
  final _pacienteNombreController = TextEditingController();
  final _diagnosticoController = TextEditingController();
  final _sintomasController = TextEditingController();
  final _planTratamientoController = TextEditingController();
  final _observacionesController = TextEditingController();

  List<Map<String, dynamic>> _pacientes = [];
  bool _cargandoPacientes = false;
  bool _resolviendoPacienteUid = false;
  Map<String, dynamic>? _pacienteSeleccionado;
  String? _pacienteSeleccionadoKey;
  bool _mostrarTodos = false;

  String? _categoriaSeleccionada;
  final List<String> _categorias = [
    'Ansiedad y Estrés',
    'Depresión',
    'Trastornos Alimenticios',
    'Autolesiones',
    'Abuso de Sustancias',
    'Problemas de Identidad',
    'Dificultades Académicas',
    'Problemas Familiares',
    'Relaciones Sociales',
    'Trastornos del Sueño',
    'Bullying/Acoso Escolar',
    'Ciberacoso',
    'Adicción a Redes Sociales',
    'Baja Autoestima',
    'Ansiedad Social',
    'Trastornos de Aprendizaje',
    'Orientación Sexual/Identidad de Género',
    'Presión Académica',
    'Conflicto Generacional',
    'Soledad/Aislamiento',
    'Otros',
  ];

  bool _saving = false;
  String? _pacienteError;
  bool get _isEditing => widget.nota != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final nota = widget.nota!;
      _pacienteUidController.text = nota.pacienteUid;
      _pacienteNombreController.text = nota.pacienteNombre;
      _categoriaSeleccionada = nota.categoria.isNotEmpty
          ? nota.categoria
          : null;
      if (_categoriaSeleccionada != null &&
          !_categorias.contains(_categoriaSeleccionada)) {
        _categorias.insert(0, _categoriaSeleccionada!);
      }
      _diagnosticoController.text = nota.diagnostico;
      _sintomasController.text = nota.sintomas;
      _planTratamientoController.text = nota.planTratamiento;
      _observacionesController.text = nota.observaciones;
      _pacienteSeleccionado = {
        'uid': nota.pacienteUid,
        'nombre': nota.pacienteNombre,
      };
      _pacienteSeleccionadoKey = nota.pacienteUid.isNotEmpty
          ? nota.pacienteUid
          : nota.pacienteNombre;
      _pacientes = [_pacienteSeleccionado!];
      _cargarPacientesPorChat();
    } else {
      _cargarPacientesPorChat();
    }
  }

  Future<void> _cargarPacientesPorChat() async {
    setState(() {
      _cargandoPacientes = true;
    });
    try {
      final currentUser = await AuthService.getCurrentUser();
      final documentoPsicologo =
          currentUser['documento']?.toString().trim() ?? '';
      final psicologoUid = FirebaseAuth.instance.currentUser?.uid?.trim() ?? '';

      if (documentoPsicologo.isEmpty && psicologoUid.isEmpty) {
        throw Exception('No se encontró la información del psicólogo.');
      }

      final chats = await ChatService.fetchChats(
        documento: documentoPsicologo,
        uid: psicologoUid,
      );

      String _readString(Map<String, dynamic> source, List<String> keys) {
        for (final key in keys) {
          final value = source[key];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
        return '';
      }

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

      if (_isEditing && _pacienteSeleccionadoKey != null) {
        final matched = pacientes.where((paciente) {
          final key = _getPacienteKey(paciente);
          return key != null && key == _pacienteSeleccionadoKey;
        }).toList();
        if (matched.isNotEmpty) {
          _pacientes = [matched.first];
          _pacienteSeleccionado = {
            ...matched.first,
            'nombre':
                matched.first['nombre'] ?? _pacienteSeleccionado!['nombre'],
          };
        } else {
          _pacientes = [_pacienteSeleccionado!];
        }
      } else {
        _pacientes = pacientes;
      }
      _mostrarTodos = false;
    } catch (error) {
      if (mounted) {
        showStyledSnackbar(
          context,
          'Error cargando pacientes: $error',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _cargandoPacientes = false;
      });
    }
  }

  // Elimina la función de cargar todos los usuarios porque ya no es compatible con el nuevo modelo de pacientes.

  Future<void> _seleccionarPaciente(Map<String, dynamic> paciente) async {
    final key = _getPacienteKey(paciente);
    if (key == null) {
      if (mounted) {
        showStyledSnackbar(
          context,
          'Paciente inválido. Selecciona otro paciente con documento o UID.',
          isError: true,
        );
      }
      return;
    }

    setState(() {
      _pacienteSeleccionado = paciente;
      _pacienteSeleccionadoKey = key;
      _pacienteUidController.text = paciente['uid']?.toString() ?? '';
      _pacienteNombreController.text = paciente['nombre']?.toString() ?? '';
      _pacienteError = null;
    });

    final patientDocument = (paciente['documento'] ?? '').toString().trim();
    if (patientDocument.isEmpty) return;

    setState(() => _resolviendoPacienteUid = true);
    try {
      final resolvedUid = await _resolvePacienteUid(patientDocument);
      if (resolvedUid.isNotEmpty) {
        setState(() {
          _pacienteSeleccionado = {...paciente, 'uid': resolvedUid};
          _pacienteUidController.text = resolvedUid;
        });
      } else {
        if (mounted) {
          showStyledSnackbar(
            context,
            'No se pudo encontrar el UID del paciente. Guarda su documento o selecciona otro paciente.',
            isError: true,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackbar(
          context,
          'Error al resolver UID del paciente: $error',
          isError: true,
        );
      }
    } finally {
      setState(() => _resolviendoPacienteUid = false);
    }
  }

  String? _getPacienteKey(Map<String, dynamic> paciente) {
    final uid = (paciente['uid'] ?? '').toString().trim();
    if (uid.isNotEmpty) return uid;

    final documento = (paciente['documento'] ?? '').toString().trim();
    if (documento.isNotEmpty) return documento;

    final chatId = (paciente['chatId'] ?? '').toString().trim();
    if (chatId.isNotEmpty) return chatId;

    return null;
  }

  Future<String> _resolvePacienteUid(String documento) async {
    final data = await ApiClient.post('/api/firestore/usuarios/query', {
      'field': 'documento',
      'operator': '==',
      'value': documento,
    }, auth: true);

    if (data is List && data.isNotEmpty) {
      final first = data.first;
      final uid = first['id']?.toString().trim() ?? '';
      if (uid.isNotEmpty) return uid;
      return first['uid']?.toString().trim() ?? '';
    }

    return '';
  }

  @override
  void dispose() {
    _pacienteUidController.dispose();
    _pacienteNombreController.dispose();
    _diagnosticoController.dispose();
    _sintomasController.dispose();
    _planTratamientoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _guardarNota() async {
    if (_pacienteSeleccionado == null) {
      setState(() {
        _pacienteError = 'Selecciona un paciente antes de guardar la nota.';
      });
    }

    if (!_formKey.currentState!.validate() || _pacienteSeleccionado == null)
      return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final pacienteUid = _pacienteUidController.text.trim();
      if (pacienteUid.isEmpty || _pacienteSeleccionado == null) {
        throw Exception('Selecciona un paciente antes de guardar la nota.');
      }

      final existingNota =
          await NotaClinicaService.getNotaByPsicologoAndPaciente(
            user.uid,
            pacienteUid,
          );
      if (existingNota != null &&
          (!_isEditing || existingNota.id != widget.nota!.id)) {
        throw Exception(
          'Ya existe una nota para este paciente. No puedes crear otra nota duplicada.',
        );
      }

      final nota = NotaClinicaModel(
        id: _isEditing ? widget.nota!.id : '',
        psicologoUid: user.uid,
        pacienteUid: pacienteUid,
        pacienteNombre: _pacienteNombreController.text.trim(),
        categoria: _categoriaSeleccionada ?? 'Otros',
        diagnostico: _diagnosticoController.text.trim(),
        sintomas: _sintomasController.text.trim(),
        planTratamiento: _planTratamientoController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        fecha: _isEditing ? widget.nota!.fecha : DateTime.now(),
      );

      if (_isEditing) {
        await NotaClinicaService.updateNota(nota.id, nota.toMap());
      } else {
        await NotaClinicaService.createNota(nota);
      }

      if (mounted) {
        showStyledSnackbar(
          context,
          _isEditing
              ? 'Nota actualizada exitosamente'
              : 'Nota guardada exitosamente',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showStyledSnackbar(context, 'Error al guardar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Nota Clínica' : 'Nueva Nota Clínica'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _guardarNota,
              child: Text(
                _isEditing ? 'Guardar cambios' : 'Guardar',
                style: const TextStyle(
                  color: Color.fromARGB(255, 127, 32, 117),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Información del Paciente
            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Seleccionar Paciente',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_cargandoPacientes)
                      const Center(child: CircularProgressIndicator())
                    else if (_pacientes.isEmpty)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _mostrarTodos
                                  ? 'No hay usuarios en el sistema'
                                  : 'No hay pacientes disponibles',
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _cargarPacientesPorChat,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      )
                    else if (_isEditing && _pacienteSeleccionado != null)
                      _PacienteCard(
                        paciente: _pacientes.first,
                        selected: true,
                        onTap: () {},
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _pacientes.length,
                          itemBuilder: (context, index) {
                            final paciente = _pacientes[index];
                            final pacienteKey = _getPacienteKey(paciente);
                            final isSelected =
                                pacienteKey != null &&
                                _pacienteSeleccionadoKey == pacienteKey;
                            return _PacienteCard(
                              paciente: paciente,
                              selected: isSelected,
                              onTap: () => _seleccionarPaciente(paciente),
                            );
                          },
                        ),
                      ),
                    if (!_isEditing && _pacienteSeleccionado != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Paciente seleccionado',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    _pacienteSeleccionado!['nombre'] ?? '',
                                    style: AppTextStyles.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_pacienteError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _pacienteError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Categorización
            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Categorización',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Categoría del Problema',
                        hintText:
                            'Selecciona la categoría que mejor describe el caso',
                        hintMaxLines: 2,
                        labelStyle: TextStyle(color: AppColors.primary),
                        hintStyle: TextStyle(color: AppColors.primary),
                        prefixIcon: Icon(
                          Icons.list_alt,
                          color: AppColors.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                      ),
                      style: TextStyle(color: AppColors.primaryDark),
                      dropdownColor: Colors.white.withOpacity(0.95),
                      iconEnabledColor: AppColors.primaryDark,
                      items: _categorias.map((categoria) {
                        return DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _categoriaSeleccionada = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Selecciona una categoría';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Evaluación Clínica
            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Evaluación Clínica',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _diagnosticoController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Diagnóstico',
                        hintText: 'Diagnóstico clínico o hipótesis diagnóstica',
                        labelStyle: TextStyle(color: AppColors.primary),
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: Icon(
                          Icons.local_hospital,
                          color: AppColors.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                      ),
                      maxLength: 500,
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sintomasController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Síntomas Presentados',
                        hintText:
                            'Describe los síntomas, conductas y manifestaciones observadas',
                        labelStyle: TextStyle(color: AppColors.primary),
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: Icon(
                          Icons.psychology,
                          color: AppColors.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                      ),
                      maxLength: 200,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plan de Tratamiento
            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Plan de Tratamiento',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _planTratamientoController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Plan de Tratamiento',
                        hintText:
                            'Estrategias, intervenciones y objetivos del tratamiento',
                        labelStyle: TextStyle(color: AppColors.primary),
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: Icon(
                          Icons.healing,
                          color: AppColors.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                      ),
                      maxLength: 500,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Observaciones Adicionales
            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Observaciones Adicionales',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _observacionesController,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        hintText:
                            'Notas adicionales, evolución, comentarios importantes...',
                        labelStyle: TextStyle(color: AppColors.primary),
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: Icon(
                          Icons.comment,
                          color: AppColors.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                      ),
                      maxLength: 200,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PacienteCard extends StatelessWidget {
  final Map<String, dynamic> paciente;
  final bool selected;
  final VoidCallback onTap;

  const _PacienteCard({
    required this.paciente,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (paciente['nombre'] ?? '').toString().trim();
    final documento = (paciente['documento'] ?? '').toString().trim();
    final motivo = (paciente['motivo'] ?? '').toString().trim();
    final categoria = (paciente['categoria'] ?? '').toString().trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE7DDF8),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.rolePsicologo.withOpacity(0.12),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.person,
                    color: selected
                        ? AppColors.primary
                        : AppColors.rolePsicologo,
                  ),
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
            if (motivo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Motivo: $motivo', style: AppTextStyles.bodyMedium),
            ],
            if (categoria.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Tema: $categoria', style: AppTextStyles.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

