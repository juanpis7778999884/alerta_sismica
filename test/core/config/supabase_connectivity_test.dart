import 'dart:io';

import 'package:alerta_sismica/core/config/supabase_config.dart';
import 'package:alerta_sismica/core/config/supabase_connectivity.dart';
import 'package:alerta_sismica/core/config/supabase_initializer.dart';
import 'package:alerta_sismica/core/config/supabase_remote_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const String fakeUrl = 'https://example.supabase.co';
  const String fakeKey = 'sb_publishable_example_only';

  Map<String, String> environment({
    String url = fakeUrl,
    String key = fakeKey,
  }) {
    return <String, String>{
      SupabaseConfig.urlEnvironmentKey: url,
      SupabaseConfig.publishableKeyEnvironmentKey: key,
    };
  }

  String Function(String name) readFrom(Map<String, String> values) =>
      (String name) => values[name] ?? '';

  SupabaseInitializer successfulInitializer(Map<String, String> values) =>
      SupabaseInitializer(
        isInitialized: () => false,
        isProduction: () => false,
        readEnvironment: readFrom(values),
        initialize: (_) async {},
        reportError: (_, _) {},
      );

  SupabaseInitializer failingInitializer(Map<String, String> values) =>
      SupabaseInitializer(
        isInitialized: () => false,
        isProduction: () => false,
        readEnvironment: readFrom(values),
        initialize: (_) async => throw StateError('fallo simulado'),
        reportError: (_, _) {},
      );

  SupabaseConfig validConfig() => SupabaseConfig.validate(
    url: fakeUrl,
    publishableKey: fakeKey,
    isProduction: false,
  );

  group('SupabaseRemoteProbe', () {
    test('200 se considera proyecto accesible', () async {
      final probe = SupabaseRemoteProbe(
        client: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
      );

      final result = await probe.check(validConfig());

      expect(result.status, SupabaseRemoteStatus.accessible);
      expect(result.statusCode, 200);
      expect(result.isAccessible, isTrue);
    });

    test('401 y 403 se consideran errores de autorización', () async {
      for (final int code in <int>[401, 403]) {
        final probe = SupabaseRemoteProbe(
          client: MockClient((_) async => http.Response('{}', code)),
        );

        final result = await probe.check(validConfig());

        expect(result.status, SupabaseRemoteStatus.authorizationError);
        expect(result.statusCode, code);
      }
    });

    test('error de socket se considera error de red', () async {
      final probe = SupabaseRemoteProbe(
        client: MockClient((_) async => throw const SocketException('offline')),
      );

      final result = await probe.check(validConfig());

      expect(result.status, SupabaseRemoteStatus.networkError);
      expect(result.detail, isNot(contains(fakeUrl)));
      expect(result.detail, isNot(contains(fakeKey)));
    });

    test('respuesta inesperada se considera error del endpoint', () async {
      final probe = SupabaseRemoteProbe(
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      final result = await probe.check(validConfig());

      expect(result.status, SupabaseRemoteStatus.endpointError);
      expect(result.statusCode, 500);
    });

    test('la petición usa solo el endpoint público de salud', () async {
      Uri? captured;
      String? sentKey;
      final probe = SupabaseRemoteProbe(
        client: MockClient((http.Request request) async {
          captured = request.url;
          sentKey = request.headers['apikey'];
          return http.Response('{"status":"ok"}', 200);
        }),
      );

      await probe.check(validConfig());

      expect(captured, isNotNull);
      expect(captured!.path, SupabaseRemoteProbe.healthPath);
      expect(captured!.query, isEmpty);
      expect(captured!.toString(), isNot(contains(fakeKey)));
      expect(sentKey, fakeKey);
    });
  });

  group('SupabaseConnectivityCheck', () {
    test('configuración ausente no inicializa ni consulta la red', () async {
      final check = SupabaseConnectivityCheck(
        readEnvironment: readFrom(<String, String>{}),
        initializer: failingInitializer(<String, String>{}),
        probe: SupabaseRemoteProbe(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      final report = await check.run();

      expect(report.configuration, SupabaseConfigurationCheckStatus.missing);
      expect(
        report.initialization,
        SupabaseInitializationCheckStatus.notAttempted,
      );
      expect(report.remote, SupabaseRemoteStatus.notChecked);
      expect(report.isConnected, isFalse);
    });

    test('configuración inválida no inicializa ni consulta la red', () async {
      final check = SupabaseConnectivityCheck(
        readEnvironment: readFrom(environment(url: 'not a uri')),
        initializer: failingInitializer(<String, String>{}),
      );

      final report = await check.run();

      expect(report.configuration, SupabaseConfigurationCheckStatus.invalid);
      expect(
        report.initialization,
        SupabaseInitializationCheckStatus.notAttempted,
      );
      expect(report.remote, SupabaseRemoteStatus.notChecked);
    });

    test('fallo de inicialización impide la comprobación remota', () async {
      final check = SupabaseConnectivityCheck(
        readEnvironment: readFrom(environment()),
        initializer: failingInitializer(environment()),
        probe: SupabaseRemoteProbe(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      final report = await check.run();

      expect(report.configuration, SupabaseConfigurationCheckStatus.valid);
      expect(report.initialization, SupabaseInitializationCheckStatus.failed);
      expect(report.remote, SupabaseRemoteStatus.notChecked);
    });

    test('inicialización correcta y endpoint accesible', () async {
      final check = SupabaseConnectivityCheck(
        readEnvironment: readFrom(environment()),
        initializer: successfulInitializer(environment()),
        probe: SupabaseRemoteProbe(
          client: MockClient(
            (_) async => http.Response('{"status":"ok"}', 200),
          ),
        ),
      );

      final report = await check.run();

      expect(report.configuration, SupabaseConfigurationCheckStatus.valid);
      expect(report.initialization, SupabaseInitializationCheckStatus.success);
      expect(report.remote, SupabaseRemoteStatus.accessible);
      expect(report.isConnected, isTrue);
    });

    test('los mensajes del informe no contienen credenciales', () async {
      final check = SupabaseConnectivityCheck(
        readEnvironment: readFrom(environment()),
        initializer: successfulInitializer(environment()),
        probe: SupabaseRemoteProbe(
          client: MockClient((_) async => http.Response('{}', 401)),
        ),
      );

      final report = await check.run();
      final String serialized = report.toString();

      expect(serialized, isNot(contains(fakeKey)));
      expect(report.remote, SupabaseRemoteStatus.authorizationError);
      expect(report.isConnected, isFalse);
    });
  });
}
