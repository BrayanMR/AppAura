import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/nota_clinica_model.dart';
import '../../services/nota_clinica_service.dart';
import '../../widgets/styled_alert.dart';
import 'crear_nota_clinica_screen.dart';

class NotasClinicasScreen extends StatefulWidget {
  const NotasClinicasScreen({super.key});

  @override
  State<NotasClinicasScreen> createState() => _NotasClinicasScreenState();
}

class _NotasClinicasScreenState extends State<NotasClinicasScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<NotaClinicaModel> _notas = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotas();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || _loading) return;
      _loadNotas(showLoading: false);
    });
  }

  Future<void> _loadNotas({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _refreshing = false;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      _notas = await NotaClinicaService.getNotasByPsicologo(user.uid);
      _notas.sort(
        (a, b) => b.fecha.compareTo(a.fecha),
      ); // Más recientes primero
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Historial de Notas')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _crearNuevaNota,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error: $_error', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_notas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: AppColors.textHint.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text('Sin notas aún', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Escribe notas clínicas sobre tus pacientes\ndespués de cada sesión.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotas(showLoading: false),
      child: Column(
        children: [
          if (_refreshing)
            Container(
              width: double.infinity,
              color: AppColors.primary.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Actualizando notas...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: _notas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final nota = _notas[index];
                final dateLabel =
                    '${nota.fecha.day}/${nota.fecha.month}/${nota.fecha.year}';
                final timeLabel =
                    nota.fecha.toLocal().hour.toString().padLeft(2, '0') +
                    ':' +
                    nota.fecha.toLocal().minute.toString().padLeft(2, '0');

                return InkWell(
                  onTap: () => _verNota(nota),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          child: Container(
                            height: 6,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nota.pacienteNombre.isNotEmpty
                                              ? nota.pacienteNombre
                                              : 'Paciente sin nombre',
                                          style: AppTextStyles.titleLarge
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Categoría • ${nota.categoria}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.secondaryDark,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        dateLabel,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeLabel,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                nota.diagnostico.isNotEmpty
                                    ? 'Diagnóstico: ${nota.diagnostico}'
                                    : 'Diagnóstico no especificado',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              if (nota.observaciones.isNotEmpty) ...[
                                Text(
                                  nota.observaciones.length > 110
                                      ? '${nota.observaciones.substring(0, 110)}...'
                                      : nota.observaciones,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                              ],
                              Row(
                                children: [
                                  _buildTag(nota.categoria),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      nota.pacienteUid.isNotEmpty
                                          ? 'UID: ${nota.pacienteUid}'
                                          : 'UID no disponible',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textHint,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppColors.secondaryDark,
                                    ),
                                    tooltip: 'Editar nota',
                                    onPressed: () => _editarNota(nota),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppColors.error,
                                    ),
                                    tooltip: 'Eliminar nota',
                                    onPressed: () => _eliminarNota(nota.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _crearNuevaNota() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CrearNotaClinicaScreen()),
    ).then((_) => _loadNotas());
  }

  void _editarNota(NotaClinicaModel nota) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CrearNotaClinicaScreen(nota: nota)),
    ).then((_) => _loadNotas());
  }

  void _verNota(NotaClinicaModel nota) {
    showStyledDialog(
      context,
      title: 'Nota de ${nota.pacienteNombre}',
      subtitle: 'Fecha: ${nota.fecha.toLocal().toString().split('.').first}',
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  nota.categoria,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (nota.diagnostico.isNotEmpty) ...[
                Text(
                  'Diagnóstico',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nota.diagnostico,
                  style: AppTextStyles.bodyMedium,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
              ],
              if (nota.sintomas.isNotEmpty) ...[
                Text(
                  'Síntomas',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nota.sintomas,
                  style: AppTextStyles.bodyMedium,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
              ],
              if (nota.planTratamiento.isNotEmpty) ...[
                Text(
                  'Plan de Tratamiento',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nota.planTratamiento,
                  style: AppTextStyles.bodyMedium,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
              ],
              if (nota.observaciones.isNotEmpty) ...[
                Text(
                  'Observaciones',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nota.observaciones,
                  style: AppTextStyles.bodyMedium,
                  softWrap: true,
                ),
              ],
            ],
          ),
        ),
      ),
      confirmLabel: 'Cerrar',
    );
  }

  Future<void> _eliminarNota(String notaId) async {
    final confirm = await showStyledConfirmationDialog(
      context,
      title: 'Eliminar nota',
      message: '¿Estás seguro de que quieres eliminar esta nota?',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
    );

    if (confirm == true) {
      try {
        await NotaClinicaService.deleteNota(notaId);
        _loadNotas();
        showStyledSnackbar(context, 'Nota eliminada', isSuccess: true);
      } catch (e) {
        showStyledSnackbar(context, 'Error al eliminar: $e', isError: true);
      }
    }
  }
}
