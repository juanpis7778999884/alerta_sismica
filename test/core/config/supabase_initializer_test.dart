import 'package:alerta_sismica/core/config/supabase_config.dart';
import 'package:alerta_sismica/core/config/supabase_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseInitializer', () {
    test(
      'inicializa el SDK una sola vez con la configuración válida',
      () async {
        var calls = 0;
        SupabaseConfig? captured;
        final initializer = SupabaseInitializer(
          isInitialized: () => false,
          isProduction: () => false,
          readEnvironment: (name) {
            if (name == SupabaseConfig.urlEnvironmentKey) {
              return 'https://example.supabase.co';
            }
            return 'sb_publishable_example';
          },
          initialize: (config) async {
            calls++;
            captured = config;
          },
          reportError: (_, _) => fail('No se esperaban errores'),
        );

        final result = await initializer.initialize();

        expect(result.initialized, isTrue);
        expect(result.hasError, isFalse);
        expect(calls, 1);
        expect(captured, isNotNull);
      },
    );

    test('omite la inicialización si el SDK ya está inicializado', () async {
      var calls = 0;
      final initializer = SupabaseInitializer(
        isInitialized: () => true,
        isProduction: () => false,
        readEnvironment: (name) {
          if (name == SupabaseConfig.urlEnvironmentKey) {
            return 'https://example.supabase.co';
          }
          return 'sb_publishable_example';
        },
        initialize: (_) async => calls++,
        reportError: (_, _) => fail('No se esperaban errores'),
      );

      final result = await initializer.initialize();

      expect(result.initialized, isTrue);
      expect(calls, 0);
    });

    test(
      'configuración ausente no lanza y reporta sin exponer secretos',
      () async {
        final reported = <Object>[];
        final initializer = SupabaseInitializer(
          isProduction: () => false,
          readEnvironment: (_) => '',
          reportError: (_, error) => reported.add(error),
        );

        final result = await initializer.initialize();

        expect(result.initialized, isFalse);
        expect(result.error, isA<SupabaseConfigurationException>());
        expect(reported, hasLength(1));
        expect(reported.single.toString(), isNot(contains('sb_secret_')));
      },
    );

    test('errores del SDK se reportan y no detienen la app', () async {
      final reported = <Object>[];
      final initializer = SupabaseInitializer(
        isInitialized: () => false,
        isProduction: () => false,
        readEnvironment: (name) {
          if (name == SupabaseConfig.urlEnvironmentKey) {
            return 'https://example.supabase.co';
          }
          return 'sb_publishable_example';
        },
        initialize: (_) async => throw StateError('network unavailable'),
        reportError: (_, error) => reported.add(error),
      );

      final result = await initializer.initialize();

      expect(result.initialized, isFalse);
      expect(result.error, isA<StateError>());
      expect(reported, hasLength(1));
    });
  });
}
