import 'package:flutter/material.dart';

import '../theme.dart';

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({
    super.key,
    required this.etiqueta,
    required this.color,
    required this.icono,
    this.onTap,
  });

  final String etiqueta;
  final Color color;
  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icono, size: 16, color: color),
      label: Text(etiqueta),
      labelStyle: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  static ConnectionChip desdeEstado({
    required bool internet,
    required bool interfaz,
    required String etiqueta,
    VoidCallback? onTap,
  }) {
    if (internet) {
      return ConnectionChip(
        etiqueta: etiqueta,
        color: AppTheme.verdeOk,
        icono: Icons.wifi_rounded,
        onTap: onTap,
      );
    }
    if (interfaz) {
      return ConnectionChip(
        etiqueta: 'Sin Internet',
        color: AppTheme.ambarOscuro,
        icono: Icons.wifi_off_rounded,
        onTap: onTap,
      );
    }
    return ConnectionChip(
      etiqueta: 'Desconectado',
      color: AppTheme.grisNeutro,
      icono: Icons.cloud_off_rounded,
      onTap: onTap,
    );
  }
}
