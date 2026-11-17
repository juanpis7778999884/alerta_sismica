enum TemaApp { claro, oscuro, sistema }

extension TemaAppX on TemaApp {
  String get etiqueta {
    switch (this) {
      case TemaApp.claro:
        return 'Claro';
      case TemaApp.oscuro:
        return 'Oscuro';
      case TemaApp.sistema:
        return 'Sistema';
    }
  }
}

class ConfiguracionApp {
  const ConfiguracionApp({
    this.tema = TemaApp.claro,
    this.magnitudMinima = 2.5,
    this.autoRefresco = true,
    this.notificarSismos = false,
    this.umbralNotificacion = 4.5,
    this.numeroEmergencia = '',
  });

  final TemaApp tema;
  final double magnitudMinima;
  final bool autoRefresco;
  final bool notificarSismos;
  final double umbralNotificacion;
  final String numeroEmergencia;

  static const ConfiguracionApp inicial = ConfiguracionApp();

  ConfiguracionApp copyWith({
    TemaApp? tema,
    double? magnitudMinima,
    bool? autoRefresco,
    bool? notificarSismos,
    double? umbralNotificacion,
    String? numeroEmergencia,
  }) {
    return ConfiguracionApp(
      tema: tema ?? this.tema,
      magnitudMinima: magnitudMinima ?? this.magnitudMinima,
      autoRefresco: autoRefresco ?? this.autoRefresco,
      notificarSismos: notificarSismos ?? this.notificarSismos,
      umbralNotificacion: umbralNotificacion ?? this.umbralNotificacion,
      numeroEmergencia: numeroEmergencia ?? this.numeroEmergencia,
    );
  }

  Map<String, dynamic> toJson() => {
    'tema': tema.name,
    'magnitudMinima': magnitudMinima,
    'autoRefresco': autoRefresco,
    'notificarSismos': notificarSismos,
    'umbralNotificacion': umbralNotificacion,
    'numeroEmergencia': numeroEmergencia,
  };

  factory ConfiguracionApp.fromJson(Map<String, dynamic> json) {
    final temaNombre = json['tema'] as String?;
    final tema = TemaApp.values.firstWhere(
      (valor) => valor.name == temaNombre,
      orElse: () => TemaApp.claro,
    );
    final magnitud = (json['magnitudMinima'] as num?)?.toDouble() ?? 2.5;
    final umbral = (json['umbralNotificacion'] as num?)?.toDouble() ?? 4.5;
    return ConfiguracionApp(
      tema: tema,
      magnitudMinima: magnitud.clamp(1.0, 7.0),
      autoRefresco: json['autoRefresco'] as bool? ?? true,
      notificarSismos: json['notificarSismos'] as bool? ?? false,
      umbralNotificacion: umbral.clamp(2.5, 7.0),
      numeroEmergencia: json['numeroEmergencia'] as String? ?? '',
    );
  }
}
