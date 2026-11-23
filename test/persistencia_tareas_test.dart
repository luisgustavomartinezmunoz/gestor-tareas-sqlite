import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/errores.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';

/// Prueba 2 de las dos obligatorias: operaciones reales de almacenamiento.
///
/// Se usa `NativeDatabase.memory()`: es el MISMO motor SQLite y el mismo SQL
/// generado por Drift que en producción, pero en memoria, para no escribir en
/// el disco del usuario ni dejar basura entre pruebas.
void main() {
  late AppDatabase db;
  late TareasRepository repositorio;

  setUp(() {
    db = AppDatabase.conExecutor(NativeDatabase.memory());
    repositorio = TareasRepository(db);
  });

  tearDown(() async {
    await repositorio.cerrar();
  });

  test('la tabla arranca vacía', () async {
    expect(await repositorio.listarTareas(), isEmpty);
  });

  test('INSERT: agregar guarda la tarea y le asigna un ID', () async {
    final tarea = await repositorio.agregarTarea('Estudiar SQLite');

    expect(tarea.id, greaterThan(0));
    expect(tarea.titulo, 'Estudiar SQLite');
    expect(tarea.completada, isFalse);

    final guardadas = await repositorio.listarTareas();
    expect(guardadas, hasLength(1));
    expect(guardadas.single.titulo, 'Estudiar SQLite');
  });

  test('INSERT: el título se normaliza antes de escribir', () async {
    final tarea = await repositorio.agregarTarea('   comprar    pan   ');
    expect(tarea.titulo, 'comprar pan');
  });

  test('INSERT: un título vacío no llega a la base de datos', () async {
    await expectLater(
      repositorio.agregarTarea('   '),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
    expect(await repositorio.listarTareas(), isEmpty);
  });

  test('SELECT: los IDs son únicos y crecientes', () async {
    final a = await repositorio.agregarTarea('Tarea A');
    final b = await repositorio.agregarTarea('Tarea B');
    final c = await repositorio.agregarTarea('Tarea C');

    expect({a.id, b.id, c.id}, hasLength(3));
    expect(b.id, greaterThan(a.id));
    expect(c.id, greaterThan(b.id));
    expect(await repositorio.listarTareas(), hasLength(3));
  });

  test('UPDATE: editar cambia el título y conserva el ID', () async {
    final tarea = await repositorio.agregarTarea('Titulo viejo');
    await repositorio.editarTitulo(tarea.id, 'Titulo nuevo');

    final guardada = (await repositorio.listarTareas()).single;
    expect(guardada.id, tarea.id);
    expect(guardada.titulo, 'Titulo nuevo');
  });

  test('UPDATE: editar con un título vacío no modifica la fila', () async {
    final tarea = await repositorio.agregarTarea('Titulo valido');

    await expectLater(
      repositorio.editarTitulo(tarea.id, '   '),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
    expect((await repositorio.listarTareas()).single.titulo, 'Titulo valido');
  });

  test('UPDATE: cambiar estado se guarda en la columna completada', () async {
    final tarea = await repositorio.agregarTarea('Marcar esta');

    await repositorio.cambiarEstado(tarea.id, true);
    expect((await repositorio.listarTareas()).single.completada, isTrue);

    await repositorio.cambiarEstado(tarea.id, false);
    expect((await repositorio.listarTareas()).single.completada, isFalse);
  });

  test('DELETE: eliminar borra solo la tarea indicada', () async {
    final a = await repositorio.agregarTarea('Queda');
    final b = await repositorio.agregarTarea('Se borra');

    await repositorio.eliminarTarea(b.id);

    final restantes = await repositorio.listarTareas();
    expect(restantes, hasLength(1));
    expect(restantes.single.id, a.id);
  });

  test('operar sobre un ID inexistente avisa con un error claro', () async {
    await expectLater(
      repositorio.eliminarTarea(9999),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
    await expectLater(
      repositorio.cambiarEstado(9999, true),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
    await expectLater(
      repositorio.editarTitulo(9999, 'x'),
      throwsA(isA<ErrorAlmacenamiento>()),
    );
  });

  test('la consulta reactiva reemite la lista tras cada escritura', () async {
    final emisiones = <int>[];
    final suscripcion =
        repositorio.observarTareas().listen((lista) => emisiones.add(lista.length));

    await repositorio.agregarTarea('Uno');
    await repositorio.agregarTarea('Dos');
    await pumpEventQueue();

    await suscripcion.cancel();
    expect(emisiones.last, 2);
  });

  test('P1 simulada: los datos sobreviven al cierre y reapertura del archivo',
      () async {
    // Un archivo temporal real, cerrado y vuelto a abrir: es la comprobacion
    // de persistencia que una lista en memoria NO puede pasar.
    final archivo = await _archivoTemporal();

    var base = AppDatabase.conExecutor(NativeDatabase(archivo));
    var repo = TareasRepository(base);
    await repo.agregarTarea('Tarea 1');
    await repo.agregarTarea('Tarea 2');
    final tercera = await repo.agregarTarea('Tarea 3');
    await repo.cambiarEstado(tercera.id, true);
    await repo.cerrar(); // se cierra la "app"

    base = AppDatabase.conExecutor(NativeDatabase(archivo));
    repo = TareasRepository(base);
    final recuperadas = await repo.listarTareas(); // se vuelve a "abrir"

    expect(recuperadas, hasLength(3));
    expect(
      recuperadas.firstWhere((t) => t.id == tercera.id).completada,
      isTrue,
    );

    await repo.cerrar();
    if (archivo.existsSync()) archivo.deleteSync();
  });
}

Future<File> _archivoTemporal() async {
  final carpeta = await Directory.systemTemp.createTemp('gestor_tareas_test');
  return File('${carpeta.path}/prueba.sqlite');
}
