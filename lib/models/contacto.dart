import '../core/utils/validators.dart';

class Contacto {
  const Contacto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.creadoEn,
    this.prioritario = false,
  });

  final String id;
  final String nombre;
  final String telefono;
  final bool prioritario;
  final DateTime creadoEn;

  String get telefonoDigitos => Validators.normalizarTelefono(telefono);

  String get telefonoFormateado => Validators.formatearTelefono(telefono);

  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'prioritario': prioritario,
    'creadoEn': creadoEn.toIso8601String(),
  };

  factory Contacto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final telefono = json['telefono'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Contacto sin identificador.');
    }
    if (nombre is! String || nombre.trim().isEmpty) {
      throw const FormatException('Contacto sin nombre.');
    }
    if (telefono is! String || telefono.trim().isEmpty) {
      throw const FormatException('Contacto sin teléfono.');
    }
    final creado = json['creadoEn'];
    return Contacto(
      id: id,
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      prioritario: json['prioritario'] as bool? ?? false,
      creadoEn: creado is String
          ? DateTime.tryParse(creado) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Contacto copyWith({
    String? id,
    String? nombre,
    String? telefono,
    bool? prioritario,
    DateTime? creadoEn,
  }) {
    return Contacto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      prioritario: prioritario ?? this.prioritario,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  bool operator ==(Object other) => other is Contacto && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Contacto($id, $nombre, $telefono)';
}
