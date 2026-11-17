import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergencia.dart';

class ResultadoCanal {
  const ResultadoCanal({
    required this.canal,
    required this.estado,
    required this.detalle,
  });

  final CanalEnvio canal;
  final EstadoEnvio estado;
  final String detalle;

  bool get abierto => estado == EstadoEnvio.abiertoEnApp;
}

abstract class EmergencyChannelGateway {
  Future<ResultadoCanal> abrirSms({
    required List<String> telefonos,
    required String mensaje,
  });

  Future<ResultadoCanal> abrirWhatsApp({
    required String telefono,
    required String mensaje,
  });

  Future<ResultadoCanal> compartir({required String mensaje, String? asunto});

  Future<ResultadoCanal> abrirMapa({
    required double latitud,
    required double longitud,
  });

  Future<ResultadoCanal> llamar({required String numero});

  Future<bool> puedeAbrirSms();
  Future<bool> puedeAbrirWhatsApp();
  Future<bool> puedeAbrirLlamada();
}

class EmergencyChannelService implements EmergencyChannelGateway {
  static String _telefono(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Future<ResultadoCanal> abrirSms({
    required List<String> telefonos,
    required String mensaje,
  }) async {
    final numeros = telefonos
        .map(_telefono)
        .where((numero) => numero.isNotEmpty)
        .toSet()
        .toList();
    if (numeros.isEmpty) {
      return const ResultadoCanal(
        canal: CanalEnvio.sms,
        estado: EstadoEnvio.noDisponible,
        detalle: 'No hay números de teléfono válidos.',
      );
    }

    final uri = Uri.parse(
      'sms:${numeros.join(',')}?body=${Uri.encodeComponent(mensaje)}',
    );
    return _lanzar(
      uri,
      canal: CanalEnvio.sms,
      detalleOk: 'Se abrió la app de mensajes con el texto preparado. La entrega no está confirmada.',
      detalleNoDisponible:
          'No se encontró una app de SMS disponible en este dispositivo.',
    );
  }

  @override
  Future<ResultadoCanal> abrirWhatsApp({
    required String telefono,
    required String mensaje,
  }) async {
    final numero = _telefono(telefono);
    if (numero.isEmpty) {
      return const ResultadoCanal(
        canal: CanalEnvio.whatsapp,
        estado: EstadoEnvio.noDisponible,
        detalle: 'El número de teléfono no es válido.',
      );
    }

    final esquema = Uri.parse(
      'whatsapp://send?phone=$numero&text=${Uri.encodeComponent(mensaje)}',
    );
    if (await canLaunchUrl(esquema)) {
      return _lanzar(
        esquema,
        canal: CanalEnvio.whatsapp,
        detalleOk: 'Se abrió WhatsApp con el mensaje preparado. La entrega no está confirmada.',
        detalleNoDisponible: 'WhatsApp no está disponible en este dispositivo.',
      );
    }

    final web = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}',
    );
    return _lanzar(
      web,
      canal: CanalEnvio.whatsapp,
      detalleOk: 'Se abrió WhatsApp o el navegador con el mensaje preparado. La entrega no está confirmada.',
      detalleNoDisponible: 'WhatsApp no está disponible en este dispositivo.',
    );
  }

  @override
  Future<ResultadoCanal> compartir({
    required String mensaje,
    String? asunto,
  }) async {
    try {
      final resultado = await SharePlus.instance.share(
        ShareParams(text: mensaje, subject: asunto, title: asunto),
      );
      switch (resultado.status) {
        case ShareResultStatus.success:
          return const ResultadoCanal(
            canal: CanalEnvio.compartir,
            estado: EstadoEnvio.abiertoEnApp,
            detalle: 'El usuario compartió el mensaje mediante el selector del sistema. La entrega no está confirmada.',
          );
        case ShareResultStatus.dismissed:
          return const ResultadoCanal(
            canal: CanalEnvio.compartir,
            estado: EstadoEnvio.cancelado,
            detalle: 'El usuario cerró el selector sin compartir.',
          );
        case ShareResultStatus.unavailable:
          return const ResultadoCanal(
            canal: CanalEnvio.compartir,
            estado: EstadoEnvio.noDisponible,
            detalle: 'El selector del sistema no está disponible.',
          );
      }
    } catch (_) {
      return const ResultadoCanal(
        canal: CanalEnvio.compartir,
        estado: EstadoEnvio.fallido,
        detalle: 'No se pudo abrir el selector del sistema.',
      );
    }
  }

  @override
  Future<ResultadoCanal> abrirMapa({
    required double latitud,
    required double longitud,
  }) async {
    return _lanzar(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud',
      ),
      canal: CanalEnvio.compartir,
      detalleOk: 'Se abrió la ubicación en la app de mapas.',
      detalleNoDisponible: 'No hay una app de mapas disponible.',
    );
  }

  @override
  Future<ResultadoCanal> llamar({required String numero}) async {
    final limpio = _telefono(numero);
    if (limpio.isEmpty) {
      return const ResultadoCanal(
        canal: CanalEnvio.llamada,
        estado: EstadoEnvio.noDisponible,
        detalle: 'No hay un número de emergencia configurado.',
      );
    }
    return _lanzar(
      Uri.parse('tel:$limpio'),
      canal: CanalEnvio.llamada,
      detalleOk:
          'Se abrió el marcador telefónico; la llamada no es automática.',
      detalleNoDisponible: 'No se pudo abrir el marcador telefónico.',
    );
  }

  @override
  Future<bool> puedeAbrirSms() async {
    try {
      return await canLaunchUrl(Uri.parse('sms:'));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> puedeAbrirWhatsApp() async {
    try {
      if (await canLaunchUrl(Uri.parse('whatsapp://send'))) return true;
      return await canLaunchUrl(Uri.parse('https://wa.me/'));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> puedeAbrirLlamada() async {
    try {
      return await canLaunchUrl(Uri.parse('tel:'));
    } catch (_) {
      return false;
    }
  }

  Future<ResultadoCanal> _lanzar(
    Uri uri, {
    required CanalEnvio canal,
    required String detalleOk,
    required String detalleNoDisponible,
  }) async {
    try {
      if (!await canLaunchUrl(uri)) {
        return ResultadoCanal(
          canal: canal,
          estado: EstadoEnvio.noDisponible,
          detalle: detalleNoDisponible,
        );
      }
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!abierto) {
        return ResultadoCanal(
          canal: canal,
          estado: EstadoEnvio.fallido,
          detalle: detalleNoDisponible,
        );
      }
      return ResultadoCanal(
        canal: canal,
        estado: EstadoEnvio.abiertoEnApp,
        detalle: detalleOk,
      );
    } catch (_) {
      return ResultadoCanal(
        canal: canal,
        estado: EstadoEnvio.fallido,
        detalle: 'Ocurrió un error al abrir el canal externo.',
      );
    }
  }
}
