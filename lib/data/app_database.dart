import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Esquema SQL que Drift genera a partir de la clase Tareas:
//
//   CREATE TABLE tareas (
//     id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
//     titulo     TEXT    NOT NULL,
//     completada INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1)),
//     creada_en  INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
//   );
//
// SQLite no tiene tipo booleano ni tipo fecha: `completada` se guarda como
// 0/1 y `creada_en` como segundos desde epoch. Drift hace la conversion.

/// Tabla de tareas.
@DataClassName('TareaRow')
class Tareas extends Table {
  @override
  String get tableName => 'tareas';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 200)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
}

/// Base de datos SQLite local de la aplicacion.
///
/// `driftDatabase()` (paquete drift_flutter) elige la implementacion correcta
/// segun la plataforma, con la MISMA base de codigo:
///
/// * Android / iOS / Windows / Linux / macOS: `NativeDatabase` sobre el
///   sqlite3 nativo que aporta `sqlite3_flutter_libs`, en un archivo
///   `gestor_tareas.sqlite` dentro del directorio de datos de la app.
/// * Web: `WasmDatabase`, que ejecuta sqlite3 compilado a WebAssembly y
///   guarda el archivo en OPFS o IndexedDB del navegador.
@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  /// Constructor normal: abre la base persistente de la plataforma actual.
  AppDatabase() : super(_abrirConexion());

  /// Constructor usado por las pruebas: recibe una conexion ya creada
  /// (por ejemplo `NativeDatabase.memory()`), sin tocar el disco del usuario.
  // ignore: use_super_parameters
  AppDatabase.conExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _abrirConexion() {
    return driftDatabase(
      name: 'gestor_tareas',
      web: DriftWebOptions(
        // Archivos que deben existir dentro de web/ (ver README).
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
