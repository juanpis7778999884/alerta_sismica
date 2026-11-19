import 'dart:async';
import 'dart:convert';

import 'package:alerta_sismica/core/sync/supabase_gateway.dart';
import 'package:alerta_sismica/core/sync/supabase_sync_queue.dart';
import 'package:alerta_sismica/models/configuracion_app.dart';
import 'package:alerta_sismica/models/contacto.dart';
import 'package:alerta_sismica/models/sismo.dart';
import 'package:alerta_sismica/repositories/contactos_repository.dart';
import 'package:alerta_sismica/repositories/settings_repository.dart';
import 'package:alerta_sismica/repositories/sismos_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSupabaseGateway implements SupabaseGateway {
  FakeSupabaseGateway({this.userId, this.isReady = true});

  String? userId;

  @override
  bool isReady;

  final StreamController<SupabaseAuthEvent> _events =
      StreamController<SupabaseAuthEvent>.broadcast();
  final Map<String, List<Map<String, dynamic>>> rows = {};

  @override
  String? get currentUserId => userId;

  @override
  Stream<SupabaseAuthEvent> get authStateChanges => _events.stream;

  void emit(SupabaseAuthEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  Future<SupabaseAuthResult> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    return SupabaseAuthResult.session(
      SupabaseIdentity(id: userId ?? 'u1', email: email, nombre: nombre),
    );
  }

  @override
  Future<SupabaseAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return SupabaseAuthResult.session(
      SupabaseIdentity(id: userId ?? 'u1', email: email, nombre: email),
    );
  }

  @override
  Future<SupabaseIdentity?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, Object?> filters = const {},
  }) async {
    final filas = rows[table] ?? const <Map<String, dynamic>>[];
    return filas
        .where(
          (fila) => filters.entries.every(
            (entry) => fila[entry.key] == entry.value,
          ),
        )
        .map((fila) => Map<String, dynamic>.from(fila))
        .toList(growable: false);
  }

  @override
  Future<void> upsertRow({
    required String table,
    required Map<String, Object> keys,
    required Map<String, dynamic> insertValues,
    required Map<String, dynamic> updateValues,
  }) async {
    final filas = rows.putIfAbsent(table, () => []);
    final indice = filas.indexWhere(
      (fila) => keys.entries.every(
        (entry) => fila[entry.key] == entry.value,
      ),
    );
    if (indice == -1) {
      filas.add({...insertValues, ...keys});
      return;
    }
    filas[indice].addAll(updateValues);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SupabaseSyncQueue', () {
    test('flush envía la operación y limpia el outbox', () async {
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final queue = SupabaseSyncQueue(gateway: gateway);

      await queue.enqueue(
        table: 'user_settings',
        userId: 'u1',
        keys: {'user_id': 'u1'},
        insertValues: {'user_id': 'u1', 'tema': 'claro'},
        updateValues: {'tema': 'claro'},
      );
      expect(await queue.leerOperaciones(), hasLength(1));

      await queue.flush();

      expect(await queue.leerOperaciones(), isEmpty);
      expect(gateway.rows['user_settings']?.single['tema'], 'claro');
    });

    test('rebindUser reasigna el usuario de las operaciones pendientes',
        () async {
      final gateway = FakeSupabaseGateway(userId: 'local');
      final queue = SupabaseSyncQueue(gateway: gateway);

      await queue.enqueue(
        table: 'emergency_contacts',
        userId: 'local',
        keys: {'id': 'c1'},
        insertValues: {'id': 'c1', 'user_id': 'local'},
        updateValues: {'nombre': 'Local'},
      );
      await queue.rebindUser('local', 'remote');

      final operaciones = await queue.leerOperaciones();
      expect(operaciones.single.userId, 'remote');
    });
  });

  group('SupabaseSyncCoordinator', () {
    test('ejecuta los pulls cuando hay sesión activa', () async {
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final coordinator = SupabaseSyncCoordinator(
        gateway: gateway,
        queue: SupabaseSyncQueue(gateway: gateway),
      );
      var pulls = 0;
      coordinator.registerPull(() async {
        pulls++;
      });

      coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(pulls, 1);

      coordinator.dispose();
      await gateway.close();
    });
  });

  group('Repositorios Supabase', () {
    test('SettingsRepository sincroniza la configuración con user_settings',
        () async {
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final repository = SettingsRepository(
        gateway: gateway,
        sync: SupabaseSyncQueue(gateway: gateway),
      );

      await repository.guardarConfiguracion(
        ConfiguracionApp.inicial.copyWith(numeroEmergencia: '123'),
      );

      final fila = gateway.rows['user_settings']?.single;
      expect(fila?['user_id'], 'u1');
      expect(fila?['numero_emergencia'], '123');
    });

    test('ContactosRepository sincroniza contactos con emergency_contacts',
        () async {
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final repository = ContactosRepository(
        gateway: gateway,
        sync: SupabaseSyncQueue(gateway: gateway),
      );
      final contacto = Contacto(
        id: 'c1',
        nombre: 'Ana',
        telefono: '3001234567',
        creadoEn: DateTime.utc(2026, 1, 1),
        prioritario: true,
      );

      await repository.guardar([contacto]);

      final fila = gateway.rows['emergency_contacts']?.single;
      expect(fila?['id'], 'c1');
      expect(fila?['user_id'], 'u1');
      expect(fila?['prioritario'], isTrue);
    });

    test('SismosRepository sincroniza solo sismos guardados por el usuario',
        () async {
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final repository = SismosRepository(
        gateway: gateway,
        sync: SupabaseSyncQueue(gateway: gateway),
      );
      final sismo = Sismo(
        id: 'usgs-1',
        magnitud: 4.2,
        lugar: 'Colombia',
        latitud: 4.6,
        longitud: -74.1,
        profundidad: 12,
        tiempo: DateTime.utc(2026, 1, 1),
        url: '',
      );

      final guardado = await repository.guardarSismo(sismo);

      final fila = gateway.rows['saved_earthquakes']?.single;
      expect(guardado.guardadoId, isNotEmpty);
      expect(fila?['guardado_id'], guardado.guardadoId);
      expect(fila?['user_id'], 'u1');
      expect(fila?['sismo_id'], 'usgs-1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sismos_cache_v1'), isNull);
    });

    test('sincronizarDesdeRemoto conserva cambios pendientes en contactos',
        () async {
      final local = Contacto(
        id: 'c1',
        nombre: 'Local',
        telefono: '3001234567',
        creadoEn: DateTime.utc(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'contactos_v2': jsonEncode([local.toJson()]),
      });
      final gateway = FakeSupabaseGateway(userId: 'u1');
      final queue = SupabaseSyncQueue(gateway: gateway);
      await queue.enqueue(
        table: 'emergency_contacts',
        userId: 'u1',
        keys: {'id': 'c1'},
        insertValues: {'id': 'c1', 'user_id': 'u1', 'nombre': 'Local'},
        updateValues: {'nombre': 'Local'},
      );
      gateway.rows['emergency_contacts'] = [
        {
          'id': 'c1',
          'user_id': 'u1',
          'nombre': 'Remoto',
          'telefono': '3009999999',
          'prioritario': false,
          'creado_en': '2026-01-01T00:00:00.000Z',
          'eliminado_en': null,
        },
      ];
      final repository = ContactosRepository(gateway: gateway, sync: queue);

      final resultado = await repository.sincronizarDesdeRemoto();

      expect(resultado.single.nombre, 'Local');
    });
  });
}
