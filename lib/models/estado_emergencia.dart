import 'sismo.dart';

enum TipoEmergencia { sos, sismo, simulacion }

class EstadoEmergencia {
  final bool activa;
  final TipoEmergencia? tipo;
  final DateTime? inicio;
  final double? latitud;
  final double? longitud;
  final Sismo? sismo;

  EstadoEmergencia({
    this.activa = false,
    this.tipo,
    this.inicio,
    this.latitud,
    this.longitud,
    this.sismo,
  });

  EstadoEmergencia copyWith({
    bool? activa,
    TipoEmergencia? tipo,
    DateTime? inicio,
    double? latitud,
    double? longitud,
    Sismo? sismo,
  }) {
    return EstadoEmergencia(
      activa: activa ?? this.activa,
      tipo: tipo ?? this.tipo,
      inicio: inicio ?? this.inicio,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      sismo: sismo ?? this.sismo,
    );
  }

  static EstadoEmergencia vacio() => EstadoEmergencia();
}
