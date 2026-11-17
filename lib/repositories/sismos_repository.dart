import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../models/sismo.dart';

enum OrigenSismos { red, cache }

class SismosCache {
  const SismosCache({required this.eventos, required this.guardadoEn});

  final List<Sismo> eventos;
  final DateTime guardadoEn;
}

class ResultadoSismos {
  const ResultadoSismos({
    required this.eventos,
    required this.actualizadoEn,
    required this.origen,
    this.advertencia,
    this.descartados = 0,
  });

  final List<Sismo> eventos;
  final DateTime actualizadoEn;
  final OrigenSismos origen;
  final String? advertencia;
  final int descartados;

  bool get desdeCache => origen == OrigenSismos.cache;
}

class SismosRepository {
  SismosRepository({
    http.Client? client,
    String? url,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _url = url ?? urlUsgs;

  static const String urlUsgs =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';
  static const String _claveCache = 'sismos_cache_v1';
  static const String _userAgent =
      'AlertaSismica/1.0 (monitoreo de eventos USGS; uso personal)';

  final http.Client _client;
  final String _url;
  final Duration timeout;

  Future<ResultadoSismos> obtener() async {
    try {
      final respuesta = await _client
          .get(Uri.parse(_url), headers: const {'User-Agent': _userAgent})
          .timeout(timeout);

      if (respuesta.statusCode != 200) {
        throw NetworkException(
          'El servicio sísmico respondió con código ${respuesta.statusCode}.',
          codigo: 'usgs_http',
        );
      }

      final (eventos, descartados) = _parsearRespuesta(respuesta.body);
      final ahora = DateTime.now();
      await guardarCache(eventos, ahora);
      return ResultadoSismos(
        eventos: eventos,
        actualizadoEn: ahora,
        origen: OrigenSismos.red,
        descartados: descartados,
      );
    } catch (error) {
      final cache = await leerCache();
      if (cache != null) {
        return ResultadoSismos(
          eventos: cache.eventos,
          actualizadoEn: cache.guardadoEn,
          origen: OrigenSismos.cache,
          advertencia:
              'Sin conexión con USGS. Se muestran los últimos datos guardados.',
        );
      }
      if (error is NetworkException) rethrow;
      throw NetworkException(
        'No se pudieron consultar los sismos. Verifica tu conexión a Internet.',
        codigo: 'usgs_sin_datos',
      );
    }
  }

  Future<SismosCache?> leerCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveCache);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final guardadoEn = DateTime.tryParse(json['guardadoEn'] as String? ?? '');
      final lista = json['eventos'];
      if (guardadoEn == null || lista is! List) return null;
      final eventos = <Sismo>[];
      for (final item in lista) {
        if (item is! Map) continue;
        try {
          eventos.add(Sismo.fromCacheJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Evento cacheado corrupto: se descarta.
        }
      }
      if (eventos.isEmpty) return null;
      eventos.sort((a, b) => b.tiempo.compareTo(a.tiempo));
      return SismosCache(eventos: eventos, guardadoEn: guardadoEn.toLocal());
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarCache(List<Sismo> eventos, DateTime guardadoEn) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'guardadoEn': guardadoEn.toUtc().toIso8601String(),
      'eventos': eventos
          .where((evento) => !evento.esSimulacion)
          .map((evento) => evento.toCacheJson())
          .toList(),
    };
    await prefs.setString(_claveCache, jsonEncode(payload));
  }

  Future<void> limpiarCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveCache);
  }

  (List<Sismo>, int) _parsearRespuesta(String body) {
    final data = jsonDecode(body);
    if (data is! Map) {
      throw const NetworkException(
        'La respuesta del servicio sísmico no tiene el formato esperado.',
        codigo: 'usgs_formato',
      );
    }
    final features = data['features'];
    if (features is! List) {
      throw const NetworkException(
        'La respuesta del servicio sísmico no contiene eventos.',
        codigo: 'usgs_formato',
      );
    }

    final porId = <String, Sismo>{};
    var descartados = 0;
    for (final feature in features) {
      if (feature is! Map) {
        descartados++;
        continue;
      }
      try {
        final sismo = Sismo.fromJson(Map<String, dynamic>.from(feature));
        porId[sismo.id] = sismo;
      } catch (_) {
        descartados++;
      }
    }

    if (porId.isEmpty) {
      throw const NetworkException(
        'El servicio sísmico no devolvió eventos válidos.',
        codigo: 'usgs_vacio',
      );
    }

    final eventos = porId.values.toList()
      ..sort((a, b) => b.tiempo.compareTo(a.tiempo));
    return (eventos, descartados);
  }
}
