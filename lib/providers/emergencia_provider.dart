import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/date_formatters.dart';
import '../models/contacto.dart';
import '../models/emergencia.dart';
import '../models/usuario.dart';
import '../repositories/emergencias_repository.dart';
import '../services/emergency_channels.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class ResultadoActivacion {
  const ResultadoActivacion({
    required this.exitosa,
    required this.mensaje,
    this.emergencia,
    this.yaExistia = false,
    this.advertencia,
  });

  final bool exitosa;
  final String mensaje;
  final Emergencia? emergencia;
  final bool yaExistia;
  final String? advertencia;
}

class EmergenciaProvider extends ChangeNotifier {
  EmergenciaProvider({
    EmergenciasRepository? repository,
    LocationGateway? location,
    DireccionGateway? direccion,
    EmergencyChannelGateway? canales,
    NotificationGateway? notificaciones,
    Uuid? uuid,
  }) : _repository = repository ?? EmergenciasRepository(),
       _location = location ?? LocationService(),
       _direccion = direccion ?? NominatimGeocodingService(),
       _canales = canales ?? EmergencyChannelService(),
       _notificaciones = notificaciones ?? NotificationService(),
       _uuid = uuid ?? const Uuid();

  final EmergenciasRepository _repository;
  final LocationGateway _location;
  final DireccionGateway _direccion;
  final EmergencyChannelGateway _canales;
  final NotificationGateway _notificaciones;
  final Uuid _uuid;

  Emergencia? _activa;
  List<Emergencia> _historial = const [];
  bool _cargando = true;
  bool _inicializado = false;
  bool _activando = false;
  bool _enviando = false;
  String? _error;
  String? _ultimoMensajeEnvio;

