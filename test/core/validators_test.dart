import 'package:alerta_sismica/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.telefono', () {
    test('acepta números con separadores y espacios', () {
      expect(Validators.telefono('300 123 4567'), isNull);
      expect(Validators.telefono('+57 300-123-4567'), isNull);
    });

    test('rechaza números demasiado cortos o sin dígitos', () {
      expect(Validators.telefono('123'), isNotNull);
      expect(Validators.telefono('sin números'), isNotNull);
      expect(Validators.telefono('0000000000'), isNotNull);
    });
  });

  group('Validators.numeroEmergencia', () {
    test('permite dejarlo vacío', () {
      expect(Validators.numeroEmergencia(''), isNull);
      expect(Validators.numeroEmergencia('   '), isNull);
    });

    test('rechaza longitudes imposibles', () {
      expect(Validators.numeroEmergencia('12'), isNotNull);
      expect(Validators.numeroEmergencia('1234567890123456'), isNotNull);
    });
  });

  group('Validators.email', () {
    test('acepta correos razonables', () {
      expect(Validators.email('persona@ejemplo.com'), isNull);
    });

    test('rechaza correos incompletos', () {
      expect(Validators.email('persona@'), isNotNull);
      expect(Validators.email('sin-arroba.com'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
  });

  group('Validators.password', () {
    test('exige letras y números con longitud mínima', () {
      expect(Validators.password('Clave12345'), isNull);
      expect(Validators.password('sololetras'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Ab1'), isNotNull);
    });
  });

  group('Validators.codigoRecuperacion', () {
    test('normaliza separadores y mayúsculas', () {
      expect(Validators.codigoRecuperacion('abcd-efgh-jklm'), isNull);
      expect(
        Validators.normalizarCodigoRecuperacion('abcd-efgh-jklm'),
        'ABCDEFGHJKLM',
      );
    });

    test('rechaza códigos de longitud incorrecta', () {
      expect(Validators.codigoRecuperacion('ABC-123'), isNotNull);
      expect(Validators.codigoRecuperacion(''), isNotNull);
    });
  });

  group('Validators.telefonosIguales', () {
    test('compara los últimos 10 dígitos', () {
      expect(
        Validators.telefonosIguales('+57 300 123 4567', '3001234567'),
        isTrue,
      );
      expect(Validators.telefonosIguales('3001234567', '3001234568'), isFalse);
    });
  });
}
