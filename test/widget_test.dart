import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';
import 'package:gestor_tareas_local/main.dart';

/// Prueba básica de apertura de la interfaz, más un alta desde la pantalla
/// contra una base SQLite en memoria.
void main() {
  late TareasRepository repositorio;

  setUp(() {
    repositorio =
        TareasRepository(AppDatabase.conExecutor(NativeDatabase.memory()));
  });

  tearDown(() async => repositorio.cerrar());

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets('Agregar una tarea desde la interfaz la guarda y la muestra',
      (tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repositorio));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Entregar la práctica');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(find.text('Entregar la práctica'), findsOneWidget);
    expect(await repositorio.listarTareas(), hasLength(1));

    await _desmontar(tester);
  });
}

/// Desmonta el árbol y deja correr el temporizador de 0 ms que Drift programa
/// al cancelar una consulta reactiva. Sin esto, flutter_test avisa de un
/// "Timer is still pending" al terminar cada prueba de widgets.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}
