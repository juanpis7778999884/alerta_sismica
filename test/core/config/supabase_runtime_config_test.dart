import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alerta_sismica/core/config/supabase_config.dart';
import 'package:alerta_sismica/core/config/supabase_runtime_config.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._data);

  final Map<String, String> _data;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _data[key];
    if (value == null) throw StateError('Asset no encontrado: $key');
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    throw StateError('Asset binario no usado: $key');
  }
}

void main() {
  test('carga la configuración desde el asset incluido', () async {
    final bundle = _FakeAssetBundle({
      'assets/supabase.env.json':
          '{"SUPABASE_URL":"https://example.supabase.co",'
          '"SUPABASE_PUBLISHABLE_KEY":"sb_publishable_test_key"}',
    });

    final config = await SupabaseRuntimeConfig.cargar(bundle: bundle);

    expect(
      config[SupabaseConfig.urlEnvironmentKey],
      'https://example.supabase.co',
    );
    expect(
      config[SupabaseConfig.publishableKeyEnvironmentKey],
      'sb_publishable_test_key',
    );
  });

  test('no falla si el asset no existe', () async {
    final bundle = _FakeAssetBundle({});

    final config = await SupabaseRuntimeConfig.cargar(bundle: bundle);

    expect(config[SupabaseConfig.urlEnvironmentKey], isEmpty);
    expect(config[SupabaseConfig.publishableKeyEnvironmentKey], isEmpty);
  });
}
