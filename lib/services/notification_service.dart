import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/utils/date_formatters.dart';
import '../models/emergencia.dart';
import '../models/sismo.dart';

abstract class NotificationGateway {
  Future<void> inicializar();
  Future<bool> permisoConcedido();
  Future<bool> solicitarPermiso();
  Future<void> mostrarPrueba();
  Future<void> mostrarSismosNuevos(List<Sismo> sismos);
  Future<void> mostrarEmergenciaActiva(Emergencia emergencia);
  Future<void> abrirAjustesNotificaciones();
}

class NotificationService implements NotificationGateway {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _inicializado = false;

  static const AndroidNotificationDetails _detalleSismo =
      AndroidNotificationDetails(
        'alerta_sismica_sismos',
        'Sismos registrados',
        channelDescription: 'Avisos locales cuando se detectan nuevos eventos sísmicos de magnitud relevante.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      );

  static const AndroidNotificationDetails _detalleEmergencia =
      AndroidNotificationDetails(
        'alerta_sismica_emergencia',
        'Emergencias SOS',
        channelDescription:
            'Estado de una emergencia SOS activada por el usuario.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        enableVibration: true,
        playSound: true,
      );

  @override
  Future<void> inicializar() async {
    if (_inicializado) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(android: android, iOS: darwin);
      await _plugin.initialize(settings: settings);
      _inicializado = true;
    } catch (_) {
      _inicializado = false;
    }
  }

  @override
  Future<bool> permisoConcedido() async {
    try {
      final estado = await Permission.notification.status;
      return estado.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> solicitarPermiso() async {
    try {
      final estado = await Permission.notification.request();
      return estado.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> abrirAjustesNotificaciones() async {
    try {
      await openAppSettings();
    } catch (_) {
      // El usuario puede abrir los ajustes manualmente.
    }
  }

  @override
  Future<void> mostrarPrueba() async {
    await _mostrar(
      id: 1001,
      titulo: 'Notificaciones activas',
      cuerpo: 'Alerta Sísmica puede mostrar avisos locales. Los avisos remotos requieren configurar Firebase Cloud Messaging.',
      android: _detalleSismo,
    );
  }

  @override
  Future<void> mostrarSismosNuevos(List<Sismo> sismos) async {
    if (sismos.isEmpty) return;
    final relevantes = sismos.take(3).toList();
    for (final sismo in relevantes) {
      await _mostrar(
        id: 2000 + (sismo.id.hashCode & 0x3fffffff),
        titulo: 'Sismo M${sismo.magnitudFormateada} · ${sismo.magnitudTexto}',
        cuerpo:
            '${sismo.lugar} · Profundidad ${sismo.profundidadTexto} · ${DateFormatters.hora(sismo.tiempo)}',
        android: _detalleSismo,
        payload: sismo.id,
      );
    }
  }

  Future<void> mostrarAlertaMovimiento() async {
    await _mostrar(
      id: 4001,
      titulo: '¿Estás bien?',
      cuerpo: 'Alerta Sísmica detectó movimiento inusual. Abre la app y confirma tu estado.',
      android: _detalleEmergencia,
      payload: 'confirmacion_movimiento',
    );
  }

  Future<void> cancelarAlertaMovimiento() async {
    if (!_inicializado) return;
    try {
      await _plugin.cancel(id: 4001);
    } catch (_) {
      // La cancelación de la notificación no debe bloquear el flujo.
    }
  }

  @override
  Future<void> mostrarEmergenciaActiva(Emergencia emergencia) async {
    await _mostrar(
      id: 3001,
      titulo: 'Emergencia SOS activa',
      cuerpo: 'La alerta fue guardada en el dispositivo. Abre la app para enviarla a tus contactos.',
      android: _detalleEmergencia,
      payload: emergencia.id,
    );
  }

  Future<void> _mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
    required AndroidNotificationDetails android,
    String? payload,
  }) async {
    if (!_inicializado) return;
    try {
      await _plugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (_) {
      // Nunca se interrumpe una emergencia por un fallo de notificación.
    }
  }
}
