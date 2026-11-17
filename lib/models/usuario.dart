class UsuarioLocal {
  const UsuarioLocal({
    required this.id,
    required this.nombre,
    required this.email,
    required this.creadoEn,
  });

  final String id;
  final String nombre;
  final String email;
  final DateTime creadoEn;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'creadoEn': creadoEn.toIso8601String(),
  };

  factory UsuarioLocal.fromJson(Map<String, dynamic> json) {
    return UsuarioLocal(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is UsuarioLocal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
