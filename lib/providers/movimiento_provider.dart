import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/motion_sensor_service.dart';

/// Mantiene las lecturas y una detección experimental de vibración.
class MovimientoProvider extends ChangeNotifier {
  MovimientoProvider({MotionSensorService? sensores})
      : _sensores = sensores ?? const MotionSensorService();

  final MotionSensorService _sensores;
  StreamSubscription<UserAccelerometerEvent>? _acelerometroSub;
  StreamSubscription<GyroscopeEvent>? _giroscopioSub;
  final List<_Muestra> _ventana = [];

  double ax = 0, ay = 0, az = 0;
  double gx = 0, gy = 0, gz = 0;
  double magnitudAceleracion = 0;
  double magnitudGiro = 0;
  double rmsVibracion = 0;

  bool _activo = false;
  bool _alertaMovimiento = false;
  String? _error;
  DateTime? _ultimoEvento;
  Timer? _temporizadorAlerta;

  bool get activo => _activo;
  bool get alertaMovimiento => _alertaMovimiento;
  String? get error => _error;
  DateTime? get ultimoEvento => _ultimoEvento;

  Future<void> iniciar() async {
    if (_activo) return;
    _activo = true;
    _error = null;
    _ventana.clear();
    notifyListeners();

    try {
      _acelerometroSub = _sensores.acelerometro().listen(
        _procesarAcelerometro,
        onError: (Object e) => _registrarError(
          'No se pudo leer el acelerómetro: $e',
        ),
        cancelOnError: false,
      );
      _giroscopioSub = _sensores.giroscopio().listen(
        _procesarGiroscopio,
        onError: (Object e) => _registrarError(
          'No se pudo leer el giroscopio: $e',
        ),
        cancelOnError: false,
      );
    } catch (e) {
      _registrarError('No se pudieron iniciar los sensores: $e');
      await detener();
    }
  }

  void _procesarAcelerometro(UserAccelerometerEvent e) {
    ax = e.x;
    ay = e.y;
    az = e.z;
    magnitudAceleracion = _magnitud(ax, ay, az);

    final ahora = DateTime.now();
    _ventana.add(_Muestra(ahora, magnitudAceleracion));
    _ventana.removeWhere(
      (m) => ahora.difference(m.instante) > const Duration(milliseconds: 1500),
    );

    if (_ventana.length >= 12) {
      final mediaCuadratica = _ventana.fold<double>(
            0,
            (suma, m) => suma + m.valor * m.valor,
          ) /
          _ventana.length;
      rmsVibracion = math.sqrt(mediaCuadratica);

      // Umbral inicial conservador, ajustable tras pruebas en el teléfono.
      if (rmsVibracion >= 1.5 &&
          (_ultimoEvento == null ||
              ahora.difference(_ultimoEvento!) >
                  const Duration(seconds: 10))) {
        _ultimoEvento = ahora;
        _alertaMovimiento = true;
        _temporizadorAlerta?.cancel();
        _temporizadorAlerta = Timer(const Duration(seconds: 5), () {
          _alertaMovimiento = false;
          notifyListeners();
        });
      }
    }
    notifyListeners();
  }

  void _procesarGiroscopio(GyroscopeEvent e) {
    gx = e.x;
    gy = e.y;
    gz = e.z;
    magnitudGiro = _magnitud(gx, gy, gz);
    notifyListeners();
  }

  double _magnitud(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);

  void _registrarError(String mensaje) {
    _error = mensaje;
    notifyListeners();
  }

  Future<void> detener() async {
    _activo = false;
    await _acelerometroSub?.cancel();
    await _giroscopioSub?.cancel();
    _acelerometroSub = null;
    _giroscopioSub = null;
    _temporizadorAlerta?.cancel();
    _temporizadorAlerta = null;
    _alertaMovimiento = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _acelerometroSub?.cancel();
    _giroscopioSub?.cancel();
    _temporizadorAlerta?.cancel();
    super.dispose();
  }
}

class _Muestra {
  const _Muestra(this.instante, this.valor);
  final DateTime instante;
  final double valor;
}
