import 'package:drift/drift.dart';

import '../models/tarea.dart';
import 'app_database.dart';
import 'errores.dart';
import 'validaciones.dart';

/// Unico punto de acceso a SQLite.
///
/// La pantalla NO ejecuta SQL: solo llama a estos metodos. Las consultas se
/// crean una sola vez (en initState) y nunca dentro de `build()` (F8).
///
/// Todos los metodos traducen cualquier fallo del motor a
/// [ErrorAlmacenamiento], con un mensaje que la interfaz puede mostrar.
class TareasRepository {
  TareasRepository(this._db);

  final AppDatabase _db;
  bool _cerrado = false;

  /// Consulta reactiva (Stream). Drift reemite la lista completa cada vez que
  /// la tabla `tareas` cambia, asi que despues de un INSERT/UPDATE/DELETE la
  /// interfaz se actualiza sola: no hace falta volver a consultar a mano.
  Stream<List<Tarea>> observarTareas() {
    final consulta = _db.select(_db.tareas)
      ..orderBy([
        (t) => OrderingTerm(expression: t.completada),
        (t) => OrderingTerm(expression: t.creadaEn, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    return consulta.watch().map(
          (filas) => filas.map(_aModelo).toList(growable: false),
        );
  }

  /// SELECT puntual, util en pruebas y al reabrir la app (F2).
  Future<List<Tarea>> listarTareas() {
    return _protegido('No se pudieron leer las tareas.', () async {
      final filas = await _db.select(_db.tareas).get();
      return filas.map(_aModelo).toList(growable: false);
    });
  }

  /// F1. INSERT. Valida y normaliza el titulo antes de escribir.
  Future<Tarea> agregarTarea(String tituloCrudo) {
    final error = validarTitulo(tituloCrudo);
    if (error != null) {
      return Future.error(ErrorAlmacenamiento(error));
    }
    final titulo = normalizarTitulo(tituloCrudo);

    return _protegido('No se pudo guardar la tarea.', () async {
      final fila = await _db.into(_db.tareas).insertReturning(
            TareasCompanion.insert(titulo: titulo),
          );
      return _aModelo(fila);
    });
  }

  /// F3. UPDATE del titulo.
  Future<void> editarTitulo(int id, String tituloCrudo) {
    final error = validarTitulo(tituloCrudo);
    if (error != null) {
      return Future.error(ErrorAlmacenamiento(error));
    }
    final titulo = normalizarTitulo(tituloCrudo);

    return _protegido('No se pudo editar la tarea $id.', () async {
      final filas = await (_db.update(_db.tareas)..where((t) => t.id.equals(id)))
          .write(TareasCompanion(titulo: Value(titulo)));
      if (filas == 0) {
        throw ErrorAlmacenamiento('La tarea $id ya no existe.');
      }
    });
  }

  /// F4. UPDATE del estado completada/pendiente.
  Future<void> cambiarEstado(int id, bool completada) {
    return _protegido('No se pudo cambiar el estado de la tarea $id.', () async {
      final filas = await (_db.update(_db.tareas)..where((t) => t.id.equals(id)))
          .write(TareasCompanion(completada: Value(completada)));
      if (filas == 0) {
        throw ErrorAlmacenamiento('La tarea $id ya no existe.');
      }
    });
  }

  /// F5. DELETE por identificador.
  Future<void> eliminarTarea(int id) {
    return _protegido('No se pudo eliminar la tarea $id.', () async {
      final filas =
          await (_db.delete(_db.tareas)..where((t) => t.id.equals(id))).go();
      if (filas == 0) {
        throw ErrorAlmacenamiento('La tarea $id ya no existe.');
      }
    });
  }

  /// Borra todas las tareas (util para reiniciar la demostracion).
  Future<int> vaciar() {
    return _protegido(
      'No se pudo vaciar la tabla.',
      () => _db.delete(_db.tareas).go(),
    );
  }

  /// F8. Libera la conexion cuando la app termina. Es idempotente: llamarlo
  /// dos veces (por ejemplo desde `dispose` y desde una prueba) no falla.
  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    await _db.close();
  }

  /// Ejecuta [accion] y convierte cualquier fallo del motor (disco lleno,
  /// base bloqueada, almacenamiento del navegador deshabilitado, etc.) en un
  /// [ErrorAlmacenamiento] con un mensaje legible. Se escribe asi, y no con
  /// `on SqliteException`, porque esa clase no existe en la version web.
  Future<T> _protegido<T>(String mensaje, Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorAlmacenamiento {
      rethrow;
    } catch (e) {
      throw ErrorAlmacenamiento('$mensaje ($e)', e);
    }
  }

  Tarea _aModelo(TareaRow fila) => Tarea(
        id: fila.id,
        titulo: fila.titulo,
        completada: fila.completada,
        creadaEn: fila.creadaEn,
      );
}
