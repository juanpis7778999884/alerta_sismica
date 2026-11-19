import 'supabase_config.dart';
import 'supabase_initializer.dart';
import 'supabase_remote_probe.dart';

enum SupabaseConfigurationCheckStatus { missing, invalid, valid }

enum SupabaseInitializationCheckStatus { notAttempted, success, failed }

class SupabaseConnectivityReport {
  const SupabaseConnectivityReport({
    required this.configuration,
    required this.initialization,
    required this.remote,
    this.remoteResult,
  });

  final SupabaseConfigurationCheckStatus configuration;
  final SupabaseInitializationCheckStatus initialization;
  final SupabaseRemoteStatus remote;
  final SupabaseRemoteProbeResult? remoteResult;

  bool get isConnected =>
      configuration == SupabaseConfigurationCheckStatus.valid &&
      initialization == SupabaseInitializationCheckStatus.success &&
      remote == SupabaseRemoteStatus.accessible;

  @override
  String toString() {
    return 'SupabaseConnectivityReport('
        'configuration: $configuration, '
        'initialization: $initialization, '
        'remote: $remote, '
        'statusCode: ${remoteResult?.statusCode})';
  }
}

class SupabaseConnectivityCheck {
  const SupabaseConnectivityCheck({
    this.readEnvironment,
    this.initializer,
    this.probe,
  });

  final String Function(String name)? readEnvironment;
  final SupabaseInitializer? initializer;
  final SupabaseRemoteProbe? probe;

  Future<SupabaseConnectivityReport> run() async {
    final String Function(String name) read =
        readEnvironment ?? (String name) => String.fromEnvironment(name);
    final String rawUrl = read(SupabaseConfig.urlEnvironmentKey).trim();
    final String rawKey = read(SupabaseConfig.publishableKeyEnvironmentKey)
        .trim();

    if (rawUrl.isEmpty || rawKey.isEmpty) {
      return const SupabaseConnectivityReport(
        configuration: SupabaseConfigurationCheckStatus.missing,
        initialization: SupabaseInitializationCheckStatus.notAttempted,
        remote: SupabaseRemoteStatus.notChecked,
      );
    }

    late final SupabaseConfig config;
    try {
      config = SupabaseConfig.validate(
        url: rawUrl,
        publishableKey: rawKey,
        isProduction: const bool.fromEnvironment('dart.vm.product'),
      );
    } on SupabaseConfigurationException {
      return const SupabaseConnectivityReport(
        configuration: SupabaseConfigurationCheckStatus.invalid,
        initialization: SupabaseInitializationCheckStatus.notAttempted,
        remote: SupabaseRemoteStatus.notChecked,
      );
    }

    final SupabaseInitializer activeInitializer =
        initializer ?? SupabaseInitializer(readEnvironment: read);
    final SupabaseInitializationResult initResult = await activeInitializer
        .initialize();
    if (!initResult.initialized) {
      return SupabaseConnectivityReport(
        configuration: SupabaseConfigurationCheckStatus.valid,
        initialization: SupabaseInitializationCheckStatus.failed,
        remote: SupabaseRemoteStatus.notChecked,
      );
    }

    final SupabaseRemoteProbe activeProbe =
        probe ?? const SupabaseRemoteProbe();
    final SupabaseRemoteProbeResult remoteResult = await activeProbe.check(
      config,
    );
    return SupabaseConnectivityReport(
      configuration: SupabaseConfigurationCheckStatus.valid,
      initialization: SupabaseInitializationCheckStatus.success,
      remote: remoteResult.status,
      remoteResult: remoteResult,
    );
  }
}
