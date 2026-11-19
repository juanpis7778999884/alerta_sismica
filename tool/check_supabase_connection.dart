import 'dart:convert';
import 'dart:io';

import 'package:alerta_sismica/core/config/supabase_config.dart';
import 'package:alerta_sismica/core/config/supabase_remote_probe.dart';

Future<void> main(List<String> args) async {
  final File file = File(args.isEmpty ? 'supabase.env.json' : args.first);
  if (!file.existsSync()) {
    stdout.writeln('CONFIGURATION=missing');
    exit(2);
  }

  late final Map<String, dynamic> values;
  try {
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      stdout.writeln('CONFIGURATION=invalid');
      exit(3);
    }
    values = decoded;
  } catch (_) {
    stdout.writeln('CONFIGURATION=invalid');
    exit(3);
  }

  final Object? rawUrl = values[SupabaseConfig.urlEnvironmentKey];
  final Object? rawKey = values[SupabaseConfig.publishableKeyEnvironmentKey];
  if (rawUrl is! String ||
      rawKey is! String ||
      rawUrl.trim().isEmpty ||
      rawKey.trim().isEmpty) {
    stdout.writeln('CONFIGURATION=missing');
    exit(2);
  }

  late final SupabaseConfig config;
  try {
    config = SupabaseConfig.validate(
      url: rawUrl,
      publishableKey: rawKey,
      isProduction: false,
    );
  } on SupabaseConfigurationException {
    stdout.writeln('CONFIGURATION=invalid');
    exit(3);
  }

  stdout.writeln('CONFIGURATION=valid');
  final SupabaseRemoteProbeResult result = await const SupabaseRemoteProbe()
      .check(config);
  stdout.writeln('REMOTE=${result.status.name}');
  stdout.writeln('HTTP_STATUS=${result.statusCode ?? '-'}');
  if (result.detail != null) {
    stdout.writeln('DETAIL=${result.detail}');
  }
  exit(result.isAccessible ? 0 : 1);
}
