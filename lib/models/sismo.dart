import 'package:flutter/material.dart';

class Sismo {
  final String id;
  final double magnitud;
  final String lugar;
  final double latitud;
  final double longitud;
  final double profundidad;
  final DateTime tiempo;
  final String url;

  Sismo({
    required this.id,
    required this.magnitud,
    required this.lugar,
    required this.latitud,
    required this.longitud,
    required this.profundidad,
    required this.tiempo,
    required this.url,
  });

  factory Sismo.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>;
    final geom = json['geometry'] as Map<String, dynamic>;
    final coords = geom['coordinates'] as List<dynamic>;

    return Sismo(
      id: json['id'] as String,
      magnitud: (props['mag'] as num).toDouble(),
      lugar: props['place'] as String? ?? 'Desconocido',
      longitud: (coords[0] as num).toDouble(),
      latitud: (coords[1] as num).toDouble(),
      profundidad: (coords[2] as num).toDouble(),
      tiempo: DateTime.fromMillisecondsSinceEpoch(props['time'] as int),
      url: props['url'] as String? ?? '',
    );
  }

  Color get colorMagnitud {
    if (magnitud >= 7.0) return const Color(0xFFB71C1C);
    if (magnitud >= 6.0) return const Color(0xFFD32F2F);
    if (magnitud >= 5.0) return const Color(0xFFF57C00);
    if (magnitud >= 4.0) return const Color(0xFFFFB300);
    return const Color(0xFF43A047);
  }

  String get magnitudTexto {
    if (magnitud >= 7.0) return 'Mayor';
    if (magnitud >= 6.0) return 'Fuerte';
    if (magnitud >= 5.0) return 'Moderado';
    if (magnitud >= 4.0) return 'Leve';
    return 'Menor';
  }
}
