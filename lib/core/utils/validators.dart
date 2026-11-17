class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _nombre = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' .-]{2,60}$");

  static String? nombre(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el nombre del contacto.';
    if (texto.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (texto.length > 60) return 'El nombre no puede superar 60 caracteres.';
    if (!_nombre.hasMatch(texto)) {
      return 'Usa solo letras, espacios, puntos, guiones o apóstrofes.';
    }
    return null;
  }

  static String? nombreUsuario(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe tu nombre.';
    if (texto.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (texto.length > 80) return 'El nombre no puede superar 80 caracteres.';
    return null;
  }

  static String? telefono(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el número de teléfono.';
    final digitos = normalizarTelefono(texto);
    if (digitos.length < 7) {
      return 'El teléfono debe tener al menos 7 dígitos.';
    }
    if (digitos.length > 15) {
      return 'El teléfono no puede superar 15 dígitos.';
    }
    if (RegExp(r'^0+$').hasMatch(digitos)) {
      return 'El teléfono no es válido.';
    }
    return null;
  }

  static String? email(String? valor) {
    final texto = (valor ?? '').trim().toLowerCase();
    if (texto.isEmpty) return 'Escribe tu correo electrónico.';
    if (texto.length > 254) return 'El correo es demasiado largo.';
    if (!_email.hasMatch(texto)) return 'El correo electrónico no es válido.';
    return null;
  }

  static String? password(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Escribe una contraseña.';
    if (texto.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (texto.length > 128) return 'La contraseña es demasiado larga.';
    if (!RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(texto) ||
        !RegExp(r'\d').hasMatch(texto)) {
      return 'La contraseña debe incluir al menos una letra y un número.';
    }
    return null;
  }

  static String? confirmarPassword(String? valor, String password) {
    if ((valor ?? '').isEmpty) return 'Confirma la contraseña.';
    if (valor != password) return 'Las contraseñas no coinciden.';
    return null;
  }

  static String? codigoRecuperacion(String? valor) {
    final limpio = normalizarCodigoRecuperacion(valor ?? '');
    if (limpio.isEmpty) return 'Escribe el código de recuperación.';
    if (limpio.length != 12) return 'El código debe tener 12 caracteres.';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(limpio)) {
      return 'El código solo contiene letras y números.';
    }
    return null;
  }

  static String? numeroEmergencia(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final digitos = normalizarTelefono(texto);
    if (digitos.length < 3 || digitos.length > 15) {
      return 'El número de emergencia no es válido.';
    }
    return null;
  }

  static String normalizarTelefono(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizarCodigoRecuperacion(String valor) {
    return valor.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  static bool telefonosIguales(String a, String b) {
    final na = normalizarTelefono(a);
    final nb = normalizarTelefono(b);
    if (na.length >= 10 && nb.length >= 10) {
      return na.substring(na.length - 10) == nb.substring(nb.length - 10);
    }
    return na == nb;
  }

  static String formatearTelefono(String valor) {
    final digitos = normalizarTelefono(valor);
    if (digitos.length == 10) {
      return '${digitos.substring(0, 3)} ${digitos.substring(3, 6)} ${digitos.substring(6)}';
    }
    return valor.trim();
  }
}
