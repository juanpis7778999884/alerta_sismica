import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/sync/supabase_gateway.dart';
import '../core/sync/supabase_sync_queue.dart';
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

class SismoGuardado {
  const SismoGuardado({
    required this.guardadoId,
    required this.sismo,
    required this.guardadoEn,
    this.eliminadoEn,
  });

  final String guardadoId;
  final Sismo sismo;
  final DateTime guardadoEn;
  final DateTime? eliminadoEn;

  factory SismoGuardado.fromJson(Map<String, dynamic> json) {
    return SismoGuardado(
      guardadoId: json['guardadoId'] as String,
      sismo: Sismo.fromCacheJson(
        Map<String, dynamic>.from(json['sismo'] as Map),
      ),
      guardadoEn: DateTime.parse(json['guardadoEn'] as String),
      eliminadoEn: json['eliminadoEn'] == null
          ? null
          : DateTime.parse(json['eliminadoEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'guardadoId': guardadoId,
    'sismo': sismo.toCacheJson(),
    'guardadoEn': guardadoEn.toUtc().toIso8601String(),
    'eliminadoEn': eliminadoEn?.toUtc().toIso8601String(),
  };

  SismoGuardado copyWith({DateTime? eliminadoEn}) {
    return SismoGuardado(
      guardadoId: guardadoId,
      sismo: sismo,
      guardadoEn: guardadoEn,
      eliminadoEn: eliminadoEn ?? this.eliminadoEn,
    );
  }
}

class SismosRepository {
  SismosRepository({
    http.Client? client,
    String? url,
    this.timeout = const Duration(seconds: 12),
    Uuid? uuid,
    SupabaseGateway? gateway,
    this._sync,
  }) : _client = client ?? http.Client(),
       _url = url ?? urlUsgs,
       _uuid = uuid ?? const Uuid(),
       _gateway = gateway ?? FlutterSupabaseGateway();

  static const String urlUsgs =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';
  static const String _claveCache = 'sismos_cache_v1';
  static const String _claveGuardados = 'sismos_guardados_v1';
  static const String _userAgent =
      'AlertaSismica/1.0 (monitoreo de eventos USGS; uso personal)';

  final http.Client _client;
  final String _url;
  final Duration timeout;
  final Uuid _uuid;
  final SupabaseGateway _gateway;
  final SupabaseSyncQueue? _sync;

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

  Future<List<SismoGuardado>> cargarGuardados({
    bool incluirEliminados = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveGuardados);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      final registros = <SismoGuardado>[];
      for (final item in json) {
        if (item is! Map) continue;
        try {
          registros.add(
            SismoGuardado.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {}
      }
      registros.sort((a, b) => b.guardadoEn.compareTo(a.guardadoEn));
      if (incluirEliminados) return registros;
      return registros.where((registro) => registro.eliminadoEn == null).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SismoGuardado> guardarSismo(Sismo sismo) async {
    final registros = await cargarGuardados(incluirEliminados: true);
    for (final registro in registros) {
      if (registro.sismo.id == sismo.id && registro.eliminadoEn == null) {
        return registro;
      }
    }

    final registro = SismoGuardado(
      guardadoId: _uuid.v4(),
      sismo: sismo,
      guardadoEn: DateTime.now(),
    );
    final actualizados = <SismoGuardado>[
      registro,
      ...registros.where(
        (item) => item.sismo.id != sismo.id || item.eliminadoEn != null,
      ),
    ];
    await _escribirGuardados(actualizados);
    await _sincronizarGuardado(registro);
    return registro;
  }

  Future<void> quitarSismo(String sismoId) async {
    final registros = await cargarGuardados(incluirEliminados: true);
    final indice = registros.indexWhere(
      (registro) =>
          registro.sismo.id == sismoId && registro.eliminadoEn == null,
    );
    if (indice == -1) return;
    final eliminado = registros[indice].copyWith(eliminadoEn: DateTime.now());
    registros[indice] = eliminado;
    await _escribirGuardados(registros);
    await _sincronizarGuardado(eliminado);
  }

  Future<List<SismoGuardado>> sincronizarGuardadosDesdeRemoto() async {
    final userId = _gateway.currentUserId;
    if (userId == null) return cargarGuardados();

    final filas = await _gateway.selectRows(
      'saved_earthquakes',
      filters: {'user_id': userId},
    );
    final sync = _sync;
    final locales = await cargarGuardados(incluirEliminados: true);
    final porId = <String, SismoGuardado>{
      for (final registro in locales) registro.guardadoId: registro,
    };
    final resultado = <SismoGuardado>[];

    for (final fila in filas) {
      if (fila['eliminado_en'] != null) continue;
      final guardadoId = fila['guardado_id'] as String?;
      if (guardadoId == null || guardadoId.isEmpty) continue;
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'saved_earthquakes',
              {'guardado_id': guardadoId},
              userId: userId,
            );
      if (pendiente && porId.containsKey(guardadoId)) {
        resultado.add(porId[guardadoId]!);
        continue;
      }
      resultado.add(_guardadoDesdeFila(fila));
    }

    final remotos = resultado.map((registro) => registro.guardadoId).toSet();
    for (final local in locales) {
      if (local.eliminadoEn != null || remotos.contains(local.guardadoId)) {
        continue;
      }
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'saved_earthquakes',
              {'guardado_id': local.guardadoId},
              userId: userId,
            );
      if (pendiente) resultado.add(local);
    }

    await _escribirGuardados(resultado);
    return resultado;
  }

  Future<void> _sincronizarGuardado(SismoGuardado registro) async {
    final sync = _sync;
    if (sync == null) return;
    final userId = _gateway.currentUserId;
    if (userId == null) return;
    final ahora = DateTime.now().toUtc().toIso8601String();
    final eliminadoEn = registro.eliminadoEn?.toUtc().toIso8601String();
    final valores = {
      'user_id': userId,
      'sismo_id': registro.sismo.id,
      'magnitud': registro.sismo.magnitud,
      'lugar': registro.sismo.lugar,
      'latitud': registro.sismo.latitud,
      'longitud': registro.sismo.longitud,
      'profundidad': registro.sismo.profundidad,
      'tiempo': registro.sismo.tiempo.toUtc().toIso8601String(),
      'url': registro.sismo.url,
      'es_simulacion': registro.sismo.esSimulacion,
      'actualizado_evento_en':
          registro.sismo.actualizadoEn?.toUtc().toIso8601String(),
      'guardado_en': registro.guardadoEn.toUtc().toIso8601String(),
      'eliminado_en': eliminadoEn,
      'cliente_actualizado_en': ahora,
    };

    await sync.enqueue(
      table: 'saved_earthquakes',
      userId: userId,
      keys: {'guardado_id': registro.guardadoId},
      insertValues: {
        'guardado_id': registro.guardadoId,
        ...valores,
      },
      updateValues: eliminadoEn == null
          ? {
              'eliminado_en': null,
              'cliente_actualizado_en': ahora,
            }
          : {
              'eliminado_en': eliminadoEn,
              'cliente_actualizado_en': ahora,
            },
    );
    await sync.flush();
  }

  Future<void> _escribirGuardados(List<SismoGuardado> registros) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveGuardados,
      jsonEncode(registros.map((registro) => registro.toJson()).toList()),
    );
  }

  SismoGuardado _guardadoDesdeFila(Map<String, dynamic> fila) {
    final sismo = Sismo(
      id: fila['sismo_id'] as String,
      magnitud: (fila['magnitud'] as num?)?.toDouble() ?? 0,
      lugar: fila['lugar'] as String? ?? 'Ubicación no especificada',
      latitud: (fila['latitud'] as num?)?.toDouble() ?? 0,
      longitud: (fila['longitud'] as num?)?.toDouble() ?? 0,
      profundidad: (fila['profundidad'] as num?)?.toDouble() ?? 0,
      tiempo: DateTime.tryParse(fila['tiempo'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      url: fila['url'] as String? ?? '',
      esSimulacion: fila['es_simulacion'] as bool? ?? false,
      actualizadoEn: fila['actualizado_evento_en'] == null
          ? null
          : DateTime.tryParse(fila['actualizado_evento_en'] as String)
              ?.toLocal(),
    );
    return SismoGuardado(
      guardadoId: fila['guardado_id'] as String,
      sismo: sismo,
      guardadoEn: DateTime.tryParse(fila['guardado_en'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      eliminadoEn: fila['eliminado_en'] == null
          ? null
          : DateTime.tryParse(fila['eliminado_en'] as String)?.toLocal(),
    );
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
