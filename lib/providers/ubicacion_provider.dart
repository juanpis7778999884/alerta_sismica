import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/location_service.dart';

class UbicacionProvider extends ChangeNotifier {
  UbicacionProvider({LocationGateway? location})
    : _location = location ?? LocationService();

  final LocationGateway _location;

  UbicacionUsuario? _ubicacion;
  DiagnosticoUbicacion _diagnostico = DiagnosticoUbicacion.inicial;
  bool _cargando = false;
  bool _inicializado = false;
  bool _actualizando = false;
  String? _error;
  StreamSubscription<UbicacionUsuario>? _suscripcion;

  UbicacionUsuario? get ubicacion => _ubicacion;
  DiagnosticoUbicacion get diagnostico => _diagnostico;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String? get error => _error;
  bool get permisoConcedido => _diagnostico.permiso.concedido;
  bool get servicioActivo => _diagnostico.servicioActivo;
  bool get tieneUbicacion => _ubicacion != null;
  bool get escuchando => _suscripcion != null;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    await refrescarDiagnostico();
    if (_diagnostico.permiso.concedido && _diagnostico.servicioActivo) {
      unawaited(actualizar(silencioso: true));
      _iniciarStream();
    }
  }

  Future<DiagnosticoUbicacion> refrescarDiagnostico() async {
    _diagnostico = await _location.diagnostico();
    notifyListeners();
    return _diagnostico;
  }

  Future<UbicacionUsuario?> actualizar({bool silencioso = false}) async {
    if (_actualizando) return _ubicacion;
    _actualizando = true;
    if (!silencioso) {
      _cargando = true;
      _error = null;
      notifyListeners();
    }
    try {
      final ubicacion = await _location.obtenerUbicacion(
        timeout: const Duration(seconds: 12),
      );
      await refrescarDiagnostico();
      if (ubicacion == null) {
        _error = _mensajeSegunDiagnostico();
        return null;
      }
      _ubicacion = ubicacion;
      _error = null;
      if (_diagnostico.permiso.concedido && _diagnostico.servicioActivo) {
        _iniciarStream();
      }
      return ubicacion;
    } catch (_) {
      _error = 'No se pudo obtener la ubicación. Revisa los permisos y el GPS.';
      return null;
    } finally {
      _actualizando = false;
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> solicitarYActualizar() => actualizar();

  Future<void> abrirAjustesApp() async {
    await _location.abrirAjustesApp();
    await refrescarDiagnostico();
  }

  Future<void> abrirAjustesUbicacion() async {
    await _location.abrirAjustesUbicacion();
    await refrescarDiagnostico();
  }

  void detener() {
    _suscripcion?.cancel();
    _suscripcion = null;
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _iniciarStream() {
    if (_suscripcion != null) return;
    final stream = _location.streamUbicacion();
    if (stream == null) return;
    _suscripcion = stream.listen(
      (ubicacion) {
        _ubicacion = ubicacion;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        // La última ubicación conocida sigue siendo válida para la interfaz.
      },
    );
  }

  String _mensajeSegunDiagnostico() {
    switch (_diagnostico.permiso) {
      case PermisoUbicacion.concedido:
        break;
      case PermisoUbicacion.denegado:
        return 'Permiso de ubicación denegado. Actívalo para compartir tu posición.';
      case PermisoUbicacion.permanentementeDenegado:
        return 'El permiso de ubicación está bloqueado. Habilítalo en los ajustes.';
      case PermisoUbicacion.restringido:
        return 'El sistema restringió la ubicación en este dispositivo.';
      case PermisoUbicacion.desconocido:
        return 'No se pudo verificar el permiso de ubicación.';
    }
    if (!_diagnostico.servicioActivo) {
      return 'El servicio de GPS está desactivado.';
    }
    return 'No se pudo obtener una ubicación precisa. Inténtalo de nuevo.';
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    super.dispose();
  }
}
