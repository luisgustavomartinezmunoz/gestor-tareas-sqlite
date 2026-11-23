/// Error de la capa de almacenamiento que la interfaz puede mostrar tal cual.
class ErrorAlmacenamiento implements Exception {
  ErrorAlmacenamiento(this.mensaje, [this.causa]);

  final String mensaje;
  final Object? causa;

  @override
  String toString() => 'ErrorAlmacenamiento: $mensaje';
}
