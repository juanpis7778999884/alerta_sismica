import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/sync/supabase_gateway.dart';
import '../models/usuario.dart';
import '../repositories/auth_repository.dart';

enum EstadoAuth { inicial, cargando, autenticado, noAutenticado }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository() {
    _suscripcion = _repository.cambiosSesion.listen(_atenderCambioSesion);
  }

  final AuthRepository _repository;
  StreamSubscription<SupabaseAuthEvent>? _suscripcion;

  EstadoAuth _estado = EstadoAuth.inicial;
  UsuarioLocal? _usuario;
  String? _error;
  bool _hayCuenta = false;
  bool _operando = false;

  EstadoAuth get estado => _estado;
  UsuarioLocal? get usuario => _usuario;
  String? get error => _error;
  bool get hayCuentaLocal => _hayCuenta;
  bool get operando => _operando;
  bool get autenticado => _estado == EstadoAuth.autenticado && _usuario != null;
  bool get inicializando =>
      _estado == EstadoAuth.inicial || _estado == EstadoAuth.cargando;

  Future<void> inicializar() async {
    _estado = EstadoAuth.cargando;
    _error = null;
    notifyListeners();
    try {
      _hayCuenta = await _repository.existeCuenta();
      final usuario = await _repository.restaurarSesion();
      _usuario = usuario;
      _estado = usuario == null
          ? EstadoAuth.noAutenticado
          : EstadoAuth.autenticado;
    } catch (error) {
      _usuario = null;
      _estado = EstadoAuth.noAutenticado;
      _error = _describir(error);
      _hayCuenta = await _consultarCuentaSegura();
    }
    notifyListeners();
  }

  Future<ResultadoRegistro> registrar({
    required String nombre,
    required String email,
    required String password,
    required bool recordarSesion,
  }) async {
    _operando = true;
    _error = null;
    notifyListeners();
    try {
      final resultado = await _repository.registrar(
        nombre: nombre,
        email: email,
        password: password,
        recordarSesion: recordarSesion,
      );
      _usuario = resultado.usuario;
      _hayCuenta = true;
      _estado = EstadoAuth.autenticado;
      return resultado;
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      const fallo = AppException(
        'No se pudo crear la cuenta local. Inténtalo de nuevo.',
      );
      _error = fallo.message;
      throw fallo;
    } finally {
      _operando = false;
      notifyListeners();
    }
  }

  Future<UsuarioLocal> iniciarSesion({
    required String email,
    required String password,
    required bool recordarSesion,
  }) async {
    _operando = true;
    _error = null;
    notifyListeners();
    try {
      final usuario = await _repository.iniciarSesion(
        email: email,
        password: password,
        recordarSesion: recordarSesion,
      );
      _usuario = usuario;
      _hayCuenta = true;
      _estado = EstadoAuth.autenticado;
      return usuario;
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      const fallo = AppException(
        'No se pudo iniciar sesión. Inténtalo de nuevo.',
      );
      _error = fallo.message;
      throw fallo;
    } finally {
      _operando = false;
      notifyListeners();
    }
  }

  Future<String> recuperarPassword({
    required String email,
    required String codigoRecuperacion,
    required String nuevoPassword,
  }) async {
    _operando = true;
    _error = null;
    notifyListeners();
    try {
      final nuevoCodigo = await _repository.recuperarPassword(
        email: email,
        codigoRecuperacion: codigoRecuperacion,
        nuevoPassword: nuevoPassword,
      );
      _usuario = null;
      _estado = EstadoAuth.noAutenticado;
      return nuevoCodigo;
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      const fallo = AppException(
        'No se pudo restablecer la contraseña. Inténtalo de nuevo.',
      );
      _error = fallo.message;
      throw fallo;
    } finally {
      _operando = false;
      notifyListeners();
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await _repository.cerrarSesion();
    } catch (_) {
      // La sesión en memoria se cierra aunque falle el almacenamiento.
    }
    _usuario = null;
    _estado = EstadoAuth.noAutenticado;
    _error = null;
    notifyListeners();
  }

  Future<bool> eliminarCuentaLocal() async {
    _operando = true;
    notifyListeners();
    try {
      await _repository.eliminarCuentaLocal();
      _usuario = null;
      _hayCuenta = false;
      _estado = EstadoAuth.noAutenticado;
      _error = null;
      return true;
    } catch (error) {
      _error = 'No se pudo eliminar la cuenta local.';
      return false;
    } finally {
      _operando = false;
      notifyListeners();
    }
  }

  Future<bool> consultarExistenciaCuenta() async {
    _hayCuenta = await _consultarCuentaSegura();
    notifyListeners();
    return _hayCuenta;
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _consultarCuentaSegura() async {
    try {
      return await _repository.existeCuenta();
    } catch (_) {
      return false;
    }
  }

  String _describir(Object error) {
    if (error is AppException) return error.message;
    return 'No se pudo recuperar la sesión local.';
  }

  void _atenderCambioSesion(SupabaseAuthEvent evento) {
    if (evento.kind != SupabaseAuthEventKind.signedOut) return;
    if (_usuario == null && _estado != EstadoAuth.autenticado) return;
    _usuario = null;
    _estado = EstadoAuth.noAutenticado;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    super.dispose();
  }
}
