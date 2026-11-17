import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum PermisoUbicacion {
  concedido,
  denegado,
  permanentementeDenegado,
  restringido,
  desconocido,
}

extension PermisoUbicacionX on PermisoUbicacion {
  String get etiqueta {
    switch (this) {
      case PermisoUbicacion.concedido:
        return 'Concedido';
      case PermisoUbicacion.denegado:
        return 'Denegado';
      case PermisoUbicacion.permanentementeDenegado:
        return 'Denegado permanentemente';
      case PermisoUbicacion.restringido:
        return 'Restringido por el sistema';
      case PermisoUbicacion.desconocido:
        return 'Desconocido';
    }
  }

  bool get concedido => this == PermisoUbicacion.concedido;
}

class DiagnosticoUbicacion {
  const DiagnosticoUbicacion({
    required this.permiso,
    required this.servicioActivo,
  });

  final PermisoUbicacion permiso;
  final bool servicioActivo;

  static const DiagnosticoUbicacion inicial = DiagnosticoUbicacion(
    permiso: PermisoUbicacion.desconocido,
    servicioActivo: false,
  );
}

enum FuenteUbicacion { gps, ultimaConocida }

class UbicacionUsuario {
  const UbicacionUsuario({
    required this.latitud,
    required this.longitud,
    required this.precisionMetros,
    required this.fecha,
    this.fuente = FuenteUbicacion.gps,
  });

  final double latitud;
  final double longitud;
  final double precisionMetros;
  final DateTime fecha;
  final FuenteUbicacion fuente;

  String get coordenadas =>
      '${latitud.toStringAsFixed(6)}, ${longitud.toStringAsFixed(6)}';

  String get urlMapa =>
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';
}

abstract class LocationGateway {
  Future<DiagnosticoUbicacion> diagnostico();
  Future<UbicacionUsuario?> obtenerUbicacion({
    Duration timeout = const Duration(seconds: 12),
  });
  Stream<UbicacionUsuario>? streamUbicacion();
  Future<void> abrirAjustesApp();
  Future<void> abrirAjustesUbicacion();
}

class LocationService implements LocationGateway {
  @override
  Future<DiagnosticoUbicacion> diagnostico() async {
    var servicioActivo = false;
    try {
      servicioActivo = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      servicioActivo = false;
    }

    PermisoUbicacion permiso;
    try {
      permiso = _mapearPermiso(await Geolocator.checkPermission());
    } catch (_) {
      permiso = PermisoUbicacion.desconocido;
    }

    return DiagnosticoUbicacion(
      permiso: permiso,
      servicioActivo: servicioActivo,
    );
  }

  @override
  Future<UbicacionUsuario?> obtenerUbicacion({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      var permiso = await Geolocator.checkPermission();

      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.unableToDetermine) {
        return null;
      }

      if (!servicioActivo) {
        return await _ultimaUbicacionConocida();
      }

      try {
        final posicion = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).timeout(timeout);
        return _desdePosicion(posicion, FuenteUbicacion.gps);
      } on TimeoutException {
        return await _ultimaUbicacionConocida();
      } catch (_) {
        return await _ultimaUbicacionConocida();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<UbicacionUsuario>? streamUbicacion() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map((posicion) => _desdePosicion(posicion, FuenteUbicacion.gps));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> abrirAjustesApp() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> abrirAjustesUbicacion() async {
    await Geolocator.openLocationSettings();
  }

  Future<UbicacionUsuario?> _ultimaUbicacionConocida() async {
    try {
      final posicion = await Geolocator.getLastKnownPosition();
      if (posicion == null) return null;
      return _desdePosicion(posicion, FuenteUbicacion.ultimaConocida);
    } catch (_) {
      return null;
    }
  }

  UbicacionUsuario _desdePosicion(Position posicion, FuenteUbicacion fuente) {
    return UbicacionUsuario(
      latitud: posicion.latitude,
      longitud: posicion.longitude,
      precisionMetros: posicion.accuracy,
      fecha: posicion.timestamp.toLocal(),
      fuente: fuente,
    );
  }

  PermisoUbicacion _mapearPermiso(LocationPermission permiso) {
    switch (permiso) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return PermisoUbicacion.concedido;
      case LocationPermission.denied:
        return PermisoUbicacion.denegado;
      case LocationPermission.deniedForever:
        return PermisoUbicacion.permanentementeDenegado;
      case LocationPermission.unableToDetermine:
        return PermisoUbicacion.desconocido;
    }
  }
}
