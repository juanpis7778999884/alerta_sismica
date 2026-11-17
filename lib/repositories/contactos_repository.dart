import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/contacto.dart';

class ContactosRepository {
  ContactosRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const String _claveContactos = 'contactos_v2';
  static const String _claveLegacy = 'contactos_emergencia';
  static const String _claveMigracion = 'contactos_migracion_v2';

  final Uuid _uuid;

  Future<List<Contacto>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveContactos);
    if (raw != null) {
      return _decodificarLista(raw);
    }

    final legacy = prefs.getStringList(_claveLegacy);
    if (legacy == null || legacy.isEmpty) return const [];
    if (prefs.getBool(_claveMigracion) == true) return const [];

    final migrados = <Contacto>[];
    for (final item in legacy) {
      try {
        final json = jsonDecode(item);
        if (json is! Map) continue;
        final map = Map<String, dynamic>.from(json);
        final nombre = (map['nombre'] as String?)?.trim() ?? '';
        final telefono = (map['telefono'] as String?)?.trim() ?? '';
        if (nombre.isEmpty || telefono.isEmpty) continue;
        if (migrados.any((contacto) => contacto.telefono == telefono)) {
          continue;
        }
        migrados.add(
          Contacto(
            id: _uuid.v4(),
            nombre: nombre,
            telefono: telefono,
            creadoEn: DateTime.now(),
          ),
        );
      } catch (_) {
        // Un registro legado inválido no debe impedir la migración del resto.
      }
    }

    if (migrados.isNotEmpty) {
      await guardar(migrados);
    }
    await prefs.setBool(_claveMigracion, true);
    await prefs.remove(_claveLegacy);
    return migrados;
  }

  Future<void> guardar(List<Contacto> contactos) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      contactos.map((contacto) => contacto.toJson()).toList(),
    );
    final guardado = await prefs.setString(_claveContactos, raw);
    if (!guardado) {
      throw StateError('No se pudieron guardar los contactos.');
    }
  }

  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveContactos);
  }

  List<Contacto> _decodificarLista(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      final contactos = <Contacto>[];
      for (final item in json) {
        if (item is! Map) continue;
        try {
          contactos.add(Contacto.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Se conserva el resto de contactos aunque uno esté corrupto.
        }
      }
      return contactos;
    } catch (_) {
      return const [];
    }
  }
}
