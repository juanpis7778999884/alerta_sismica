import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_gateway.dart';

class SupabaseSyncOperation {
  const SupabaseSyncOperation({
    required this.id,
    required this.userId,
    required this.table,
    required this.keys,
    required this.insertValues,
    required this.updateValues,
    required this.creadoEn,
    this.intentos = 0,
    this.siguienteIntento,
  });

  final String id;
  final String userId;
  final String table;
  final Map<String, Object> keys;
  final Map<String, dynamic> insertValues;
  final Map<String, dynamic> updateValues;
  final DateTime creadoEn;
  final int intentos;
  final DateTime? siguienteIntento;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'table': table,
    'keys': keys,
    'insertValues': insertValues,
    'updateValues': updateValues,
    'creadoEn': creadoEn.toUtc().toIso8601String(),
    'intentos': intentos,
    'siguienteIntento': siguienteIntento?.toUtc().toIso8601String(),
  };

  factory SupabaseSyncOperation.fromJson(Map<String, dynamic> json) {
    return SupabaseSyncOperation(
      id: json['id'] as String,
      userId: json['userId'] as String,
      table: json['table'] as String,
      keys: _mapaObjetos(json['keys']),
      insertValues: _mapaDinamico(json['insertValues']),
      updateValues: _mapaDinamico(json['updateValues']),
      creadoEn: DateTime.parse(json['creadoEn'] as String).toLocal(),
      intentos: (json['intentos'] as num?)?.toInt() ?? 0,
      siguienteIntento: json['siguienteIntento'] == null
          ? null
          : DateTime.parse(json['siguienteIntento'] as String).toLocal(),
    );
  }

  SupabaseSyncOperation copiar({
    int? intentos,
    DateTime? siguienteIntento,
    String? userId,
    Map<String, Object>? keys,
  }) {
    return SupabaseSyncOperation(
      id: id,
      userId: userId ?? this.userId,
      table: table,
      keys: keys ?? this.keys,
      insertValues: insertValues,
      updateValues: updateValues,
      creadoEn: creadoEn,
      intentos: intentos ?? this.intentos,
      siguienteIntento: siguienteIntento ?? this.siguienteIntento,
    );
  }

  static Map<String, Object> _mapaObjetos(Object? valor) {
    if (valor is! Map) return const {};
    return Map<String, Object>.from(
      valor.map((clave, entry) => MapEntry(clave.toString(), entry as Object)),
    );
  }

  static Map<String, dynamic> _mapaDinamico(Object? valor) {
    if (valor is! Map) return {};
    return Map<String, dynamic>.from(
      valor.map((clave, entry) => MapEntry(clave.toString(), entry)),
    );
  }
}

class SupabaseSyncQueue {
  SupabaseSyncQueue({
    required this._gateway,
    this.archivo = 'supabase_sync_outbox_v1',
  });

  static const int _maximoReintentos = 10;

  final SupabaseGateway _gateway;
  final String archivo;
  Future<void>? _flushEnCurso;

  Future<void> initialize() async {
    await SharedPreferences.getInstance();
  }

