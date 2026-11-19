class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'SupabaseConfigurationException: $message';
}

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
    required this.isProduction,
  });

  static const String urlEnvironmentKey = 'SUPABASE_URL';
  static const String publishableKeyEnvironmentKey = 'SUPABASE_PUBLISHABLE_KEY';

  final String url;
  final String publishableKey;
  final bool isProduction;

  factory SupabaseConfig.fromEnvironment({
    bool? isProduction,
    String Function(String name)? readValue,
  }) {
    final production =
        isProduction ?? const bool.fromEnvironment('dart.vm.product');
    final read = readValue ?? _readFromEnvironment;
    return SupabaseConfig.validate(
      url: read(urlEnvironmentKey),
      publishableKey: read(publishableKeyEnvironmentKey),
      isProduction: production,
    );
  }

  static String _readFromEnvironment(String name) =>
      String.fromEnvironment(name);

  factory SupabaseConfig.validate({
    required String url,
    required String publishableKey,
    required bool isProduction,
  }) {
    final trimmedUrl = url.trim();
    final trimmedKey = publishableKey.trim();

    if (trimmedUrl.isEmpty) {
      throw const SupabaseConfigurationException(
        'Falta SUPABASE_URL. Define la variable mediante --dart-define-from-file.',
      );
    }
    if (trimmedKey.isEmpty) {
      throw const SupabaseConfigurationException(
        'Falta SUPABASE_PUBLISHABLE_KEY. Define la variable mediante '
        '--dart-define-from-file.',
      );
    }

    final keyLower = trimmedKey.toLowerCase();
    if (_containsAdministrativeCredential(keyLower)) {
      throw const SupabaseConfigurationException(
        'Se detectó una clave administrativa o secreta. El cliente Flutter '
        'solo debe usar la Publishable key.',
      );
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL no es una URI válida.',
      );
    }
    if (!uri.scheme.toLowerCase().contains('http')) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL debe usar el esquema http o https.',
      );
    }
    if (isProduction && uri.scheme.toLowerCase() != 'https') {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL debe usar HTTPS en producción.',
      );
    }
    if (uri.host.isEmpty || !_isPlausibleHost(uri.host)) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL no contiene un host válido.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL no debe contener credenciales incrustadas.',
      );
    }
    if (_containsUrlCredential(trimmedUrl)) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL no debe contener credenciales incrustadas.',
      );
    }

    return SupabaseConfig(
      url: trimmedUrl,
      publishableKey: trimmedKey,
      isProduction: isProduction,
    );
  }

  static bool _containsAdministrativeCredential(String key) {
    return key.contains('service_role') ||
        key.contains('service-role') ||
        key.contains('sb_secret_') ||
        key.contains('secret_key') ||
        key.contains('secret-key') ||
        key.contains('private_key') ||
        key.contains('private-key');
  }

  static bool _containsUrlCredential(String url) {
    final pattern = RegExp(
      r'(?:^|[/?&])(?:token|key|password|secret|apikey)=',
      caseSensitive: false,
    );
    return pattern.hasMatch(url);
  }

  static bool _isPlausibleHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    final hostPattern = RegExp(
      r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+'
      r'[a-z]{2,63}$',
      caseSensitive: false,
    );
    return hostPattern.hasMatch(host);
  }
}
