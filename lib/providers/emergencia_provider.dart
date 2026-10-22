import 'package:flutter/foundation.dart';
import '../models/estado_emergencia.dart';
import '../models/sismo.dart';

class EmergenciaProvider extends ChangeNotifier {
  EstadoEmergencia _estado = EstadoEmergencia.vacio();

  EstadoEmergencia get estado => _estado;
  bool get activa => _estado.activa;

  void activarSos(double lat, double lon) {
    _estado = _estado.copyWith(
      activa: true,
      tipo: TipoEmergencia.sos,
      inicio: DateTime.now(),
      latitud: lat,
      longitud: lon,
    );
    notifyListeners();
  }

  void activarAlertaSismo(Sismo sismo, double lat, double lon) {
    _estado = _estado.copyWith(
      activa: true,
      tipo: TipoEmergencia.sismo,
      inicio: DateTime.now(),
      latitud: lat,
      longitud: lon,
      sismo: sismo,
    );
    notifyListeners();
  }

  void activarSimulacion(double lat, double lon) {
    _estado = _estado.copyWith(
      activa: true,
      tipo: TipoEmergencia.simulacion,
      inicio: DateTime.now(),
      latitud: lat,
      longitud: lon,
    );
    notifyListeners();
  }

  void desactivar() {
    _estado = EstadoEmergencia.vacio();
    notifyListeners();
  }
}
