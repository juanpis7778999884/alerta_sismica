import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/logo_alerta.dart';

class AcercaScreen extends StatelessWidget {
  const AcercaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Alerta Sísmica')),
      body: ListView(
        padding: AppTheme.paddingL,
        children: [
          const Center(
            child: LogoAlerta(
              tamano: 72,
              subtitulo: 'Monitoreo sísmico y SOS local',
            ),
          ),
          const SizedBox(height: AppTheme.espacioL),
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Qué hace la app', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.espacioS),
                  const Text(
                    'Consulta los sismos de las últimas 24 horas publicados por '
                    'el Servicio Geológico de Estados Unidos (USGS), los muestra '
                    'en un mapa y en una lista, guarda una caché para consultarlos '
                    'sin conexión y permite preparar un aviso SOS por SMS o '
                    'WhatsApp a tus contactos de emergencia.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.espacioM),
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacidad y datos', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.espacioS),
                  const Text(
                    'La cuenta es local: no hay servidor de autenticación ni '
                    'sincronización en la nube. La contraseña se protege con '
                    'PBKDF2-HMAC-SHA256. Los contactos, el historial y la '
                    'configuración se guardan en el almacenamiento de la app. '
                    'La ubicación solo se usa para el mapa y los mensajes SOS; '
                    'no se envía a servidores propios.',
                  ),
                  const SizedBox(height: AppTheme.espacioS),
                  const Text(
                    'Puedes borrar contactos, historial y caché desde la '
                    'configuración. La cuenta local se elimina desde la misma '
                    'pantalla.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.espacioM),
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Límites importantes',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.espacioS),
                  const Text(
                    '• No es un sistema oficial de alerta temprana ni sustituye '
                    'a los organismos de emergencia.\n'
                    '• Los datos de USGS pueden llegar con retraso o faltar.\n'
                    '• La app no llama automáticamente a emergencias: solo abre '
                    'el marcador si configuras un número.\n'
                    '• El envío por SMS o WhatsApp se abre en la app externa. '
                    'Alerta Sísmica no puede confirmar la entrega.\n'
                    '• Las notificaciones son locales; no hay avisos remotos '
                    'sin configurar un servicio como Firebase Cloud Messaging.\n'
                    '• La red satelital solo aparece si el sistema operativo la '
                    'reporta; la app no puede activarla.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.espacioM),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: const Text('Fuente de datos sísmicos'),
                  subtitle: const Text(
                    'USGS Earthquake Hazards Program · feed all_day.geojson',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Mapa'),
                  subtitle: const Text(
                    'OpenStreetMap · tiles © OpenStreetMap contributors',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Licencias de software'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Alerta Sísmica',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.espacioL),
          Center(
            child: Text('Versión 1.0.0', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: AppTheme.espacioL),
        ],
      ),
    );
  }
}
