import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/conectividad_provider.dart';
import '../providers/configuracion_provider.dart';
import '../providers/contactos_provider.dart';
import '../providers/emergencia_provider.dart';
import '../providers/sismos_provider.dart';
import '../theme.dart';
import '../widgets/confirmar_dialog.dart';
import '../widgets/emergencia_activa_banner.dart';
import 'acerca_screen.dart';
import 'conectividad/conectividad_screen.dart';
import 'configuracion/configuracion_screen.dart';
import 'contactos/contactos_screen.dart';
import 'emergencia/emergencia_screen.dart';
import 'historial/historial_screen.dart';
import 'inicio/inicio_screen.dart';
import 'mapa/mapa_screen.dart';
import 'sismos/lista_sismos_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _indice = 0;
  Timer? _temporizador;

  static const List<String> _titulos = [
    'Alerta Sísmica',
    'Mapa sísmico',
    'Sismos recientes',
    'Emergencia SOS',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _temporizador = Timer.periodic(const Duration(minutes: 2), (_) {
      _refrescarAutomatico();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refrescarAutomatico();
    }
  }

  void _refrescarAutomatico() {
    if (!mounted) return;
    final configuracion = context.read<ConfiguracionProvider>();
    if (!configuracion.autoRefresco) return;
    final conectividad = context.read<ConectividadProvider>();
    if (conectividad.verificando) return;
    unawaited(context.read<SismosProvider>().cargar(silencioso: true));
  }

  void _cambiarTab(int indice) {
    setState(() => _indice = indice);
  }

  void _abrirPantalla(Widget pantalla) {
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  Future<void> _cerrarSesion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Quieres cerrar la sesión local? Tus contactos y tu historial permanecerán en el dispositivo.',
      etiquetaConfirmar: 'Cerrar sesión',
      destructivo: false,
    );
    if (!confirmado || !mounted) return;
    Navigator.of(context).pop();
    await context.read<AuthProvider>().cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final emergencia = context.watch<EmergenciaProvider>();
    final conectividad = context.watch<ConectividadProvider>();
    final contactos = context.watch<ContactosProvider>();
    final auth = context.watch<AuthProvider>();
    final activa = emergencia.activa;
    final hayActiva = activa != null && activa.activa;
    final colorConexion = conectividad.internetReal
        ? AppTheme.verdeOk
        : conectividad.hayInterfaz
        ? AppTheme.ambarOscuro
        : AppTheme.grisNeutro;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_indice == 0) ...[
              const Icon(
                Icons.crisis_alert_rounded,
                color: AppTheme.rojoCritico,
                size: 22,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(_titulos[_indice], overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _abrirPantalla(const ConectividadScreen()),
            icon: Icon(
              conectividad.internetReal
                  ? Icons.wifi_rounded
                  : conectividad.hayInterfaz
                  ? Icons.wifi_off_rounded
                  : Icons.cloud_off_rounded,
              color: colorConexion,
            ),
            tooltip: conectividad.etiquetaRed,
          ),
          if (_indice < 3)
            IconButton(
              onPressed: () => context.read<SismosProvider>().refrescar(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar sismos',
            ),
          if (_indice == 3)
            IconButton(
              onPressed: () => _abrirPantalla(const HistorialScreen()),
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Historial de emergencias',
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                margin: EdgeInsets.zero,
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppTheme.rojoCritico,
                  foregroundColor: Colors.white,
                  child: Text(
                    auth.usuario?.iniciales ?? '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                accountName: Text(
                  auth.usuario?.nombre ?? 'Usuario local',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                accountEmail: Text(auth.usuario?.email ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.contacts_rounded),
                title: const Text('Contactos de emergencia'),
                trailing: Badge(
                  isLabelVisible: contactos.total > 0,
                  label: Text('${contactos.total}'),
                ),
                onTap: () => _abrirPantalla(const ContactosScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Historial SOS'),
                onTap: () => _abrirPantalla(const HistorialScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.network_check_rounded),
                title: const Text('Conectividad'),
                onTap: () => _abrirPantalla(const ConectividadScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Configuración'),
                onTap: () => _abrirPantalla(const ConfiguracionScreen()),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Acerca de Alerta Sísmica'),
                onTap: () => _abrirPantalla(const AcercaScreen()),
              ),
              const Spacer(),
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: _cerrarSesion,
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.espacioM),
                child: Text(
                  'Versión 1.0.0 · Datos locales',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (activa != null && activa.activa)
            EmergenciaActivaBanner(
              emergencia: activa,
              onAbrir: () => _cambiarTab(3),
            ),
          Expanded(
            child: IndexedStack(
              index: _indice,
              children: [
                InicioScreen(onCambiarTab: _cambiarTab),
                const MapaSismosScreen(),
                const ListaSismosScreen(),
                const EmergenciaScreen(embebida: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _cambiarTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public_rounded),
            label: 'Sismos',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: hayActiva,
              smallSize: 8,
              child: const Icon(Icons.sos_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: hayActiva,
              smallSize: 8,
              child: const Icon(Icons.sos_rounded),
            ),
            label: 'SOS',
          ),
        ],
      ),
    );
  }
}
