import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';
import 'package:gestor_tareas_local/main.dart';

/// Prueba básica de apertura de la interfaz (la que venía en el código base),
/// más un recorrido de la interfaz contra una base SQLite en memoria.
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

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    await _desmontar(tester);
  });

  testWidgets('Agregar una tarea desde la interfaz la muestra en la lista',
      (tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Entregar la práctica');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(find.text('Entregar la práctica'), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsNothing);
    expect(await repositorio.listarTareas(), hasLength(1));
    await _desmontar(tester);
  });

  testWidgets('Un título vacío muestra un error y no guarda nada',
      (tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe un título: no se aceptan tareas vacías.'),
      findsOneWidget,
    );
    expect(await repositorio.listarTareas(), isEmpty);
    await _desmontar(tester);
  });

  testWidgets('El checkbox marca la tarea como completada en la base',
      (tester) async {
    final tarea = await repositorio.agregarTarea('Marcar esta tarea');

    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final guardada = (await repositorio.listarTareas()).single;
    expect(guardada.id, tarea.id);
    expect(guardada.completada, isTrue);
    await _desmontar(tester);
  });
}

/// Desmonta el arbol y deja correr el temporizador de 0 ms que Drift programa
/// al cancelar una consulta reactiva. Sin esto, flutter_test avisa de un
/// "Timer is still pending" al terminar cada prueba de widgets.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

