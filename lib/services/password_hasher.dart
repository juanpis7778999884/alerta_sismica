import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Derivación PBKDF2-HMAC-SHA256 con sal aleatoria.
///
/// Se usa para no almacenar contraseñas ni códigos de recuperación en texto
/// plano. Las credenciales quedan en el almacenamiento privado de la app.
class PasswordHasher {
  const PasswordHasher({this.iteraciones = 60000});

  final int iteraciones;

  static const String _alfabetoRecuperacion =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String generarSalt([int longitudBytes = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(longitudBytes, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String derivar(String password, String saltBase64, {int? iteraciones}) {
    final rondas = iteraciones ?? this.iteraciones;
    final salt = base64Decode(saltBase64);
    final hmac = Hmac(sha256, utf8.encode(password));
    final bloque = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(bloque).bytes;
    final resultado = List<int>.from(u);

    for (var i = 1; i < rondas; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < resultado.length; j++) {
        resultado[j] ^= u[j];
      }
    }

    return base64Encode(resultado);
  }

  bool verificar(
    String password,
    String saltBase64,
    String hashEsperado, {
    int? iteraciones,
  }) {
    final calculado = derivar(password, saltBase64, iteraciones: iteraciones);
    return _comparacionTiempoConstante(calculado, hashEsperado);
  }

  String generarCodigoRecuperacion() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buffer.write(
        _alfabetoRecuperacion[random.nextInt(_alfabetoRecuperacion.length)],
      );
    }
    return buffer.toString();
  }

  String formatearCodigo(String codigo) {
    final limpio = codigo.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (limpio.length != 12) return limpio;
    return '${limpio.substring(0, 4)}-${limpio.substring(4, 8)}-${limpio.substring(8)}';
  }

  String generarToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  bool _comparacionTiempoConstante(String a, String b) {
    final bytesA = utf8.encode(a);
    final bytesB = utf8.encode(b);
    if (bytesA.length != bytesB.length) return false;
    var diferencia = 0;
    for (var i = 0; i < bytesA.length; i++) {
      diferencia |= bytesA[i] ^ bytesB[i];
    }
    return diferencia == 0;
  }
}
