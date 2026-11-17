import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_navigator.dart';
import 'models/configuracion_app.dart';
import 'providers/auth_provider.dart';
import 'providers/conectividad_provider.dart';
import 'providers/configuracion_provider.dart';
import 'providers/contactos_provider.dart';
import 'providers/emergencia_provider.dart';
import 'providers/sismos_provider.dart';
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

  final settingsRepository = SettingsRepository();
  final authRepository = AuthRepository();
  final contactosRepository = ContactosRepository();
  final emergenciasRepository = EmergenciasRepository();
  final sismosRepository = SismosRepository();
  final locationService = LocationService();
  final connectivityService = ConnectivityService();
  final emergencyChannels = EmergencyChannelService();
  final geocodingService = NominatimGeocodingService();
  final notificationService = NotificationService();
  await notificationService.inicializar();

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
  unawaited(authProvider.inicializar());
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
