import 'package:alerta_sismica/models/sismo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> geoJson() => {
    'id': 'us7000abcd',
    'properties': <String, dynamic>{
      'mag': 5.4,
      'place': '  Cerca de la costa  ',
      'time': 1700000000000,
      'url': 'https://earthquake.usgs.gov/earthquakes/eventpage/us7000abcd',
      'updated': 1700000060000,
    },
    'geometry': <String, dynamic>{
      'coordinates': <double>[-74.0836, 4.6533, 35.2],
    },
  };

  group('Sismo.fromJson', () {
    test('interpreta el GeoJSON de USGS', () {
      final sismo = Sismo.fromJson(geoJson());

      expect(sismo.id, 'us7000abcd');
      expect(sismo.magnitud, 5.4);
      expect(sismo.lugar, 'Cerca de la costa');
      expect(sismo.latitud, 4.6533);
      expect(sismo.longitud, -74.0836);
      expect(sismo.profundidad, 35.2);
      expect(sismo.tieneEnlace, isTrue);
      expect(sismo.tiempo.isUtc, isTrue);
      expect(sismo.nivel, MagnitudNivel.moderado);
      expect(sismo.magnitudFormateada, '5.4');
      expect(sismo.profundidadTexto, '35.2 km');
    });

    test('descarta enlaces con esquemas no seguros', () {
      final json = geoJson();
      (json['properties'] as Map<String, dynamic>)['url'] =
          'javascript:alert(1)';

      expect(Sismo.fromJson(json).tieneEnlace, isFalse);
    });

    test('exige magnitud y coordenadas válidas', () {
      final sinMagnitud = geoJson();
      (sinMagnitud['properties'] as Map<String, dynamic>)['mag'] = null;
      expect(() => Sismo.fromJson(sinMagnitud), throwsFormatException);

      final coordenadasIncompletas = geoJson();
      (coordenadasIncompletas['geometry']
          as Map<String, dynamic>)['coordinates'] = [
        -74.0836,
        4.6533,
      ];
      expect(
        () => Sismo.fromJson(coordenadasIncompletas),
        throwsFormatException,
      );
    });

    test('rechaza latitudes fuera de rango', () {
      final json = geoJson();
      (json['geometry'] as Map<String, dynamic>)['coordinates'] = [
        -74.0,
        95.0,
        10.0,
      ];
      expect(() => Sismo.fromJson(json), throwsFormatException);
    });
  });

  group('Sismo.cache', () {
    test('conserva los datos al guardar y restaurar la caché', () {
      final original = Sismo.fromJson(geoJson());
      final restaurado = Sismo.fromCacheJson(original.toCacheJson());

      expect(restaurado.id, original.id);
      expect(restaurado.magnitud, original.magnitud);
      expect(restaurado.lugar, original.lugar);
      expect(restaurado.tiempo, original.tiempo);
      expect(restaurado.url, original.url);
    });

    test('marca los eventos simulados', () {
      final simulado = Sismo.simulado(magnitud: 6.1);

      expect(simulado.esSimulacion, isTrue);
      expect(simulado.id, startsWith('simulacion_'));
      expect(simulado.magnitud, 6.1);
      expect(simulado.nivel, MagnitudNivel.fuerte);
    });
  });

  group('Sismo.distanciaKmDesde', () {
    test('aproxima un grado de latitud a 111 km', () {
      final sismo = Sismo(
        id: 'test',
        magnitud: 4,
        lugar: 'Ecuador',
        latitud: 0,
        longitud: 0,
        profundidad: 10,
        tiempo: DateTime.utc(2026),
        url: '',
      );

      expect(sismo.distanciaKmDesde(0, 1), closeTo(111.2, 0.5));
      expect(sismo.distanciaKmDesde(0, 0), closeTo(0, 0.001));
    });
  });
}
