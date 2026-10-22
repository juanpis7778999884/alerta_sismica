import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contacto.dart';

class ContactosProvider extends ChangeNotifier {
  static const String _key = 'contactos_emergencia';

  List<Contacto> _contactos = [];

  List<Contacto> get contactos => _contactos;

  ContactosProvider() {
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    _contactos = lista
        .map((e) => Contacto.fromMap(Map<String, String>.from(jsonDecode(e))))
        .toList();
    notifyListeners();
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _contactos
        .map((c) => jsonEncode(c.toMap()))
        .toList();
    await prefs.setStringList(_key, lista);
  }

  Future<void> agregar(String nombre, String telefono) async {
    _contactos.add(Contacto(nombre: nombre, telefono: telefono));
    await _guardar();
    notifyListeners();
  }

  Future<void> eliminar(Contacto contacto) async {
    _contactos.remove(contacto);
    await _guardar();
    notifyListeners();
  }

  Future<void> limpiar() async {
    _contactos.clear();
    await _guardar();
    notifyListeners();
  }
}
