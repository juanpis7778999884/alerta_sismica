class Contacto {
  final String nombre;
  final String telefono;

  Contacto({required this.nombre, required this.telefono});

  Map<String, String> toMap() => {'nombre': nombre, 'telefono': telefono};

  factory Contacto.fromMap(Map<String, String> map) =>
      Contacto(nombre: map['nombre']!, telefono: map['telefono']!);
}
