import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sismo.dart';

class SismosProvider extends ChangeNotifier {
  static const String _usgsUrl =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';

  List<Sismo> _sismos = [];
  Sismo? _ultimoSismo;
  bool _cargando = false;
  String? _error;

  List<Sismo> get sismos => _sismos;
  Sismo? get ultimoSismo => _ultimoSismo;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarSismos() async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await http.get(Uri.parse(_usgsUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Tiempo agotado'),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>;

        _sismos = features
            .map((f) => Sismo.fromJson(f as Map<String, dynamic>))
            .where((s) => s.magnitud >= 2.5)
            .toList();

        _sismos.sort((a, b) => b.tiempo.compareTo(a.tiempo));
        _ultimoSismo = _sismos.isNotEmpty ? _sismos.first : null;
      } else {
        _error = 'Error ${resp.statusCode} al obtener sismos';
      }
    } catch (e) {
      _error = 'Sin conexión: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void simularSismo() {
    final ahora = DateTime.now();
    final sismo = Sismo(
      id: 'simulado_${ahora.millisecondsSinceEpoch}',
      magnitud: 5.2,
      lugar: 'Simulación - Cerca de tu ubicación',
      latitud: 4.65,
      longitud: -74.1,
      profundidad: 10.0,
      tiempo: ahora,
      url: '',
    );
    _sismos.insert(0, sismo);
    _ultimoSismo = sismo;
    notifyListeners();
  }
}
