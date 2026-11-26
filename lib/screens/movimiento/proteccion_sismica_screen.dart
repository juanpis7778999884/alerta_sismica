import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/emergencia.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contactos_provider.dart';
import '../../providers/emergencia_provider.dart';
import '../../services/motion_protection_service.dart';
import '../../theme.dart';

class ProteccionSismicaScreen extends StatefulWidget {
  const ProteccionSismicaScreen({super.key, this.sosSolicitado = false, this.alertaAbierta = false});

  final bool sosSolicitado;
  final bool alertaAbierta;

  @override
  State<ProteccionSismicaScreen> createState() => _ProteccionSismicaScreenState();
}

class _ProteccionSismicaScreenState extends State<ProteccionSismicaScreen> {
  bool _activa = false;
  bool _cargando = true;
  bool _procesandoSos = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
    if (widget.sosSolicitado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _activarSos());
    }
  }

  Future<void> _cargarEstado() async {
    try {
      final activa = await MotionProtectionService.estaActiva();
      if (!mounted) return;
      setState(() {
        _activa = activa;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo consultar el estado de Protección sísmica: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarProteccion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final permiso = await Permission.notification.request();
      if (!permiso.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa el permiso de notificaciones para recibir los avisos de protección.')),
        );
      }
      final ok = _activa
          ? await MotionProtectionService.detener()
          : await MotionProtectionService.iniciar();
      if (!mounted) return;
      setState(() {
        _activa = ok ? !_activa : _activa;
        _cargando = false;
        if (!ok) _error = 'Android no confirmó el cambio del servicio.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cambiar la protección: $e';
      });
    }
  }

  Future<void> _confirmarBien() async {
    await MotionProtectionService.confirmarBien();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gracias por confirmar que estás bien.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _activarSos() async {
    if (_procesandoSos || !mounted) return;
    _procesandoSos = true;
    final usuario = context.read<AuthProvider>().usuario;
    final contactos = context.read<ContactosProvider>().contactos;
    if (usuario == null || contactos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(usuario == null
                ? 'Inicia sesión para activar el SOS.'
                : 'No tienes contactos de emergencia configurados.'),
          ),
        );
      }
      _procesandoSos = false;
      return;
    }

    final provider = context.read<EmergenciaProvider>();
    final resultado = await provider.activarSos(
      usuario: usuario,
      contactos: contactos,
      tipo: TipoEmergencia.sos,
      referenciaEvento: 'Movimiento inusual detectado por Protección sísmica.',
    );
    if (!mounted) {
      _procesandoSos = false;
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resultado.mensaje)),
    );
    if (resultado.exitosa && !resultado.yaExistia) {
      final envio = await provider.intentarEnvioInicial();
      if (mounted && envio != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(envio)),
        );
      }
    }
    _procesandoSos = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Protección sísmica')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.espacioM),
        children: [
          Card(
            child: Padding(
              padding: AppTheme.paddingL,
              child: Column(
                children: [
                  Icon(
                    _activa ? Icons.shield_rounded : Icons.shield_outlined,
                    size: 64,
                    color: _activa ? AppTheme.verdeOk : theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activa ? 'Protección activa' : 'Protección desactivada',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activa
                        ? 'Android mantiene el acelerómetro y el giroscopio activos mediante un servicio en primer plano.'
                        : 'Activa la protección para mantener el monitoreo aunque salgas de la app o bloquees la pantalla.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _cargando ? null : _cambiarProteccion,
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_activa ? Icons.stop_rounded : Icons.shield_rounded),
                      label: Text(_activa ? 'Detener protección' : 'Activar protección'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.alertaAbierta) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: AppTheme.paddingM,
                child: Column(
                  children: [
                    const Text('Se detectó movimiento inusual. ¿Estás bien?'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _confirmarBien,
                            child: const Text('Estoy bien'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _procesandoSos ? null : _activarSos,
                            icon: const Icon(Icons.sos_rounded),
                            label: const Text('Activar SOS'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Notificación permanente'),
            subtitle: Text('Verás en Android que la protección está activa. También podrás detenerla desde esa notificación.'),
          ),
          const ListTile(
            leading: Icon(Icons.sensors_outlined),
            title: Text('Sensores nativos'),
            subtitle: Text('El servicio Android utiliza acelerómetro y giroscopio sin depender de que Flutter permanezca abierto.'),
          ),
          const ListTile(
            leading: Icon(Icons.timer_outlined),
            title: Text('Confirmación cada 30 segundos'),
            subtitle: Text('Si detecta movimiento inusual, repetirá la notificación hasta que confirmes que estás bien o abras SOS.'),
          ),
          const SizedBox(height: 12),
          Text(
            'Importante: el monitoreo puede detenerse si fuerzas la detención de la app, si el sistema restringe el servicio o al apagar/reiniciar el teléfono. Esta detección es experimental y no sustituye las alertas oficiales.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
