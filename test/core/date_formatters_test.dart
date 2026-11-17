import 'package:alerta_sismica/core/utils/date_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateFormatters.duracion', () {
    test('formatea minutos y segundos', () {
      expect(
        DateFormatters.duracion(const Duration(minutes: 2, seconds: 5)),
        '02:05',
      );
    });

    test('incluye horas cuando corresponde', () {
      expect(
        DateFormatters.duracion(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
    });

    test('usa el valor absoluto de duraciones negativas', () {
      expect(DateFormatters.duracion(const Duration(seconds: -5)), '00:05');
    });
  });

  group('DateFormatters.coordenadas', () {
    test('indica hemisferios y cinco decimales', () {
      expect(
        DateFormatters.coordenadas(-4.6533, -74.0836),
        '4.65330° S, 74.08360° O',
      );
      expect(
        DateFormatters.coordenadas(19.4326, -99.1332),
        '19.43260° N, 99.13320° O',
      );
    });
  });

  group('DateFormatters.hace', () {
    final ahora = DateTime(2026, 11, 16, 12, 0);

    test('describe intervalos recientes', () {
      expect(
        DateFormatters.hace(
          ahora.subtract(const Duration(seconds: 10)),
          ahora: ahora,
        ),
        'Hace menos de 1 min',
      );
      expect(
        DateFormatters.hace(
          ahora.subtract(const Duration(minutes: 5)),
          ahora: ahora,
        ),
        'Hace 5 min',
      );
      expect(
        DateFormatters.hace(
          ahora.subtract(const Duration(hours: 3)),
          ahora: ahora,
        ),
        'Hace 3 h',
      );
    });

    test('devuelve Ahora para fechas futuras', () {
      expect(
        DateFormatters.hace(
          ahora.add(const Duration(minutes: 1)),
          ahora: ahora,
        ),
        'Ahora',
      );
    });
  });
}
