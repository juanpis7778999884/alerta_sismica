import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/emergencia.dart';
import '../../models/sismo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/configuracion_provider.dart';
import '../../providers/contactos_provider.dart';
import '../../providers/emergencia_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/confirmar_dialog.dart';
import '../../widgets/cronometro_emergencia.dart';
import '../../widgets/magnitud_badge.dart';
import '../configuracion/configuracion_screen.dart';
import '../contactos/contactos_screen.dart';
import '../historial/historial_screen.dart';

class EmergenciaScreen extends StatefulWidget {
  const EmergenciaScreen({
    super.key,
    this.embebida = false,
    this.sismoRelacionado,
  });

  final bool embebida;
  final Sismo? sismoRelacionado;

  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  void _mostrarSnack(String mensaje) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(mensaje), duration: const Duration(seconds: 6)),
    );
  }

  Future<void> _activar() async {
    final auth = context.read<AuthProvider>();
    final usuario = auth.usuario;
    if (usuario == null) {
      _mostrarSnack('Inicia sesión para activar una emergencia.');
      return;
    }
    final contactos = context.read<ContactosProvider>();
    final destinatarios = contactos.destinatariosSos;
    final sismo = widget.sismoRelacionado;
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Activar emergencia SOS',
      mensaje: destinatarios.isEmpty
          ? 'No tienes contactos configurados. La emergencia se guardará con '
                'hora y ubicación, pero no habrá a quién preparar el aviso. '
                '¿Deseas activarla de todos modos?'
          : 'Se guardará la emergencia con hora y ubicación. Después se '
                'intentará abrir la app de mensajes con el aviso preparado para '
                '${destinatarios.length} contacto(s). La app no envía el SMS sin '
                'tu confirmación y no llama automáticamente a emergencias.',
      etiquetaConfirmar: 'Activar SOS',
    );
    if (!confirmado || !mounted) return;

    final provider = context.read<EmergenciaProvider>();
    final resultado = await provider.activarSos(
      usuario: usuario,
      contactos: contactos.contactos,
      tipo: sismo == null ? TipoEmergencia.sos : TipoEmergencia.sismo,
      referenciaEvento: sismo == null
          ? null
          : 'Sismo de referencia: M${sismo.magnitudFormateada} — ${sismo.lugar} '
                '(${DateFormatters.fechaHora(sismo.tiempo)})',
    );
    if (!mounted) return;

    final mensaje = resultado.advertencia == null
        ? resultado.mensaje
        : '${resultado.mensaje} ${resultado.advertencia}';
    _mostrarSnack(mensaje);

    if (!resultado.exitosa || resultado.yaExistia) return;
    if (destinatarios.isEmpty) return;

    final mensajeEnvio = await provider.intentarEnvioInicial();
    if (!mounted) return;
    if (mensajeEnvio != null) _mostrarSnack(mensajeEnvio);
  }

  Future<void> _prepararEnvioInicial() async {
    final mensaje = await context
        .read<EmergenciaProvider>()
        .intentarEnvioInicial();
    if (mensaje != null) _mostrarSnack(mensaje);
  }

  Future<void> _enviarSmsTodos() async {
    final resultado = await context
        .read<EmergenciaProvider>()
        .enviarSmsATodos();
    if (resultado != null) _mostrarSnack(resultado.detalle);
  }

  Future<void> _compartir() async {
    final resultado = await context
        .read<EmergenciaProvider>()
        .compartirMensaje();
    if (resultado != null) _mostrarSnack(resultado.detalle);
  }

  Future<void> _abrirMapa() async {
    final resultado = await context
        .read<EmergenciaProvider>()
        .abrirMapaEmergencia();
    if (!resultado.abierto) _mostrarSnack(resultado.detalle);
  }

  Future<void> _llamarEmergencia(String numero) async {
    final resultado = await context.read<EmergenciaProvider>().llamarEmergencia(
      numero,
    );
    if (!resultado.abierto) _mostrarSnack(resultado.detalle);
  }

  Future<void> _finalizar() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Finalizar emergencia',
      mensaje:
          '¿Confirmas que ya no necesitas la emergencia activa? Se guardará en '
          'el historial y podrás consultarla después.',
      etiquetaConfirmar: 'Finalizar',
    );
    if (!confirmado || !mounted) return;
    final provider = context.read<EmergenciaProvider>();
    final ok = await provider.finalizar();
    if (!mounted) return;
    _mostrarSnack(
      ok
          ? 'Emergencia finalizada y guardada en el historial.'
          : provider.error ?? 'No se pudo finalizar la emergencia.',
    );
  }

  Future<void> _enviarAContacto(EnvioContacto envio, CanalEnvio canal) async {
    final resultado = await context.read<EmergenciaProvider>().enviarAContacto(
      contactoId: envio.contactoId,
      canal: canal,
    );
    if (resultado != null) _mostrarSnack(resultado.detalle);
  }

  Future<void> _copiarMensaje(String mensaje) async {
    await Clipboard.setData(ClipboardData(text: mensaje));
    _mostrarSnack('Mensaje copiado al portapapeles.');
  }

  Future<void> _copiarCoordenadas(Emergencia emergencia) async {
    await Clipboard.setData(ClipboardData(text: emergencia.coordenadasTexto));
    _mostrarSnack('Coordenadas copiadas.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergenciaProvider>();
    final activa = provider.activa;

    final contenido = provider.cargando
        ? const Center(child: CircularProgressIndicator())
        : activa != null && activa.activa
        ? _vistaActiva(context, provider, activa)
        : _vistaSinEmergencia(context, provider);

    if (widget.embebida) return contenido;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia SOS'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistorialScreen()),
            ),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial SOS',
          ),
        ],
      ),
      body: contenido,
    );
  }

  Widget _vistaSinEmergencia(
    BuildContext context,
    EmergenciaProvider provider,
  ) {
    final theme = Theme.of(context);
    final contactos = context.watch<ContactosProvider>();
    final configuracion = context.watch<ConfiguracionProvider>();
    final destinatarios = contactos.destinatariosSos;
    final sismo = widget.sismoRelacionado;
    final activando = provider.activando;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.rojoCritico,
            borderRadius: BorderRadius.circular(AppTheme.radioGrande),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sos_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerta Sísmica SOS',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Un aviso local para pedir ayuda a tus contactos.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.rojoOscuro,
                ),
                onPressed: activando ? null : _activar,
                icon: activando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.rojoOscuro,
                        ),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(
                  activando
                      ? 'Activando y obteniendo ubicación…'
                      : 'Activar emergencia SOS',
                ),
              ),
            ],
          ),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 12),
          AvisoBanner(
            mensaje: provider.error!,
            nivel: NivelAviso.error,
            onCerrar: provider.limpiarError,
          ),
        ],
        if (sismo != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: AppTheme.paddingM,
              child: Row(
                children: [
                  MagnitudBadge(magnitud: sismo.magnitud, tamano: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS por sismo',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${sismo.lugar} · M${sismo.magnitudFormateada}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contacts_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contactos del aviso',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${destinatarios.length}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (contactos.cargando)
                  const LinearProgressIndicator(minHeight: 2)
                else if (destinatarios.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No hay contactos configurados. Puedes activar la '
                        'emergencia igualmente, pero no se preparará ningún mensaje.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ContactosScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Agregar contacto'),
                      ),
                    ],
                  )
                else ...[
                  for (final contacto in destinatarios.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: contacto.prioritario
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: contacto.prioritario
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                            child: Text(
                              contacto.iniciales,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${contacto.nombre} · ${contacto.telefonoFormateado}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contacto.prioritario)
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppTheme.ambarOscuro,
                            ),
                        ],
                      ),
                    ),
                  if (destinatarios.length > 5)
                    Text(
                      'y ${destinatarios.length - 5} más…',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (contactos.prioritarios.isEmpty)
                    Text(
                      'No hay contactos prioritarios: se usarán todos.',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qué ocurre al activar',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const _Punto(
                  icono: Icons.place_outlined,
                  texto:
                      'Se guarda la hora y, si está disponible, tu ubicación.',
                ),
                const _Punto(
                  icono: Icons.sms_outlined,
                  texto:
                      'Se abre la app de mensajes con el aviso preparado para los '
                      'contactos prioritarios. Tú confirmas el envío.',
                ),
                const _Punto(
                  icono: Icons.phone_in_talk_outlined,
                  texto:
                      'No se llama automáticamente a emergencias: el botón de '
                      'llamada solo abre el marcador.',
                ),
                const _Punto(
                  icono: Icons.lock_outline_rounded,
                  texto: 'La emergencia y su historial se guardan en este dispositivo.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (configuracion.numeroEmergencia.isEmpty)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ConfiguracionScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_phone_rounded),
            label: const Text('Configurar número de emergencia'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _llamarEmergencia(configuracion.numeroEmergencia),
            icon: const Icon(Icons.call_rounded),
            label: Text('Abrir marcador · ${configuracion.numeroEmergencia}'),
          ),
        const SizedBox(height: AppTheme.espacioM),
        Text(
          'La app no es un servicio oficial de emergencia. Si hay peligro '
          'inminente, contacta a los organismos de tu país por los canales '
          'habituales.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _vistaActiva(
    BuildContext context,
    EmergenciaProvider provider,
    Emergencia emergencia,
  ) {
    final theme = Theme.of(context);
    final configuracion = context.watch<ConfiguracionProvider>();
    final contactos = context.watch<ContactosProvider>();
    final abiertos = emergencia.envios
        .where((envio) => envio.estado == EstadoEnvio.abiertoEnApp)
        .length;
    final pendientes = emergencia.envios
        .where((envio) => envio.estado == EstadoEnvio.pendiente)
        .length;
    final fallidos = emergencia.envios
        .where(
          (envio) =>
              envio.estado == EstadoEnvio.fallido ||
              envio.estado == EstadoEnvio.noDisponible,
        )
        .length;
    final enviando = provider.enviando;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.rojoCritico,
            borderRadius: BorderRadius.circular(AppTheme.radioGrande),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'EMERGENCIA ACTIVA',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(emergencia.tipo.etiqueta),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CronometroEmergencia(
                inicio: emergencia.inicio,
                style: AppTheme.numerosGrandes.copyWith(
                  color: Colors.white,
                  fontSize: 42,
                ),
              ),
              Text(
                'Iniciada ${DateFormatters.fechaHora(emergencia.inicio)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        if (provider.error != null) ...[
          const SizedBox(height: 10),
          AvisoBanner(
            mensaje: provider.error!,
            nivel: NivelAviso.advertencia,
            onCerrar: provider.limpiarError,
          ),
        ],
        if (!emergencia.envioInicialIntentado &&
            emergencia.envios.isNotEmpty) ...[
          const SizedBox(height: 10),
          AvisoBanner(
            titulo: 'Envío inicial pendiente',
            mensaje:
                'La emergencia está guardada. Puedes preparar ahora el mensaje '
                'para tus contactos prioritarios.',
            nivel: NivelAviso.info,
            etiquetaAccion: 'Preparar envío',
            onAccion: enviando ? null : _prepararEnvioInicial,
          ),
        ],
        if (emergencia.envios.isEmpty) ...[
          const SizedBox(height: 10),
          AvisoBanner(
            titulo: 'Sin contactos',
            mensaje:
                'No hay contactos en esta emergencia. Agrega uno para poder '
                'avisar por SMS o WhatsApp.',
            nivel: NivelAviso.advertencia,
            etiquetaAccion: 'Agregar contacto',
            onAccion: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactosScreen()),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado del aviso', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  emergencia.resumenEnvios,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Contador(
                      etiqueta: 'Abiertos',
                      valor: abiertos,
                      color: AppTheme.azulInfo,
                    ),
                    _Contador(
                      etiqueta: 'Pendientes',
                      valor: pendientes,
                      color: AppTheme.ambarOscuro,
                    ),
                    _Contador(
                      etiqueta: 'Con problema',
                      valor: fallidos,
                      color: theme.colorScheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Un canal abierto significa que se preparó el SMS, WhatsApp o '
                  'el selector del sistema; no confirma que el mensaje haya '
                  'llegado al contacto.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ubicación del aviso',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (emergencia.tieneUbicacion) ...[
                  Text(
                    emergencia.ubicacionLegible ??
                        'Dirección no disponible. Se usan las coordenadas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    emergencia.coordenadasTexto,
                    style: AppTheme.monospace,
                  ),
                  if (emergencia.precisionMetros != null)
                    Text(
                      'Precisión aproximada: '
                      '${emergencia.precisionMetros!.round()} m',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _abrirMapa,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Ver mapa'),
                      ),
                      TextButton.icon(
                        onPressed: () => _copiarCoordenadas(emergencia),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar coordenadas'),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'No se pudo obtener la ubicación al activar la emergencia. '
                    'El mensaje indica que la ubicación no estaba disponible.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: AppTheme.paddingM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mensaje preparado',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copiarMensaje(emergencia.mensaje),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copiar mensaje',
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radio),
                  ),
                  child: SelectableText(
                    emergencia.mensaje,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: enviando
              ? null
              : emergencia.envioInicialIntentado
              ? _enviarSmsTodos
              : _prepararEnvioInicial,
          icon: enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sms_rounded),
          label: Text(
            enviando
                ? 'Abriendo canal…'
                : emergencia.envioInicialIntentado
                ? 'Reintentar SMS a prioritarios'
                : 'Preparar envío inicial',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: enviando ? null : _compartir,
          icon: const Icon(Icons.share_rounded),
          label: const Text('Compartir aviso'),
        ),
        if (configuracion.numeroEmergencia.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _llamarEmergencia(configuracion.numeroEmergencia),
            icon: const Icon(Icons.call_rounded),
            label: Text('Abrir marcador · ${configuracion.numeroEmergencia}'),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Contactos del aviso',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              '${emergencia.envios.length}',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (contactos.total == 0)
          Text(
            'No hay contactos guardados en la app.',
            style: theme.textTheme.bodySmall,
          )
        else if (emergencia.envios.isEmpty)
          Text(
            'Esta emergencia se creó sin contactos.',
            style: theme.textTheme.bodySmall,
          )
        else
          for (final envio in emergencia.envios)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TarjetaEnvio(
                envio: envio,
                enviando: enviando,
                onSms: () => _enviarAContacto(envio, CanalEnvio.sms),
                onWhatsApp: () => _enviarAContacto(envio, CanalEnvio.whatsapp),
              ),
            ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
          onPressed: provider.activando || enviando ? null : _finalizar,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Finalizar emergencia'),
        ),
        const SizedBox(height: AppTheme.espacioM),
        Text(
          'La entrega de SMS, WhatsApp o mensajes compartidos no está '
          'confirmada por Alerta Sísmica. Revisa la app externa y confirma con '
          'tus contactos cuando sea seguro.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$etiqueta: $valor',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TarjetaEnvio extends StatelessWidget {
  const _TarjetaEnvio({
    required this.envio,
    required this.enviando,
    required this.onSms,
    required this.onWhatsApp,
  });

  final EnvioContacto envio;
  final bool enviando;
  final VoidCallback onSms;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorEstado(theme);
    final inicial = envio.nombre.trim().isEmpty
        ? '?'
        : envio.nombre.trim()[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                  child: Text(
                    inicial,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              envio.nombre,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (envio.prioritario) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppTheme.ambarOscuro,
                            ),
                          ],
                        ],
                      ),
                      Text(envio.telefono, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: enviando ? null : onSms,
                  icon: const Icon(Icons.sms_outlined),
                  tooltip: 'Abrir SMS para ${envio.nombre}',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: enviando ? null : onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  tooltip: 'Abrir WhatsApp para ${envio.nombre}',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                _etiquetaEstado(envio.estado),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (envio.detalle != null) ...[
              const SizedBox(height: 4),
              Text(envio.detalle!, style: theme.textTheme.bodySmall),
            ],
            if (envio.actualizadoEn != null)
              Text(
                'Actualizado ${DateFormatters.hora(envio.actualizadoEn!)}',
                style: theme.textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(ThemeData theme) {
    switch (envio.estado) {
      case EstadoEnvio.pendiente:
        return AppTheme.ambarOscuro;
      case EstadoEnvio.abiertoEnApp:
        return AppTheme.azulInfo;
      case EstadoEnvio.cancelado:
        return theme.colorScheme.onSurfaceVariant;
      case EstadoEnvio.fallido:
      case EstadoEnvio.noDisponible:
        return theme.colorScheme.error;
    }
  }

  String _etiquetaEstado(EstadoEnvio estado) {
    switch (estado) {
      case EstadoEnvio.pendiente:
        return 'Pendiente de envío';
      case EstadoEnvio.abiertoEnApp:
        return 'Canal abierto · entrega sin confirmar';
      case EstadoEnvio.cancelado:
        return 'Cancelado';
      case EstadoEnvio.fallido:
        return 'Fallido';
      case EstadoEnvio.noDisponible:
        return 'No disponible';
    }
  }
}
