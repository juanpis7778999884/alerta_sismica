import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/usuario.dart';
import '../services/password_hasher.dart';

class ResultadoRegistro {
  const ResultadoRegistro({
    required this.usuario,
    required this.codigoRecuperacion,
  });

  final UsuarioLocal usuario;
  final String codigoRecuperacion;
}

class AuthRepository {
  AuthRepository({PasswordHasher? hasher, Uuid? uuid, Duration? duracionSesion})
    : _hasher = hasher ?? const PasswordHasher(),
      _uuid = uuid ?? const Uuid(),
      _duracionSesion = duracionSesion ?? const Duration(days: 30);

  static const String _claveCuenta = 'auth_cuenta_v1';
  static const String _claveSesion = 'auth_sesion_v1';

  final PasswordHasher _hasher;
  final Uuid _uuid;
  final Duration _duracionSesion;

  Future<bool> existeCuenta() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_claveCuenta);
  }

  Future<UsuarioLocal?> usuarioGuardado() async {
    final cuenta = await _leerCuenta();
    if (cuenta == null) return null;
    return _usuarioDesdeCuenta(cuenta);
  }

  Future<ResultadoRegistro> registrar({
    required String nombre,
    required String email,
    required String password,
    required bool recordarSesion,
  }) async {
    final errorNombre = Validators.nombreUsuario(nombre);
    if (errorNombre != null) throw ValidationException(errorNombre);
    final errorEmail = Validators.email(email);
    if (errorEmail != null) throw ValidationException(errorEmail);
    final errorPassword = Validators.password(password);
    if (errorPassword != null) throw ValidationException(errorPassword);

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_claveCuenta)) {
      throw const AuthException(
        'Ya existe una cuenta local en este dispositivo.',
        codigo: 'cuenta_existente',
      );
    }

    final usuario = UsuarioLocal(
      id: _uuid.v4(),
      nombre: nombre.trim(),
      email: email.trim().toLowerCase(),
      creadoEn: DateTime.now(),
    );
    final codigoRecuperacion = _hasher.generarCodigoRecuperacion();
    final saltPassword = _hasher.generarSalt();
    final saltRecuperacion = _hasher.generarSalt();

    final cuenta = {
      'usuario': usuario.toJson(),
      'credenciales': {
        'saltPassword': saltPassword,
        'hashPassword': _hasher.derivar(password, saltPassword),
        'iteraciones': _hasher.iteraciones,
        'saltRecuperacion': saltRecuperacion,
        'hashRecuperacion': _hasher.derivar(
          codigoRecuperacion,
          saltRecuperacion,
        ),
      },
    };

    final guardado = await prefs.setString(_claveCuenta, jsonEncode(cuenta));
    if (!guardado) {
      throw const StorageException('No se pudo guardar la cuenta local.');
    }

    if (recordarSesion) {
      await _guardarSesion(usuario);
    } else {
      await prefs.remove(_claveSesion);
    }

    return ResultadoRegistro(
      usuario: usuario,
      codigoRecuperacion: codigoRecuperacion,
    );
  }

  Future<UsuarioLocal> iniciarSesion({
    required String email,
    required String password,
    required bool recordarSesion,
  }) async {
    final errorEmail = Validators.email(email);
    if (errorEmail != null) throw ValidationException(errorEmail);
    if (password.isEmpty) {
      throw const ValidationException('Escribe tu contraseña.');
    }

    final cuenta = await _leerCuenta();
    if (cuenta == null) {
      throw const AuthException(
        'No hay una cuenta local. Crea una cuenta para continuar.',
        codigo: 'sin_cuenta',
      );
    }

    final usuario = _usuarioDesdeCuenta(cuenta);
    final credenciales = _credencialesDesdeCuenta(cuenta);
    final coincideEmail =
        usuario.email.toLowerCase() == email.trim().toLowerCase();
    final salt = credenciales['saltPassword'] as String? ?? '';
    final hash = credenciales['hashPassword'] as String? ?? '';
    final iteraciones =
        (credenciales['iteraciones'] as num?)?.toInt() ?? _hasher.iteraciones;

    final passwordValida =
        salt.isNotEmpty &&
        hash.isNotEmpty &&
        _hasher.verificar(password, salt, hash, iteraciones: iteraciones);

    if (!coincideEmail || !passwordValida) {
      throw const AuthException(
        'Correo o contraseña incorrectos.',
        codigo: 'credenciales_invalidas',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    if (recordarSesion) {
      await _guardarSesion(usuario);
    } else {
      await prefs.remove(_claveSesion);
    }
    return usuario;
  }

  Future<String> recuperarPassword({
    required String email,
    required String codigoRecuperacion,
    required String nuevoPassword,
  }) async {
    final errorEmail = Validators.email(email);
    if (errorEmail != null) throw ValidationException(errorEmail);
    final errorCodigo = Validators.codigoRecuperacion(codigoRecuperacion);
    if (errorCodigo != null) throw ValidationException(errorCodigo);
    final errorPassword = Validators.password(nuevoPassword);
    if (errorPassword != null) throw ValidationException(errorPassword);

    final cuenta = await _leerCuenta();
    if (cuenta == null) {
      throw const AuthException(
        'No hay una cuenta local en este dispositivo.',
        codigo: 'sin_cuenta',
      );
    }
    final usuario = _usuarioDesdeCuenta(cuenta);
    final credenciales = _credencialesDesdeCuenta(cuenta);
    final saltRecuperacion = credenciales['saltRecuperacion'] as String? ?? '';
    final hashRecuperacion = credenciales['hashRecuperacion'] as String? ?? '';
    final iteraciones =
        (credenciales['iteraciones'] as num?)?.toInt() ?? _hasher.iteraciones;
    final codigoNormalizado = Validators.normalizarCodigoRecuperacion(
      codigoRecuperacion,
    );

    final coincideEmail =
        usuario.email.toLowerCase() == email.trim().toLowerCase();
    final codigoValido =
        saltRecuperacion.isNotEmpty &&
        hashRecuperacion.isNotEmpty &&
        _hasher.verificar(
          codigoNormalizado,
          saltRecuperacion,
          hashRecuperacion,
          iteraciones: iteraciones,
        );

    if (!coincideEmail || !codigoValido) {
      throw const AuthException(
        'Correo o código de recuperación incorrectos.',
        codigo: 'codigo_invalido',
      );
    }

    final nuevoCodigo = _hasher.generarCodigoRecuperacion();
    final saltPassword = _hasher.generarSalt();
    final saltRecuperacionNuevo = _hasher.generarSalt();
    final nuevaCuenta = {
      'usuario': usuario.toJson(),
      'credenciales': {
        'saltPassword': saltPassword,
        'hashPassword': _hasher.derivar(nuevoPassword, saltPassword),
        'iteraciones': _hasher.iteraciones,
        'saltRecuperacion': saltRecuperacionNuevo,
        'hashRecuperacion': _hasher.derivar(nuevoCodigo, saltRecuperacionNuevo),
      },
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveCuenta, jsonEncode(nuevaCuenta));
    await prefs.remove(_claveSesion);
    return nuevoCodigo;
  }

  Future<UsuarioLocal?> restaurarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveSesion);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        await prefs.remove(_claveSesion);
        return null;
      }
      final sesion = Map<String, dynamic>.from(json);
      final expira = sesion['expiraEn'] as String?;
      final expiraEn = expira == null ? null : DateTime.tryParse(expira);
      if (expiraEn == null || DateTime.now().isAfter(expiraEn.toLocal())) {
        await prefs.remove(_claveSesion);
        return null;
      }
      final usuario = await usuarioGuardado();
      if (usuario == null || usuario.id != sesion['userId']) {
        await prefs.remove(_claveSesion);
        return null;
      }
      return usuario;
    } catch (_) {
      await prefs.remove(_claveSesion);
      return null;
    }
  }

  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
  }

  Future<void> eliminarCuentaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveCuenta);
    await prefs.remove(_claveSesion);
  }

  Future<void> _guardarSesion(UsuarioLocal usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final sesion = {
      'userId': usuario.id,
      'token': _hasher.generarToken(),
      'expiraEn': DateTime.now().add(_duracionSesion).toUtc().toIso8601String(),
    };
    await prefs.setString(_claveSesion, jsonEncode(sesion));
  }

  Future<Map<String, dynamic>?> _leerCuenta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveCuenta);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return Map<String, dynamic>.from(json);
      }
    } catch (_) {
      // Cuenta corrupta: se trata como inexistente.
    }
    return null;
  }

  UsuarioLocal _usuarioDesdeCuenta(Map<String, dynamic> cuenta) {
    final usuario = cuenta['usuario'];
    if (usuario is! Map) {
      throw const AuthException(
        'La cuenta local está dañada. Restablece la aplicación.',
        codigo: 'cuenta_corrupta',
      );
    }
    try {
      return UsuarioLocal.fromJson(Map<String, dynamic>.from(usuario));
    } catch (_) {
      throw const AuthException(
        'La cuenta local está dañada. Restablece la aplicación.',
        codigo: 'cuenta_corrupta',
      );
    }
  }

  Map<String, dynamic> _credencialesDesdeCuenta(Map<String, dynamic> cuenta) {
    final credenciales = cuenta['credenciales'];
    if (credenciales is! Map) {
      throw const AuthException(
        'Las credenciales locales están dañadas.',
        codigo: 'cuenta_corrupta',
      );
    }
    return Map<String, dynamic>.from(credenciales);
  }
}
