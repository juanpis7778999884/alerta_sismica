import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/sismo.dart';
import '../../providers/ubicacion_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/magnitud_badge.dart';
import '../emergencia/emergencia_screen.dart';

class DetalleSismoScreen extends StatefulWidget {
  const DetalleSismoScreen({super.key, required this.sismo});

  final Sismo sismo;

  @override
  State<DetalleSismoScreen> createState() => _DetalleSismoScreenState();
}

class _DetalleSismoScreenState extends State<DetalleSismoScreen> {
  String? _error;

  Future<void> _abrirEnlace(String url, String etiqueta) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = 'El enlace de $etiqueta no es válido.');
      return;
    }
    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        setState(() => _error = 'No se pudo abrir $etiqueta.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir $etiqueta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ubicacion = context.watch<UbicacionProvider>().ubicacion;
    final distancia = ubicacion == null
        ? null
        : widget.sismo.distanciaKmDesde(ubicacion.latitud, ubicacion.longitud);
    final sismo = widget.sismo;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del sismo')),
      body: ListView(
        padding: AppTheme.paddingL,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AvisoBanner(
                mensaje: _error!,
                nivel: NivelAviso.error,
                onCerrar: () => setState(() => _error = null),
              ),
            ),
          Card(
            child: Padding(
              padding: AppTheme.paddingL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MagnitudBadge(magnitud: sismo.magnitud, tamano: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Magnitud ${sismo.magnitudFormateada}',
                              style: theme.textTheme.headlineMedium,
                            ),
                            Text(
                              '${sismo.magnitudTexto} · ${sismo.profundidadTexto} de profundidad',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (sismo.esSimulacion) ...[
                              const SizedBox(height: 6),
                              Chip(
                                label: const Text('Evento simulado'),
                                backgroundColor: AppTheme.azulInfo.withValues(
                                  alpha: 0.1,
                                ),
                                side: const BorderSide(
                                  color: AppTheme.azulInfo,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.espacioL),
                  Text(sismo.lugar, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.espacioM),
                  _FilaDato(
                    icono: Icons.schedule_rounded,
                    etiqueta: 'Hora local',
                    valor: DateFormatters.fechaHora(sismo.tiempo),
                  ),
                  _FilaDato(
                    icono: Icons.timer_outlined,
                    etiqueta: 'Registrado',
                    valor: DateFormatters.hace(sismo.tiempo),
                  ),
                  if (distancia != null)
                    _FilaDato(
                      icono: Icons.near_me_outlined,
                      etiqueta: 'Distancia aproximada',
                      valor: distancia < 1
                          ? 'Menos de 1 km de tu ubicación'
                          : '${distancia.round()} km de tu ubicación',
                    ),
                  _FilaDato(
                    icono: Icons.place_outlined,
                    etiqueta: 'Coordenadas',
                    valor: DateFormatters.coordenadas(
                      sismo.latitud,
                      sismo.longitud,
                    ),
                  ),
                  if (sismo.actualizadoEn != null)
                    _FilaDato(
                      icono: Icons.update_rounded,
                      etiqueta: 'Última actualización USGS',
                      valor: DateFormatters.fechaHora(sismo.actualizadoEn!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.espacioM),
          if (sismo.tieneEnlace)
            OutlinedButton.icon(
              onPressed: () => _abrirEnlace(sismo.url, 'la ficha de USGS'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ver informe oficial en USGS'),
            ),
          const SizedBox(height: AppTheme.espacioS),
          OutlinedButton.icon(
            onPressed: () => _abrirEnlace(sismo.urlMapa, 'el mapa'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir ubicación en la app de mapas'),
          ),
          const SizedBox(height: AppTheme.espacioS),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EmergenciaScreen(sismoRelacionado: sismo),
                ),
              );
            },
            icon: const Icon(Icons.sos_rounded),
            label: const Text('Preparar SOS por este sismo'),
          ),
          const SizedBox(height: AppTheme.espacioL),
          Text(
            'Fuente: USGS Earthquake Hazards Program. La información puede '
            'cambiar después de una revisión. No es una predicción ni una '
            'alerta oficial.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: theme.textTheme.labelSmall),
                SelectableText(valor, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
