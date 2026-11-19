import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/sync/supabase_gateway.dart';
import '../core/sync/supabase_sync_queue.dart';
import '../models/contacto.dart';

class ContactosRepository {
  ContactosRepository({
    Uuid? uuid,
    SupabaseGateway? gateway,
    this._sync,
  }) : _uuid = uuid ?? const Uuid(),
       _gateway = gateway ?? FlutterSupabaseGateway();

  static const String _claveContactos = 'contactos_v2';
  static const String _claveLegacy = 'contactos_emergencia';
  static const String _claveMigracion = 'contactos_migracion_v2';

  final Uuid _uuid;
  final SupabaseGateway _gateway;
  final SupabaseSyncQueue? _sync;

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
      } catch (_) {}
    }

    if (migrados.isNotEmpty) {
      await guardar(migrados);
    }
    await prefs.setBool(_claveMigracion, true);
    await prefs.remove(_claveLegacy);
    return migrados;
  }

  Future<void> guardar(List<Contacto> contactos) async {
    final anteriores = await _leerContactos();
    await _escribirContactos(contactos);
    await _sincronizarCambios(anteriores, contactos);
  }

  Future<void> limpiar() async {
    final anteriores = await _leerContactos();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveContactos);
    await _eliminarRemotos(anteriores);
  }

  Future<List<Contacto>> sincronizarDesdeRemoto() async {
    final userId = _gateway.currentUserId;
    if (userId == null) return _leerContactos();

    final filas = await _gateway.selectRows(
      'emergency_contacts',
      filters: {'user_id': userId},
    );
    final locales = await _leerContactos();
    final sync = _sync;
    final porId = <String, Contacto>{
      for (final contacto in locales) contacto.id: contacto,
    };
    final resultado = <Contacto>[];

    for (final fila in filas) {
      if (fila['eliminado_en'] != null) continue;
      final id = fila['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'emergency_contacts',
              {'id': id},
              userId: userId,
            );
      if (pendiente) {
        final local = porId[id];
        if (local != null) resultado.add(local);
        continue;
      }
      resultado.add(_contactoDesdeFila(fila));
    }

    final remotos = resultado.map((contacto) => contacto.id).toSet();
    for (final local in locales) {
      if (remotos.contains(local.id)) continue;
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'emergency_contacts',
              {'id': local.id},
              userId: userId,
            );
      if (pendiente) resultado.add(local);
    }

    await _escribirContactos(resultado);
    return resultado;
  }

  Future<void> _sincronizarCambios(
    List<Contacto> anteriores,
    List<Contacto> actuales,
  ) async {
    final sync = _sync;
    if (sync == null) return;
    final userId = _gateway.currentUserId;
    if (userId == null) return;

    final ahora = DateTime.now().toUtc().toIso8601String();
    final actualesIds = actuales.map((contacto) => contacto.id).toSet();
    final eliminados = anteriores
        .where((contacto) => !actualesIds.contains(contacto.id))
        .toList();
    await _eliminarRemotos(eliminados, userId: userId, ahora: ahora);

    for (final contacto in actuales) {
      final valores = {
        'id': contacto.id,
        'user_id': userId,
        'nombre': contacto.nombre,
        'telefono': contacto.telefono,
        'prioritario': contacto.prioritario,
        'creado_en': contacto.creadoEn.toUtc().toIso8601String(),
        'eliminado_en': null,
        'cliente_actualizado_en': ahora,
      };
      await sync.enqueue(
        table: 'emergency_contacts',
        userId: userId,
        keys: {'id': contacto.id},
        insertValues: valores,
        updateValues: {
          'nombre': contacto.nombre,
          'telefono': contacto.telefono,
          'prioritario': contacto.prioritario,
          'eliminado_en': null,
          'cliente_actualizado_en': ahora,
        },
      );
    }
    await sync.flush();
  }

  Future<void> _eliminarRemotos(
    List<Contacto> contactos, {
    String? userId,
    String? ahora,
  }) async {
    final sync = _sync;
    if (sync == null || contactos.isEmpty) return;
    final usuario = userId ?? _gateway.currentUserId;
    if (usuario == null) return;
    final fecha = ahora ?? DateTime.now().toUtc().toIso8601String();
    for (final contacto in contactos) {
      await sync.enqueue(
        table: 'emergency_contacts',
        userId: usuario,
        keys: {'id': contacto.id},
        insertValues: {
          'id': contacto.id,
          'user_id': usuario,
          'nombre': contacto.nombre,
          'telefono': contacto.telefono,
          'prioritario': contacto.prioritario,
          'creado_en': contacto.creadoEn.toUtc().toIso8601String(),
          'eliminado_en': fecha,
          'cliente_actualizado_en': fecha,
        },
        updateValues: {
          'eliminado_en': fecha,
          'cliente_actualizado_en': fecha,
        },
      );
    }
    await sync.flush();
  }

  Future<List<Contacto>> _leerContactos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveContactos);
    if (raw == null || raw.isEmpty) return const [];
    return _decodificarLista(raw);
  }

  Future<void> _escribirContactos(List<Contacto> contactos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveContactos,
      jsonEncode(contactos.map((contacto) => contacto.toJson()).toList()),
    );
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
        } catch (_) {}
      }
      return contactos;
    } catch (_) {
      return const [];
    }
  }

  Contacto _contactoDesdeFila(Map<String, dynamic> fila) {
    final creado = fila['creado_en'] as String?;
    return Contacto(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String? ?? '',
      telefono: fila['telefono'] as String? ?? '',
      prioritario: fila['prioritario'] as bool? ?? false,
      creadoEn: creado == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(creado)?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
