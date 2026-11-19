import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/sync/supabase_gateway.dart';
import '../core/sync/supabase_sync_queue.dart';
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
  AuthRepository({
    PasswordHasher? hasher,
    Uuid? uuid,
    Duration? duracionSesion,
    SupabaseGateway? gateway,
    this._sync,
  }) : _hasher = hasher ?? const PasswordHasher(),
       _uuid = uuid ?? const Uuid(),
       _duracionSesion = duracionSesion ?? const Duration(days: 30),
       _gateway = gateway ?? FlutterSupabaseGateway();

  static const String _claveCuenta = 'auth_cuenta_v1';
  static const String _claveSesion = 'auth_sesion_v1';
  static const String _claveRecordar = 'auth_recordar_supabase_v1';

  final PasswordHasher _hasher;
  final Uuid _uuid;
  final Duration _duracionSesion;
  final SupabaseGateway _gateway;
  final SupabaseSyncQueue? _sync;

  Stream<SupabaseAuthEvent> get cambiosSesion => _gateway.authStateChanges;

  bool get _supabaseActivo => _gateway.isReady;

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
    final nombreLimpio = nombre.trim();
    final emailLimpio = email.trim().toLowerCase();
    final errorNombre = Validators.nombreUsuario(nombreLimpio);
    if (errorNombre != null) throw ValidationException(errorNombre);
    final errorEmail = Validators.email(emailLimpio);
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

    final legacyId = _uuid.v4();
    var usuario = UsuarioLocal(
      id: legacyId,
      nombre: nombreLimpio,
      email: emailLimpio,
      creadoEn: DateTime.now(),
    );
    final codigoRecuperacion = _hasher.generarCodigoRecuperacion();
    final credenciales = _crearCredenciales(password, codigoRecuperacion);

    String? remoteId;
    if (_supabaseActivo) {
      final remoto = await _gateway.signUp(
        email: emailLimpio,
        password: password,
        nombre: nombreLimpio,
      );
      if (remoto.outcome == SupabaseAuthOutcome.confirmationRequired) {
        throw const AuthException(
          'Revisa tu correo para confirmar la cuenta antes de ingresar.',
          codigo: 'confirmacion_pendiente',
        );
      }
      if (remoto.identity == null) {
        throw const AuthException(
          'No se pudo crear la cuenta. Inténtalo de nuevo.',
          codigo: 'supabase_registro',
        );
      }
      final identidad = remoto.identity!;
      remoteId = identidad.id;
      usuario = UsuarioLocal(
        id: identidad.id,
        nombre: nombreLimpio,
        email: identidad.email,
        creadoEn: DateTime.now(),
      );
      await prefs.setBool(_claveRecordar, recordarSesion);
    }

    final cuenta = <String, dynamic>{
      'usuario': usuario.toJson(),
      'credenciales': credenciales,
      'legacyLocalId': legacyId,
      'remoteId': remoteId,
      'vinculado': remoteId != null,
      'pendienteConfirmacion': false,
    };
    final guardado = await prefs.setString(_claveCuenta, jsonEncode(cuenta));
    if (!guardado) {
      throw const StorageException('No se pudo guardar la cuenta local.');
    }

    if (remoteId != null) {
      await _asegurarPerfil(
        SupabaseIdentity(
          id: remoteId,
          email: usuario.email,
          nombre: usuario.nombre,
        ),
        legacyId,
      );
      await _asegurarAjustes(remoteId);
    } else {
      await prefs.remove(_claveRecordar);
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

    final usuarioLocal = _validarCredencialesLocal(
      cuenta: cuenta,
      email: email,
      password: password,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveRecordar, _supabaseActivo ? recordarSesion : false);

    if (!_supabaseActivo) {
      if (recordarSesion) {
        await _guardarSesion(usuarioLocal);
      } else {
        await prefs.remove(_claveSesion);
      }
      return usuarioLocal;
    }

    final correo = usuarioLocal.email;
    final vinculado = cuenta['vinculado'] == true || cuenta['remoteId'] != null;
    SupabaseAuthResult remoto;
    if (vinculado) {
      remoto = await _gateway.signIn(email: correo, password: password);
    } else {
      remoto = await _gateway.signIn(email: correo, password: password);
      if (remoto.outcome == SupabaseAuthOutcome.invalidCredentials) {
        remoto = await _gateway.signUp(
          email: correo,
          password: password,
          nombre: usuarioLocal.nombre,
        );
      }
    }

    if (remoto.outcome == SupabaseAuthOutcome.confirmationRequired) {
      throw const AuthException(
        'Revisa tu correo para confirmar la cuenta antes de ingresar.',
        codigo: 'confirmacion_pendiente',
      );
    }
    if (remoto.identity == null) {
      throw const AuthException(
        'No se pudo iniciar sesión. Inténtalo de nuevo.',
        codigo: 'supabase_login',
      );
    }

    return _vincularSesion(
      cuenta: cuenta,
      identidad: remoto.identity!,
      recordarSesion: recordarSesion,
    );
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
    final nuevasCredenciales = _crearCredenciales(
      nuevoPassword,
      nuevoCodigo,
    );
    final nuevaCuenta = Map<String, dynamic>.from(cuenta)
      ..['usuario'] = usuario.toJson()
      ..['credenciales'] = nuevasCredenciales;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveCuenta, jsonEncode(nuevaCuenta));
    await prefs.remove(_claveSesion);

    if (_supabaseActivo) {
      try {
        if (_gateway.currentUserId != null) {
          await _gateway.updatePassword(nuevoPassword);
        } else {
          await _gateway.requestPasswordReset(usuario.email);
        }
      } catch (_) {}
    }

    return nuevoCodigo;
  }

  Future<UsuarioLocal?> restaurarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final recordar = prefs.getBool(_claveRecordar) ?? true;

    if (!_supabaseActivo) {
      await prefs.remove(_claveRecordar);
      return _restaurarSesionLocal(prefs);
    }

    if (!recordar) {
      await _gateway.signOut();
      await prefs.remove(_claveSesion);
      return null;
    }

    final identidad = await _gateway.restoreSession();
    if (identidad == null) {
      await prefs.remove(_claveSesion);
      return null;
    }

    final cuenta = await _leerCuenta();
    if (cuenta == null) {
      await prefs.remove(_claveSesion);
      return null;
    }

    final usuario = _usuarioDesdeCuenta(cuenta);
    if (usuario.id == identidad.id &&
        cuenta['remoteId'] == identidad.id &&
        cuenta['vinculado'] == true) {
      await _asegurarPerfil(
        identidad,
        cuenta['legacyLocalId'] as String?,
        nombre: usuario.nombre,
      );
      await _asegurarAjustes(identidad.id);
      await _guardarSesion(usuario);
      return usuario;
    }

    return _vincularSesion(
      cuenta: cuenta,
      identidad: identidad,
      recordarSesion: true,
    );
  }

  Future<void> cerrarSesion() async {
    if (_supabaseActivo) {
      try {
        await _gateway.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
    await prefs.setBool(_claveRecordar, false);
  }

  Future<void> eliminarCuentaLocal() async {
    if (_supabaseActivo) {
      try {
        await _gateway.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveCuenta);
    await prefs.remove(_claveSesion);
    await prefs.remove(_claveRecordar);
  }

  Map<String, dynamic> _crearCredenciales(
    String password,
    String codigoRecuperacion,
  ) {
    final saltPassword = _hasher.generarSalt();
    final saltRecuperacion = _hasher.generarSalt();
    return {
      'saltPassword': saltPassword,
      'hashPassword': _hasher.derivar(password, saltPassword),
      'iteraciones': _hasher.iteraciones,
      'saltRecuperacion': saltRecuperacion,
      'hashRecuperacion': _hasher.derivar(
        codigoRecuperacion,
        saltRecuperacion,
      ),
    };
  }

  UsuarioLocal _validarCredencialesLocal({
    required Map<String, dynamic> cuenta,
    required String email,
    required String password,
  }) {
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
    return usuario;
  }

  Future<UsuarioLocal> _vincularSesion({
    required Map<String, dynamic> cuenta,
    required SupabaseIdentity identidad,
    required bool recordarSesion,
  }) async {
    final usuarioAnterior = _usuarioDesdeCuenta(cuenta);
    final anteriorId = usuarioAnterior.id;
    final legacyId =
        (cuenta['legacyLocalId'] as String?) ??
        (cuenta['remoteId'] as String?) ??
        anteriorId;
    final usuario = UsuarioLocal(
      id: identidad.id,
      nombre: usuarioAnterior.nombre,
      email: identidad.email,
      creadoEn: usuarioAnterior.creadoEn,
    );

    final cuentaActualizada = Map<String, dynamic>.from(cuenta)
      ..['usuario'] = usuario.toJson()
      ..['legacyLocalId'] = legacyId
      ..['remoteId'] = identidad.id
      ..['vinculado'] = true
      ..['pendienteConfirmacion'] = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveCuenta, jsonEncode(cuentaActualizada));

    if (anteriorId != identidad.id) {
      await _sync?.rebindUser(anteriorId, identidad.id);
    }

    await _asegurarPerfil(identidad, legacyId, nombre: usuario.nombre);
    await _asegurarAjustes(identidad.id);

    if (recordarSesion) {
      await _guardarSesion(usuario);
    } else {
      await prefs.remove(_claveSesion);
    }

    return usuario;
  }

  Future<void> _asegurarPerfil(
    SupabaseIdentity identidad,
    String? legacyId, {
    String? nombre,
  }) async {
    if (!_supabaseActivo) return;
    final nombrePerfil = (nombre ?? identidad.nombre).trim().isNotEmpty
        ? (nombre ?? identidad.nombre).trim()
        : identidad.nombre;
    try {
      final filas = await _gateway.selectRows(
        'profiles',
        filters: {'id': identidad.id},
      );
      if (filas.isEmpty) {
        final valores = <String, dynamic>{
          'id': identidad.id,
          'nombre': nombrePerfil,
          'email': identidad.email,
          'cliente_actualizado_en': DateTime.now().toUtc().toIso8601String(),
        };
        if (legacyId != null) valores['legacy_local_id'] = legacyId;
        await _gateway.upsertRow(
          table: 'profiles',
          keys: {'id': identidad.id},
          insertValues: valores,
          updateValues: {
            'nombre': nombrePerfil,
            'cliente_actualizado_en':
                DateTime.now().toUtc().toIso8601String(),
          },
        );
        return;
      }
      await _gateway.upsertRow(
        table: 'profiles',
        keys: {'id': identidad.id},
        insertValues: {
          'id': identidad.id,
          'nombre': nombrePerfil,
          'email': identidad.email,
          'cliente_actualizado_en': DateTime.now().toUtc().toIso8601String(),
        },
        updateValues: {
          'nombre': nombrePerfil,
          'cliente_actualizado_en': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<void> _asegurarAjustes(String userId) async {
    if (!_supabaseActivo) return;
    try {
      final filas = await _gateway.selectRows(
        'user_settings',
        filters: {'user_id': userId},
      );
      if (filas.isNotEmpty) return;
      await _gateway.upsertRow(
        table: 'user_settings',
        keys: {'user_id': userId},
        insertValues: {
          'user_id': userId,
          'tema': 'claro',
          'magnitud_minima': 2.5,
          'auto_refresco': true,
          'notificar_sismos': false,
          'umbral_notificacion': 4.5,
          'numero_emergencia': '',
          'cliente_actualizado_en': DateTime.now().toUtc().toIso8601String(),
        },
        updateValues: {},
      );
    } catch (_) {}
  }

  Future<UsuarioLocal?> _restaurarSesionLocal(SharedPreferences prefs) async {
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
    } catch (_) {}
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
