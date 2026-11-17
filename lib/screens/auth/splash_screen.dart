import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/logo_alerta.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoAlerta(
                tamano: 84,
                subtitulo: 'Preparando tu monitoreo sísmico…',
              ),
              const SizedBox(height: AppTheme.espacioXL),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
