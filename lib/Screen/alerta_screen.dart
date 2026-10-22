import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/estado_emergencia.dart';
import '../providers/emergencia_provider.dart';
import 'emergencia_screen.dart';
import '../theme.dart';

class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});

  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen> {
  Timer? _timer;
  int _segundos = 35;

  @override
  void initState() {
    super.initState();
    final emergencia = context.read<EmergenciaProvider>();
    if (emergencia.estado.tipo == TipoEmergencia.simulacion) {
      _segundos = 35;
    } else if (emergencia.estado.sismo != null) {
      _segundos = 30;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_segundos > 0) {
        setState(() => _segundos--);
      } else {
        t.cancel();
        _pasarAEmergencia();
      }
    });
  }

  void _pasarAEmergencia() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmergenciaScreen()),
    );
  }

  void _estoyASalvo() {
    _timer?.cancel();
    context.read<EmergenciaProvider>().desactivar();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencia = context.watch<EmergenciaProvider>().estado;
    final sismo = emergencia.sismo;
    final esSimulacion = emergencia.tipo == TipoEmergencia.simulacion;
    final colorIcono = esSimulacion ? AppTheme.azulInfo : AppTheme.ambarAdvertencia;
    final colorBorde = esSimulacion ? AppTheme.azulInfo : AppTheme.ambarAdvertencia;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: AppTheme.paddingL,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  esSimulacion ? Icons.science_outlined : Icons.warning_amber_rounded,
                  size: AppTheme.iconoXXL,
                  color: colorIcono,
                ),
                const SizedBox(height: AppTheme.espacioM),
                Text(
                  esSimulacion ? 'Simulación de sismo' : '¡Sismo inminente!',
                  style: AppTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.espacioS),
                Text(
                  esSimulacion
                      ? 'Esta es una prueba. En un caso real, agáchate, cúbrete y sujétate.'
                      : 'Agáchate, cúbrete y sujétate',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.textoSecundario),
                  textAlign: TextAlign.center,
                ),
                if (sismo != null) ...[
                  const SizedBox(height: AppTheme.espacioL),
                  Container(
                    width: double.infinity,
                    padding: AppTheme.paddingM,
decoration: BoxDecoration(
                       color: AppTheme.superficie,
                       borderRadius: BorderRadius.circular(AppTheme.radio),
                       border: Border.all(color: sismo.colorMagnitud, width: 1),
                     ),
                    child: Column(
                      children: [
                        Text(
                          '${sismo.magnitud.toStringAsFixed(1)} Richter • ${sismo.magnitudTexto}',
                          style: AppTheme.headlineMedium.copyWith(color: sismo.colorMagnitud),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.espacioXS),
                        Text(
                          sismo.lugar,
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.espacioXL),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorBorde, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cuenta regresiva', style: AppTheme.bodySmall),
                      Text(
                        '$_segundos s',
                        style: AppTheme.numerosGrandes,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.espacioXL),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _estoyASalvo,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.verdeOk,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Estoy a salvo', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
