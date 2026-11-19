import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

typedef SupabaseInitializerCallback = Future<void> Function(
  SupabaseConfig config,
);

class SupabaseInitializationResult {
  const SupabaseInitializationResult({
    required this.initialized,
    required this.isProduction,
    this.error,
  });

  final bool initialized;
  final bool isProduction;
  final Object? error;

  bool get hasError => error != null;
}

class SupabaseInitializer {
  const SupabaseInitializer({
    SupabaseInitializerCallback? initialize,
    this._isInitialized,
    this._isProduction,
    this._readEnvironment,
    this._reportError,
  }) : _initialize = initialize ?? _initializeSupabase;

  final SupabaseInitializerCallback _initialize;
  final bool Function()? _isInitialized;
  final bool Function()? _isProduction;
  final String Function(String name)? _readEnvironment;
  final void Function(String event, Object error)? _reportError;

  Future<SupabaseInitializationResult> initialize() async {
    final production =
        _isProduction?.call() ?? const bool.fromEnvironment('dart.vm.product');

    try {
      SupabaseConfig config;
      try {
        config = SupabaseConfig.fromEnvironment(
          isProduction: production,
          readValue: _readEnvironment,
        );
      } on SupabaseConfigurationException catch (error) {
        _report('configuracion', error);
        return SupabaseInitializationResult(
          initialized: false,
          isProduction: production,
          error: error,
        );
      }

      if (_isInitialized?.call() ?? _isSupabaseInitialized()) {
        return SupabaseInitializationResult(
          initialized: true,
          isProduction: production,
        );
      }

      await _initialize(config);

      return SupabaseInitializationResult(
        initialized: true,
        isProduction: production,
      );
    } catch (error, stackTrace) {
      _report('inicializacion', error, stackTrace);
      return SupabaseInitializationResult(
        initialized: false,
        isProduction: production,
        error: error,
      );
    }
  }

  void _report(String event, Object error, [StackTrace? stackTrace]) {
    final reporter = _reportError;
    if (reporter != null) {
      reporter(event, error);
      return;
    }
    if (kDebugMode) {
      developer.log(
        'Supabase: fallo de $event. La app continúa sin servicios de Supabase.',
        name: 'alerta_sismica.supabase',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _isSupabaseInitialized() {
    try {
      return Supabase.instance.isInitialized;
    } on AssertionError {
      return false;
    }
  }

  static Future<void> _initializeSupabase(SupabaseConfig config) {
    return Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
    );
  }
}
