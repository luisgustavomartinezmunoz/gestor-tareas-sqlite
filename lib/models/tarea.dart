/// Modelo de dominio de la aplicacion.
///
/// Es un objeto inmutable y SIN dependencias de la base de datos: la capa de
/// persistencia (Drift) genera su propia clase de fila y el repositorio la
/// convierte a este modelo. Asi la interfaz no conoce detalles de SQLite.
class Tarea {
  const Tarea({
    required this.id,
    required this.titulo,
    required this.completada,
    this.creadaEn,
  });

  /// Identificador unico. En SQLite corresponde a la columna
  /// `id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT`.
  final int id;

  /// Texto de la tarea. En SQLite es `titulo TEXT NOT NULL`.
  final String titulo;

  /// Estado de la tarea. SQLite no tiene tipo booleano: Drift lo guarda como
  /// `completada INTEGER NOT NULL DEFAULT 0` (0 = false, 1 = true).
  final bool completada;

  /// Fecha de alta, guardada como entero (segundos desde epoch).
  final DateTime? creadaEn;

  Tarea copyWith({int? id, String? titulo, bool? completada, DateTime? creadaEn}) {
    return Tarea(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      completada: completada ?? this.completada,
      creadaEn: creadaEn ?? this.creadaEn,
    );
  }

  @override
  String toString() => 'Tarea(id: $id, titulo: $titulo, completada: $completada)';

  @override
  bool operator ==(Object other) =>
      other is Tarea &&
      other.id == id &&
      other.titulo == titulo &&
      other.completada == completada;

  @override
  int get hashCode => Object.hash(id, titulo, completada);
}
