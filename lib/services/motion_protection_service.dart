import 'package:flutter/services.dart';

class MotionProtectionService {
  MotionProtectionService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.alerta_sismica/motion_protection');

  static Future<bool> iniciar() async =>
      await _channel.invokeMethod<bool>('startProtection') ?? false;

  static Future<bool> detener() async =>
      await _channel.invokeMethod<bool>('stopProtection') ?? false;

  static Future<bool> consumirAlertaAbierta() async =>
      await _channel.invokeMethod<bool>('consumePendingAlert') ?? false;

  static Future<bool> confirmarBien() async =>
      await _channel.invokeMethod<bool>('confirmMovement') ?? false;

  static Future<bool> consumirSosPendiente() async =>
      await _channel.invokeMethod<bool>('consumePendingSos') ?? false;

  static Future<bool> estaActiva() async =>
      await _channel.invokeMethod<bool>('isProtectionActive') ?? false;

  static void escucharSolicitudSos(Future<void> Function(bool sosSolicitado) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProtectionSosRequested' ||
          call.method == 'onMovementAlertOpened') {
        if (call.method == 'onProtectionSosRequested') {
          await _channel.invokeMethod<bool>('consumePendingSos');
          await callback(true);
        } else {
          await _channel.invokeMethod<bool>('consumePendingAlert');
          await callback(false);
        }
      }
    });
  }
}
