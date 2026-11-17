import 'package:flutter/material.dart';

import '../theme.dart';

enum NivelAviso { info, advertencia, error, exito }

class AvisoBanner extends StatelessWidget {
  const AvisoBanner({
    super.key,
    required this.mensaje,
    this.nivel = NivelAviso.info,
    this.titulo,
    this.etiquetaAccion,
    this.onAccion,
    this.onCerrar,
  });

  final String mensaje;
  final NivelAviso nivel;
  final String? titulo;
  final String? etiquetaAccion;
  final VoidCallback? onAccion;
  final VoidCallback? onCerrar;

  Color _color(BuildContext context) {
    switch (nivel) {
      case NivelAviso.info:
        return AppTheme.azulInfo;
      case NivelAviso.advertencia:
        return AppTheme.ambarOscuro;
      case NivelAviso.error:
        return Theme.of(context).colorScheme.error;
      case NivelAviso.exito:
        return AppTheme.verdeOk;
    }
  }

  IconData get _icono {
    switch (nivel) {
      case NivelAviso.info:
        return Icons.info_outline_rounded;
      case NivelAviso.advertencia:
        return Icons.warning_amber_rounded;
      case NivelAviso.error:
        return Icons.error_outline_rounded;
      case NivelAviso.exito:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radio),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null) ...[
                  Text(
                    titulo!,
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(mensaje, style: theme.textTheme.bodySmall),
                if (etiquetaAccion != null && onAccion != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onAccion,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        etiquetaAccion!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCerrar != null)
            IconButton(
              onPressed: onCerrar,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Cerrar aviso',
            ),
        ],
      ),
    );
  }
}
