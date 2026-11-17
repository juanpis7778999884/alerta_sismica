import 'package:flutter/material.dart';

import '../theme.dart';

class MagnitudBadge extends StatelessWidget {
  const MagnitudBadge({
    super.key,
    required this.magnitud,
    this.tamano = 48,
    this.compacto = false,
  });

  final double magnitud;
  final double tamano;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorParaMagnitud(magnitud);
    final colorTexto = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final texto = magnitud.toStringAsFixed(1);

    return Semantics(
      label: 'Magnitud $texto',
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(tamano * 0.25),
          boxShadow: compacto
              ? const []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'M',
              style: TextStyle(
                color: colorTexto.withValues(alpha: 0.85),
                fontSize: tamano * 0.2,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            Text(
              texto,
              style: TextStyle(
                color: colorTexto,
                fontSize: tamano * 0.34,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
