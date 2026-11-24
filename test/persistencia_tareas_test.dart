import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/errores.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';

/// Prueba 2 de las dos obligatorias: operaciones reales de almacenamiento.
///
/// Se usa el mismo motor SQLite y el mismo SQL que en producción, pero en
/// memoria o sobre un archivo temporal, para no tocar la base del usuario.
void main() {
  test('CRUD completo sobre SQLite', () async {
    final repo = TareasRepository(AppDatabase.conExecutor(NativeDatabase.memory()));

    // Alta (F1) y consulta (F2).
    final tarea = await repo.agregarTarea('  Estudiar   SQLite  ');
    expect(tarea.id, greaterThan(0));
    expect(tarea.titulo, 'Estudiar SQLite'); // el título se normaliza
    expect(await repo.listarTareas(), hasLength(1));

    // Edición del título (F3).
    await repo.editarTitulo(tarea.id, 'Título nuevo');
    expect((await repo.listarTareas()).single.titulo, 'Título nuevo');

    // Cambio de estado (F4).
    await repo.cambiarEstado(tarea.id, true);
    expect((await repo.listarTareas()).single.completada, isTrue);

    // Eliminación (F5).
    await repo.eliminarTarea(tarea.id);
    expect(await repo.listarTareas(), isEmpty);

    await repo.cerrar();
  });

  test('un título vacío no llega a la base de datos', () async {
    final repo = TareasRepository(AppDatabase.conExecutor(NativeDatabase.memory()));

    await expectLater(
      repo.agregarTarea('   '),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
    expect(await repo.listarTareas(), isEmpty);

    await repo.cerrar();
  });

  test('los datos sobreviven al cierre y la reapertura del archivo', () async {
    // Esta es la comprobación que una lista en memoria no puede pasar.
    final carpeta = await Directory.systemTemp.createTemp('gestor_tareas_test');
    final archivo = File('${carpeta.path}/prueba.sqlite');

    var repo = TareasRepository(AppDatabase.conExecutor(NativeDatabase(archivo)));
    await repo.agregarTarea('Tarea 1');
    final segunda = await repo.agregarTarea('Tarea 2');
    await repo.cambiarEstado(segunda.id, true);
    await repo.cerrar(); // se cierra la "app"

    repo = TareasRepository(AppDatabase.conExecutor(NativeDatabase(archivo)));
    final recuperadas = await repo.listarTareas(); // se vuelve a "abrir"

    expect(recuperadas, hasLength(2));
    expect(recuperadas.firstWhere((t) => t.id == segunda.id).completada, isTrue);

    await repo.cerrar();
    carpeta.deleteSync(recursive: true);
  });
}