  Future<void> enqueue({
    required String table,
    required String userId,
    required Map<String, Object> keys,
    required Map<String, dynamic> insertValues,
    required Map<String, dynamic> updateValues,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final operaciones = await _leer(prefs);
    final id = _idOperacion(table, keys);
    final indice = operaciones.indexWhere((operacion) => operacion.id == id);
    final anterior = indice == -1 ? null : operaciones[indice];
    final operacion = SupabaseSyncOperation(
      id: id,
      userId: userId,
      table: table,
      keys: Map<String, Object>.from(keys),
      insertValues: Map<String, dynamic>.from(insertValues),
      updateValues: Map<String, dynamic>.from(updateValues),
      creadoEn: anterior?.creadoEn ?? DateTime.now(),
      intentos: anterior?.intentos ?? 0,
      siguienteIntento: anterior?.siguienteIntento,
    );
    if (indice == -1) {
      operaciones.add(operacion);
    } else {
      operaciones[indice] = operacion;
    }
    await _escribir(prefs, operaciones);
  }

  Future<bool> hasPending(
    String table,
    Map<String, Object> keys, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final operaciones = await _leer(prefs);
    final id = _idOperacion(table, keys);
    final usuario = userId ?? _gateway.currentUserId;
    return operaciones.any(
      (operacion) =>
          operacion.id == id &&
          (usuario == null || operacion.userId == usuario),
    );
  }

  Future<void> flush() {
    final enCurso = _flushEnCurso;
    if (enCurso != null) return enCurso;
    final futuro = _flushInterno();
    _flushEnCurso = futuro.whenComplete(() => _flushEnCurso = null);
    return _flushEnCurso!;
  }

  Future<void> rebindUser(String anterior, String nuevo) async {
    if (anterior == nuevo) return;
    final prefs = await SharedPreferences.getInstance();
    final operaciones = await _leer(prefs);
    final actualizadas = <SupabaseSyncOperation>[];
    for (final operacion in operaciones) {
      if (operacion.userId != anterior) {
        actualizadas.add(operacion);
        continue;
      }
      final llaves = _reemplazar(operacion.keys, anterior, nuevo)
          as Map<String, Object>;
      actualizadas.add(
        operacion.copiar(
          userId: nuevo,
          keys: llaves,
          intentos: 0,
          siguienteIntento: null,
        ),
      );
    }
    await _escribir(prefs, actualizadas);
  }

  Future<List<SupabaseSyncOperation>> leerOperaciones() async {
    final prefs = await SharedPreferences.getInstance();
    return _leer(prefs);
  }

  Future<void> _flushInterno() async {
    final userId = _gateway.currentUserId;
    if (!_gateway.isReady || userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final operaciones = await _leer(prefs);
    final ahora = DateTime.now();
    var cambio = false;

    for (final operacion in List<SupabaseSyncOperation>.from(operaciones)) {
      if (operacion.userId != userId) continue;
      final siguiente = operacion.siguienteIntento;
      if (siguiente != null && ahora.isBefore(siguiente)) continue;

      try {
        await _gateway.upsertRow(
          table: operacion.table,
          keys: operacion.keys,
          insertValues: operacion.insertValues,
          updateValues: operacion.updateValues,
        );
        operaciones.removeWhere((item) => item.id == operacion.id);
        cambio = true;
      } catch (_) {
        final intentos = (operacion.intentos + 1).clamp(0, _maximoReintentos);
        final espera = _esperaSegundos(intentos);
        final indice = operaciones.indexWhere((item) => item.id == operacion.id);
        if (indice != -1) {
          operaciones[indice] = operacion.copiar(
            intentos: intentos,
            siguienteIntento: ahora.add(Duration(seconds: espera)),
          );
          cambio = true;
        }
      }
    }

    if (cambio) await _escribir(prefs, operaciones);
  }

  int _esperaSegundos(int intentos) {
    final exponente = intentos.clamp(0, 8);
    final segundos = 5 * (1 << exponente);
    return segundos > 3600 ? 3600 : segundos;
  }

  String _idOperacion(String table, Map<String, Object> keys) {
    final partes = keys.keys.toList()..sort();
    final llave = partes
        .map((columna) => '$columna=${keys[columna]}')
        .join('|');
    return '$table|$llave';
  }

  Future<List<SupabaseSyncOperation>> _leer(SharedPreferences prefs) async {
    final raw = prefs.getString(archivo);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final operaciones = <SupabaseSyncOperation>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          operaciones.add(
            SupabaseSyncOperation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {}
      }
      return operaciones;
    } catch (_) {
      return [];
    }
  }

  Future<void> _escribir(
    SharedPreferences prefs,
    List<SupabaseSyncOperation> operaciones,
  ) async {
    await prefs.setString(
      archivo,
      jsonEncode(operaciones.map((operacion) => operacion.toJson()).toList()),
    );
  }

  Object _reemplazar(Object valor, String anterior, String nuevo) {
    if (valor is String) {
      return valor == anterior ? nuevo : valor;
    }
    if (valor is List) {
      return valor.map((item) => _reemplazar(item, anterior, nuevo)).toList();
    }
    if (valor is Map) {
      return valor.map<String, Object>(
        (clave, item) => MapEntry(
          clave.toString(),
          _reemplazar(item as Object, anterior, nuevo),
        ),
      );
    }
    return valor;
  }
}

class SupabaseSyncCoordinator {
  SupabaseSyncCoordinator({
    required this._gateway,
    required this._queue,
  });

  final SupabaseGateway _gateway;
  final SupabaseSyncQueue _queue;
  final List<Future<void> Function()> _pulls = [];
  StreamSubscription<SupabaseAuthEvent>? _suscripcion;
  bool _iniciado = false;

  void registerPull(Future<void> Function() pull) {
    _pulls.add(pull);
  }

  void start() {
    if (_iniciado) return;
    _iniciado = true;
    _suscripcion = _gateway.authStateChanges.listen(
      _atenderEvento,
      onError: (Object error, StackTrace stackTrace) {},
    );
    final userId = _gateway.currentUserId;
    if (userId != null) unawaited(_sincronizar());
  }

  Future<void> sincronizarAhora() async {
    final userId = _gateway.currentUserId;
    if (userId == null) return;
    await _sincronizar();
  }

  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _iniciado = false;
  }

  void _atenderEvento(SupabaseAuthEvent evento) {
    if (evento.kind == SupabaseAuthEventKind.signedOut) return;
    final userId = evento.userId ?? _gateway.currentUserId;
    if (userId == null) return;
    unawaited(_sincronizar());
  }

  Future<void> _sincronizar() async {
    await _queue.flush();
    for (final pull in List<Future<void> Function()>.from(_pulls)) {
      try {
        await pull();
      } catch (_) {}
    }
  }
}
