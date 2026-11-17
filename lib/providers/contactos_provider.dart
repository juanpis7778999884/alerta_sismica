import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/contacto.dart';
import '../repositories/contactos_repository.dart';

class ContactosProvider extends ChangeNotifier {
  ContactosProvider({ContactosRepository? repository, Uuid? uuid})
    : _repository = repository ?? ContactosRepository(),
      _uuid = uuid ?? const Uuid();

  final ContactosRepository _repository;
  final Uuid _uuid;

  List<Contacto> _contactos = const [];
  bool _cargando = true;
  bool _inicializado = false;
  String? _error;

  List<Contacto> get contactos => List.unmodifiable(_contactos);
  bool get cargando => _cargando;
  String? get error => _error;
  bool get hayContactos => _contactos.isNotEmpty;
  int get total => _contactos.length;

  List<Contacto> get prioritarios =>
      _contactos.where((contacto) => contacto.prioritario).toList();

  List<Contacto> get destinatariosSos {
    final prioritarios = this.prioritarios;
    return prioritarios.isNotEmpty ? prioritarios : contactos;
  }

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    await cargar();
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _contactos = _ordenar(await _repository.cargar());
    } catch (_) {
      _contactos = const [];
      _error = 'No se pudieron cargar los contactos guardados.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> recargar() => cargar();

  Contacto? porId(String id) {
    for (final contacto in _contactos) {
      if (contacto.id == id) return contacto;
    }
    return null;
  }

  Future<Contacto> agregar({
    required String nombre,
    required String telefono,
    bool prioritario = false,
  }) async {
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefono.trim();
    _validar(nombreLimpio, telefonoLimpio);
    _verificarDuplicado(telefonoLimpio);

    final contacto = Contacto(
      id: _uuid.v4(),
      nombre: nombreLimpio,
      telefono: telefonoLimpio,
      prioritario: _contactos.isEmpty ? true : prioritario,
      creadoEn: DateTime.now(),
    );
    final nuevos = await _guardarLista([..._contactos, contacto]);
    _contactos = nuevos;
    _error = null;
    notifyListeners();
    return contacto;
  }

  Future<Contacto> editar({
    required String id,
    required String nombre,
    required String telefono,
    required bool prioritario,
  }) async {
    final indice = _contactos.indexWhere((contacto) => contacto.id == id);
    if (indice == -1) {
      throw const AppException('El contacto ya no existe.');
    }
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefono.trim();
    _validar(nombreLimpio, telefonoLimpio);
    _verificarDuplicado(telefonoLimpio, exceptoId: id);

    final actualizado = _contactos[indice].copyWith(
      nombre: nombreLimpio,
      telefono: telefonoLimpio,
      prioritario: prioritario,
    );
    final lista = List<Contacto>.from(_contactos);
    lista[indice] = actualizado;
    _contactos = await _guardarLista(lista);
    _error = null;
    notifyListeners();
    return actualizado;
  }

  Future<void> eliminar(String id) async {
    final lista = _contactos.where((contacto) => contacto.id != id).toList();
    if (lista.length == _contactos.length) return;
    if (lista.isNotEmpty && !lista.any((contacto) => contacto.prioritario)) {
      lista[0] = lista[0].copyWith(prioritario: true);
    }
    _contactos = await _guardarLista(lista);
    _error = null;
    notifyListeners();
  }

  Future<void> cambiarPrioridad(String id, bool prioritario) async {
    final indice = _contactos.indexWhere((contacto) => contacto.id == id);
    if (indice == -1) return;
    final lista = List<Contacto>.from(_contactos);
    lista[indice] = lista[indice].copyWith(prioritario: prioritario);
    if (lista.isNotEmpty && !lista.any((contacto) => contacto.prioritario)) {
      _error = 'Debe existir al menos un contacto prioritario.';
      notifyListeners();
      return;
    }
    _contactos = await _guardarLista(lista);
    _error = null;
    notifyListeners();
  }

  Future<bool> borrarTodos() async {
    try {
      await _repository.limpiar();
      _contactos = const [];
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudieron borrar los contactos.';
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<List<Contacto>> _guardarLista(List<Contacto> lista) async {
    final ordenada = _ordenar(lista);
    try {
      await _repository.guardar(ordenada);
    } catch (_) {
      throw const StorageException(
        'No se pudieron guardar los contactos en el dispositivo.',
      );
    }
    return ordenada;
  }

  void _validar(String nombre, String telefono) {
    final errorNombre = Validators.nombre(nombre);
    if (errorNombre != null) throw ValidationException(errorNombre);
    final errorTelefono = Validators.telefono(telefono);
    if (errorTelefono != null) throw ValidationException(errorTelefono);
  }

  void _verificarDuplicado(String telefono, {String? exceptoId}) {
    final duplicado = _contactos.any(
      (contacto) =>
          contacto.id != exceptoId &&
          Validators.telefonosIguales(contacto.telefono, telefono),
    );
    if (duplicado) {
      throw const ValidationException(
        'Ya existe un contacto con ese número de teléfono.',
      );
    }
  }

  List<Contacto> _ordenar(List<Contacto> lista) {
    final copia = List<Contacto>.from(lista);
    copia.sort((a, b) {
      if (a.prioritario != b.prioritario) {
        return a.prioritario ? -1 : 1;
      }
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return copia;
  }
}
