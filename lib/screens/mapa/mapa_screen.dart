import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../providers/conectividad_provider.dart';
import '../../providers/configuracion_provider.dart';
import '../../providers/sismos_provider.dart';
import '../../providers/ubicacion_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/magnitud_badge.dart';
import '../sismos/detalle_sismo_screen.dart';

class MapaSismosScreen extends StatefulWidget {
  const MapaSismosScreen({super.key});

  @override
  State<MapaSismosScreen> createState() => _MapaSismosScreenState();
}

class _MapaSismosScreenState extends State<MapaSismosScreen> {
  final MapController _mapController = MapController();
  bool _soloCercanos = false;
  bool _centradoAutomatico = false;

  static const LatLng _centroInicial = LatLng(4.6533, -74.0836);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _centrarEnMi() async {
    final ubicacion = context.read<UbicacionProvider>();
    final actual = ubicacion.ubicacion ?? await ubicacion.actualizar();
    if (!mounted) return;
    if (actual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ubicacion.error ?? 'No se pudo obtener tu ubicación. Revisa los permisos y el GPS.',
          ),
        ),
      );
      return;
    }
    try {
      _mapController.move(LatLng(actual.latitud, actual.longitud), 11);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El mapa aún no está listo.')),
      );
    }
  }

  void _centrarAutomaticamente(UbicacionUsuario? ubicacion) {
    if (_centradoAutomatico || ubicacion == null) return;
    _centradoAutomatico = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(LatLng(ubicacion.latitud, ubicacion.longitud), 6);
      } catch (_) {
        _centradoAutomatico = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sismos = context.watch<SismosProvider>();
    final ubicacion = context.watch<UbicacionProvider>();
    final configuracion = context.watch<ConfiguracionProvider>();
    final conectividad = context.watch<ConectividadProvider>();
    final theme = Theme.of(context);

    _centrarAutomaticamente(ubicacion.ubicacion);

    var visibles = sismos.visibles;
    if (_soloCercanos && ubicacion.ubicacion != null) {
      final actual = ubicacion.ubicacion!;
      visibles = visibles
          .where(
            (sismo) =>
                sismo.distanciaKmDesde(actual.latitud, actual.longitud) <= 750,
          )
          .toList();
    }
    final mostrados = visibles.take(300).toList();
    final usuario = ubicacion.ubicacion;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _centroInicial,
            initialZoom: 4.5,
            minZoom: 2,
            maxZoom: 17,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.alerta_sismica',
              tileProvider: NetworkTileProvider(
                cachingProvider: const DisabledMapCachingProvider(),
              ),
            ),
            if (usuario != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(usuario.latitud, usuario.longitud),
                    radius: 300,
                    useRadiusInMeter: true,
                    color: AppTheme.azulInfo.withValues(alpha: 0.12),
                    borderColor: AppTheme.azulInfo,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(usuario.latitud, usuario.longitud),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.azulInfo,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            MarkerLayer(
              markers: [
                for (final sismo in mostrados)
                  Marker(
                    point: LatLng(sismo.latitud, sismo.longitud),
                    width: 42,
                    height: 42,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetalleSismoScreen(sismo: sismo),
                        ),
                      ),
                      child: MagnitudBadge(
                        magnitud: sismo.magnitud,
                        tamano: 38,
                        compacto: true,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mostrados.length} sismo(s) en el mapa',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              sismos.actualizadoEn == null
                                  ? 'Consultando USGS…'
                                  : sismos.usaCache
                                  ? 'Datos guardados · '
                                        '${DateFormatters.hace(sismos.actualizadoEn!)}'
                                  : 'USGS · actualizado '
                                        '${DateFormatters.hace(sismos.actualizadoEn!)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            context.read<SismosProvider>().refrescar(),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: 'Actualizar sismos',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('Solo cercanos'),
                        selected: _soloCercanos,
                        onSelected: (valor) async {
                          setState(() => _soloCercanos = valor);
                          if (valor && ubicacion.ubicacion == null) {
                            await _centrarEnMi();
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          'M≥${configuracion.magnitudMinima.toStringAsFixed(1)}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (!conectividad.internetReal)
                        Chip(
                          avatar: const Icon(Icons.cloud_off_rounded, size: 15),
                          label: const Text('Sin Internet'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (usuario == null)
                        ActionChip(
                          avatar: const Icon(
                            Icons.location_off_rounded,
                            size: 15,
                          ),
                          label: const Text('Ubicación'),
                          onPressed: _centrarEnMi,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 34,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Magnitud', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  _Leyenda(color: AppTheme.colorMagnitudMenor, texto: '< 4'),
                  _Leyenda(color: AppTheme.colorMagnitudLeve, texto: '4–4.9'),
                  _Leyenda(
                    color: AppTheme.colorMagnitudModerado,
                    texto: '5–5.9',
                  ),
                  _Leyenda(color: AppTheme.colorMagnitudFuerte, texto: '6–6.9'),
                  _Leyenda(color: AppTheme.colorMagnitudMayor, texto: '≥ 7'),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 64,
          child: Column(
            children: [
              _BotonMapa(
                icono: Icons.my_location_rounded,
                tooltip: 'Centrar en mi ubicación',
                onTap: _centrarEnMi,
              ),
              const SizedBox(height: 8),
              _BotonMapa(
                icono: Icons.add_rounded,
                tooltip: 'Acercar',
                onTap: () {
                  try {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (zoom + 1).clamp(2, 17),
                    );
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
              _BotonMapa(
                icono: Icons.remove_rounded,
                tooltip: 'Alejar',
                onTap: () {
                  try {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (zoom - 1).clamp(2, 17),
                    );
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
        if (sismos.cargando && !sismos.hayDatos)
          const Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!sismos.cargando && mostrados.isEmpty)
          Positioned(
            top: 155,
            left: 24,
            right: 24,
            child: Card(
              child: Padding(
                padding: AppTheme.paddingM,
                child: Column(
                  children: [
                    const Icon(Icons.travel_explore_rounded, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      sismos.hayDatos
                          ? 'No hay sismos que coincidan con el filtro.'
                          : 'No hay sismos disponibles. Revisa tu conexión.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(texto, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa({
    required this.icono,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: IconButton(onPressed: onTap, icon: Icon(icono), tooltip: tooltip),
    );
  }
}
