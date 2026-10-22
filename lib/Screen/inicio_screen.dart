import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/sismo.dart';
import '../providers/sismos_provider.dart';
import '../providers/contactos_provider.dart';
import '../providers/emergencia_provider.dart';
import '../services/gps_service.dart';
import '../services/sos_service.dart';
import 'alerta_screen.dart';
import 'configuracion_screen.dart';
import 'emergencia_screen.dart';
import '../theme.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final MapController _mapController = MapController();
  Timer? _timerSos;
  double _progresoSos = 0;
  LatLng? _miUbicacion;
  String? _errorGps;
  bool _cargandoUbicacion = true;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionInicial();
    _escucharUbicacion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SismosProvider>().cargarSismos();
    });
  }

  Future<void> _obtenerUbicacionInicial() async {
    final pos = await GpsService.obtenerUbicacion();
    if (mounted) {
      setState(() {
        if (pos != null) {
          _miUbicacion = LatLng(pos.latitude, pos.longitude);
          _errorGps = null;
        } else {
          _errorGps = 'No se pudo obtener la ubicación. Verifica permisos y GPS.';
        }
        _cargandoUbicacion = false;
      });
      if (_miUbicacion != null) {
        _mapController.move(_miUbicacion!, 13);
      }
    }
  }

  void _escucharUbicacion() {
    GpsService.streamUbicacion().listen((pos) {
      if (mounted) {
        setState(() {
          _miUbicacion = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
  }

  void _iniciarSos() {
    _timerSos?.cancel();
    _progresoSos = 0;
    _timerSos = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) return;
      setState(() => _progresoSos += 0.025);
      if (_progresoSos >= 1) {
        t.cancel();
        setState(() => _progresoSos = 0);
        _activarSosReal();
      }
    });
  }

  void _cancelarSos() {
    _timerSos?.cancel();
    setState(() => _progresoSos = 0);
  }

  Future<void> _activarSosReal() async {
    if (_miUbicacion == null) {
      _mostrarError('No hay ubicación GPS disponible');
      return;
    }
    final contactos = context.read<ContactosProvider>().contactos;
    if (contactos.isEmpty) {
      _mostrarError('No hay contactos de emergencia configurados');
      return;
    }
    context.read<EmergenciaProvider>().activarSos(
      _miUbicacion!.latitude,
      _miUbicacion!.longitude,
    );
    await SosService.enviarSos(
      contactos: contactos,
      latitud: _miUbicacion!.latitude,
      longitud: _miUbicacion!.longitude,
    );
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergenciaScreen()),
      );
    }
  }

  void _simularSismo() {
    if (_miUbicacion == null) {
      _mostrarError('No hay ubicación GPS disponible');
      return;
    }
    context.read<SismosProvider>().simularSismo();
    final sismo = context.read<SismosProvider>().ultimoSismo!;
    context.read<EmergenciaProvider>().activarAlertaSismo(
      sismo,
      _miUbicacion!.latitude,
      _miUbicacion!.longitude,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlertaScreen()),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.rojoCritico),
    );
  }

  @override
  void dispose() {
    _timerSos?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerta sísmica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
            ),
          ),
          Consumer<SismosProvider>(
            builder: (_, prov, _) => IconButton(
              icon: Icon(
                prov.cargando ? Icons.sync : Icons.refresh,
                color: prov.cargando ? AppTheme.ambarAdvertencia : AppTheme.textoPrincipal,
              ),
              onPressed: prov.cargando ? null : () => prov.cargarSismos(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _miUbicacion ?? const LatLng(4.65, -74.1),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.alerta_sismica',
                      maxZoom: 19,
                    ),
                    if (_miUbicacion != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _miUbicacion!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.my_location,
                              color: AppTheme.rojoCritico,
                              size: 32,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                    Consumer<SismosProvider>(
                      builder: (_, prov, _) => MarkerLayer(
                        markers: prov.sismos.map((s) => Marker(
                          point: LatLng(s.latitud, s.longitud),
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.circle,
                            color: s.colorMagnitud,
                            size: 20,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
                if (_cargandoUbicacion)
                  const Center(
                    child: CircularProgressIndicator(color: AppTheme.rojoCritico),
                  ),
                if (_errorGps != null)
                  Positioned(
                    left: AppTheme.espacioM,
                    right: AppTheme.espacioM,
                    bottom: 160,
                    child: Material(
                      color: AppTheme.rojoCritico,
                      borderRadius: BorderRadius.circular(AppTheme.radio),
                      child: Padding(
                        padding: AppTheme.paddingM,
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.textoSobreRojo),
                            const SizedBox(width: AppTheme.espacioS),
                            Expanded(child: Text(_errorGps!, style: const TextStyle(color: AppTheme.textoSobreRojo))),
                            TextButton(
                              onPressed: () => GpsService.abrirConfiguracion(),
                              child: const Text('Abrir ajustes', style: TextStyle(color: AppTheme.textoSobreRojo)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: AppTheme.espacioM,
                  right: AppTheme.espacioM,
                  bottom: AppTheme.espacioM,
                  child: Consumer<SismosProvider>(
                    builder: (_, prov, _) => _TarjetaUltimoSismo(
                      sismo: prov.ultimoSismo,
                      cargando: prov.cargando,
                      error: prov.error,
                      onSimular: _simularSismo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BotonSos(progreso: _progresoSos, onIniciar: _iniciarSos, onCancelar: _cancelarSos),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text('Mantener 2 segundos', style: TextStyle(color: AppTheme.textoTerciario)),
          ),
        ],
      ),
    );
  }
}

class _TarjetaUltimoSismo extends StatelessWidget {
  final Sismo? sismo;
  final bool cargando;
  final String? error;
  final VoidCallback onSimular;

  const _TarjetaUltimoSismo({
    required this.sismo,
    required this.cargando,
    required this.error,
    required this.onSimular,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando && sismo == null) {
      return const _TarjetaCargando();
    }
    if (error != null && sismo == null) {
      return _TarjetaError(error: error!, onReintentar: onSimular);
    }
    if (sismo == null) {
      return const _TarjetaSinDatos();
    }
    final s = sismo!;
    return Card(
      child: Padding(
        padding: AppTheme.paddingM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.colorMagnitud,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.espacioS),
                Expanded(
                  child: Text(
                    'Último sismo: ${s.magnitud.toStringAsFixed(1)} Richter',
                    style: AppTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.espacioXS),
            Text(
              s.lugar,
              style: AppTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.espacioS),
            Row(
              children: [
                Text(
                  _formatearTiempo(s.tiempo),
                  style: AppTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSimular,
                  child: const Text('Simular alerta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearTiempo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Hace menos de 1 min';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}

class _TarjetaCargando extends StatelessWidget {
  const _TarjetaCargando();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppTheme.paddingM,
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.rojoCritico)),
            const SizedBox(width: AppTheme.espacioM),
            const Text('Cargando sismos...'),
          ],
        ),
      ),
    );
  }
}

class _TarjetaError extends StatelessWidget {
  final String error;
  final VoidCallback onReintentar;

  const _TarjetaError({required this.error, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppTheme.paddingM,
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.rojoCritico),
            const SizedBox(width: AppTheme.espacioS),
            Expanded(child: Text(error, style: AppTheme.bodyMedium)),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _TarjetaSinDatos extends StatelessWidget {
  const _TarjetaSinDatos();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppTheme.paddingM,
        child: Text('No hay datos de sismos recientes', style: AppTheme.bodyMedium),
      ),
    );
  }
}

class _BotonSos extends StatelessWidget {
  final double progreso;
  final VoidCallback onIniciar;
  final VoidCallback onCancelar;

  const _BotonSos({
    required this.progreso,
    required this.onIniciar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onIniciar(),
      onTapUp: (_) => onCancelar(),
      onTapCancel: onCancelar,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: progreso,
                strokeWidth: 6,
                color: AppTheme.textoPrincipal,
                backgroundColor: AppTheme.textoTerciario,
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppTheme.rojoCritico,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'SOS\nAYUDA',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
