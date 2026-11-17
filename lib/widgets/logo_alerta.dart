import 'package:flutter/material.dart';

import '../theme.dart';

class LogoAlerta extends StatelessWidget {
  const LogoAlerta({
    super.key,
    this.tamano = 64,
    this.mostrarTexto = true,
    this.subtitulo,
  });

  final double tamano;
  final bool mostrarTexto;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: AppTheme.rojoCritico,
        borderRadius: BorderRadius.circular(tamano * 0.28),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.crisis_alert_rounded,
        size: tamano * 0.56,
        color: Colors.white,
      ),
    );

    if (!mostrarTexto) return logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(height: AppTheme.espacioM),
        Text(
          'Alerta Sísmica',
          style: theme.textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: AppTheme.espacioS),
          Text(
            subtitulo!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
