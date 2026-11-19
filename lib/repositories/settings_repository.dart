import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync/supabase_gateway.dart';
import '../core/sync/supabase_sync_queue.dart';
import '../models/configuracion_app.dart';

class SettingsRepository {
  SettingsRepository({
    SupabaseGateway? gateway,
    this._sync,
  }) : _gateway = gateway ?? FlutterSupabaseGateway();

  static const String _claveConfiguracion = 'configuracion_app_v1';
  static const String _claveUltimaConexion = 'ultima_conexion_v1';

  final SupabaseGateway _gateway;
  final SupabaseSyncQueue? _sync;

  Future<ConfiguracionApp> cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveConfiguracion);
    if (raw == null || raw.isEmpty) return ConfiguracionApp.inicial;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return ConfiguracionApp.fromJson(json);
      }
      if (json is Map) {
        return ConfiguracionApp.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {}
    return ConfiguracionApp.inicial;
  }

  Future<void> guardarConfiguracion(ConfiguracionApp configuracion) async {
    await _guardarLocal(configuracion);
    final userId = _gateway.currentUserId;
    final sync = _sync;
    if (userId == null || sync == null) return;

    final ahora = DateTime.now().toUtc().toIso8601String();
    final valores = _valoresRemotos(configuracion, ahora);
    await sync.enqueue(
      table: 'user_settings',
      userId: userId,
      keys: {'user_id': userId},
      insertValues: {
        'user_id': userId,
        ...valores,
      },
      updateValues: valores,
    );
    await sync.flush();
  }

  Future<ConfiguracionApp?> sincronizarDesdeRemoto() async {
    final userId = _gateway.currentUserId;
    if (userId == null) return null;
    final filas = await _gateway.selectRows(
      'user_settings',
      filters: {'user_id': userId},
    );
    if (filas.isEmpty) return null;
    final sync = _sync;
    if (sync != null) {
      final pendiente = await sync.hasPending(
        'user_settings',
        {'user_id': userId},
        userId: userId,
      );
      if (pendiente) return cargarConfiguracion();
    }
    final remota = _configuracionDesdeFila(filas.first);
    await _guardarLocal(remota);
    return remota;
  }

  Future<DateTime?> cargarUltimaConexion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveUltimaConexion);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> guardarUltimaConexion(DateTime fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveUltimaConexion,
      fecha.toUtc().toIso8601String(),
    );
  }

  Future<void> _guardarLocal(ConfiguracionApp configuracion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveConfiguracion,
      jsonEncode(configuracion.toJson()),
    );
  }

  Map<String, dynamic> _valoresRemotos(
    ConfiguracionApp configuracion,
    String ahora,
  ) {
    return {
      'tema': configuracion.tema.name,
      'magnitud_minima': configuracion.magnitudMinima,
      'auto_refresco': configuracion.autoRefresco,
      'notificar_sismos': configuracion.notificarSismos,
      'umbral_notificacion': configuracion.umbralNotificacion,
      'numero_emergencia': configuracion.numeroEmergencia,
      'cliente_actualizado_en': ahora,
    };
  }

  ConfiguracionApp _configuracionDesdeFila(Map<String, dynamic> fila) {
    return ConfiguracionApp(
      tema: TemaApp.values.firstWhere(
        (valor) => valor.name == fila['tema'],
        orElse: () => TemaApp.claro,
      ),
      magnitudMinima: (fila['magnitud_minima'] as num?)?.toDouble() ?? 2.5,
      autoRefresco: fila['auto_refresco'] as bool? ?? true,
      notificarSismos: fila['notificar_sismos'] as bool? ?? false,
      umbralNotificacion:
          (fila['umbral_notificacion'] as num?)?.toDouble() ?? 4.5,
      numeroEmergencia: fila['numero_emergencia'] as String? ?? '',
    );
  }
}
