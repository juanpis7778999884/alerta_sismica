import 'package:alerta_sismica/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validUrl = 'https://example.supabase.co';
  const validKey = 'sb_publishable_example_value';

  SupabaseConfig makeConfig({
    String url = validUrl,
    String key = validKey,
    bool isProduction = false,
  }) {
    return SupabaseConfig.validate(
      url: url,
      publishableKey: key,
      isProduction: isProduction,
    );
  }

  group('SupabaseConfig', () {
    test('rechaza URL vacía', () {
      expect(
        () => makeConfig(url: '   '),
        throwsA(
          isA<SupabaseConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('rechaza Publishable key vacía', () {
      expect(
        () => makeConfig(key: '   '),
        throwsA(
          isA<SupabaseConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_PUBLISHABLE_KEY'),
          ),
        ),
      );
    });

    test('rechaza URL malformada', () {
      expect(
        () => makeConfig(url: 'not a uri'),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    });

    test('rechaza URL sin HTTPS en producción', () {
      expect(
        () => makeConfig(url: 'http://example.supabase.co', isProduction: true),
        throwsA(
          isA<SupabaseConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });

    test('rechaza host inválido', () {
      expect(
        () => makeConfig(url: 'https://-invalid-host'),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    });

    test('rechaza credenciales incrustadas en la URL', () {
      expect(
        () => makeConfig(url: 'https://user:pass@example.supabase.co'),
        throwsA(
          isA<SupabaseConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('credenciales incrustadas'),
          ),
        ),
      );
      expect(
        () => makeConfig(url: '$validUrl?apikey=secret'),
        throwsA(isA<SupabaseConfigurationException>()),
      );
    });

    test('rechaza claves administrativas o secretas', () {
      const forbiddenKeys = [
        'sb_secret_example',
        'service_role.example',
        'service-role-example',
        'example-secret-key',
        'private_key_example',
      ];
      for (final key in forbiddenKeys) {
        expect(
          () => makeConfig(key: key),
          throwsA(
            isA<SupabaseConfigurationException>().having(
              (e) => e.message,
              'message',
              contains('clave administrativa'),
            ),
          ),
          reason: 'La clave $key no debe aceptarse en el cliente',
        );
      }
    });

    test('acepta configuración válida y normaliza espacios', () {
      final config = makeConfig(url: '  $validUrl  ', key: '  $validKey  ');

      expect(config.url, validUrl);
      expect(config.publishableKey, validKey);
    });

    test('los mensajes de error no exponen credenciales', () {
      const secretValue = 'sb_secret_do_not_disclose_123456';
      try {
        makeConfig(key: secretValue);
        fail('Se esperaba una excepción');
      } on SupabaseConfigurationException catch (error) {
        expect(error.toString(), isNot(contains(secretValue)));
        expect(error.message, isNot(contains(secretValue)));
      }
    });

    test('lee valores desde String.fromEnvironment inyectado', () {
      final config = SupabaseConfig.fromEnvironment(
        isProduction: false,
        readValue: (name) {
          switch (name) {
            case SupabaseConfig.urlEnvironmentKey:
              return 'http://localhost:54321';
            case SupabaseConfig.publishableKeyEnvironmentKey:
              return validKey;
            default:
              return '';
          }
        },
      );

      expect(config.url, 'http://localhost:54321');
    });
  });
}
