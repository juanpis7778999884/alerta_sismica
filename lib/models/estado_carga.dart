enum EstadoCarga {
  inicial,
  cargando,
  exito,
  sinConexion,
  datosDesactualizados,
  error,
}

extension EstadoCargaX on EstadoCarga {
  bool get estaCargando => this == EstadoCarga.cargando;

  bool get tieneDatos =>
      this == EstadoCarga.exito || this == EstadoCarga.datosDesactualizados;

  bool get usaCache => this == EstadoCarga.datosDesactualizados;
}
