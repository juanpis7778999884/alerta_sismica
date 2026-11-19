import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseAuthOutcome { session, confirmationRequired, invalidCredentials, networkError }

enum SupabaseAuthEventKind {
  initialSession,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  passwordRecovery,
  other,
}

class SupabaseIdentity {
  const SupabaseIdentity({
    required this.id,
    required this.email,
    required this.nombre,
  });

  final String id;
  final String email;
  final String nombre;
}

class SupabaseAuthResult {
  const SupabaseAuthResult._({
    required this.outcome,
    this.identity,
    this.code,
  });

  factory SupabaseAuthResult.session(SupabaseIdentity identity) =>
      SupabaseAuthResult._(
        outcome: SupabaseAuthOutcome.session,
        identity: identity,
      );

  factory SupabaseAuthResult.confirmationRequired() =>
      const SupabaseAuthResult._(
        outcome: SupabaseAuthOutcome.confirmationRequired,
      );

  factory SupabaseAuthResult.invalidCredentials({String? code}) =>
      SupabaseAuthResult._(
        outcome: SupabaseAuthOutcome.invalidCredentials,
        code: code,
      );

  factory SupabaseAuthResult.networkError(Object error) =>
      SupabaseAuthResult._(
        outcome: SupabaseAuthOutcome.networkError,
        code: error.runtimeType.toString(),
      );

  final SupabaseAuthOutcome outcome;
  final SupabaseIdentity? identity;
  final String? code;

  bool get ok => outcome == SupabaseAuthOutcome.session;
}

class SupabaseAuthEvent {
  const SupabaseAuthEvent({required this.kind, this.userId});

  final SupabaseAuthEventKind kind;
  final String? userId;
}

abstract class SupabaseGateway {
  bool get isReady;
  String? get currentUserId;
  Stream<SupabaseAuthEvent> get authStateChanges;

  Future<SupabaseAuthResult> signUp({
    required String email,
    required String password,
    required String nombre,
  });

  Future<SupabaseAuthResult> signIn({
    required String email,
    required String password,
  });

  Future<SupabaseIdentity?> restoreSession();
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);

  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, Object?> filters = const {},
  });

  Future<void> upsertRow({
    required String table,
    required Map<String, Object> keys,
    required Map<String, dynamic> insertValues,
    required Map<String, dynamic> updateValues,
  });
}

class FlutterSupabaseGateway implements SupabaseGateway {
  FlutterSupabaseGateway({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _effectiveClient => _client ?? Supabase.instance.client;

  @override
  bool get isReady {
    if (_client != null) return true;
    try {
      return Supabase.instance.isInitialized;
    } on AssertionError {
      return false;
    }
  }

  @override
  String? get currentUserId {
    if (!isReady) return null;
    return _effectiveClient.auth.currentUser?.id;
  }

  @override
  Stream<SupabaseAuthEvent> get authStateChanges {
    if (!isReady) return const Stream<SupabaseAuthEvent>.empty();
    return _effectiveClient.auth.onAuthStateChange.map(_mapAuthEvent);
  }

  @override
  Future<SupabaseAuthResult> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      final response = await _effectiveClient.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': nombre},
      );
      if (response.session == null) {
        return SupabaseAuthResult.confirmationRequired();
      }
      final identity = _identityDesdeUsuario(response.user, nombre: nombre);
      if (identity == null) {
        return SupabaseAuthResult.networkError(
          StateError('supabase_auth_sin_usuario'),
        );
      }
      return SupabaseAuthResult.session(identity);
    } catch (error) {
      return _mapAuthError(error);
    }
  }

  @override
  Future<SupabaseAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _effectiveClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        return SupabaseAuthResult.confirmationRequired();
      }
      final identity = _identityDesdeUsuario(
        session.user,
        nombre: email.split('@').first,
      );
      if (identity == null) {
        return SupabaseAuthResult.networkError(
          StateError('supabase_auth_sin_usuario'),
        );
      }
      return SupabaseAuthResult.session(identity);
    } catch (error) {
      return _mapAuthError(error);
    }
  }

  @override
  Future<SupabaseIdentity?> restoreSession() async {
    if (!isReady) return null;
    try {
      final session = await _effectiveClient.auth.getSession();
      if (session == null) return null;
      return _identityDesdeUsuario(
        session.user,
        nombre: session.user.userMetadata?['nombre'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!isReady) return;
    try {
      await _effectiveClient.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    if (!isReady) return;
    await _effectiveClient.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updatePassword(String password) async {
    if (!isReady) return;
    await _effectiveClient.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, Object?> filters = const {},
  }) async {
    dynamic query = _effectiveClient.from(table).select();
    filters.forEach((column, value) {
      query = query.eq(column, value);
    });
    final response = await query as List<dynamic>;
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  @override
  Future<void> upsertRow({
    required String table,
    required Map<String, Object> keys,
    required Map<String, dynamic> insertValues,
    required Map<String, dynamic> updateValues,
  }) async {
    final rows = await selectRows(table, filters: keys);
    if (rows.isEmpty) {
      await _effectiveClient.from(table).insert(insertValues);
      return;
    }
    dynamic query = _effectiveClient.from(table).update(updateValues);
    keys.forEach((column, value) {
      query = query.eq(column, value);
    });
    await query;
  }

  SupabaseIdentity? _identityDesdeUsuario(User? user, {required String nombre}) {
    if (user == null || user.id.isEmpty) return null;
    final metadataNombre = user.userMetadata?['nombre'] as String?;
    final correo = user.email?.trim().toLowerCase();
    if (correo == null || correo.isEmpty) return null;
    return SupabaseIdentity(
      id: user.id,
      email: correo,
      nombre: (metadataNombre ?? nombre).trim().isNotEmpty
          ? (metadataNombre ?? nombre).trim()
          : correo.split('@').first,
    );
  }

  SupabaseAuthEvent _mapAuthEvent(AuthState state) {
    final userId = state.session?.user.id;
    switch (state.event) {
      case AuthChangeEvent.initialSession:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.initialSession,
          userId: userId,
        );
      case AuthChangeEvent.signedIn:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.signedIn,
          userId: userId,
        );
      case AuthChangeEvent.signedOut:
        return const SupabaseAuthEvent(kind: SupabaseAuthEventKind.signedOut);
      case AuthChangeEvent.tokenRefreshed:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.tokenRefreshed,
          userId: userId,
        );
      case AuthChangeEvent.userUpdated:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.userUpdated,
          userId: userId,
        );
      case AuthChangeEvent.passwordRecovery:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.passwordRecovery,
          userId: userId,
        );
      default:
        return SupabaseAuthEvent(
          kind: SupabaseAuthEventKind.other,
          userId: userId,
        );
    }
  }

  SupabaseAuthResult _mapAuthError(Object error) {
    final mensaje = error.toString().toLowerCase();
    if (mensaje.contains('email not confirmed') ||
        mensaje.contains('email_not_confirmed')) {
      return SupabaseAuthResult.confirmationRequired();
    }
    if (mensaje.contains('already registered') ||
        mensaje.contains('already been registered') ||
        mensaje.contains('invalid login credentials') ||
        mensaje.contains('invalid_login_credentials') ||
        mensaje.contains('user not found')) {
      return SupabaseAuthResult.invalidCredentials();
    }
    return SupabaseAuthResult.networkError(error);
  }
}
