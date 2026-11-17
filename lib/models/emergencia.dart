enum TipoEmergencia { sos, sismo }

extension TipoEmergenciaX on TipoEmergencia {
  String get etiqueta {
    switch (this) {
      case TipoEmergencia.sos:
        return 'SOS general';
      case TipoEmergencia.sismo:
        return 'SOS por sismo';
    }
  }

  String get descripcion {
    switch (this) {
      case TipoEmergencia.sos:
        return 'Solicitud de ayuda iniciada manualmente.';
      case TipoEmergencia.sismo:
        return 'Solicitud de ayuda relacionada con un sismo registrado.';
    }
  }
}

enum CanalEnvio { sms, whatsapp, compartir, llamada }

extension CanalEnvioX on CanalEnvio {
  String get etiqueta {
    switch (this) {
      case CanalEnvio.sms:
        return 'SMS';
      case CanalEnvio.whatsapp:
        return 'WhatsApp';
      case CanalEnvio.compartir:
        return 'Compartir';
      case CanalEnvio.llamada:
        return 'Llamada';
    }
  }
}

enum EstadoEnvio { pendiente, abiertoEnApp, cancelado, fallido, noDisponible }

extension EstadoEnvioX on EstadoEnvio {
  String get etiqueta {
    switch (this) {
      case EstadoEnvio.pendiente:
        return 'Pendiente';
      case EstadoEnvio.abiertoEnApp:
        return 'Canal abierto (entrega sin confirmar)';
      case EstadoEnvio.cancelado:
        return 'Cancelado por el usuario';
      case EstadoEnvio.fallido:
        return 'Fallido';
      case EstadoEnvio.noDisponible:
        return 'No disponible';
    }
  }

  bool get requiereAccion =>
      this == EstadoEnvio.pendiente ||
      this == EstadoEnvio.fallido ||
      this == EstadoEnvio.noDisponible;

  bool get fueAbierto => this == EstadoEnvio.abiertoEnApp;
}

class EnvioContacto {
  const EnvioContacto({
    required this.contactoId,
    required this.nombre,
    required this.telefono,
    required this.prioritario,
    this.canal,
    this.estado = EstadoEnvio.pendiente,
    this.detalle,
    this.actualizadoEn,
  });

  final String contactoId;
  final String nombre;
  final String telefono;
  final bool prioritario;
  final CanalEnvio? canal;
  final EstadoEnvio estado;
  final String? detalle;
  final DateTime? actualizadoEn;

