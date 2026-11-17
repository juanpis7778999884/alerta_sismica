import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../providers/conectividad_provider.dart';
import '../../providers/ubicacion_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';

class ConectividadScreen extends StatelessWidget {
  const ConectividadScreen({super.key});

  Future<void> _refrescar(BuildContext context) async {
    final conectividad = context.read<ConectividadProvider>();
    final ubicacion = context.read<UbicacionProvider>();
    await conectividad.refrescar();
    await ubicacion.refrescarDiagnostico();
  }

  Future<void> _actualizarUbicacion(BuildContext context) async {
    final ubicacion = context.read<UbicacionProvider>();
    final resultado = await ubicacion.actualizar();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado != null
              ? 'Ubicación actualizada.'
              : ubicacion.error ?? 'No se pudo obtener la ubicación.',
        ),
      ),
    );
  }

  Future<void> _solicitarPermiso(BuildContext context) async {
    final conectividad = context.read<ConectividadProvider>();
    final concedido = await conectividad.solicitarPermisoNotificaciones();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          concedido
              ? 'Permiso de notificaciones concedido.'
              : conectividad.error ?? 'Permiso no concedido.',
        ),
      ),
    );
  }

  Future<void> _probarNotificacion(BuildContext context) async {
    final conectividad = context.read<ConectividadProvider>();
    var habilitadas = conectividad.notificacionesHabilitadas ?? false;
    if (!habilitadas) {
      habilitadas = await conectividad.solicitarPermisoNotificaciones();
    }
    if (!context.mounted) return;
    if (!habilitadas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay permiso para mostrar notificaciones.'),
        ),
      );
      return;
    }
    await conectividad.mostrarNotificacionPrueba();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          conectividad.error ??
              'Notificación de prueba enviada. Revisa la barra del sistema.',
        ),
      ),
    );
  }

  String _fechaVerificacion(DateTime fecha) {
    if (fecha.millisecondsSinceEpoch <= 0) return 'Aún no verificado';
    return DateFormatters.fechaHora(fecha);
  }

  String _textoBooleano(
    bool? valor, {
    String si = 'Disponible',
    String no = 'No disponible',
  }) {
    if (valor == null) return 'Sin verificar';
    return valor ? si : no;
  }

  Color _colorBooleano(bool? valor) {
    if (valor == null) return AppTheme.grisNeutro;
    return valor ? AppTheme.verdeOk : AppTheme.rojoCritico;
  }

  @override
  Widget build(BuildContext context) {
    final conectividad = context.watch<ConectividadProvider>();
    final ubicacion = context.watch<UbicacionProvider>();
    final theme = Theme.of(context);
    final snapshot = conectividad.snapshot;
    final ubicacionActual = ubicacion.ubicacion;
    final diagnostico = ubicacion.diagnostico;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectividad y permisos'),
        actions: [
          IconButton(
            onPressed: conectividad.verificando
                ? null
                : () => _refrescar(context),
            tooltip: 'Verificar ahora',
            icon: conectividad.verificando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refrescar(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AvisoBanner(
              titulo: conectividad.etiquetaRed,
              mensaje: conectividad.resumen,
              nivel: conectividad.internetReal && conectividad.servicioSismos
                  ? NivelAviso.exito
                  : conectividad.hayInterfaz
                  ? NivelAviso.advertencia
                  : NivelAviso.error,
            ),
            if (conectividad.error != null) ...[
              const SizedBox(height: 8),
              AvisoBanner(
                mensaje: conectividad.error!,
                nivel: NivelAviso.error,
                onCerrar: conectividad.limpiarError,
              ),
            ],
            const SizedBox(height: AppTheme.espacioM),
            _Panel(
              titulo: 'Estado de la red',
              icono: Icons.network_check_rounded,
              children: [
                _FilaEstado(
                  etiqueta: 'Tipo de interfaz',
                  valor: snapshot.tipoRed.etiqueta,
                  color: conectividad.hayInterfaz
                      ? AppTheme.azulInfo
                      : AppTheme.rojoCritico,
                ),
                _FilaEstado(
                  etiqueta: 'Acceso real a Internet',
                  valor: conectividad.internetReal
                      ? 'Confirmado'
                      : 'No confirmado',
                  color: _colorBooleano(conectividad.internetReal),
                ),
                _FilaEstado(
                  etiqueta: 'Servicio sísmico (USGS)',
                  valor: conectividad.servicioSismos
                      ? 'Responde'
                      : 'Sin respuesta',
                  color: _colorBooleano(conectividad.servicioSismos),
                ),
                _FilaEstado(
                  etiqueta: 'Red satelital detectada',
                  valor: snapshot.redSatelitalDetectada ? 'Sí' : 'No',
                  color: snapshot.redSatelitalDetectada
                      ? AppTheme.azulInfo
                      : AppTheme.grisNeutro,
                ),
                _FilaEstado(
                  etiqueta: 'Última verificación',
                  valor: _fechaVerificacion(snapshot.verificadoEn),
                  color: AppTheme.grisNeutro,
                ),
                _FilaEstado(
                  etiqueta: 'Última conexión confirmada',
                  valor: conectividad.ultimaConexion == null
                      ? 'Sin registro'
                      : DateFormatters.fechaHora(conectividad.ultimaConexion!),
                  color: AppTheme.grisNeutro,
                ),
                const SizedBox(height: 4),
                Text(
                  'El acceso a Internet se comprueba con una solicitud de red '
                  'real, no solo con el estado que reporta el sistema. La red '
                  'satelital solo se muestra si el sistema operativo la '
                  'notifica; la app no puede activarla.',
                  style: theme.textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: conectividad.verificando
                        ? null
                        : () => _refrescar(context),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Volver a verificar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioM),
            _Panel(
              titulo: 'Ubicación',
              icono: Icons.my_location_rounded,
              children: [
                _FilaEstado(
                  etiqueta: 'Permiso',
                  valor: diagnostico.permiso.etiqueta,
                  color: diagnostico.permiso.concedido
                      ? AppTheme.verdeOk
                      : AppTheme.rojoCritico,
                ),
                _FilaEstado(
                  etiqueta: 'Servicio de ubicación (GPS)',
                  valor: diagnostico.servicioActivo ? 'Activo' : 'Desactivado',
                  color: _colorBooleano(diagnostico.servicioActivo),
                ),
                _FilaEstado(
                  etiqueta: 'Ubicación actual',
                  valor: ubicacionActual == null
                      ? 'No disponible'
                      : DateFormatters.coordenadas(
                          ubicacionActual.latitud,
                          ubicacionActual.longitud,
                        ),
                  color: ubicacionActual == null
                      ? AppTheme.grisNeutro
                      : AppTheme.azulInfo,
                ),
                if (ubicacionActual != null)
                  _FilaEstado(
                    etiqueta: 'Origen y precisión',
                    valor:
                        '${ubicacionActual.fuente == FuenteUbicacion.gps ? 'GPS' : 'Última conocida'} · '
                        '±${ubicacionActual.precisionMetros.round()} m · '
                        '${DateFormatters.hace(ubicacionActual.fecha)}',
                    color: AppTheme.grisNeutro,
                  ),
                if (ubicacion.error != null) ...[
                  const SizedBox(height: 4),
                  AvisoBanner(
                    mensaje: ubicacion.error!,
                    nivel: NivelAviso.advertencia,
                    onCerrar: ubicacion.limpiarError,
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: ubicacion.actualizando
                          ? null
                          : () => _actualizarUbicacion(context),
                      icon: ubicacion.actualizando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed_rounded, size: 18),
                      label: Text(
                        ubicacion.actualizando
                            ? 'Obteniendo…'
                            : 'Actualizar ubicación',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: ubicacion.abrirAjustesApp,
                      icon: const Icon(
                        Icons.app_settings_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Permisos de la app'),
                    ),
                    TextButton.icon(
                      onPressed: ubicacion.abrirAjustesUbicacion,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Ajustes de GPS'),
                    ),
                  ],
                ),
                Text(
                  'La ubicación se usa para centrar el mapa y redactar el '
                  'mensaje SOS. No se envía a servidores propios; solo viaja '
                  'al abrir SMS, WhatsApp o el mapa.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioM),
            _Panel(
              titulo: 'Canales de aviso',
              icono: Icons.send_outlined,
              children: [
                _FilaEstado(
                  etiqueta: 'SMS',
                  valor: _textoBooleano(conectividad.puedeAbrirSms),
                  color: _colorBooleano(conectividad.puedeAbrirSms),
                ),
                _FilaEstado(
                  etiqueta: 'WhatsApp',
                  valor: _textoBooleano(conectividad.puedeAbrirWhatsApp),
                  color: _colorBooleano(conectividad.puedeAbrirWhatsApp),
                ),
                _FilaEstado(
                  etiqueta: 'Marcador telefónico',
                  valor: _textoBooleano(conectividad.puedeAbrirLlamada),
                  color: _colorBooleano(conectividad.puedeAbrirLlamada),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los avisos se preparan en la app externa de SMS, WhatsApp o '
                  'en el selector del sistema. Alerta Sísmica no envía mensajes '
                  'por sí misma y no puede confirmar la entrega. La llamada de '
                  'emergencia solo abre el marcador para que tú la confirmes.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioM),
            _Panel(
              titulo: 'Notificaciones',
              icono: Icons.notifications_active_outlined,
              children: [
                _FilaEstado(
                  etiqueta: 'Permiso',
                  valor: _textoBooleano(
                    conectividad.notificacionesHabilitadas,
                    si: 'Concedido',
                    no: 'Denegado',
                  ),
                  color: _colorBooleano(conectividad.notificacionesHabilitadas),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (conectividad.notificacionesHabilitadas != true)
                      FilledButton.icon(
                        onPressed: () => _solicitarPermiso(context),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                        ),
                        label: const Text('Solicitar permiso'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _probarNotificacion(context),
                      icon: const Icon(
                        Icons.notification_add_outlined,
                        size: 18,
                      ),
                      label: const Text('Probar notificación'),
                    ),
                    TextButton.icon(
                      onPressed: conectividad.abrirAjustesNotificaciones,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Ajustes del sistema'),
                    ),
                  ],
                ),
                Text(
                  'Las notificaciones son locales. No se reciben alertas '
                  'remotas ni con la app cerrada: para eso hace falta un '
                  'servicio externo de notificaciones push.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioM),
            _Panel(
              titulo: 'Alcance y límites',
              icono: Icons.info_outline_rounded,
              children: [
                Text(
                  '• Los sismos provienen del feed público de USGS '
                  '(all_day.geojson) y pueden llegar con retraso.\n'
                  '• Esta app no es un sistema oficial de alerta temprana.\n'
                  '• Sin Internet se muestran los últimos datos guardados; el '
                  'mapa base puede no cargar si no hay caché de mosaicos.\n'
                  '• La detección de red satelital depende del sistema '
                  'operativo.\n'
                  '• Los mensajes SOS requieren que tú completes el envío en '
                  'la app externa.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioL),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.titulo,
    required this.icono,
    required this.children,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icono, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(titulo, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaEstado extends StatelessWidget {
  const _FilaEstado({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(etiqueta, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
