import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'supabase_config.dart';

enum SupabaseRemoteStatus {
  notChecked,
  accessible,
  networkError,
  authorizationError,
  endpointError,
}

class SupabaseRemoteProbeResult {
  const SupabaseRemoteProbeResult({
    required this.status,
    this.statusCode,
    this.detail,
  });

  final SupabaseRemoteStatus status;
  final int? statusCode;
  final String? detail;

  bool get isAccessible => status == SupabaseRemoteStatus.accessible;
}

class SupabaseRemoteProbe {
  const SupabaseRemoteProbe({this.client})
    : _timeout = const Duration(seconds: 15);

  final http.Client? client;
  final Duration _timeout;

  static const String healthPath = '/auth/v1/health';

  Future<SupabaseRemoteProbeResult> check(SupabaseConfig config) async {
    final http.Client activeClient = client ?? http.Client();
    try {
      final Uri uri = Uri.parse(config.url)
          .replace(path: healthPath, query: '', fragment: '');
      final http.Response response = await activeClient
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'apikey': config.publishableKey,
            },
          )
          .timeout(_timeout);
      final int code = response.statusCode;
      if (code >= 200 && code < 300) {
        return SupabaseRemoteProbeResult(
          status: SupabaseRemoteStatus.accessible,
          statusCode: code,
        );
      }
      if (code == 401 || code == 403) {
        return SupabaseRemoteProbeResult(
          status: SupabaseRemoteStatus.authorizationError,
          statusCode: code,
          detail: 'El proyecto respondió con un error de autorización.',
        );
      }
      return SupabaseRemoteProbeResult(
        status: SupabaseRemoteStatus.endpointError,
        statusCode: code,
        detail: 'El endpoint de salud respondió con un estado inesperado.',
      );
    } on SocketException {
      return const SupabaseRemoteProbeResult(
        status: SupabaseRemoteStatus.networkError,
        detail: 'No se pudo alcanzar el host de Supabase.',
      );
    } on TimeoutException {
      return const SupabaseRemoteProbeResult(
        status: SupabaseRemoteStatus.networkError,
        detail: 'Tiempo de espera agotado al contactar Supabase.',
      );
    } on http.ClientException {
      return const SupabaseRemoteProbeResult(
        status: SupabaseRemoteStatus.networkError,
        detail: 'Error de red al contactar Supabase.',
      );
    } catch (_) {
      return const SupabaseRemoteProbeResult(
        status: SupabaseRemoteStatus.endpointError,
        detail: 'Error inesperado durante la comprobación remota.',
      );
    } finally {
      if (client == null) {
        activeClient.close();
      }
    }
  }
}
