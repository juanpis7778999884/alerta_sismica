class DateFormatters {
  DateFormatters._();

  static const List<String> _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String fechaHora(DateTime fecha) {
    final local = fecha.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = _meses[local.month - 1];
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia $mes ${local.year}, $hora:$minuto';
  }

  static String hora(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String fechaCompleta(DateTime fecha) {
    final local = fecha.toLocal();
    const mesesLargos = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${local.day} de ${mesesLargos[local.month - 1]} de ${local.year}, '
        '${hora(local)}';
  }

  static String hace(DateTime fecha, {DateTime? ahora}) {
    final referencia = ahora ?? DateTime.now();
    final diferencia = referencia.difference(fecha);
    if (diferencia.isNegative) return 'Ahora';
    if (diferencia.inSeconds < 45) return 'Hace menos de 1 min';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
    if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays} d';
    return fechaHora(fecha);
  }

  static String duracion(Duration duracion) {
    final segundos = duracion.inSeconds.abs();
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final seg = segundos % 60;
    if (horas > 0) {
      return '${horas.toString().padLeft(2, '0')}:'
          '${minutos.toString().padLeft(2, '0')}:'
          '${seg.toString().padLeft(2, '0')}';
    }
    return '${minutos.toString().padLeft(2, '0')}:'
        '${seg.toString().padLeft(2, '0')}';
  }

  static String coordenadas(double latitud, double longitud) {
    final ns = latitud >= 0 ? 'N' : 'S';
    final ew = longitud >= 0 ? 'E' : 'O';
    return '${latitud.abs().toStringAsFixed(5)}° $ns, '
        '${longitud.abs().toStringAsFixed(5)}° $ew';
  }
}
