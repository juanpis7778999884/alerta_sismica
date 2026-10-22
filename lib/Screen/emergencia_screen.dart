import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emergencia_provider.dart';
import '../theme.dart';

class EmergenciaScreen extends StatefulWidget {
  const EmergenciaScreen({super.key});

  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  bool _gpsListo = false;
  bool _mensajesEnviados = false;

  @override
  void initState() {
    super.initState();
    _verificarGps();
    _enviarMensajes();
  }

  Future<void> _verificarGps() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _gpsListo = true);
  }

  Future<void> _enviarMensajes() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _mensajesEnviados = true);
  }

  Widget _paso(String texto, bool listo, IconData icono) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        listo ? Icons.check_circle : icono,
        color: listo ? AppTheme.verdeOk : AppTheme.textoTerciario,
        size: 28,
      ),
      title: Text(texto, style: AppTheme.bodyLarge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EmergenciaProvider>().estado;
    final lat = estado.latitud?.toStringAsFixed(6) ?? '--';
    final lon = estado.longitud?.toStringAsFixed(6) ?? '--';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergencia activa'),
          backgroundColor: AppTheme.rojoOscuro,
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: AppTheme.paddingL,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.espacioXS),
              _paso('Coordenadas GPS capturadas', _gpsListo, Icons.gps_fixed),
              const Divider(),
              _paso('Mensajes SOS enviados a contactos', _mensajesEnviados, Icons.sms),
              const Divider(),
              const SizedBox(height: AppTheme.espacioM),
              Text(
                'Ubicación: $lat, $lon',
                style: AppTheme.monospace,
              ),
              const Spacer(),
              Icon(Icons.satellite_alt, size: AppTheme.iconoXXL, color: AppTheme.textoTerciario),
              const SizedBox(height: AppTheme.espacioM),
              Text(
                'Enlazando satélite...',
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.textoSecundario),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.read<EmergenciaProvider>().desactivar();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: AppTheme.borde),
                  ),
                  child: const Text('Cancelar alerta', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
