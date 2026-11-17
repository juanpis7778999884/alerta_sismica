import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/estado_carga.dart';
import '../models/sismo.dart';
import '../repositories/sismos_repository.dart';
import '../services/notification_service.dart';
import 'configuracion_provider.dart';

class SismoConDistancia {
  const SismoConDistancia({required this.sismo, required this.distanciaKm});

  final Sismo sismo;
  final double distanciaKm;
}

class SismosProvider extends ChangeNotifier {
  SismosProvider({
    required this.configuracion,
    SismosRepository? repository,
    NotificationGateway? notificaciones,
  }) : _repository = repository ?? SismosRepository(),
       _notificaciones = notificaciones ?? NotificationService();

  final ConfiguracionProvider configuracion;
  final SismosRepository _repository;
  final NotificationGateway _notificaciones;

  List<Sismo> _sismos = const [];
  EstadoCarga _estado = EstadoCarga.inicial;
  String? _error;
  DateTime? _actualizadoEn;
  OrigenSismos? _origen;
  int _descartados = 0;
  bool _enCurso = false;
  bool _inicializado = false;

  List<Sismo> get todos => List.unmodifiable(_sismos);
  EstadoCarga get estado => _estado;
  String? get error => _error;
  DateTime? get actualizadoEn => _actualizadoEn;
  OrigenSismos? get origen => _origen;
  bool get usaCache =>
      _estado == EstadoCarga.datosDesactualizados ||
      _origen == OrigenSismos.cache;
  int get descartados => _descartados;
  bool get cargando => _enCurso || _estado == EstadoCarga.cargando;
  bool get hayDatos => _sismos.isNotEmpty;
  bool get vacio => !hayDatos && !cargando;

  List<Sismo> get visibles => _sismos
      .where((sismo) => sismo.magnitud >= configuracion.magnitudMinima)
      .toList();

  Sismo? get ultimoSismo => visibles.isEmpty ? null : visibles.first;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    await cargar();
  }

  Future<void> cargar({bool silencioso = false}) async {
    if (_enCurso) return;
    _enCurso = true;
    if (!silencioso) {
      _estado = EstadoCarga.cargando;
      _error = null;
      notifyListeners();
    }

    final idsPrevios = _sismos.map((sismo) => sismo.id).toSet();
    final teniaDatos = idsPrevios.isNotEmpty;

    try {
      final resultado = await _repository.obtener();
      _sismos = resultado.eventos;
      _actualizadoEn = resultado.actualizadoEn;
      _origen = resultado.origen;
      _descartados = resultado.descartados;
      _error = resultado.advertencia;
      _estado = resultado.desdeCache
          ? EstadoCarga.datosDesactualizados
          : EstadoCarga.exito;

      if (teniaDatos) {
        await _notificarNuevos(idsPrevios);
      }
    } on AppException catch (error) {
      _error = error.message;
      _estado = _sismos.isEmpty
          ? EstadoCarga.sinConexion
          : EstadoCarga.datosDesactualizados;
    } catch (_) {
      _error = 'No se pudieron actualizar los sismos. Se muestran los datos disponibles.';
      _estado = _sismos.isEmpty
          ? EstadoCarga.sinConexion
          : EstadoCarga.datosDesactualizados;
    } finally {
      _enCurso = false;
      notifyListeners();
    }
  }

  Future<void> refrescar() => cargar();

  Future<bool> limpiarCache() async {
    try {
      await _repository.limpiarCache();
      _sismos = const [];
      _actualizadoEn = null;
      _origen = null;
      _descartados = 0;
      _estado = EstadoCarga.inicial;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo borrar la caché de sismos.';
      notifyListeners();
      return false;
    }
  }

  List<SismoConDistancia> cercanos(
    double latitud,
    double longitud, {
    double radioKm = 1500,
  }) {
    final resultado = <SismoConDistancia>[];
    for (final sismo in visibles) {
      final distancia = sismo.distanciaKmDesde(latitud, longitud);
      if (distancia <= radioKm) {
        resultado.add(SismoConDistancia(sismo: sismo, distanciaKm: distancia));
      }
    }
    resultado.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return resultado;
  }

  Future<void> _notificarNuevos(Set<String> idsPrevios) async {
    if (!configuracion.notificarSismos) return;
    final nuevos = _sismos
        .where(
          (sismo) =>
              !idsPrevios.contains(sismo.id) &&
              !sismo.esSimulacion &&
              sismo.magnitud >= configuracion.umbralNotificacion,
        )
        .take(3)
        .toList();
    if (nuevos.isEmpty) return;
    try {
      await _notificaciones.mostrarSismosNuevos(nuevos);
    } catch (_) {
      // Una notificación fallida no debe afectar la lista de sismos.
    }
  }
}
