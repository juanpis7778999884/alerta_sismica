import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync/supabase_gateway.dart';
import '../core/sync/supabase_sync_queue.dart';
import '../models/emergencia.dart';

class EmergenciasRepository {
  EmergenciasRepository({
    SupabaseGateway? gateway,
    this._sync,
  }) : _gateway = gateway ?? FlutterSupabaseGateway();

  static const String _claveActiva = 'emergencia_activa_v1';
  static const String _claveHistorial = 'emergencias_historial_v1';
  static const int _maximoHistorial = 50;

  final SupabaseGateway _gateway;
  final SupabaseSyncQueue? _sync;

  Future<Emergencia?> cargarActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveActiva);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return Emergencia.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {}
    return null;
  }

  Future<void> guardarActiva(Emergencia emergencia) async {
    await _escribirActiva(emergencia);
    await _sincronizarEvento(emergencia);
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
        } catch (_) {}
      }
      emergencias.sort((a, b) => b.inicio.compareTo(a.inicio));
      return emergencias;
    } catch (_) {
      return const [];
    }
  }

  Future<void> guardarHistorial(List<Emergencia> emergencias) async {
    await _escribirHistorial(emergencias);
    for (final emergencia in emergencias) {
      await _sincronizarEvento(emergencia);
    }
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
    final historial = await cargarHistorial();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveHistorial);
    await _eliminarRemotos(historial);
  }

  Future<void> sincronizarDesdeRemoto() async {
    final userId = _gateway.currentUserId;
    if (userId == null) return;

    final filas = await _gateway.selectRows(
      'emergency_events',
      filters: {'user_id': userId},
    );
    final activaLocal = await cargarActiva();
    final historialLocal = await cargarHistorial();
    final sync = _sync;
    final porId = <String, Emergencia>{
      ...?(activaLocal == null ? null : {activaLocal.id: activaLocal}),
      for (final emergencia in historialLocal) emergencia.id: emergencia,
    };

    Emergencia? activa;
    final historial = <Emergencia>[];

    for (final fila in filas) {
      if (fila['eliminado_en'] != null) continue;
      final id = fila['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'emergency_events',
              {'id': id},
              userId: userId,
            );
      Emergencia emergencia;
      if (pendiente && porId.containsKey(id)) {
        emergencia = porId[id]!;
      } else {
        final entregas = await _gateway.selectRows(
          'emergency_event_deliveries',
          filters: {'event_id': id},
        );
        emergencia = _emergenciaDesdeFila(
          fila,
          entregas.map((item) => _envioDesdeFila(item)).toList(),
        );
      }
      if (emergencia.activa && emergencia.tipo == TipoEmergencia.sos) {
        activa ??= emergencia;
      } else {
        historial.add(emergencia);
      }
    }

    if (activa == null && activaLocal != null) {
      final pendiente = sync == null
          ? false
          : await sync.hasPending(
              'emergency_events',
              {'id': activaLocal.id},
              userId: userId,
            );
      if (pendiente) activa = activaLocal;
    }

    await _escribirActiva(activa);
    await _escribirHistorial(historial);
  }

  Future<void> _sincronizarEvento(Emergencia emergencia) async {
    final sync = _sync;
    if (sync == null) return;
    final userId = _gateway.currentUserId;
    if (userId == null) return;
    final ahora = DateTime.now().toUtc().toIso8601String();
    final valoresEvento = _valoresEvento(emergencia, userId, ahora);

    await sync.enqueue(
      table: 'emergency_events',
      userId: userId,
      keys: {'id': emergencia.id},
      insertValues: {
        'id': emergencia.id,
        'user_id': userId,
        ...valoresEvento,
      },
      updateValues: valoresEvento,
    );

    for (final envio in emergencia.envios) {
      final valoresEnvio = _valoresEnvio(envio, ahora);
      await sync.enqueue(
        table: 'emergency_event_deliveries',
        userId: userId,
        keys: {
          'event_id': emergencia.id,
          'contacto_id': envio.contactoId,
        },
        insertValues: {
          'event_id': emergencia.id,
          'contacto_id': envio.contactoId,
          ...valoresEnvio,
        },
        updateValues: valoresEnvio,
      );
    }
    await sync.flush();
  }

  Future<void> _eliminarRemotos(List<Emergencia> emergencias) async {
    final sync = _sync;
    if (sync == null || emergencias.isEmpty) return;
    final userId = _gateway.currentUserId;
    if (userId == null) return;
    final ahora = DateTime.now().toUtc().toIso8601String();
    for (final emergencia in emergencias) {
      await sync.enqueue(
        table: 'emergency_events',
        userId: userId,
        keys: {'id': emergencia.id},
        insertValues: {
          'id': emergencia.id,
          'user_id': userId,
          ..._valoresEvento(emergencia, userId, ahora),
          'eliminado_en': ahora,
        },
        updateValues: {
          'eliminado_en': ahora,
          'cliente_actualizado_en': ahora,
        },
      );
    }
    await sync.flush();
  }

  Map<String, dynamic> _valoresEvento(
    Emergencia emergencia,
    String userId,
    String ahora,
  ) {
    return {
      'tipo': emergencia.tipo.name,
      'usuario_nombre': emergencia.usuarioNombre,
      'inicio': emergencia.inicio.toUtc().toIso8601String(),
      'fin': emergencia.fin?.toUtc().toIso8601String(),
      'activa': emergencia.activa,
      'mensaje': emergencia.mensaje,
      'envio_inicial_intentado': emergencia.envioInicialIntentado,
      'latitud': emergencia.latitud,
      'longitud': emergencia.longitud,
      'precision_metros': emergencia.precisionMetros,
      'ubicacion_legible': emergencia.ubicacionLegible,
      'estado_compartir': emergencia.estadoCompartir?.name,
      'compartido_en': emergencia.compartidoEn?.toUtc().toIso8601String(),
      'eliminado_en': null,
      'cliente_actualizado_en': ahora,
    };
  }

  Map<String, dynamic> _valoresEnvio(EnvioContacto envio, String ahora) {
    return {
      'nombre': envio.nombre,
      'telefono': envio.telefono,
      'prioritario': envio.prioritario,
      'canal': envio.canal?.name,
      'estado': envio.estado.name,
      'detalle': envio.detalle,
      'cliente_actualizado_en': ahora,
    };
  }

  Future<void> _escribirActiva(Emergencia? emergencia) async {
    final prefs = await SharedPreferences.getInstance();
    if (emergencia == null) {
      await prefs.remove(_claveActiva);
      return;
    }
    await prefs.setString(_claveActiva, jsonEncode(emergencia.toJson()));
  }

  Future<void> _escribirHistorial(List<Emergencia> emergencias) async {
    final prefs = await SharedPreferences.getInstance();
    final ordenadas = List<Emergencia>.from(emergencias)
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
    final limitadas = ordenadas.take(_maximoHistorial).toList();
    await prefs.setString(
      _claveHistorial,
      jsonEncode(limitadas.map((emergencia) => emergencia.toJson()).toList()),
    );
  }

  Emergencia _emergenciaDesdeFila(
    Map<String, dynamic> fila,
    List<EnvioContacto> envios,
  ) {
    final inicio = DateTime.tryParse(fila['inicio'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final fin = fila['fin'] == null
        ? null
        : DateTime.tryParse(fila['fin'] as String)?.toLocal();
    return Emergencia(
      id: fila['id'] as String,
      tipo: fila['tipo'] == 'sismo'
          ? TipoEmergencia.sismo
          : TipoEmergencia.sos,
      usuarioNombre: fila['usuario_nombre'] as String? ?? 'Usuario',
      inicio: inicio,
      fin: fin,
      activa: fila['activa'] as bool? ?? false,
      mensaje: fila['mensaje'] as String? ?? '',
      envios: envios,
      envioInicialIntentado: fila['envio_inicial_intentado'] as bool? ?? false,
      latitud: (fila['latitud'] as num?)?.toDouble(),
      longitud: (fila['longitud'] as num?)?.toDouble(),
      precisionMetros: (fila['precision_metros'] as num?)?.toDouble(),
      ubicacionLegible: fila['ubicacion_legible'] as String?,
      estadoCompartir: _estadoDesdeNombre(fila['estado_compartir'] as String?),
      compartidoEn: fila['compartido_en'] == null
          ? null
          : DateTime.tryParse(fila['compartido_en'] as String)?.toLocal(),
    );
  }

  EnvioContacto _envioDesdeFila(Map<String, dynamic> fila) {
    return EnvioContacto(
      contactoId: fila['contacto_id'] as String,
      nombre: fila['nombre'] as String? ?? '',
      telefono: fila['telefono'] as String? ?? '',
      prioritario: fila['prioritario'] as bool? ?? false,
      canal: CanalEnvio.values.firstWhere(
        (valor) => valor.name == fila['canal'],
        orElse: () => CanalEnvio.sms,
      ),
      estado: EstadoEnvio.values.firstWhere(
        (valor) => valor.name == fila['estado'],
        orElse: () => EstadoEnvio.pendiente,
      ),
      detalle: fila['detalle'] as String?,
      actualizadoEn: fila['actualizado_en'] == null
          ? null
          : DateTime.tryParse(fila['actualizado_en'] as String)?.toLocal(),
    );
  }

  EstadoEnvio? _estadoDesdeNombre(String? nombre) {
    if (nombre == null) return null;
    for (final valor in EstadoEnvio.values) {
      if (valor.name == nombre) return valor;
    }
    return null;
  }
}
