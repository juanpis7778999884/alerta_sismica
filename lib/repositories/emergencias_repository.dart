import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergencia.dart';

class EmergenciasRepository {
  static const String _claveActiva = 'emergencia_activa_v1';
  static const String _claveHistorial = 'emergencias_historial_v1';
  static const int _maximoHistorial = 50;

  Future<Emergencia?> cargarActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveActiva);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return Emergencia.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      // Estado corrupto: se ignora para no bloquear la app.
    }
    return null;
  }

  Future<void> guardarActiva(Emergencia emergencia) async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = await prefs.setString(
      _claveActiva,
      jsonEncode(emergencia.toJson()),
    );
    if (!guardado) {
      throw StateError('No se pudo guardar la emergencia activa.');
    }
  }

  Future<void> eliminarActiva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveActiva);
  }

  Future<List<Emergencia>> cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveHistorial);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      final emergencias = <Emergencia>[];
      for (final item in json) {
        if (item is! Map) continue;
        try {
          emergencias.add(Emergencia.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Se conserva el resto del historial.
        }
      }
      emergencias.sort((a, b) => b.inicio.compareTo(a.inicio));
      return emergencias;
    } catch (_) {
      return const [];
    }
  }

  Future<void> guardarHistorial(List<Emergencia> emergencias) async {
    final prefs = await SharedPreferences.getInstance();
    final ordenadas = List<Emergencia>.from(emergencias)
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
    final limitadas = ordenadas.take(_maximoHistorial).toList();
    await prefs.setString(
      _claveHistorial,
      jsonEncode(limitadas.map((emergencia) => emergencia.toJson()).toList()),
    );
  }

  Future<void> finalizar(Emergencia emergencia) async {
    final historial = await cargarHistorial();
    final actualizado = [
      emergencia,
      ...historial.where((item) => item.id != emergencia.id),
    ];
    await guardarHistorial(actualizado);
    await eliminarActiva();
  }

  Future<void> limpiarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveHistorial);
  }
}