  Emergencia? get activa => _activa;
  List<Emergencia> get historial => List.unmodifiable(_historial);
  bool get cargando => _cargando;
  bool get activando => _activando;
  bool get enviando => _enviando;
  String? get error => _error;
  String? get ultimoMensajeEnvio => _ultimoMensajeEnvio;
  bool get hayEmergenciaActiva => _activa != null && _activa!.activa;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    _cargando = true;
    notifyListeners();
    try {
      final activa = await _repository.cargarActiva();
      if (activa != null && !activa.activa) {
        await _repository.finalizar(activa);
        _activa = null;
      } else {
        _activa = activa;
      }
      _historial = _ordenarHistorial(await _repository.cargarHistorial());
      _error = null;
    } catch (_) {
      _error = 'No se pudo recuperar el estado de emergencias guardado.';
      _historial = const [];
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<ResultadoActivacion> activarSos({
    required UsuarioLocal usuario,
    required List<Contacto> contactos,
    TipoEmergencia tipo = TipoEmergencia.sos,
    String? referenciaEvento,
  }) async {
    final actual = _activa;
    if (actual != null && actual.activa) {
      return ResultadoActivacion(
        exitosa: true,
        yaExistia: true,
        emergencia: actual,
        mensaje:
            'Ya hay una emergencia activa. Finalízala antes de iniciar otra.',
      );
    }
    if (_activando) {
      return const ResultadoActivacion(
        exitosa: false,
        mensaje: 'La activación de la emergencia ya está en curso.',
      );
    }

    _activando = true;
    _error = null;
    notifyListeners();

    try {
      UbicacionUsuario? ubicacion;
      try {
        ubicacion = await _location.obtenerUbicacion(
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {
        ubicacion = null;
      }

      String? direccion;
      if (ubicacion != null) {
        try {
          direccion = await _direccion
              .obtenerDireccion(ubicacion.latitud, ubicacion.longitud)
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
        } catch (_) {
          direccion = null;
        }
      }

      final ahora = DateTime.now();
      final emergencia = Emergencia(
        id: 'emg_${_uuid.v4()}',
        tipo: tipo,
        usuarioNombre: usuario.nombre,
        inicio: ahora,
        mensaje: _construirMensaje(
          usuario: usuario,
          tipo: tipo,
          inicio: ahora,
          ubicacion: ubicacion,
          direccion: direccion,
          referenciaEvento: referenciaEvento,
        ),
        envios: contactos
            .map(
              (contacto) => EnvioContacto(
                contactoId: contacto.id,
                nombre: contacto.nombre,
                telefono: contacto.telefono,
                prioritario: contacto.prioritario,
              ),
            )
            .toList(),
        envioInicialIntentado: false,
        latitud: ubicacion?.latitud,
        longitud: ubicacion?.longitud,
        precisionMetros: ubicacion?.precisionMetros,
        ubicacionLegible: direccion,
      );

      final guardada = await _persistirActiva(emergencia);
      _ultimoMensajeEnvio = null;

      try {
        await _notificaciones.mostrarEmergenciaActiva(emergencia);
      } catch (_) {
        // La notificación es un aviso adicional, nunca bloquea la emergencia.
      }

      final sinContactos = contactos.isEmpty;
      final advertencia = guardada
          ? null
          : 'La emergencia está activa en memoria, pero no se pudo guardar en el dispositivo.';
      return ResultadoActivacion(
        exitosa: true,
        emergencia: guardada ? emergencia : _activa,
        mensaje: sinContactos
            ? 'Emergencia activada. No tienes contactos configurados para enviar el aviso.'
            : 'Emergencia activada y guardada en el dispositivo. La entrega de mensajes aún no está confirmada.',
        advertencia: advertencia,
      );
    } on AppException catch (error) {
      _error = error.message;
      return ResultadoActivacion(exitosa: false, mensaje: error.message);
    } catch (_) {
      _error = 'No se pudo activar la emergencia. Inténtalo de nuevo.';
      return const ResultadoActivacion(
        exitosa: false,
        mensaje: 'No se pudo activar la emergencia. Inténtalo de nuevo.',
      );
    } finally {
      _activando = false;
      notifyListeners();
    }
  }

  Future<String?> intentarEnvioInicial() async {
    final actual = _activa;
    if (actual == null || !actual.activa) {
      return null;
    }
    if (actual.envioInicialIntentado) {
      return _ultimoMensajeEnvio;
    }
    if (_enviando) {
      return 'Hay un envío en curso. Espera un momento.';
    }

    _enviando = true;
    _error = null;
    notifyListeners();

    try {
      final destinatarios = _destinatariosDesdeEnvios(actual.envios);
      String mensaje;

      if (destinatarios.isEmpty) {
        final nueva = actual.conEnvioInicial(intentado: true);
        await _persistirActiva(nueva);
        mensaje = 'No hay contactos de emergencia configurados. Agrega al menos uno para enviar el aviso.';
        _ultimoMensajeEnvio = mensaje;
        return mensaje;
      }

      final sms = await _canales.abrirSms(
        telefonos: destinatarios.map((envio) => envio.telefono).toList(),
        mensaje: actual.mensaje,
      );

      Emergencia nueva;
      if (sms.abierto) {
        nueva = actual
            .conEnvios(_actualizarEnvios(actual, destinatarios, sms))
            .conEnvioInicial(intentado: true);
        mensaje =
            'Se abrió la app de mensajes para ${destinatarios.length} contacto(s). Revisa y envía el SMS: la entrega no está confirmada.';
      } else {
        final compartir = await _canales.compartir(
          mensaje: actual.mensaje,
          asunto: 'Alerta Sísmica SOS',
        );
        nueva = actual.conEnvioInicial(
          intentado: true,
          estadoCompartir: compartir.estado,
          compartidoEn: DateTime.now(),
        );
        if (compartir.abierto) {
          mensaje = 'Se abrió el selector para compartir el aviso. La entrega no está confirmada; verifica que hayas elegido a tus contactos.';
        } else {
          mensaje =
              'No se pudo abrir un canal de envío. ${sms.detalle} ${compartir.detalle}';
        }
      }

      await _persistirActiva(nueva);
      _ultimoMensajeEnvio = mensaje;
      return mensaje;
    } catch (_) {
      _error = 'No se pudo intentar el envío inicial del aviso.';
      return _error;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<ResultadoCanal?> enviarAContacto({
    required String contactoId,
    required CanalEnvio canal,
  }) async {
    final actual = _activa;
    if (actual == null || !actual.activa) {
      _error = 'No hay una emergencia activa.';
      notifyListeners();
      return null;
    }
    if (_enviando) {
      _error = 'Hay un envío en curso. Espera un momento.';
      notifyListeners();
      return null;
    }
    final envio = _buscarEnvio(actual.envios, contactoId);
    if (envio == null) {
      _error = 'El contacto de esta emergencia ya no está disponible.';
      notifyListeners();
      return null;
    }

    _enviando = true;
    _error = null;
    notifyListeners();
    try {
      ResultadoCanal resultado;
      switch (canal) {
        case CanalEnvio.sms:
          resultado = await _canales.abrirSms(
            telefonos: [envio.telefono],
            mensaje: actual.mensaje,
          );
          break;
        case CanalEnvio.whatsapp:
          resultado = await _canales.abrirWhatsApp(
            telefono: envio.telefono,
            mensaje: actual.mensaje,
          );
          break;
        case CanalEnvio.compartir:
        case CanalEnvio.llamada:
          _error = 'Ese canal no se usa para enviar el aviso a un contacto específico.';
          return null;
      }

      final nueva = actual
          .conEnvios(_actualizarEnvios(actual, [envio], resultado))
          .conEnvioInicial(intentado: true);
      await _persistirActiva(nueva);
      return resultado;
    } catch (_) {
      _error = 'No se pudo abrir el canal seleccionado.';
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<ResultadoCanal?> enviarSmsATodos() async {
    final actual = _activa;
    if (actual == null || !actual.activa) {
      _error = 'No hay una emergencia activa.';
      notifyListeners();
      return null;
    }
    if (_enviando) {
      _error = 'Hay un envío en curso. Espera un momento.';
      notifyListeners();
      return null;
    }
    final destinatarios = _destinatariosDesdeEnvios(actual.envios);
    if (destinatarios.isEmpty) {
      _error = 'No hay contactos de emergencia configurados.';
      notifyListeners();
      return null;
    }

    _enviando = true;
    _error = null;
    notifyListeners();
    try {
      final resultado = await _canales.abrirSms(
        telefonos: destinatarios.map((envio) => envio.telefono).toList(),
        mensaje: actual.mensaje,
      );
      final nueva = actual
          .conEnvios(_actualizarEnvios(actual, destinatarios, resultado))
          .conEnvioInicial(intentado: true);
      await _persistirActiva(nueva);
      _ultimoMensajeEnvio = resultado.detalle;
      return resultado;
    } catch (_) {
      _error = 'No se pudo abrir la app de mensajes.';
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<ResultadoCanal?> compartirMensaje() async {
    final actual = _activa;
    if (actual == null || !actual.activa) {
      _error = 'No hay una emergencia activa.';
      notifyListeners();
      return null;
    }
    if (_enviando) {
      _error = 'Hay un envío en curso. Espera un momento.';
      notifyListeners();
      return null;
    }

    _enviando = true;
    _error = null;
    notifyListeners();
    try {
      final resultado = await _canales.compartir(
        mensaje: actual.mensaje,
        asunto: 'Alerta Sísmica SOS',
      );
      final nueva = actual.conEnvioInicial(
        intentado: true,
        estadoCompartir: resultado.estado,
        compartidoEn: DateTime.now(),
      );
      await _persistirActiva(nueva);
      _ultimoMensajeEnvio = resultado.detalle;
      return resultado;
    } catch (_) {
      _error = 'No se pudo abrir el selector para compartir.';
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<ResultadoCanal> abrirMapaEmergencia() async {
    final actual = _activa;
    if (actual == null || !actual.tieneUbicacion) {
      return const ResultadoCanal(
        canal: CanalEnvio.compartir,
        estado: EstadoEnvio.noDisponible,
        detalle: 'No hay coordenadas guardadas para esta emergencia.',
      );
    }
    return _canales.abrirMapa(
      latitud: actual.latitud!,
      longitud: actual.longitud!,
    );
  }

  Future<ResultadoCanal> llamarEmergencia(String numero) {
    return _canales.llamar(numero: numero);
  }

  Future<bool> finalizar() async {
    final actual = _activa;
    if (actual == null) return false;
    if (_activando || _enviando) {
      _error = 'Espera a que termine la acción en curso antes de finalizar.';
      notifyListeners();
      return false;
    }
    try {
      final fin = actual.finalizada(DateTime.now());
      await _repository.finalizar(fin);
      _historial = _ordenarHistorial([
        fin,
        ..._historial.where((emergencia) => emergencia.id != fin.id),
      ]);
      _activa = null;
      _ultimoMensajeEnvio = null;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo finalizar la emergencia. Inténtalo de nuevo.';
      notifyListeners();
      return false;
    }
  }

  Future<void> recargarHistorial() async {
    try {
      _historial = _ordenarHistorial(await _repository.cargarHistorial());
      notifyListeners();
    } catch (_) {
      _error = 'No se pudo recargar el historial de emergencias.';
      notifyListeners();
    }
  }

  Future<bool> limpiarHistorial() async {
    try {
      await _repository.limpiarHistorial();
      _historial = const [];
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo borrar el historial de emergencias.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> borrarDatosLocales() async {
    try {
      await _repository.eliminarActiva();
      await _repository.limpiarHistorial();
      _activa = null;
      _historial = const [];
      _ultimoMensajeEnvio = null;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudieron borrar los datos de emergencias.';
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _persistirActiva(Emergencia nueva) async {
    var guardada = true;
    try {
      await _repository.guardarActiva(nueva);
    } catch (_) {
      guardada = false;
    }
    _activa = nueva;
    notifyListeners();
    return guardada;
  }

  List<EnvioContacto> _actualizarEnvios(
    Emergencia emergencia,
    Iterable<EnvioContacto> objetivos,
    ResultadoCanal resultado,
  ) {
    final ids = objetivos.map((envio) => envio.contactoId).toSet();
    final ahora = DateTime.now();
    return emergencia.envios.map((envio) {
      if (!ids.contains(envio.contactoId)) return envio;
      return envio.copyWith(
        canal: resultado.canal,
        estado: resultado.estado,
        detalle: resultado.detalle,
        actualizadoEn: ahora,
      );
    }).toList();
  }

  EnvioContacto? _buscarEnvio(List<EnvioContacto> envios, String contactoId) {
    for (final envio in envios) {
      if (envio.contactoId == contactoId) return envio;
    }
    return null;
  }

  List<EnvioContacto> _destinatariosDesdeEnvios(List<EnvioContacto> envios) {
    final prioritarios = envios.where((envio) => envio.prioritario).toList();
    return prioritarios.isNotEmpty ? prioritarios : envios;
  }

  List<Emergencia> _ordenarHistorial(List<Emergencia> historial) {
    final copia = List<Emergencia>.from(historial)
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
    return copia.take(50).toList();
  }

  String _construirMensaje({
    required UsuarioLocal usuario,
    required TipoEmergencia tipo,
    required DateTime inicio,
    required UbicacionUsuario? ubicacion,
    required String? direccion,
    required String? referenciaEvento,
  }) {
    final lineas = <String>[];
    lineas.add(
      tipo == TipoEmergencia.sismo
          ? 'SOS POR SISMO - ALERTA SÍSMICA'
          : 'EMERGENCIA SOS - ALERTA SÍSMICA',
    );
    lineas.add('Soy ${usuario.nombre}. Necesito ayuda.');
    if (referenciaEvento != null && referenciaEvento.trim().isNotEmpty) {
      lineas.add(referenciaEvento.trim());
    }
    lineas.add('Fecha: ${DateFormatters.fechaCompleta(inicio)}');
    if (ubicacion != null) {
      if (direccion != null && direccion.trim().isNotEmpty) {
        lineas.add('Lugar aproximado: ${direccion.trim()}');
      }
      lineas.add(
        'Coordenadas: ${ubicacion.latitud.toStringAsFixed(6)}, '
        '${ubicacion.longitud.toStringAsFixed(6)}',
      );
      lineas.add('Mapa: ${ubicacion.urlMapa}');
      if (ubicacion.fuente == FuenteUbicacion.ultimaConocida) {
        lineas.add(
          'Nota: es la última ubicación conocida (${DateFormatters.hora(ubicacion.fecha)}).',
        );
      }
    } else {
      lineas.add('Ubicación no disponible al momento de la alerta.');
    }
    lineas.add('Mensaje generado automáticamente desde Alerta Sísmica.');
    return lineas.join('\n');
  }
}
