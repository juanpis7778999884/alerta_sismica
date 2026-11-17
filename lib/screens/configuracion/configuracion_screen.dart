import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/configuracion_app.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conectividad_provider.dart';
import '../../providers/configuracion_provider.dart';
import '../../providers/contactos_provider.dart';
import '../../providers/emergencia_provider.dart';
import '../../providers/sismos_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/confirmar_dialog.dart';
import '../acerca_screen.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroController;
  late double _magnitud;
  late double _umbral;
  bool _guardandoNumero = false;
  bool _procesandoNotificaciones = false;

  @override
  void initState() {
    super.initState();
    final configuracion = context.read<ConfiguracionProvider>();
    _magnitud = configuracion.magnitudMinima;
    _umbral = configuracion.umbralNotificacion;
    _numeroController = TextEditingController(
      text: configuracion.numeroEmergencia,
    );
  }

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _sincronizarDesde(ConfiguracionApp config) {
    setState(() {
      _magnitud = config.magnitudMinima;
      _umbral = config.umbralNotificacion;
      _numeroController.text = config.numeroEmergencia;
      _numeroController.selection = TextSelection.collapsed(
        offset: _numeroController.text.length,
      );
    });
  }

  Future<void> _guardarNumero() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final configuracion = context.read<ConfiguracionProvider>();
    setState(() => _guardandoNumero = true);
    await configuracion.cambiarNumeroEmergencia(_numeroController.text);
    if (!mounted) return;
    setState(() => _guardandoNumero = false);
    _snack(
      configuracion.error ??
          'Número guardado. La app solo abrirá el marcador; nunca llama '
              'automáticamente.',
    );
  }

  Future<void> _alternarNotificaciones(bool valor) async {
    final conectividad = context.read<ConectividadProvider>();
    final configuracion = context.read<ConfiguracionProvider>();
    setState(() => _procesandoNotificaciones = true);
    try {
      if (valor && conectividad.notificacionesHabilitadas != true) {
        final concedido = await conectividad.solicitarPermisoNotificaciones();
        if (!mounted) return;
        if (!concedido) {
          _snack(
            'Sin permiso de notificaciones no se pueden mostrar avisos. '
            'Habilítalo en los ajustes del sistema.',
          );
          return;
        }
      }
      await configuracion.cambiarNotificarSismos(valor);
      if (!mounted) return;
      _snack(
        configuracion.error ??
            (valor
                ? 'Notificaciones de sismos activadas.'
                : 'Notificaciones de sismos desactivadas.'),
      );
    } finally {
      if (mounted) setState(() => _procesandoNotificaciones = false);
    }
  }

  Future<void> _probarNotificacion() async {
    final conectividad = context.read<ConectividadProvider>();
    var habilitadas = conectividad.notificacionesHabilitadas ?? false;
    if (!habilitadas) {
      habilitadas = await conectividad.solicitarPermisoNotificaciones();
    }
    if (!mounted) return;
    if (!habilitadas) {
      _snack('No hay permiso para mostrar notificaciones.');
      return;
    }
    await conectividad.mostrarNotificacionPrueba();
    if (!mounted) return;
    _snack(
      conectividad.error ??
          'Notificación de prueba enviada. Revisa la barra del sistema.',
    );
  }

  Future<void> _restablecerPreferencias() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Restablecer preferencias',
      mensaje:
          'El tema, la magnitud mínima, el auto-refresco y las notificaciones '
          'volverán a los valores iniciales. No se borran contactos ni '
          'historial.',
      etiquetaConfirmar: 'Restablecer',
      destructivo: false,
    );
    if (!confirmado || !mounted) return;
    final configuracion = context.read<ConfiguracionProvider>();
    await configuracion.restablecer();
    if (!mounted) return;
    _sincronizarDesde(configuracion.configuracion);
    _snack(configuracion.error ?? 'Preferencias restablecidas.');
  }

  Future<void> _limpiarCache() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Borrar caché de sismos',
      mensaje:
          'Se eliminarán los sismos guardados para consulta sin conexión. La '
          'próxima actualización volverá a descargarlos de USGS.',
      etiquetaConfirmar: 'Borrar caché',
    );
    if (!confirmado || !mounted) return;
    final sismos = context.read<SismosProvider>();
    final ok = await sismos.limpiarCache();
    if (!mounted) return;
    _snack(
      ok
          ? 'Caché de sismos eliminada.'
          : sismos.error ?? 'No se pudo borrar la caché.',
    );
  }

  Future<void> _borrarTodo() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Borrar todos los datos locales',
      mensaje:
          'Se eliminarán la cuenta local, los contactos de emergencia, la '
          'emergencia activa, el historial, la caché de sismos y las '
          'preferencias. Esta acción no se puede deshacer.',
      etiquetaConfirmar: 'Borrar todo',
    );
    if (!confirmado || !mounted) return;

    final contactos = context.read<ContactosProvider>();
    final emergencia = context.read<EmergenciaProvider>();
    final sismos = context.read<SismosProvider>();
    final configuracion = context.read<ConfiguracionProvider>();
    final auth = context.read<AuthProvider>();

    final okContactos = await contactos.borrarTodos();
    final okEmergencia = await emergencia.borrarDatosLocales();
    final okCache = await sismos.limpiarCache();
    await configuracion.restablecer();
    if (!mounted) return;
    if (!okContactos || !okEmergencia || !okCache) {
      final errores = [
        if (!okContactos) contactos.error,
        if (!okEmergencia) emergencia.error,
        if (!okCache) sismos.error,
      ].whereType<String>();
      _snack(
        errores.isNotEmpty
            ? errores.first
            : 'No se pudieron borrar todos los datos locales.',
      );
      return;
    }

    final okCuenta = await auth.eliminarCuentaLocal();
    if (!mounted) return;
    if (!okCuenta) {
      _snack(auth.error ?? 'No se pudo eliminar la cuenta local.');
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final configuracion = context.watch<ConfiguracionProvider>();
    final conectividad = context.watch<ConectividadProvider>();
    final sismos = context.watch<SismosProvider>();
    final config = configuracion.configuracion;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (configuracion.error != null) ...[
            AvisoBanner(
              mensaje: configuracion.error!,
              nivel: NivelAviso.error,
              onCerrar: configuracion.limpiarError,
            ),
            const SizedBox(height: 12),
          ],
          if (configuracion.guardando) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          _Seccion(
            titulo: 'Apariencia',
            icono: Icons.palette_outlined,
            children: [
              Text('Tema de la aplicación', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TemaApp>(
                  segments: const [
                    ButtonSegment(value: TemaApp.claro, label: Text('Claro')),
                    ButtonSegment(value: TemaApp.oscuro, label: Text('Oscuro')),
                    ButtonSegment(
                      value: TemaApp.sistema,
                      label: Text('Sistema'),
                    ),
                  ],
                  selected: {config.tema},
                  showSelectedIcon: false,
                  onSelectionChanged: (seleccion) =>
                      configuracion.cambiarTema(seleccion.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioM),
          _Seccion(
            titulo: 'Sismos',
            icono: Icons.public_rounded,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Magnitud mínima para mostrar',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    'M ${_magnitud.toStringAsFixed(1)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.colorParaMagnitud(_magnitud),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _magnitud,
                min: 1,
                max: 7,
                divisions: 12,
                label: 'M ${_magnitud.toStringAsFixed(1)}',
                onChanged: (valor) => setState(() => _magnitud = valor),
                onChangeEnd: (valor) =>
                    configuracion.cambiarMagnitudMinima(valor),
              ),
              Text(
                'Filtra la lista, el mapa y los conteos de la pantalla de '
                'inicio. No cambia el umbral de las notificaciones.',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Actualizar sismos automáticamente'),
                subtitle: const Text(
                  'Consulta el feed de USGS cada 2 minutos mientras la app '
                  'está abierta y al volver a primer plano.',
                ),
                value: config.autoRefresco,
                onChanged: configuracion.guardando
                    ? null
                    : configuracion.cambiarAutoRefresco,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioM),
          _Seccion(
            titulo: 'Notificaciones locales',
            icono: Icons.notifications_active_outlined,
            children: [
              if (conectividad.notificacionesHabilitadas == false) ...[
                AvisoBanner(
                  mensaje:
                      'El permiso de notificaciones está desactivado en el '
                      'sistema. Puedes solicitarlo o abrir los ajustes.',
                  nivel: NivelAviso.advertencia,
                  etiquetaAccion: 'Solicitar permiso',
                  onAccion: _procesarPermiso,
                ),
                const SizedBox(height: 8),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisar de sismos nuevos'),
                subtitle: Text(
                  conectividad.notificacionesHabilitadas == null
                      ? 'Estado del permiso desconocido.'
                      : conectividad.notificacionesHabilitadas == true
                      ? 'Permiso concedido.'
                      : 'Permiso pendiente o denegado.',
                ),
                value: config.notificarSismos,
                onChanged: _procesandoNotificaciones
                    ? null
                    : _alternarNotificaciones,
              ),
              if (config.notificarSismos) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Umbral de notificación',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      'M ${_umbral.toStringAsFixed(1)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.colorParaMagnitud(_umbral),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _umbral,
                  min: 2.5,
                  max: 7,
                  divisions: 9,
                  label: 'M ${_umbral.toStringAsFixed(1)}',
                  onChanged: (valor) => setState(() => _umbral = valor),
                  onChangeEnd: (valor) =>
                      configuracion.cambiarUmbralNotificacion(valor),
                ),
                Text(
                  'Solo se notifican sismos nuevos con magnitud igual o mayor '
                  'al umbral. Los eventos simulados se excluyen.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _probarNotificacion,
                    icon: const Icon(Icons.notification_add_outlined, size: 18),
                    label: const Text('Probar notificación'),
                  ),
                  TextButton.icon(
                    onPressed: conectividad.abrirAjustesNotificaciones,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Ajustes del sistema'),
                  ),
                ],
              ),
              Text(
                'Son notificaciones locales: no requieren servidor, pero '
                'tampoco llegan si la app está cerrada o bloqueada por el '
                'sistema.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioM),
          _Seccion(
            titulo: 'Llamada de emergencia',
            icono: Icons.local_phone_outlined,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _numeroController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Número de emergencia (opcional)',
                        hintText: 'Número local de emergencias',
                        prefixIcon: Icon(Icons.dialpad_rounded),
                      ),
                      validator: Validators.numeroEmergencia,
                      onFieldSubmitted: (_) => _guardarNumero(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _guardandoNumero ? null : _guardarNumero,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _guardandoNumero ? 'Guardando…' : 'Guardar número',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Este número solo se usa en el botón de llamada del SOS: la '
                'app abre el marcador y tú confirmas la llamada. Nunca se '
                'marca automáticamente.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioM),
          _Seccion(
            titulo: 'Datos y privacidad',
            icono: Icons.storage_outlined,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restore_rounded),
                      title: const Text('Restablecer preferencias'),
                      subtitle: const Text(
                        'Tema, filtros y notificaciones vuelven a los valores '
                        'iniciales.',
                      ),
                      onTap: _restablecerPreferencias,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('Borrar caché de sismos'),
                      subtitle: Text(
                        sismos.actualizadoEn == null
                            ? 'Sin caché guardada.'
                            : 'Última actualización: '
                                  '${DateFormatters.fechaHora(sismos.actualizadoEn!)}',
                      ),
                      onTap: _limpiarCache,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Acerca de Alerta Sísmica'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AcercaScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Borrar todos los datos locales',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      subtitle: const Text(
                        'Elimina cuenta, contactos, emergencia activa, '
                        'historial, caché y preferencias.',
                      ),
                      onTap: _borrarTodo,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Todos los datos permanecen en este dispositivo. No hay '
                'servidores propios ni copias en la nube.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.espacioL),
          Center(
            child: Text(
              'Alerta Sísmica · versión 1.0.0',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarPermiso() async {
    final conectividad = context.read<ConectividadProvider>();
    final concedido = await conectividad.solicitarPermisoNotificaciones();
    if (!mounted) return;
    _snack(
      concedido
          ? 'Permiso de notificaciones concedido.'
          : conectividad.error ?? 'Permiso no concedido.',
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.children,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icono, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(titulo, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
