import 'dart:async';

import 'package:flutter/material.dart';

import '../core/utils/date_formatters.dart';

class CronometroEmergencia extends StatefulWidget {
  const CronometroEmergencia({super.key, required this.inicio, this.style});

  final DateTime inicio;
  final TextStyle? style;

  @override
  State<CronometroEmergencia> createState() => _CronometroEmergenciaState();
}

class _CronometroEmergenciaState extends State<CronometroEmergencia> {
  late Timer _timer;
  Duration _transcurrido = Duration.zero;

  @override
  void initState() {
    super.initState();
    _actualizar();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _actualizar());
  }

  void _actualizar() {
    if (!mounted) return;
    setState(() {
      _transcurrido = DateTime.now().difference(widget.inicio);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tiempo transcurrido ${DateFormatters.duracion(_transcurrido)}',
      child: Text(DateFormatters.duracion(_transcurrido), style: widget.style),
    );
  }
}
