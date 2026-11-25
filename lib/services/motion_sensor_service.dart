import 'package:sensors_plus/sensors_plus.dart';

/// Acceso centralizado a los sensores físicos del dispositivo.
class MotionSensorService {
  const MotionSensorService();

  Stream<UserAccelerometerEvent> acelerometro({
    Duration intervalo = const Duration(milliseconds: 40),
  }) {
    return userAccelerometerEventStream(samplingPeriod: intervalo);
  }

  Stream<GyroscopeEvent> giroscopio({
    Duration intervalo = const Duration(milliseconds: 40),
  }) {
    return gyroscopeEventStream(samplingPeriod: intervalo);
  }
}
