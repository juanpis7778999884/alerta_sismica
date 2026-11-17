import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/emergencia.dart';
import '../../providers/emergencia_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/confirmar_dialog.dart';
import '../../widgets/estado_vacio.dart';
import '../emergencia/emergencia_screen.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  Future<void> _limpiar(BuildContext context) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Borrar historial',
      mensaje:
          'Se eliminarán todas las emergencias guardadas. Esta acción no se '
          'puede deshacer.',
      etiquetaConfirmar: 'Borrar historial',
    );
    if (!confirmado || !context.mounted) return;
    final provider = context.read<EmergenciaProvider>();
    final ok = await provider.limpiarHistorial();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Historial eliminado.'
              : provider.error ?? 'No se pudo borrar el historial.',
        ),
      ),
    );
  }

  void _abrirDetalle(BuildContext context, Emergencia emergencia) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emergencia.tipo.etiqueta,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormatters.fechaCompleta(emergencia.inicio)} · '
                '${emergencia.fin == null ? 'Sin finalizar' : 'Duración ${DateFormatters.duracion(emergencia.fin!.difference(emergencia.inicio))}'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.espacioM),
              _Fila(
                icono: Icons.person_outline_rounded,
                texto: emergencia.usuarioNombre,
              ),
              if (emergencia.tieneUbicacion)
                _Fila(
                  icono: Icons.place_outlined,
                  texto:
                      emergencia.ubicacionLegible ??
                      emergencia.coordenadasTexto,
                )
              else
                const _Fila(
                  icono: Icons.location_off_outlined,
                  texto: 'Ubicación no disponible',
                ),
              const SizedBox(height: AppTheme.espacioM),
              Text('Mensaje', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radio),
                ),
                child: SelectableText(
                  emergencia.mensaje,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppTheme.espacioM),
              Text(
                'Contactos y estado final',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              if (emergencia.envios.isEmpty)
                Text(
                  'Esta emergencia se registró sin contactos.',
                  style: theme.textTheme.bodySmall,
                )
              else
                for (final envio in emergencia.envios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          envio.estado == EstadoEnvio.abiertoEnApp
                              ? Icons.outbox_rounded
                              : envio.estado == EstadoEnvio.pendiente
                              ? Icons.schedule_rounded
                              : Icons.error_outline_rounded,
                          size: 18,
                          color: envio.estado == EstadoEnvio.abiertoEnApp
                              ? AppTheme.azulInfo
                              : envio.estado == EstadoEnvio.pendiente
                              ? AppTheme.ambarOscuro
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${envio.nombre} · ${envio.telefono}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                envio.estado.etiqueta,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (envio.detalle != null)
                                Text(
                                  envio.detalle!,
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: AppTheme.espacioM),
              Text(
                'El estado "canal abierto" indica que se preparó el SMS o se '
                'abrió el selector del sistema, no que el mensaje haya sido '
                'entregado.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergenciaProvider>();
    final theme = Theme.of(context);
    final activa = provider.activa;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial SOS'),
        actions: [
          if (provider.historial.isNotEmpty)
            IconButton(
              onPressed: () => _limpiar(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Borrar historial',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.recargarHistorial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (activa != null && activa.activa) ...[
              AvisoBanner(
                titulo: 'Tienes una emergencia activa',
                mensaje:
                    'Finalízala desde la pantalla SOS para que aparezca en el '
                    'historial.',
                nivel: NivelAviso.advertencia,
                etiquetaAccion: 'Abrir emergencia',
                onAccion: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmergenciaScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (provider.error != null) ...[
              AvisoBanner(
                mensaje: provider.error!,
                nivel: NivelAviso.error,
                onCerrar: provider.limpiarError,
              ),
              const SizedBox(height: 12),
            ],
            if (provider.cargando)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.historial.isEmpty)
              SizedBox(
                height: 440,
                child: EstadoVacio(
                  icono: Icons.history_toggle_off_rounded,
                  titulo: 'Sin emergencias registradas',
                  mensaje:
                      'Cuando finalices una emergencia SOS, aparecerá aquí con '
                      'la hora, la ubicación y el estado de los avisos. La '
                      'información se guarda solo en este dispositivo.',
                ),
              )
            else ...[
              Text(
                '${provider.historial.length} emergencia(s)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final emergencia in provider.historial)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _abrirDetalle(context, emergencia),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.rojoSuave,
                              foregroundColor: AppTheme.rojoOscuro,
                              child: Icon(
                                emergencia.tipo == TipoEmergencia.sismo
                                    ? Icons.public_rounded
                                    : Icons.sos_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emergencia.tipo.etiqueta,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormatters.fechaHora(emergencia.inicio),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        '${emergencia.envios.length} contacto(s)',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                      Text(
                                        emergencia.fin == null
                                            ? 'Sin finalizar'
                                            : 'Duración ${DateFormatters.duracion(emergencia.fin!.difference(emergencia.inicio))}',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                      if (emergencia.tieneUbicacion)
                                        Text(
                                          'Con ubicación',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
