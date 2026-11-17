import 'package:flutter/material.dart';

import '../theme.dart';

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.etiquetaAccion,
    this.onAccion,
    this.colorIcono,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final String? etiquetaAccion;
  final VoidCallback? onAccion;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorIcono ?? theme.colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: AppTheme.paddingL,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icono, size: 36, color: color),
              ),
              const SizedBox(height: AppTheme.espacioL),
              Text(
                titulo,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.espacioS),
              Text(
                mensaje,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (etiquetaAccion != null && onAccion != null) ...[
                const SizedBox(height: AppTheme.espacioL),
                FilledButton.icon(
                  onPressed: onAccion,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(etiquetaAccion!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
