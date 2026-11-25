import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/movimiento_provider.dart';
import '../../theme.dart';

class MonitorMovimientoScreen extends StatefulWidget {
  const MonitorMovimientoScreen({super.key});

  @override
  State<MonitorMovimientoScreen> createState() =>
      _MonitorMovimientoScreenState();
}

class _MonitorMovimientoScreenState extends State<MonitorMovimientoScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MovimientoProvider>().iniciar();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<MovimientoProvider>();
    if (state == AppLifecycleState.resumed) {
      provider.iniciar();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      provider.detener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<MovimientoProvider>().detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MovimientoProvider>();
    final theme = Theme.of(context);
    final colorEstado = p.alertaMovimiento
        ? AppTheme.ambarOscuro
        : AppTheme.verdeOk;

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor de movimiento')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.espacioM),
        children: [
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: colorEstado.withValues(alpha: 0.12),
                    child: Icon(
                      p.alertaMovimiento
                          ? Icons.vibration_rounded
                          : Icons.sensors_rounded,
                      color: colorEstado,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.alertaMovimiento
                              ? 'Movimiento inusual detectado'
                              : p.activo
                                  ? 'Sensores activos'
                                  : 'Monitor detenido',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          p.alertaMovimiento
                              ? 'Se registró una vibración por encima del umbral experimental.'
                              : 'Lecturas del dispositivo en tiempo real.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (p.error != null) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: AppTheme.paddingM,
                child: Text(
                  p.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.espacioM),
          Text('Acelerómetro', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          _LecturasCard(
            icono: Icons.speed_rounded,
            unidad: 'm/s²',
            x: p.ax,
            y: p.ay,
            z: p.az,
            magnitud: p.magnitudAceleracion,
            etiquetaMagnitud: 'Aceleración lineal',
          ),
          const SizedBox(height: AppTheme.espacioM),
          Text('Giroscopio', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          _LecturasCard(
            icono: Icons.screen_rotation_alt_rounded,
            unidad: 'rad/s',
            x: p.gx,
            y: p.gy,
            z: p.gz,
            magnitud: p.magnitudGiro,
            etiquetaMagnitud: 'Velocidad angular',
          ),
          const SizedBox(height: AppTheme.espacioM),
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Análisis de vibración', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${p.rmsVibracion.toStringAsFixed(3)} m/s²',
                    style: AppTheme.numerosGrandes.copyWith(
                      color: p.alertaMovimiento
                          ? AppTheme.ambarOscuro
                          : theme.colorScheme.primary,
                      fontSize: 34,
                    ),
                  ),
                  Text(
                    'Nivel RMS de aceleración en una ventana móvil de 1,5 segundos.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.espacioM),
          FilledButton.icon(
            onPressed: p.activo ? p.detener : p.iniciar,
            icon: Icon(p.activo ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(p.activo ? 'Detener monitor' : 'Iniciar monitor'),
          ),
          const SizedBox(height: 12),
          Text(
            'Aviso: esta función es experimental. El teléfono no es un sismómetro '
            'calibrado y las lecturas pueden verse afectadas por la superficie, '
            'el movimiento del dispositivo y el hardware. No confirma terremotos '
            'ni sustituye las alertas oficiales.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LecturasCard extends StatelessWidget {
  const _LecturasCard({
    required this.icono,
    required this.unidad,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitud,
    required this.etiquetaMagnitud,
  });

  final IconData icono;
  final String unidad;
  final double x, y, z, magnitud;
  final String etiquetaMagnitud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: AppTheme.paddingM,
        child: Column(
          children: [
            Row(
              children: [
                Icon(icono, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Ejes X · Y · Z', style: theme.textTheme.titleMedium)),
                Text(unidad, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Eje(nombre: 'X', valor: x),
                _Eje(nombre: 'Y', valor: y),
                _Eje(nombre: 'Z', valor: z),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text(etiquetaMagnitud, style: theme.textTheme.bodyMedium)),
                Text(
                  '${magnitud.toStringAsFixed(3)} $unidad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Eje extends StatelessWidget {
  const _Eje({required this.nombre, required this.valor});
  final String nombre;
  final double valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(nombre, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            valor.toStringAsFixed(2),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
