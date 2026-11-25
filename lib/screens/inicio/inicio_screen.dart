import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/sismo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conectividad_provider.dart';
import '../../providers/configuracion_provider.dart';
import '../../providers/contactos_provider.dart';
import '../../providers/emergencia_provider.dart';
import '../../providers/sismos_provider.dart';
import '../../providers/ubicacion_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/cronometro_emergencia.dart';
import '../../widgets/sismo_tile.dart';
import '../alerta/alerta_sismo_screen.dart';
import '../conectividad/conectividad_screen.dart';
import '../contactos/contactos_screen.dart';
import '../historial/historial_screen.dart';
import '../movimiento/monitor_movimiento_screen.dart';
import '../sismos/detalle_sismo_screen.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.onCambiarTab});

  final ValueChanged<int> onCambiarTab;

  Future<void> _refrescar(BuildContext context) async {
    await Future.wait([
      context.read<SismosProvider>().cargar(silencioso: true),
      context.read<ConectividadProvider>().refrescar(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sismos = context.watch<SismosProvider>();
    final contactos = context.watch<ContactosProvider>();
    final emergencia = context.watch<EmergenciaProvider>();
    final conectividad = context.watch<ConectividadProvider>();
    final ubicacion = context.watch<UbicacionProvider>();
    final configuracion = context.watch<ConfiguracionProvider>();
    final theme = Theme.of(context);

    final visibles = sismos.visibles;
    final ultimo = visibles.isEmpty ? null : visibles.first;
    final mayor = visibles.isEmpty
        ? null
        : visibles.reduce((a, b) => a.magnitud >= b.magnitud ? a : b);
    final activa = emergencia.activa;
    final sismoFuerte = _sismoFuerte(visibles);
    final distancia = ultimo != null && ubicacion.ubicacion != null
        ? ultimo.distanciaKmDesde(
            ubicacion.ubicacion!.latitud,
            ubicacion.ubicacion!.longitud,
          )
        : null;

    return RefreshIndicator(
      onRefresh: () => _refrescar(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${auth.usuario?.nombre.split(' ').first ?? 'Usuario'}',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatters.fechaCompleta(DateTime.now()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  auth.usuario?.iniciales ?? '?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioM),
          if (!conectividad.internetReal)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AvisoBanner(
                titulo: conectividad.hayInterfaz
                    ? 'Sin acceso confirmado a Internet'
                    : 'Sin conexión',
                mensaje: conectividad.hayInterfaz
                    ? 'Se muestran los sismos guardados. El SOS por SMS puede '
                          'seguir disponible según tu operador.'
                    : 'La app funciona con los datos guardados. Puedes intentar '
                          'un SOS por SMS aunque no haya Internet.',
                nivel: NivelAviso.advertencia,
                etiquetaAccion: 'Ver conectividad',
                onAccion: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConectividadScreen(),
                  ),
                ),
              ),
            ),
          if (sismos.error != null && conectividad.internetReal)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AvisoBanner(
                mensaje: sismos.error!,
                nivel: NivelAviso.advertencia,
                etiquetaAccion: 'Reintentar',
                onAccion: () => context.read<SismosProvider>().refrescar(),
              ),
            ),
          if (sismoFuerte != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppTheme.ambarOscuro.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radio),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radio),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlertaSismoScreen(
                        sismo: sismoFuerte,
                        distanciaKm: ubicacion.ubicacion == null
                            ? null
                            : sismoFuerte.distanciaKmDesde(
                                ubicacion.ubicacion!.latitud,
                                ubicacion.ubicacion!.longitud,
                              ),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radio),
                      border: Border.all(
                        color: AppTheme.ambarOscuro.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.ambarOscuro,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sismo fuerte reciente: M${sismoFuerte.magnitudFormateada}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.ambarOscuro,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                sismoFuerte.lugar,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (activa != null && activa.activa)
            Card(
              color: AppTheme.rojoCritico,
              child: Padding(
                padding: AppTheme.paddingM,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Emergencia SOS activa',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        CronometroEmergencia(
                          inicio: activa.inicio,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La entrega de mensajes no está confirmada. Revisa el '
                      'estado de cada contacto.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.rojoOscuro,
                      ),
                      onPressed: () => onCambiarTab(3),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir emergencia'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: AppTheme.paddingM,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sos_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¿Necesitas ayuda?',
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                contactos.hayContactos
                                    ? '${contactos.destinatariosSos.length} contacto(s) recibirán el aviso prioritario.'
                                    : 'Aún no tienes contactos de emergencia.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => onCambiarTab(3),
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text('Activar SOS'),
                          ),
                        ),
                        if (!contactos.hayContactos) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ContactosScreen(),
                              ),
                            ),
                            child: const Text('Agregar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppTheme.espacioM),
          Row(
            children: [
              Text('Último sismo', style: theme.textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () => onCambiarTab(2),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          if (ultimo != null)
            SismoTile(
              sismo: ultimo,
              distanciaKm: distancia,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetalleSismoScreen(sismo: ultimo),
                ),
              ),
            )
          else if (sismos.cargando)
            const Card(
              child: Padding(
                padding: AppTheme.paddingL,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            Card(
              child: Padding(
                padding: AppTheme.paddingM,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sismos.hayDatos
                          ? 'Ningún evento supera M${configuracion.magnitudMinima.toStringAsFixed(1)}'
                          : 'No hay sismos disponibles',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sismos.hayDatos
                          ? 'Puedes ajustar la magnitud mínima en Configuración.'
                          : 'Revisa la conexión e inténtalo de nuevo.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<SismosProvider>().refrescar(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppTheme.espacioM),
          Row(
            children: [
              Expanded(
                child: _Estadistica(
                  icono: Icons.public_rounded,
                  valor: '${visibles.length}',
                  etiqueta: 'Sismos 24 h',
                  color: AppTheme.azulInfo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Estadistica(
                  icono: Icons.speed_rounded,
                  valor: mayor == null ? '—' : 'M${mayor.magnitudFormateada}',
                  etiqueta: 'Mayor magnitud',
                  color: mayor == null
                      ? AppTheme.grisNeutro
                      : AppTheme.colorParaMagnitud(mayor.magnitud),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Estadistica(
                  icono: Icons.contacts_rounded,
                  valor: '${contactos.total}',
                  etiqueta: 'Contactos',
                  color: AppTheme.verdeOk,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioL),
          Text('Accesos rápidos', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.espacioS),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _AccesoRapido(
                icono: Icons.map_rounded,
                titulo: 'Mapa sísmico',
                onTap: () => onCambiarTab(1),
              ),
              _AccesoRapido(
                icono: Icons.public_rounded,
                titulo: 'Lista de sismos',
                onTap: () => onCambiarTab(2),
              ),
              _AccesoRapido(
                icono: Icons.contacts_rounded,
                titulo: 'Contactos',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ContactosScreen(),
                  ),
                ),
              ),
              _AccesoRapido(
                icono: Icons.sensors_rounded,
                titulo: 'Monitor de movimiento',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MonitorMovimientoScreen(),
                  ),
                ),
              ),
              _AccesoRapido(
                icono: Icons.history_rounded,
                titulo: 'Historial SOS',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistorialScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioL),
          Text(
            'Los datos de USGS pueden llegar con retraso. Esta app no sustituye '
            'a los sistemas oficiales de alerta ni a los servicios de emergencia.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Sismo? _sismoFuerte(List<Sismo> visibles) {
    final ahora = DateTime.now();
    for (final sismo in visibles) {
      final diferencia = ahora.difference(sismo.tiempo.toLocal());
      if (sismo.magnitud >= 5.5 &&
          !diferencia.isNegative &&
          diferencia.inHours < 6) {
        return sismo;
      }
    }
    return null;
  }
}

class _Estadistica extends StatelessWidget {
  const _Estadistica({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              valor,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              etiqueta,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icono, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
