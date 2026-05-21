import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/cita_model.dart';
import '../../services/chat_service.dart';
import '../../services/cita_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/styled_alert.dart';

class CitasPsicologoScreen extends StatefulWidget {
  final String? uid;
  final String? nombreUsuario;
  final String? documentoUsuario;

  const CitasPsicologoScreen({
    super.key,
    this.uid,
    this.nombreUsuario,
    this.documentoUsuario,
  });

  @override
  State<CitasPsicologoScreen> createState() => _CitasPsicologoScreenState();
}

class _CitasPsicologoScreenState extends State<CitasPsicologoScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _uid;
  String? _documento;
  String _nombre = 'Psicólogo/a';
  String _query = '';
  List<CitaModel> _citas = <CitaModel>[];
  List<Map<String, dynamic>> _pacientesCache = <Map<String, dynamic>>[];
  bool _loadingPacientes = false;

  @override
  void initState() {
    super.initState();
    _loadCitas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCitas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _uid = widget.uid?.trim().isNotEmpty == true
          ? widget.uid!.trim()
          : FirebaseAuth.instance.currentUser?.uid;

      _documento = widget.documentoUsuario?.trim();
      if ((_documento == null || _documento!.isEmpty) &&
          _uid != null &&
          _uid!.isNotEmpty) {
        _documento = await _resolveDocumento(_uid!);
      }

      _nombre = await _resolveNombre(_uid, fallback: widget.nombreUsuario);

      final citas = await CitaService.fetchCitas(
        psicologoUid: _uid,
        psicologoNombre: _nombre,
        psicologoDocumento: _documento,
      );

      if (!mounted) return;
      setState(() {
        _citas = citas;
      });

      // Precarga en segundo plano para evitar espera al abrir "Nueva cita".
      unawaited(_primePacientesCache());
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

  Future<String?> _resolveDocumento(String uid) async {
    try {
      final doc = await FirestoreService.getDocument('usuarios', uid);
      final value = _readString(doc, const ['documento', 'Documento']);
      if (value.isNotEmpty) return value;
    } catch (_) {}

    try {
      final docs = await FirestoreService.query(
        'usuarios',
        field: 'uid',
        operator: '==',
        value: uid,
      );
      if (docs.isNotEmpty) {
        final value = _readString(docs.first, const ['documento', 'Documento']);
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}

    return null;
  }

  Future<String> _resolveNombre(String? uid, {String? fallback}) async {
    if (fallback?.trim().isNotEmpty == true) {
      return fallback!.trim();
    }

    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    if (uid == null || uid.trim().isEmpty) {
      return _nombre;
    }

    try {
      final doc = await FirestoreService.getDocument('usuarios', uid.trim());
      final nombre = _readString(doc, const ['nombre', 'displayName']);
      final apellido = _readString(doc, const ['apellido']);
      final merged = [
        nombre,
        apellido,
      ].where((part) => part.trim().isNotEmpty).join(' ').trim();
      if (merged.isNotEmpty) return merged;
    } catch (_) {}

    return _nombre;
  }

  Future<List<Map<String, dynamic>>> _fetchPacientes() async {
    final pacientesMap = <String, Map<String, dynamic>>{};

    final documentoPsicologo = _documento?.trim() ?? '';
    final psicologoUid = _uid?.trim() ?? '';
    if (documentoPsicologo.isEmpty && psicologoUid.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final chats = await ChatService.fetchChats(
        documento: documentoPsicologo,
        uid: psicologoUid,
      );

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
            ? 'doc:$patientDocument'
            : patientUid.isNotEmpty
            ? 'uid:$patientUid'
            : (chat['id'] ?? '').toString();
        if (key.trim().isEmpty) continue;

        final nombre = _readString(chat, const [
          'nombre_usuario',
          'nombreUsuario',
          'Nombre_usuario',
          'Paciente_nombre',
          'pacienteNombre',
        ]);
        final documento = patientDocument;
        final uid = patientUid;

        final existing = pacientesMap[key];
        if (existing == null) {
          pacientesMap[key] = <String, dynamic>{
            'uid': uid,
            'documento': documento,
            'nombre': nombre.isNotEmpty ? nombre : 'Paciente',
            'motivo': _readString(chat, const ['Motivo', 'motivo', 'Tema']),
            'categoria': _readString(chat, const [
              'Categoria',
              'categoria',
              'tema',
            ]),
            'psicologo': _readString(chat, const [
              'nombre_psicologo',
              'nombrePsicologo',
              'Nombre_psicologo',
            ]),
          };
          continue;
        }

        if (existing['nombre'].toString().isEmpty && nombre.isNotEmpty) {
          existing['nombre'] = nombre;
        }
        if (existing['documento'].toString().isEmpty && documento.isNotEmpty) {
          existing['documento'] = documento;
        }
        if (existing['uid'].toString().isEmpty && uid.isNotEmpty) {
          existing['uid'] = uid;
        }
        if (existing['motivo'].toString().isEmpty) {
          existing['motivo'] = _readString(chat, const [
            'Motivo',
            'motivo',
            'Tema',
          ]);
        }
        if (existing['categoria'].toString().isEmpty) {
          existing['categoria'] = _readString(chat, const [
            'Categoria',
            'categoria',
            'tema',
          ]);
        }
        if (existing['psicologo'].toString().isEmpty) {
          existing['psicologo'] = _readString(chat, const [
            'nombre_psicologo',
            'nombrePsicologo',
            'Nombre_psicologo',
          ]);
        }
      }
    } catch (_) {
      return <Map<String, dynamic>>[];
    }

    final pacientes = pacientesMap.values.toList()
      ..sort((a, b) {
        final aName = a['nombre'].toString().toLowerCase();
        final bName = b['nombre'].toString().toLowerCase();
        return aName.compareTo(bName);
      });

    return pacientes;
  }

  Future<void> _primePacientesCache() async {
    if (_loadingPacientes || _pacientesCache.isNotEmpty) return;
    _loadingPacientes = true;
    try {
      final patients = await _fetchPacientes();
      if (!mounted) return;
      _pacientesCache = patients;
    } finally {
      _loadingPacientes = false;
    }
  }

  Future<_CitaDraft?> _openCitaForm() async {
    if (!mounted) return null;

    return Navigator.of(context).push<_CitaDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CitaCreatePage(
          psicologoNombre: _nombre,
          psicologoUid: _uid?.trim() ?? '',
          psicologoDocumento: _documento?.trim() ?? '',
          pacientes: List<Map<String, dynamic>>.from(_pacientesCache),
          onLoadPacientes: () async {
            final loaded = await _fetchPacientes();
            _pacientesCache = loaded;
            return loaded;
          },
        ),
      ),
    );
  }

  Future<void> _crearCita() async {
    if (_saving) return;

    final draft = await _openCitaForm();
    if (draft == null) return;

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = CitaModel(
      id: tempId,
      paciente: draft.paciente,
      psicologo: draft.psicologo,
      fecha: draft.fecha,
      motivo: draft.motivo,
      estado: EstadoCita.pendiente,
      pacienteUid: draft.pacienteUid.isEmpty ? null : draft.pacienteUid,
      psicologoUid: draft.psicologoUid.isEmpty ? null : draft.psicologoUid,
      pacienteDocumento: draft.pacienteDocumento.isEmpty
          ? null
          : draft.pacienteDocumento,
      psicologoDocumento: draft.psicologoDocumento.isEmpty
          ? null
          : draft.psicologoDocumento,
    );

    setState(() {
      _saving = true;
      _citas = [optimistic, ..._citas];
    });

    try {
      final realId = await CitaService.addCita(
        paciente: draft.paciente,
        psicologo: draft.psicologo,
        fecha: draft.fecha,
        motivo: draft.motivo,
        estado: 'pendiente',
        pacienteUid: draft.pacienteUid.isEmpty ? null : draft.pacienteUid,
        psicologoUid: draft.psicologoUid.isEmpty ? null : draft.psicologoUid,
        pacienteDocumento: draft.pacienteDocumento.isEmpty
            ? null
            : draft.pacienteDocumento,
        psicologoDocumento: draft.psicologoDocumento.isEmpty
            ? null
            : draft.psicologoDocumento,
      );

      if (!mounted) return;
      setState(() {
        final index = _citas.indexWhere((cita) => cita.id == tempId);
        if (index != -1) {
          _citas[index] = CitaModel(
            id: realId,
            paciente: optimistic.paciente,
            psicologo: optimistic.psicologo,
            fecha: optimistic.fecha,
            motivo: optimistic.motivo,
            estado: optimistic.estado,
            pacienteUid: optimistic.pacienteUid,
            psicologoUid: optimistic.psicologoUid,
            pacienteDocumento: optimistic.pacienteDocumento,
            psicologoDocumento: optimistic.psicologoDocumento,
            createdAt: optimistic.createdAt,
          );
        }
      });

      showStyledSnackbar(
        context,
        'Cita creada correctamente.',
        isSuccess: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _citas.removeWhere((cita) => cita.id == tempId);
      });
      showStyledSnackbar(
        context,
        'No se pudo crear la cita: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _eliminarCita(CitaModel cita) async {
    final confirm = await showStyledConfirmationDialog(
      context,
      title: 'Eliminar cita',
      message: '¿Quieres eliminar la cita de ${cita.paciente}?',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
    );

    if (confirm != true) return;

    try {
      await CitaService.deleteCita(cita.id);
      if (!mounted) return;
      setState(() {
        _citas.removeWhere((item) => item.id == cita.id);
      });
    } catch (error) {
      if (!mounted) return;
      showStyledSnackbar(
        context,
        'No se pudo eliminar la cita: $error',
        isError: true,
      );
    }
  }

  List<CitaModel> get _filteredCitas {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _citas;

    return _citas.where((cita) {
      return cita.paciente.toLowerCase().contains(query) ||
          cita.psicologo.toLowerCase().contains(query) ||
          cita.motivo.toLowerCase().contains(query) ||
          cita.estado.name.toLowerCase().contains(query) ||
          DateFormat('dd/MM/yyyy HH:mm').format(cita.fecha).contains(query);
    }).toList();
  }

  String _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return '';
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _estadoLabel(EstadoCita estado) {
    switch (estado) {
      case EstadoCita.pendiente:
        return 'Pendiente';
      case EstadoCita.confirmada:
        return 'Confirmada';
      case EstadoCita.cancelada:
        return 'Cancelada';
    }
  }

  Color _estadoColor(EstadoCita estado) {
    switch (estado) {
      case EstadoCita.pendiente:
        return AppColors.warning;
      case EstadoCita.confirmada:
        return AppColors.success;
      case EstadoCita.cancelada:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaFormato = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Citas'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saving ? null : _crearCita,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
          ),
          IconButton(onPressed: _loadCitas, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(nombre: _nombre, documento: _documento),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar por paciente, motivo, fecha o estado',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF4ECFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        'No se pudieron cargar las citas\n$_error',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    )
                  : _filteredCitas.isEmpty
                  ? Center(
                      child: Text(
                        'No hay citas para mostrar',
                        style: AppTextStyles.titleLarge,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCitas,
                      child: ListView.builder(
                        itemCount: _filteredCitas.length,
                        itemBuilder: (context, index) {
                          final cita = _filteredCitas[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cita.paciente,
                                        style: AppTextStyles.titleLarge,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(_estadoLabel(cita.estado)),
                                      backgroundColor: _estadoColor(
                                        cita.estado,
                                      ),
                                      labelStyle: AppTextStyles.bodySmall
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cita.motivo,
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  fechaFormato.format(cita.fecha),
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _eliminarCita(cita),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _saving ? null : _crearCita,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva cita', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String nombre;
  final String? documento;

  const _HeaderCard({required this.nombre, required this.documento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.rolePsicologo,
            child: Icon(Icons.calendar_month, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: AppTextStyles.titleLarge),
                Text(
                  documento == null || documento!.isEmpty
                      ? 'Gestiona y confirma citas'
                      : 'Documento: $documento',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CitaDraft {
  final String paciente;
  final String pacienteUid;
  final String pacienteDocumento;
  final String psicologo;
  final String psicologoUid;
  final String psicologoDocumento;
  final DateTime fecha;
  final String motivo;

  const _CitaDraft({
    required this.paciente,
    required this.pacienteUid,
    required this.pacienteDocumento,
    required this.psicologo,
    required this.psicologoUid,
    required this.psicologoDocumento,
    required this.fecha,
    required this.motivo,
  });
}

class _CitaCreatePage extends StatefulWidget {
  final String psicologoNombre;
  final String psicologoUid;
  final String psicologoDocumento;
  final List<Map<String, dynamic>> pacientes;
  final Future<List<Map<String, dynamic>>> Function() onLoadPacientes;

  const _CitaCreatePage({
    required this.psicologoNombre,
    required this.psicologoUid,
    required this.psicologoDocumento,
    required this.pacientes,
    required this.onLoadPacientes,
  });

  @override
  State<_CitaCreatePage> createState() => _CitaCreatePageState();
}

class _CitaCreatePageState extends State<_CitaCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();

  Map<String, dynamic>? _pacienteSeleccionado;
  late List<Map<String, dynamic>> _pacientes;
  late DateTime _fechaSeleccionada;
  bool _saving = false;
  bool _loadingPacientes = false;

  @override
  void initState() {
    super.initState();
    _pacientes = List<Map<String, dynamic>>.from(widget.pacientes);
    _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
    _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
    _horaCtrl.text = '09:00';
    if (_pacientes.isEmpty) {
      unawaited(_loadPacientes());
    }
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPacientes() async {
    if (_loadingPacientes) return;
    setState(() => _loadingPacientes = true);
    try {
      final loaded = await widget.onLoadPacientes();
      if (!mounted) return;
      setState(() {
        _pacientes = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      showStyledSnackbar(
        context,
        'No se pudieron cargar pacientes.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loadingPacientes = false);
      }
    }
  }

  Future<void> _guardar() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _pacienteSeleccionado == null) {
      showStyledSnackbar(
        context,
        'Selecciona un paciente y completa el formulario.',
        isError: true,
      );
      return;
    }

    final parsedDate = _parseDate(_fechaCtrl.text.trim());
    final parsedTime = _parseTime(_horaCtrl.text.trim());
    if (parsedDate == null || parsedTime == null) {
      showStyledSnackbar(
        context,
        'Usa fecha dd/MM/yyyy y hora HH:mm.',
        isError: true,
      );
      return;
    }

    final fecha = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    setState(() => _saving = true);
    try {
      Navigator.of(context).pop(
        _CitaDraft(
          paciente: _patientLabel(_pacienteSeleccionado!),
          pacienteUid: (_pacienteSeleccionado!['uid'] ?? '').toString().trim(),
          pacienteDocumento: (_pacienteSeleccionado!['documento'] ?? '')
              .toString()
              .trim(),
          psicologo: widget.psicologoNombre,
          psicologoUid: widget.psicologoUid,
          psicologoDocumento: widget.psicologoDocumento,
          fecha: fecha,
          motivo: _motivoCtrl.text.trim(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  DateTime? _parseDate(String text) {
    final match = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  TimeOfDay? _parseTime(String text) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _patientLabel(Map<String, dynamic> paciente) {
    final nombre = (paciente['nombre'] ?? 'Usuario').toString().trim();
    final documento = (paciente['documento'] ?? '').toString().trim();
    if (documento.isEmpty) return nombre;
    return '$nombre · $documento';
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.secondary,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
            outline: AppColors.primary,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _fechaSeleccionada = picked;
      _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  Future<void> _pickHora() async {
    final parsed =
        _parseTime(_horaCtrl.text.trim()) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: parsed,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
            outline: AppColors.primary,
          ),
          timePickerTheme: TimePickerThemeData(
            dialHandColor: AppColors.primary,
            dialBackgroundColor: Colors.white,
            hourMinuteColor: AppColors.primary.withOpacity(0.15),
            hourMinuteTextColor: AppColors.textPrimary,
            dayPeriodColor: Colors.white,
            dayPeriodTextColor: AppColors.textPrimary,
            dayPeriodBorderSide: BorderSide(
              color: AppColors.primary.withOpacity(0.24),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() {
      _horaCtrl.text = '$hh:$mm';
    });
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nueva cita'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D4AFF), Color(0xFF3D9BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.event_available_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agendar nueva cita',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Psicólogo: ${widget.psicologoNombre}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFE4A8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF8F6B00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estado inicial: pendiente',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFF8F6B00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loadingPacientes)
                  const LinearProgressIndicator(minHeight: 2),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _pacienteSeleccionado,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: Colors.white,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        hint: Text(
                          'Selecciona un paciente',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                        items: _pacientes
                            .map(
                              (paciente) =>
                                  DropdownMenuItem<Map<String, dynamic>>(
                                    value: paciente,
                                    child: Text(
                                      _patientLabel(paciente),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: _loadingPacientes
                            ? null
                            : (value) {
                                setState(() => _pacienteSeleccionado = value);
                              },
                        decoration: _fieldDecoration(
                          label: 'Paciente',
                          icon: Icons.person_outline,
                        ),
                      ),
                      if (!_loadingPacientes && _pacientes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No hay pacientes disponibles para seleccionar.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _fechaCtrl,
                        readOnly: true,
                        onTap: _pickFecha,
                        decoration: _fieldDecoration(
                          label: 'Fecha (dd/MM/yyyy)',
                          icon: Icons.calendar_month_outlined,
                          suffix: IconButton(
                            onPressed: _pickFecha,
                            icon: const Icon(Icons.edit_calendar_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _horaCtrl,
                        readOnly: true,
                        onTap: _pickHora,
                        decoration: _fieldDecoration(
                          label: 'Hora (HH:mm)',
                          icon: Icons.schedule_outlined,
                          suffix: IconButton(
                            onPressed: _pickHora,
                            icon: const Icon(Icons.access_time_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _motivoCtrl,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: _fieldDecoration(
                          label: 'Motivo de la cita',
                          icon: Icons.edit_note_outlined,
                        ).copyWith(alignLabelWithHint: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Escribe el motivo';
                          }
                          if (value.trim().length > 500) {
                            return 'El motivo no puede exceder 500 caracteres';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando...' : 'Crear cita',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
