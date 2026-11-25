import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_initializer.dart';
import 'core/config/supabase_runtime_config.dart';
import 'core/navigation/app_navigator.dart';
import 'core/sync/supabase_gateway.dart';
import 'core/sync/supabase_sync_queue.dart';
import 'models/configuracion_app.dart';
import 'providers/auth_provider.dart';
import 'providers/conectividad_provider.dart';
import 'providers/configuracion_provider.dart';
import 'providers/contactos_provider.dart';
import 'providers/emergencia_provider.dart';
import 'providers/sismos_provider.dart';
import 'providers/movimiento_provider.dart';
import 'providers/ubicacion_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/contactos_repository.dart';
import 'repositories/emergencias_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/sismos_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/home_shell.dart';
import 'services/connectivity_service.dart';
import 'services/emergency_channels.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseEnv = await SupabaseRuntimeConfig.cargar();
  await SupabaseInitializer(
    readEnvironment: (name) => supabaseEnv[name] ?? '',
  ).initialize();

  final supabaseGateway = FlutterSupabaseGateway();
  final syncQueue = SupabaseSyncQueue(gateway: supabaseGateway);
  await syncQueue.initialize();
  final syncCoordinator = SupabaseSyncCoordinator(
    gateway: supabaseGateway,
    queue: syncQueue,
  );
  final settingsRepository = SettingsRepository(
    gateway: supabaseGateway,
    sync: syncQueue,
  );
  final authRepository = AuthRepository(
    gateway: supabaseGateway,
    sync: syncQueue,
  );
  final contactosRepository = ContactosRepository(
    gateway: supabaseGateway,
    sync: syncQueue,
  );
  final emergenciasRepository = EmergenciasRepository(
    gateway: supabaseGateway,
    sync: syncQueue,
  );
  final sismosRepository = SismosRepository(
    gateway: supabaseGateway,
    sync: syncQueue,
  );
  final locationService = LocationService();
  final connectivityService = ConnectivityService();
  final emergencyChannels = EmergencyChannelService();
  final geocodingService = NominatimGeocodingService();
  final notificationService = NotificationService();
  await notificationService.inicializar();

  syncCoordinator.registerPull(() async {
    await settingsRepository.sincronizarDesdeRemoto();
  });
  syncCoordinator.registerPull(contactosRepository.sincronizarDesdeRemoto);
  syncCoordinator.registerPull(emergenciasRepository.sincronizarDesdeRemoto);
  syncCoordinator.registerPull(sismosRepository.sincronizarGuardadosDesdeRemoto);

  final configuracionProvider = ConfiguracionProvider(
    repository: settingsRepository,
  );
  final authProvider = AuthProvider(repository: authRepository);
  final ubicacionProvider = UbicacionProvider(location: locationService);
  final conectividadProvider = ConectividadProvider(
    connectivity: connectivityService,
    location: locationService,
    notificaciones: notificationService,
    canales: emergencyChannels,
    settings: settingsRepository,
  );
  final contactosProvider = ContactosProvider(repository: contactosRepository);
  final emergenciaProvider = EmergenciaProvider(
    repository: emergenciasRepository,
    location: locationService,
    direccion: geocodingService,
    canales: emergencyChannels,
    notificaciones: notificationService,
  );
  final sismosProvider = SismosProvider(
    configuracion: configuracionProvider,
    repository: sismosRepository,
    notificaciones: notificationService,
  );

  unawaited(configuracionProvider.inicializar());
  unawaited(authProvider.inicializar().whenComplete(syncCoordinator.start));
  unawaited(ubicacionProvider.inicializar());
  unawaited(conectividadProvider.inicializar());
  unawaited(contactosProvider.inicializar());
  unawaited(emergenciaProvider.inicializar());
  unawaited(sismosProvider.inicializar());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configuracionProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: ubicacionProvider),
        ChangeNotifierProvider.value(value: conectividadProvider),
        ChangeNotifierProvider.value(value: contactosProvider),
        ChangeNotifierProvider.value(value: emergenciaProvider),
        ChangeNotifierProvider.value(value: sismosProvider),
        ChangeNotifierProvider(create: (_) => MovimientoProvider()),
      ],
      child: const AlertaSismicaApp(),
    ),
  );
}

class AlertaSismicaApp extends StatelessWidget {
  const AlertaSismicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configuracion = context.watch<ConfiguracionProvider>();
    final temaOscuro =
        configuracion.tema == TemaApp.oscuro ||
        (configuracion.tema == TemaApp.sistema &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Alerta Sísmica',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: temaOscuro ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.inicializando) {
      return const SplashScreen();
    }
    if (!auth.autenticado) {
      return auth.hayCuentaLocal
          ? const LoginScreen()
          : const RegistroScreen(esPrimerUso: true);
    }
    return const HomeShell();
  }
}
