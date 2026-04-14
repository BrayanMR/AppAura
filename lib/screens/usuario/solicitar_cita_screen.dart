import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/cita_model.dart';
import '../../services/cita_service.dart';

class SolicitarCitaScreen extends StatefulWidget {
  const SolicitarCitaScreen({super.key});

  @override
  State<SolicitarCitaScreen> createState() => _SolicitarCitaScreenState();
}

class _SolicitarCitaScreenState extends State<SolicitarCitaScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<CitaModel> _citas = <CitaModel>[];

  @override
  void initState() {
    super.initState();
    _loadCitas();
  }

  Future<void> _loadCitas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final citas = await CitaService.fetchCitasUsuario(pacienteUid: user?.uid);
      if (!mounted) return;
      setState(() {
        _citas = citas;
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

  Future<void> _confirmarCita(CitaModel cita) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await CitaService.confirmCita(cita.id);
      if (!mounted) return;
      setState(() {
        _citas = _citas
            .map(
              (item) => item.id == cita.id
                  ? CitaModel(
                      id: item.id,
                      paciente: item.paciente,
                      psicologo: item.psicologo,
                      fecha: item.fecha,
                      motivo: item.motivo,
                      estado: EstadoCita.confirmada,
                      pacienteUid: item.pacienteUid,
                      psicologoUid: item.psicologoUid,
                      pacienteDocumento: item.pacienteDocumento,
                      psicologoDocumento: item.psicologoDocumento,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita confirmada correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar la cita: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis notificaciones'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadCitas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCitas,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
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
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Icon(
                          Icons.notifications_none,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tus citas', style: AppTextStyles.titleLarge),
                            Text(
                              'Aquí ves el estado de tus citas. Tú confirmas cuando estés listo.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'No se pudieron cargar tus citas\n$_error',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else if (_citas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'No tienes citas registradas.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
              )
            else
              ..._citas.map(
                (cita) => Container(
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
                              cita.psicologo,
                              style: AppTextStyles.titleLarge,
                            ),
                          ),
                          Chip(
                            label: Text(_estadoLabel(cita.estado)),
                            backgroundColor: _estadoColor(cita.estado),
                            labelStyle: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(cita.motivo, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        dateFormat.format(cita.fecha),
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cita.estado == EstadoCita.pendiente
                            ? 'Pendiente de tu confirmación.'
                            : cita.estado == EstadoCita.confirmada
                            ? 'Cita confirmada.'
                            : 'Cita cancelada.',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (cita.estado == EstadoCita.pendiente) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _confirmarCita(cita),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Confirmar cita'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}
