import 'dart:convert';

import 'package:flutter/services.dart';

import 'supabase_config.dart';

class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig._();

  static const String _asset = 'assets/supabase.env.json';

  static Future<Map<String, String>> cargar({AssetBundle? bundle}) async {
    final valores = <String, String>{
      SupabaseConfig.urlEnvironmentKey: String.fromEnvironment(
        SupabaseConfig.urlEnvironmentKey,
      ),
      SupabaseConfig.publishableKeyEnvironmentKey: String.fromEnvironment(
        SupabaseConfig.publishableKeyEnvironmentKey,
      ),
    };

    final url = valores[SupabaseConfig.urlEnvironmentKey] ?? '';
    final key = valores[SupabaseConfig.publishableKeyEnvironmentKey] ?? '';
    if (url.trim().isNotEmpty && key.trim().isNotEmpty) return valores;

    try {
      final raw = await (bundle ?? rootBundle).loadString(_asset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return valores;
      for (final nombre in valores.keys.toList()) {
        final valor = decoded[nombre];
        if (valor is! String) continue;
        if (valores[nombre]!.trim().isEmpty) valores[nombre] = valor.trim();
      }
    } catch (_) {}

    return valores;
  }
}
