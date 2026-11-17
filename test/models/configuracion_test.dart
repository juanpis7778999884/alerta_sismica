import 'package:alerta_sismica/models/configuracion_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfiguracionApp', () {
    test('usa valores iniciales seguros', () {
      const config = ConfiguracionApp.inicial;

      expect(config.tema, TemaApp.claro);
      expect(config.magnitudMinima, 2.5);
      expect(config.autoRefresco, isTrue);
      expect(config.notificarSismos, isFalse);
      expect(config.umbralNotificacion, 4.5);
      expect(config.numeroEmergencia, isEmpty);
    });

    test('serializa y restaura la configuración', () {
      const original = ConfiguracionApp(
        tema: TemaApp.oscuro,
        magnitudMinima: 4,
        autoRefresco: false,
        notificarSismos: true,
        umbralNotificacion: 5.5,
        numeroEmergencia: '123',
      );
      final restaurada = ConfiguracionApp.fromJson(original.toJson());

      expect(restaurada.tema, TemaApp.oscuro);
      expect(restaurada.magnitudMinima, 4);
      expect(restaurada.autoRefresco, isFalse);
      expect(restaurada.notificarSismos, isTrue);
      expect(restaurada.umbralNotificacion, 5.5);
      expect(restaurada.numeroEmergencia, '123');
    });

    test('corrige valores fuera de rango y temas desconocidos', () {
      final config = ConfiguracionApp.fromJson({
        'tema': 'inexistente',
        'magnitudMinima': 99,
        'umbralNotificacion': -1,
        'numeroEmergencia': ' 911 ',
      });

      expect(config.tema, TemaApp.claro);
      expect(config.magnitudMinima, 7.0);
      expect(config.umbralNotificacion, 2.5);
      expect(config.numeroEmergencia, ' 911 ');
    });

    test('copyWith cambia solo lo indicado', () {
      final config = ConfiguracionApp.inicial.copyWith(
        magnitudMinima: 3.5,
        notificarSismos: true,
      );

      expect(config.magnitudMinima, 3.5);
      expect(config.notificarSismos, isTrue);
      expect(config.tema, ConfiguracionApp.inicial.tema);
      expect(config.autoRefresco, ConfiguracionApp.inicial.autoRefresco);
    });
  });
}
