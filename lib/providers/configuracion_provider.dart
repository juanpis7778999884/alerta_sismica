import 'package:flutter/foundation.dart';

import '../models/configuracion_app.dart';
import '../repositories/settings_repository.dart';

class ConfiguracionProvider extends ChangeNotifier {
  ConfiguracionProvider({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository();

  final SettingsRepository _repository;

  ConfiguracionApp _configuracion = ConfiguracionApp.inicial;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  ConfiguracionApp get configuracion => _configuracion;
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  TemaApp get tema => _configuracion.tema;
  double get magnitudMinima => _configuracion.magnitudMinima;
  bool get autoRefresco => _configuracion.autoRefresco;
  bool get notificarSismos => _configuracion.notificarSismos;
  double get umbralNotificacion => _configuracion.umbralNotificacion;
  String get numeroEmergencia => _configuracion.numeroEmergencia;

  Future<void> inicializar() async {
    _cargando = true;
    notifyListeners();
    try {
      _configuracion = await _repository.cargarConfiguracion();
      _error = null;
    } catch (_) {
      _configuracion = ConfiguracionApp.inicial;
      _error = 'No se pudo cargar la configuración. Se usan valores seguros.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cambiarTema(TemaApp tema) =>
      _actualizar(_configuracion.copyWith(tema: tema));

  Future<void> cambiarMagnitudMinima(double valor) => _actualizar(
    _configuracion.copyWith(magnitudMinima: valor.clamp(1.0, 7.0)),
  );

  Future<void> cambiarAutoRefresco(bool valor) =>
      _actualizar(_configuracion.copyWith(autoRefresco: valor));

  Future<void> cambiarNotificarSismos(bool valor) =>
      _actualizar(_configuracion.copyWith(notificarSismos: valor));

  Future<void> cambiarUmbralNotificacion(double valor) => _actualizar(
    _configuracion.copyWith(umbralNotificacion: valor.clamp(2.5, 7.0)),
  );

  Future<void> cambiarNumeroEmergencia(String numero) =>
      _actualizar(_configuracion.copyWith(numeroEmergencia: numero.trim()));

  Future<void> restablecer() => _actualizar(ConfiguracionApp.inicial);

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _actualizar(ConfiguracionApp nueva) async {
    final anterior = _configuracion;
    _configuracion = nueva;
    _error = null;
    _guardando = true;
    notifyListeners();
    try {
      await _repository.guardarConfiguracion(nueva);
    } catch (_) {
      _configuracion = anterior;
      _error = 'No se pudo guardar la configuración. Se conservaron los valores anteriores.';
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}