  EnvioContacto copyWith({
    CanalEnvio? canal,
    EstadoEnvio? estado,
    String? detalle,
    DateTime? actualizadoEn,
  }) {
    return EnvioContacto(
      contactoId: contactoId,
      nombre: nombre,
      telefono: telefono,
      prioritario: prioritario,
      canal: canal ?? this.canal,
      estado: estado ?? this.estado,
      detalle: detalle ?? this.detalle,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  Map<String, dynamic> toJson() => {
    'contactoId': contactoId,
    'nombre': nombre,
    'telefono': telefono,
    'prioritario': prioritario,
    'canal': canal?.name,
    'estado': estado.name,
    'detalle': detalle,
    'actualizadoEn': actualizadoEn?.toIso8601String(),
  };

  factory EnvioContacto.fromJson(Map<String, dynamic> json) {
    return EnvioContacto(
      contactoId: json['contactoId'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String,
      prioritario: json['prioritario'] as bool? ?? false,
      canal: _canalDesdeNombre(json['canal'] as String?),
      estado: EstadoEnvio.values.firstWhere(
        (valor) => valor.name == json['estado'],
        orElse: () => EstadoEnvio.pendiente,
      ),
      detalle: json['detalle'] as String?,
      actualizadoEn: json['actualizadoEn'] == null
          ? null
          : DateTime.tryParse(json['actualizadoEn'] as String),
    );
  }
}

class Emergencia {
  const Emergencia({
    required this.id,
    required this.tipo,
    required this.usuarioNombre,
    required this.inicio,
    required this.mensaje,
    required this.envios,
    required this.envioInicialIntentado,
    this.fin,
    this.activa = true,
    this.latitud,
    this.longitud,
    this.precisionMetros,
    this.ubicacionLegible,
    this.estadoCompartir,
    this.compartidoEn,
  });

  final String id;
  final TipoEmergencia tipo;
  final String usuarioNombre;
  final DateTime inicio;
  final DateTime? fin;
  final bool activa;
  final String mensaje;
  final List<EnvioContacto> envios;
  final bool envioInicialIntentado;
  final double? latitud;
  final double? longitud;
  final double? precisionMetros;
  final String? ubicacionLegible;
  final EstadoEnvio? estadoCompartir;
  final DateTime? compartidoEn;

  bool get tieneUbicacion => latitud != null && longitud != null;

  String get coordenadasTexto => tieneUbicacion
      ? '${latitud!.toStringAsFixed(6)}, ${longitud!.toStringAsFixed(6)}'
      : 'Ubicación no disponible';

  String get urlMapa => tieneUbicacion
      ? 'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud'
      : '';

  List<EnvioContacto> get enviosPrioritarios =>
      envios.where((envio) => envio.prioritario).toList();

  bool get hayPendientes =>
      envios.any((envio) => envio.estado == EstadoEnvio.pendiente);

  bool get hayFallidos =>
      envios.any((envio) => envio.estado == EstadoEnvio.fallido);

  bool get hayCanalesAbiertos =>
      envios.any((envio) => envio.estado == EstadoEnvio.abiertoEnApp);

  String get resumenEnvios {
    if (envios.isEmpty) return 'Sin contactos de emergencia configurados.';
    if (hayCanalesAbiertos) {
      return 'Se abrió al menos un canal externo. La entrega no está confirmada.';
    }
    if (hayFallidos) {
      return 'No se pudo abrir ningún canal. Revisa la conectividad.';
    }
    return 'Envíos pendientes de acción del usuario.';
  }

  Duration duracionHasta(DateTime ahora) => (fin ?? ahora).difference(inicio);

  Emergencia conEnvios(List<EnvioContacto> nuevosEnvios) {
    return _copiar(envios: nuevosEnvios);
  }

  Emergencia conEnvioInicial({
    required bool intentado,
    EstadoEnvio? estadoCompartir,
    DateTime? compartidoEn,
  }) {
    return _copiar(
      envioInicialIntentado: intentado,
      estadoCompartir: estadoCompartir,
      compartidoEn: compartidoEn,
    );
  }

  Emergencia conCompartido(EstadoEnvio estado, DateTime fecha) {
    return _copiar(estadoCompartir: estado, compartidoEn: fecha);
  }

  Emergencia finalizada(DateTime fecha) {
    return _copiar(activa: false, fin: fecha);
  }

  Emergencia _copiar({
    DateTime? fin,
    bool? activa,
    List<EnvioContacto>? envios,
    bool? envioInicialIntentado,
    EstadoEnvio? estadoCompartir,
    DateTime? compartidoEn,
  }) {
    return Emergencia(
      id: id,
      tipo: tipo,
      usuarioNombre: usuarioNombre,
      inicio: inicio,
      fin: fin ?? this.fin,
      activa: activa ?? this.activa,
      mensaje: mensaje,
      envios: envios ?? this.envios,
      envioInicialIntentado:
          envioInicialIntentado ?? this.envioInicialIntentado,
      latitud: latitud,
      longitud: longitud,
      precisionMetros: precisionMetros,
      ubicacionLegible: ubicacionLegible,
      estadoCompartir: estadoCompartir ?? this.estadoCompartir,
      compartidoEn: compartidoEn ?? this.compartidoEn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'usuarioNombre': usuarioNombre,
    'inicio': inicio.toIso8601String(),
    'fin': fin?.toIso8601String(),
    'activa': activa,
    'mensaje': mensaje,
    'envios': envios.map((envio) => envio.toJson()).toList(),
    'envioInicialIntentado': envioInicialIntentado,
    'latitud': latitud,
    'longitud': longitud,
    'precisionMetros': precisionMetros,
    'ubicacionLegible': ubicacionLegible,
    'estadoCompartir': estadoCompartir?.name,
    'compartidoEn': compartidoEn?.toIso8601String(),
  };

  factory Emergencia.fromJson(Map<String, dynamic> json) {
    final enviosJson = json['envios'];

    return Emergencia(
      id: json['id'] as String,
      tipo: TipoEmergencia.values.firstWhere(
        (valor) => valor.name == json['tipo'],
        orElse: () => TipoEmergencia.sos,
      ),
      usuarioNombre: json['usuarioNombre'] as String? ?? 'Usuario',
      inicio: DateTime.parse(json['inicio'] as String),
      fin: json['fin'] == null
          ? null
          : DateTime.tryParse(json['fin'] as String),
      activa: json['activa'] as bool? ?? false,
      mensaje: json['mensaje'] as String? ?? '',
      envios: enviosJson is List
          ? enviosJson
                .whereType<Map>()
                .map(
                  (item) =>
                      EnvioContacto.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      envioInicialIntentado: json['envioInicialIntentado'] as bool? ?? false,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      precisionMetros: (json['precisionMetros'] as num?)?.toDouble(),
      ubicacionLegible: json['ubicacionLegible'] as String?,
      estadoCompartir: _estadoDesdeNombre(json['estadoCompartir'] as String?),
      compartidoEn: json['compartidoEn'] == null
          ? null
          : DateTime.tryParse(json['compartidoEn'] as String),
    );
  }
}

CanalEnvio? _canalDesdeNombre(String? nombre) {
  for (final valor in CanalEnvio.values) {
    if (valor.name == nombre) return valor;
  }
  return null;
}

EstadoEnvio? _estadoDesdeNombre(String? nombre) {
  for (final valor in EstadoEnvio.values) {
    if (valor.name == nombre) return valor;
  }
  return null;
}
