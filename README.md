# Gestor de tareas con SQLite

Práctica de Programación de Dispositivos Móviles (ISC — UAA). Aplicación
Flutter que administra tareas con una base **SQLite local**, sin servidor y
sin peticiones HTTP, con la misma base de código para Android, iOS, Windows,
Linux, macOS y web.

## Tecnología

Se usa **drift** con **drift_flutter**. Su función `driftDatabase()` resuelve
sola la implementación de cada plataforma: archivo nativo mediante
`sqlite3_flutter_libs` en móvil y escritorio, y sqlite3 compilado a
WebAssembly en el navegador. Se descartó `sqflite` porque no cubre web ni
escritorio sin un `DatabaseFactory` distinto por plataforma.

## Tabla

```sql
CREATE TABLE "tareas" (
  "id"         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "titulo"     TEXT    NOT NULL,
  "completada" INTEGER NOT NULL DEFAULT 0 CHECK ("completada" IN (0, 1)),
  "creada_en"  INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
```

SQLite no tiene tipo booleano ni tipo fecha: `completada` se guarda como 0/1 y
`creada_en` como segundos desde epoch. Drift convierte al leer.

## Estructura

```
lib/
├── main.dart                  Abre la base una vez y la inyecta.
├── models/tarea.dart          Modelo de dominio, sin SQLite.
├── data/
│   ├── app_database.dart      Tabla Drift y apertura multiplataforma.
│   ├── tareas_repository.dart Único lugar con SQL.
│   ├── validaciones.dart      Validación del título.
│   └── errores.dart           ErrorAlmacenamiento.
└── screens/tareas_page.dart   Interfaz; consume un Stream.
```

La pantalla no ejecuta SQL: el `Stream` de Drift se crea una sola vez en
`initState()`, así que ninguna consulta ocurre dentro de `build()`. Al ser
reactivo, la lista se actualiza sola tras cada escritura.

## Ejecutar

```bash
flutter pub get
dart run build_runner build   # genera lib/data/app_database.g.dart
flutter test
flutter run -d windows        # o -d chrome, -d android, ...
```

`web/sqlite3.wasm` y `web/drift_worker.js` ya están incluidos y deben
coincidir con las versiones de los paquetes (`sqlite3-3.5.2` y `drift-2.35.4`).
Con versiones desparejadas la app arranca pero falla al abrir la base en el
navegador.

## Dónde se guardan los datos

En plataformas nativas, `gestor_tareas.sqlite` dentro del directorio de
documentos de la aplicación; en Windows, la carpeta Documentos del usuario,
que el sistema puede redirigir a OneDrive. En web, OPFS o IndexedDB del
navegador, ligado al origen y al perfil: los datos se pierden al borrar los
datos del sitio o al usar una ventana de incógnito. No hay sincronización
entre dispositivos.

## Pruebas

`flutter test` ejecuta 8 pruebas:

- `validacion_titulo_test.dart` — títulos vacíos, solo espacios, longitud
  máxima y normalización de espacios.
- `persistencia_tareas_test.dart` — CRUD completo contra SQLite, el rechazo de
  títulos vacíos y una prueba que escribe un archivo `.sqlite` real, lo cierra
  y lo vuelve a abrir.
- `widget_test.dart` — la pantalla inicial y un alta desde la interfaz.
