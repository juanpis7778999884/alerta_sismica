import 'package:url_launcher/url_launcher.dart';
import '../models/contacto.dart';

class SosService {
  static String _generarMensaje(double lat, double lon) {
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    return 'EMERGENCIA: Necesito ayuda. Mi ubicación: $mapsUrl';
  }

  static String _normalizarTelefono(String telefono) {
    return telefono.replaceAll(RegExp(r'[^\d]'), '');
  }

  static Future<void> enviarSos({
    required List<Contacto> contactos,
    required double latitud,
    required double longitud,
  }) async {
    final mensaje = _generarMensaje(latitud, longitud);

    for (final c in contactos) {
      final tel = _normalizarTelefono(c.telefono);
      if (tel.isEmpty) continue;

      final whatsappUri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}');
      final smsUri = Uri.parse('sms:$tel?body=${Uri.encodeComponent(mensaje)}');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }
  }

  static Future<void> abrirMaps(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
