import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum TipoRed { ninguna, wifi, movil, ethernet, vpn, bluetooth, satelite, otra }

extension TipoRedX on TipoRed {
  String get etiqueta {
    switch (this) {
      case TipoRed.ninguna:
        return 'Sin red';
      case TipoRed.wifi:
        return 'Wi-Fi';
      case TipoRed.movil:
        return 'Datos móviles';
      case TipoRed.ethernet:
        return 'Ethernet';
      case TipoRed.vpn:
        return 'VPN';
      case TipoRed.bluetooth:
        return 'Bluetooth';
      case TipoRed.satelite:
        return 'Red satelital (reportada por el sistema)';
      case TipoRed.otra:
        return 'Otra red';
    }
  }
}

class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    required this.tipoRed,
    required this.internetReal,
    required this.servicioUsgs,
    required this.redSatelitalDetectada,
    required this.verificadoEn,
  });

  final TipoRed tipoRed;
  final bool internetReal;
  final bool servicioUsgs;
  final bool redSatelitalDetectada;
  final DateTime verificadoEn;

  bool get hayInterfaz => tipoRed != TipoRed.ninguna;

  static ConnectivitySnapshot inicial() => ConnectivitySnapshot(
    tipoRed: TipoRed.ninguna,
    internetReal: false,
    servicioUsgs: false,
    redSatelitalDetectada: false,
    verificadoEn: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

abstract class ConnectivityGateway {
  Future<ConnectivitySnapshot> verificar();
  Stream<TipoRed> get cambios;
}

class ConnectivityService implements ConnectivityGateway {
  ConnectivityService({
    Connectivity? connectivity,
    http.Client? client,
    this.timeoutInternet = const Duration(seconds: 5),
    this.timeoutUsgs = const Duration(seconds: 7),
  }) : _connectivity = connectivity ?? Connectivity(),
       _client = client ?? http.Client();

  final Connectivity _connectivity;
  final http.Client _client;
  final Duration timeoutInternet;
  final Duration timeoutUsgs;

  static const String _urlInternet = 'https://www.gstatic.com/generate_204';
  static const String _urlUsgs =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson';

  @override
  Stream<TipoRed> get cambios {
    return _connectivity.onConnectivityChanged.map(_mapear).distinct();
  }

  @override
  Future<ConnectivitySnapshot> verificar() async {
    List<ConnectivityResult> resultados;
    try {
      resultados = await _connectivity.checkConnectivity();
    } catch (_) {
      resultados = const [ConnectivityResult.none];
    }

    final tipo = _mapear(resultados);
    final satelite = resultados.contains(ConnectivityResult.satellite);
    if (tipo == TipoRed.ninguna) {
      return ConnectivitySnapshot(
        tipoRed: tipo,
        internetReal: false,
        servicioUsgs: false,
        redSatelitalDetectada: satelite,
        verificadoEn: DateTime.now(),
      );
    }

    final verificaciones = await Future.wait([
      _comprobarInternet(),
      _comprobarUsgs(),
    ]);

    return ConnectivitySnapshot(
      tipoRed: tipo,
      internetReal: verificaciones[0],
      servicioUsgs: verificaciones[1],
      redSatelitalDetectada: satelite,
      verificadoEn: DateTime.now(),
    );
  }

  Future<bool> _comprobarInternet() async {
    try {
      final respuesta = await _client
          .get(
            Uri.parse(_urlInternet),
            headers: const {'User-Agent': 'AlertaSismica/1.0'},
          )
          .timeout(timeoutInternet);
      return respuesta.statusCode == 204 || respuesta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _comprobarUsgs() async {
    try {
      final respuesta = await _client
          .get(
            Uri.parse(_urlUsgs),
            headers: const {'User-Agent': 'AlertaSismica/1.0'},
          )
          .timeout(timeoutUsgs);
      return respuesta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  TipoRed _mapear(List<ConnectivityResult> resultados) {
    if (resultados.isEmpty || resultados.contains(ConnectivityResult.none)) {
      return TipoRed.ninguna;
    }
    if (resultados.contains(ConnectivityResult.wifi)) return TipoRed.wifi;
    if (resultados.contains(ConnectivityResult.mobile)) return TipoRed.movil;
    if (resultados.contains(ConnectivityResult.ethernet)) {
      return TipoRed.ethernet;
    }
    if (resultados.contains(ConnectivityResult.satellite)) {
      return TipoRed.satelite;
    }
    if (resultados.contains(ConnectivityResult.vpn)) return TipoRed.vpn;
    if (resultados.contains(ConnectivityResult.bluetooth)) {
      return TipoRed.bluetooth;
    }
    return TipoRed.otra;
  }
}
