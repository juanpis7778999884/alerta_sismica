import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/sismo.dart';
import '../../providers/emergencia_provider.dart';
import '../../theme.dart';
import '../../widgets/magnitud_badge.dart';
import '../emergencia/emergencia_screen.dart';
import '../sismos/detalle_sismo_screen.dart';

class AlertaSismoScreen extends StatelessWidget {
  const AlertaSismoScreen({super.key, required this.sismo, this.distanciaKm});

  final Sismo sismo;
  final double? distanciaKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emergencia = context.watch<EmergenciaProvider>();
    final hayActiva = emergencia.hayEmergenciaActiva;

    return Scaffold(
      appBar: AppBar(title: const Text('Alerta sísmica')),
      body: ListView(
        padding: AppTheme.paddingL,
        children: [
          Container(
            padding: AppTheme.paddingL,
            decoration: BoxDecoration(
              color: AppTheme.rojoCritico,
              borderRadius: BorderRadius.circular(AppTheme.radioGrande),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sismo.magnitud >= 6
                            ? 'SISMO FUERTE REGISTRADO'
                            : 'SISMO RELEVANTE REGISTRADO',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (sismo.esSimulacion)
                      const Chip(
                        label: Text('SIMULACIÓN'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.espacioM),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MagnitudBadge(magnitud: sismo.magnitud, tamano: 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sismo.lugar,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormatters.fechaHora(sismo.tiempo)}\n'
                            'Profundidad ${sismo.profundidadTexto}'
                            '${distanciaKm == null ? '' : ' · a ${distanciaKm!.round()} km de ti'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.espacioL),
          Text('Recomendaciones inmediatas', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.espacioS),
          const _Paso(
            numero: 1,
            titulo: 'Protégete primero',
            detalle:
                'Agáchate, cúbrete la cabeza y sujétate de un mueble firme. '
                'Aléjate de ventanas y objetos que puedan caer.',
          ),
          const _Paso(
            numero: 2,
            titulo: 'No uses ascensores',
            detalle:
                'Si estás en un edificio, espera a que termine el movimiento y '
                'evacúa por las escaleras si es seguro.',
          ),
          const _Paso(
            numero: 3,
            titulo: 'Evita llamar por teléfono',
            detalle:
                'Las líneas pueden saturarse. Usa SMS o mensajes de datos para '
                'avisar a tus contactos.',
          ),
          const _Paso(
            numero: 4,
            titulo: 'Sigue las indicaciones oficiales',
            detalle:
                'Atiende a los organismos de emergencia de tu país. Esta app no '
                'emite alertas oficiales ni predicciones.',
          ),
          const SizedBox(height: AppTheme.espacioL),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EmergenciaScreen(sismoRelacionado: sismo),
                ),
              );
            },
            icon: const Icon(Icons.sos_rounded),
            label: Text(
              hayActiva
                  ? 'Abrir emergencia activa'
                  : 'Activar SOS por este sismo',
            ),
          ),
          const SizedBox(height: AppTheme.espacioS),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetalleSismoScreen(sismo: sismo),
                ),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('Ver ficha completa del sismo'),
          ),
          const SizedBox(height: AppTheme.espacioL),
          Text(
            'Los datos sísmicos provienen de USGS y pueden llegar con retraso. '
            'La alerta no predice sismos ni reemplaza a los sistemas oficiales.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.detalle,
  });

  final int numero;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  '$numero',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(detalle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
