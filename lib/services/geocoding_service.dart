import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Obtiene una dirección legible a partir de coordenadas.
///
/// Usa el servicio público de Nominatim (OpenStreetMap). Es una dependencia de
/// red opcional: si falla, la app conserva las coordenadas como referencia.
abstract class DireccionGateway {
  Future<String?> obtenerDireccion(double latitud, double longitud);
}

class NominatimGeocodingService implements DireccionGateway {
  NominatimGeocodingService({
    http.Client? client,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String _userAgent =
      'AlertaSismica/1.0 (aplicacion de emergencia; configurar contacto del propietario)';

  final Map<String, String?> _cache = {};
  DateTime? _ultimaConsulta;

  @override
  Future<String?> obtenerDireccion(double latitud, double longitud) async {
    final clave =
        '${latitud.toStringAsFixed(5)},${longitud.toStringAsFixed(5)}';
    if (_cache.containsKey(clave)) return _cache[clave];

    final ahora = DateTime.now();
    final ultima = _ultimaConsulta;
    if (ultima != null) {
      final espera = const Duration(seconds: 1) - ahora.difference(ultima);
      if (!espera.isNegative) {
        await Future<void>.delayed(espera);
      }
    }
    _ultimaConsulta = DateTime.now();

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$latitud&lon=$longitud&accept-language=es',
      );
      final respuesta = await _client
          .get(
            uri,
            headers: const {'User-Agent': _userAgent, 'Accept-Language': 'es'},
          )
          .timeout(timeout);

      if (respuesta.statusCode != 200) {
        _cache[clave] = null;
        return null;
      }

      final json = jsonDecode(respuesta.body);
      if (json is Map) {
        final direccion = (json['display_name'] as String?)?.trim();
        final resultado = direccion == null || direccion.isEmpty
            ? null
            : direccion;
        _guardarEnCache(clave, resultado);
        return resultado;
      }
      _cache[clave] = null;
      return null;
    } catch (_) {
      _cache[clave] = null;
      return null;
    }
  }

  void _guardarEnCache(String clave, String? valor) {
    if (_cache.length > 50) {
      _cache.remove(_cache.keys.first);
    }
    _cache[clave] = valor;
  }
}
