import 'dart:math' as math;

enum MagnitudNivel { menor, leve, moderado, fuerte, mayor }

extension MagnitudNivelX on MagnitudNivel {
  String get etiqueta {
    switch (this) {
      case MagnitudNivel.menor:
        return 'Menor';
      case MagnitudNivel.leve:
        return 'Leve';
      case MagnitudNivel.moderado:
        return 'Moderado';
      case MagnitudNivel.fuerte:
        return 'Fuerte';
      case MagnitudNivel.mayor:
        return 'Mayor';
    }
  }
}

class Sismo {
  const Sismo({
    required this.id,
    required this.magnitud,
    required this.lugar,
    required this.latitud,
    required this.longitud,
    required this.profundidad,
    required this.tiempo,
    required this.url,
    this.esSimulacion = false,
    this.actualizadoEn,
  });

  final String id;
  final double magnitud;
  final String lugar;
  final double latitud;
  final double longitud;
  final double profundidad;
  final DateTime tiempo;
  final String url;
  final bool esSimulacion;
  final DateTime? actualizadoEn;

  factory Sismo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final props = json['properties'];
    final geometry = json['geometry'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Evento sin identificador.');
    }
    if (props is! Map<String, dynamic>) {
      throw const FormatException('Evento sin propiedades.');
    }
    if (geometry is! Map<String, dynamic>) {
      throw const FormatException('Evento sin geometría.');
    }

    final mag = props['mag'];
    if (mag is! num) {
      throw const FormatException('Evento sin magnitud válida.');
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 3) {
      throw const FormatException('Evento con coordenadas incompletas.');
    }

    final longitud = coordinates[0];
    final latitud = coordinates[1];
    final profundidad = coordinates[2];
    if (latitud is! num || longitud is! num || profundidad is! num) {
      throw const FormatException('Evento con coordenadas no numéricas.');
    }
    if (latitud < -90 || latitud > 90 || longitud < -180 || longitud > 180) {
      throw const FormatException('Evento con coordenadas fuera de rango.');
    }

    final tiempoMs = props['time'];
    if (tiempoMs is! num) {
      throw const FormatException('Evento sin fecha válida.');
    }

    final url = props['url'];
    final urlSegura =
        url is String &&
            (url.startsWith('https://') || url.startsWith('http://'))
        ? url
        : '';

    final actualizadoMs = props['updated'];
    final actualizado = actualizadoMs is num
        ? DateTime.fromMillisecondsSinceEpoch(
            actualizadoMs.toInt(),
            isUtc: true,
          )
        : null;

    return Sismo(
      id: id,
      magnitud: mag.toDouble(),
      lugar: (props['place'] as String?)?.trim().isNotEmpty == true
          ? (props['place'] as String).trim()
          : 'Ubicación no especificada',
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      profundidad: profundidad.toDouble(),
      tiempo: DateTime.fromMillisecondsSinceEpoch(
        tiempoMs.toInt(),
        isUtc: true,
      ),
      url: urlSegura,
      actualizadoEn: actualizado,
    );
  }

  factory Sismo.fromCacheJson(Map<String, dynamic> json) {
    return Sismo(
      id: json['id'] as String,
      magnitud: (json['magnitud'] as num).toDouble(),
      lugar: json['lugar'] as String? ?? 'Ubicación no especificada',
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      profundidad: (json['profundidad'] as num).toDouble(),
      tiempo: DateTime.parse(json['tiempo'] as String),
      url: json['url'] as String? ?? '',
      esSimulacion: json['esSimulacion'] as bool? ?? false,
      actualizadoEn: json['actualizadoEn'] == null
          ? null
          : DateTime.parse(json['actualizadoEn'] as String),
    );
  }

  factory Sismo.simulado({
    double magnitud = 5.4,
    String lugar = 'Simulación cerca de tu ubicación',
    double latitud = 4.6533,
    double longitud = -74.0836,
    DateTime? tiempo,
  }) {
    final ahora = tiempo ?? DateTime.now();
    return Sismo(
      id: 'simulacion_${ahora.millisecondsSinceEpoch}',
      magnitud: magnitud,
      lugar: lugar,
      latitud: latitud,
      longitud: longitud,
      profundidad: 12,
      tiempo: ahora,
      url: '',
      esSimulacion: true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'magnitud': magnitud,
    'lugar': lugar,
    'latitud': latitud,
    'longitud': longitud,
    'profundidad': profundidad,
    'tiempo': tiempo.toIso8601String(),
    'url': url,
    'esSimulacion': esSimulacion,
    'actualizadoEn': actualizadoEn?.toIso8601String(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'properties': {
      'mag': magnitud,
      'place': lugar,
      'time': tiempo.millisecondsSinceEpoch,
      'url': url,
      'updated': actualizadoEn?.millisecondsSinceEpoch,
    },
    'geometry': {
      'coordinates': [longitud, latitud, profundidad],
    },
  };

  MagnitudNivel get nivel {
    if (magnitud >= 7) return MagnitudNivel.mayor;
    if (magnitud >= 6) return MagnitudNivel.fuerte;
    if (magnitud >= 5) return MagnitudNivel.moderado;
    if (magnitud >= 4) return MagnitudNivel.leve;
    return MagnitudNivel.menor;
  }

  String get magnitudTexto => nivel.etiqueta;

  String get magnitudFormateada => magnitud.toStringAsFixed(1);

  String get profundidadTexto => '${profundidad.toStringAsFixed(1)} km';

  String get coordenadasTexto =>
      '${latitud.toStringAsFixed(4)}, ${longitud.toStringAsFixed(4)}';

  String get urlMapa =>
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';

  bool get esReciente =>
      DateTime.now().difference(tiempo.toLocal()).inHours < 1;

  bool get tieneEnlace => url.isNotEmpty;

  double distanciaKmDesde(double otraLatitud, double otraLongitud) {
    const radioTierraKm = 6371.0;
    final dLat = _radianes(otraLatitud - latitud);
    final dLon = _radianes(otraLongitud - longitud);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radianes(latitud)) *
            math.cos(_radianes(otraLatitud)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierraKm * c;
  }

  Sismo copyWith({
    String? id,
    double? magnitud,
    String? lugar,
    double? latitud,
    double? longitud,
    double? profundidad,
    DateTime? tiempo,
    String? url,
    bool? esSimulacion,
    DateTime? actualizadoEn,
  }) {
    return Sismo(
      id: id ?? this.id,
      magnitud: magnitud ?? this.magnitud,
      lugar: lugar ?? this.lugar,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      profundidad: profundidad ?? this.profundidad,
      tiempo: tiempo ?? this.tiempo,
      url: url ?? this.url,
      esSimulacion: esSimulacion ?? this.esSimulacion,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Sismo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Sismo($id, M$magnitudFormateada, $lugar, ${tiempo.toIso8601String()})';

  static double _radianes(double grados) => grados * math.pi / 180;
}
