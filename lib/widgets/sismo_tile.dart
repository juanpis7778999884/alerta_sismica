import 'package:flutter/material.dart';

import '../core/utils/date_formatters.dart';
import '../models/sismo.dart';
import '../theme.dart';
import 'magnitud_badge.dart';

class SismoTile extends StatelessWidget {
  const SismoTile({
    super.key,
    required this.sismo,
    this.distanciaKm,
    this.onTap,
  });

  final Sismo sismo;
  final double? distanciaKm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MagnitudBadge(magnitud: sismo.magnitud, tamano: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sismo.lugar,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormatters.fechaHora(sismo.tiempo)} · '
                      '${DateFormatters.hace(sismo.tiempo)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Dato(
                          icono: Icons.vertical_align_bottom_rounded,
                          texto: sismo.profundidadTexto,
                        ),
                        if (distanciaKm != null)
                          _Dato(
                            icono: Icons.near_me_outlined,
                            texto: _distancia(distanciaKm!),
                          ),
                        _Dato(
                          icono: Icons.speed_rounded,
                          texto:
                              'M${sismo.magnitudFormateada} · ${sismo.magnitudTexto}',
                          color: AppTheme.colorParaMagnitud(sismo.magnitud),
                        ),
                        if (sismo.esSimulacion)
                          const _Etiqueta(
                            texto: 'SIMULADO',
                            color: AppTheme.azulInfo,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _distancia(double km) {
    if (km < 1) return '< 1 km';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.color});

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorFinal = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: colorFinal),
        const SizedBox(width: 3),
        Text(
          texto,
          style: theme.textTheme.labelSmall?.copyWith(color: colorFinal),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
