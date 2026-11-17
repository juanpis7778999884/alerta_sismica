import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/configuracion_app.dart';

class SettingsRepository {
  static const String _claveConfiguracion = 'configuracion_app_v1';
  static const String _claveUltimaConexion = 'ultima_conexion_v1';

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
    } catch (_) {
      // Configuración corrupta: se descarta y se usan valores por defecto.
    }
    return ConfiguracionApp.inicial;
  }

  Future<void> guardarConfiguracion(ConfiguracionApp configuracion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveConfiguracion,
      jsonEncode(configuracion.toJson()),
    );
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
}
