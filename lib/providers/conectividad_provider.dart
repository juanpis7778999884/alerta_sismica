import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/settings_repository.dart';
import '../services/connectivity_service.dart';
import '../services/emergency_channels.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class ConectividadProvider extends ChangeNotifier {
  ConectividadProvider({
    ConnectivityGateway? connectivity,
    LocationGateway? location,
    NotificationGateway? notificaciones,
    EmergencyChannelGateway? canales,
    SettingsRepository? settings,
  }) : _connectivity = connectivity ?? ConnectivityService(),
       _location = location ?? LocationService(),
       _notificaciones = notificaciones ?? NotificationService(),
       _canales = canales ?? EmergencyChannelService(),
       _settings = settings ?? SettingsRepository();

  final ConnectivityGateway _connectivity;
  final LocationGateway _location;
  final NotificationGateway _notificaciones;
  final EmergencyChannelGateway _canales;
  final SettingsRepository _settings;

  ConnectivitySnapshot _snapshot = ConnectivitySnapshot.inicial();
  DiagnosticoUbicacion _diagnosticoUbicacion = DiagnosticoUbicacion.inicial;
  DateTime? _ultimaConexion;
  bool? _notificacionesHabilitadas;
  bool? _puedeSms;
  bool? _puedeWhatsApp;
  bool? _puedeLlamada;
  bool _verificando = false;
  bool _inicializado = false;
  String? _error;
  StreamSubscription<TipoRed>? _suscripcion;
  Future<void>? _verificacionEnCurso;

  ConnectivitySnapshot get snapshot => _snapshot;
  DiagnosticoUbicacion get diagnosticoUbicacion => _diagnosticoUbicacion;
  DateTime? get ultimaConexion => _ultimaConexion;
  bool? get notificacionesHabilitadas => _notificacionesHabilitadas;
  bool? get puedeAbrirSms => _puedeSms;
  bool? get puedeAbrirWhatsApp => _puedeWhatsApp;
  bool? get puedeAbrirLlamada => _puedeLlamada;
  bool get verificando => _verificando;
  String? get error => _error;

  bool get hayInterfaz => _snapshot.hayInterfaz;
  bool get internetReal => _snapshot.internetReal;
  bool get servicioSismos => _snapshot.servicioUsgs;
  bool get redSatelital => _snapshot.redSatelitalDetectada;
  DateTime get verificadoEn => _snapshot.verificadoEn;

  String get etiquetaRed {
    if (internetReal) return 'En línea · ${_snapshot.tipoRed.etiqueta}';
    if (hayInterfaz) return '${_snapshot.tipoRed.etiqueta} sin Internet';
    return 'Sin conexión';
  }

  String get resumen {
    if (!hayInterfaz) {
      return 'El dispositivo no reporta una red disponible. La app funciona con datos guardados.';
    }
    if (!internetReal) {
      return 'Hay una interfaz de red, pero no se pudo confirmar acceso a Internet.';
    }
    if (!servicioSismos) {
      return 'Internet disponible, pero el servicio sísmico no respondió. Se usará la caché.';
    }
    return 'Internet y servicio sísmico disponibles.';
  }

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    _ultimaConexion = await _settings.cargarUltimaConexion();
    await refrescar();
    _suscripcion = _connectivity.cambios.listen((_) {
      unawaited(refrescar());
    });
  }

  Future<void> refrescar() {
    final enCurso = _verificacionEnCurso;
    if (enCurso != null) return enCurso;
    final futuro = _refrescarInterno();
    _verificacionEnCurso = futuro.whenComplete(() {
      _verificacionEnCurso = null;
    });
    return _verificacionEnCurso!;
  }

  Future<void> _refrescarInterno() async {
    _verificando = true;
    _error = null;
    notifyListeners();
    try {
      final futuroSnapshot = _snapshotSeguro();
      final futuroDiagnostico = _diagnosticoSeguro();
      final futuroNotificaciones = _notificacionesSeguro();
      final futuroSms = _booleanoSeguro(_canales.puedeAbrirSms);
      final futuroWhatsApp = _booleanoSeguro(_canales.puedeAbrirWhatsApp);
      final futuroLlamada = _booleanoSeguro(_canales.puedeAbrirLlamada);

      final snapshot = await futuroSnapshot;
      final diagnostico = await futuroDiagnostico;
      final notificaciones = await futuroNotificaciones;
      final sms = await futuroSms;
      final whatsapp = await futuroWhatsApp;
      final llamada = await futuroLlamada;

      if (snapshot != null) {
        _snapshot = snapshot;
        if (snapshot.internetReal) {
          _ultimaConexion = snapshot.verificadoEn;
          try {
            await _settings.guardarUltimaConexion(snapshot.verificadoEn);
          } catch (_) {
            // La fecha es informativa; no se interrumpe el diagnóstico.
          }
        }
      }
      if (diagnostico != null) _diagnosticoUbicacion = diagnostico;
      _notificacionesHabilitadas = notificaciones;
      _puedeSms = sms;
      _puedeWhatsApp = whatsapp;
      _puedeLlamada = llamada;
      if (snapshot == null) {
        _error = 'No se pudo verificar la conectividad en este momento.';
      }
    } catch (_) {
      _error = 'No se pudo completar la verificación de conectividad.';
    } finally {
      _verificando = false;
      notifyListeners();
    }
  }

  Future<bool> solicitarPermisoNotificaciones() async {
    try {
      final concedido = await _notificaciones.solicitarPermiso();
      _notificacionesHabilitadas = concedido;
      if (!concedido) {
        _error = 'El permiso de notificaciones no fue concedido. Puedes habilitarlo en los ajustes.';
      }
      notifyListeners();
      return concedido;
    } catch (_) {
      _error = 'No se pudo solicitar el permiso de notificaciones.';
      notifyListeners();
      return false;
    }
  }

  Future<void> abrirAjustesNotificaciones() async {
    await _notificaciones.abrirAjustesNotificaciones();
  }

  Future<void> mostrarNotificacionPrueba() async {
    try {
      await _notificaciones.mostrarPrueba();
    } catch (_) {
      _error = 'No se pudo mostrar la notificación de prueba.';
      notifyListeners();
    }
  }

  Future<void> abrirAjustesUbicacion() async {
    await _location.abrirAjustesApp();
    await refrescar();
  }

  Future<void> actualizarDiagnosticoUbicacion() async {
    final diagnostico = await _diagnosticoSeguro();
    if (diagnostico != null) {
      _diagnosticoUbicacion = diagnostico;
      notifyListeners();
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<ConnectivitySnapshot?> _snapshotSeguro() async {
    try {
      return await _connectivity.verificar();
    } catch (_) {
      return null;
    }
  }

  Future<DiagnosticoUbicacion?> _diagnosticoSeguro() async {
    try {
      return await _location.diagnostico();
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _notificacionesSeguro() async {
    try {
      return await _notificaciones.permisoConcedido();
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _booleanoSeguro(Future<bool> Function() consulta) async {
    try {
      return await consulta();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    super.dispose();
  }
}
