import 'package:alerta_sismica/models/emergencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Emergencia crearEmergencia({EstadoEnvio estado = EstadoEnvio.pendiente}) {
    return Emergencia(
      id: 'emg_1',
      tipo: TipoEmergencia.sos,
      usuarioNombre: 'Ana Pérez',
      inicio: DateTime.utc(2026, 11, 16, 10),
      mensaje: 'SOS de prueba',
      envios: [
        EnvioContacto(
          contactoId: 'c1',
          nombre: 'Luis',
          telefono: '3001234567',
          prioritario: true,
          estado: estado,
          canal: CanalEnvio.sms,
        ),
      ],
      envioInicialIntentado: true,
      latitud: 4.6533,
      longitud: -74.0836,
      ubicacionLegible: 'Bogotá',
    );
  }

  group('Emergencia', () {
    test('serializa y restaura todos los campos relevantes', () {
      final original = crearEmergencia(estado: EstadoEnvio.abiertoEnApp);
      final restaurada = Emergencia.fromJson(original.toJson());

      expect(restaurada.id, original.id);
      expect(restaurada.tipo, TipoEmergencia.sos);
      expect(restaurada.mensaje, original.mensaje);
      expect(restaurada.envios.single.estado, EstadoEnvio.abiertoEnApp);
      expect(restaurada.tieneUbicacion, isTrue);
      expect(restaurada.coordenadasTexto, '4.653300, -74.083600');
      expect(restaurada.urlMapa, contains('4.6533'));
      expect(restaurada.ubicacionLegible, 'Bogotá');
    });

    test('finalizada deja de estar activa y guarda la hora de fin', () {
      final fin = DateTime.utc(2026, 11, 16, 10, 5);
      final cerrada = crearEmergencia().finalizada(fin);

      expect(cerrada.activa, isFalse);
      expect(cerrada.fin, fin);
      expect(cerrada.duracionHasta(fin), const Duration(minutes: 5));
    });

    test('resume los estados de los envíos sin afirmar entrega', () {
      expect(
        crearEmergencia().resumenEnvios,
        'Envíos pendientes de acción del usuario.',
      );
      expect(
        crearEmergencia(estado: EstadoEnvio.abiertoEnApp).resumenEnvios,
        contains('no está confirmada'),
      );
      expect(
        crearEmergencia(estado: EstadoEnvio.fallido).resumenEnvios,
        contains('No se pudo abrir'),
      );
    });

    test('sin coordenadas informa ubicación no disponible', () {
      final sinUbicacion = Emergencia(
        id: 'emg_2',
        tipo: TipoEmergencia.sismo,
        usuarioNombre: 'Ana',
        inicio: DateTime.utc(2026),
        mensaje: 'SOS',
        envios: const [],
        envioInicialIntentado: false,
      );

      expect(sinUbicacion.tieneUbicacion, isFalse);
      expect(sinUbicacion.coordenadasTexto, 'Ubicación no disponible');
      expect(sinUbicacion.resumenEnvios, contains('Sin contactos'));
    });
  });
}
