# Gestor de tareas con SQLite

Práctica de **Programación de Dispositivos Móviles** (7.º semestre, ISC — UAA).
Aplicación Flutter que administra tareas con una base de datos **SQLite local**,
sin servidor, sin MySQL y sin peticiones HTTP. La misma base de código está
diseñada para Android, iOS, Windows, Linux, macOS y web.

---

## 1. Tecnología de persistencia elegida

| Decisión | Qué se usa | Por qué |
|---|---|---|
| ORM / capa SQL | **`drift` 2.35** | Da SQL tipado, consultas reactivas (`Stream`) y migraciones, con una sola API para las seis plataformas. |
| Apertura de la base | **`drift_flutter` 0.3** | Su función `driftDatabase()` resuelve sola la implementación por plataforma: archivo nativo en móvil/escritorio y WebAssembly en el navegador. |
| Motor nativo | `sqlite3_flutter_libs` | Empaqueta el binario de SQLite en Android, iOS, Windows, Linux y macOS. |
| Motor web | `sqlite3.wasm` + `drift_worker.js` | SQLite compilado a WebAssembly, con el archivo guardado en OPFS o IndexedDB. |

Se descartó `sqflite` porque no soporta web ni escritorio sin paquetes extra y
sin un `DatabaseFactory` distinto por plataforma. Se descartó guardar JSON en
`shared_preferences` porque el enunciado lo prohíbe explícitamente y porque no
es una base de datos: no permite consultas, índices ni actualizaciones parciales.

## 2. Esquema de la tabla

```sql
CREATE TABLE "tareas" (
  "id"         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "titulo"     TEXT    NOT NULL,
  "completada" INTEGER NOT NULL DEFAULT 0 CHECK ("completada" IN (0, 1)),
  "creada_en"  INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
```

Este es el DDL exacto que genera Drift, leído con `sqlite3` directamente del
archivo `gestor_tareas.sqlite` que la app crea en Windows.

SQLite no tiene tipo booleano ni tipo fecha: `completada` se guarda como `0`/`1`
y `creada_en` como segundos desde epoch. Drift hace la conversión a `bool` y
`DateTime` al leer. El identificador único es `id INTEGER PRIMARY KEY
AUTOINCREMENT`, que SQLite asigna solo y nunca reutiliza.

## 3. Organización del código

```
lib/
├── main.dart                     Arranque; abre la base UNA vez y la inyecta.
├── models/
│   └── tarea.dart                Modelo de dominio, sin dependencias de SQLite.
├── data/
│   ├── app_database.dart         Tabla Drift + apertura multiplataforma.
│   ├── app_database.g.dart       Código generado por build_runner.
│   ├── tareas_repository.dart    Único lugar con SQL: INSERT/SELECT/UPDATE/DELETE.
│   ├── validaciones.dart         Validación y normalización del título.
│   └── errores.dart              ErrorAlmacenamiento, legible para el usuario.
└── screens/
    └── tareas_page.dart          Interfaz; consume un Stream, nunca consulta en build().
```

La pantalla **no ejecuta SQL**. El `Stream` de Drift se crea una sola vez en
`initState()` y `StreamBuilder` solo pinta lo que llega, por lo que ninguna
consulta ocurre dentro de `build()` (requisito F8). Como la consulta es
reactiva, después de cada escritura la lista se actualiza sola: no hace falta
volver a consultar a mano ni llamar a `setState` para refrescar datos.

## 4. Cómo ejecutarlo

```bash
flutter pub get
dart run build_runner build      # genera lib/data/app_database.g.dart
flutter analyze
flutter test
```

| Plataforma | Comando |
|---|---|
| Windows | `flutter run -d windows` |
| Web (Chrome) | `flutter run -d chrome` |
| Android | `flutter run -d <id del dispositivo>` |
| Linux / macOS / iOS | `flutter run -d linux` / `-d macos` / `-d ios` |

### Requisito propio de la web

`web/sqlite3.wasm` y `web/drift_worker.js` **ya están incluidos** en el
repositorio y deben coincidir con las versiones de los paquetes:

* `sqlite3.wasm` → release `sqlite3-3.5.2` de `simolus3/sqlite3.dart`
* `drift_worker.js` → release `drift-2.35.4` de `simolus3/drift`

Si se actualiza `drift` hay que volver a descargarlos; con versiones
desparejadas la app arranca pero falla al abrir la base en el navegador.

## 5. Dónde se guardan los datos

`driftDatabase()` usa en todas las plataformas nativas el directorio de
documentos de la aplicación (`getApplicationDocumentsDirectory()`), con el
nombre `gestor_tareas.sqlite`:

| Plataforma | Ubicación |
|---|---|
| Android | `/data/data/<paquete>/app_flutter/gestor_tareas.sqlite` |
| iOS / macOS | `Documents/` del sandbox de la app |
| Windows | Carpeta **Documentos** del usuario. Comprobado en una máquina real: `C:\Users\<usuario>\OneDrive\Documentos\gestor_tareas.sqlite`, porque Windows puede redirigir Documentos a OneDrive |
| Linux | Carpeta de documentos del usuario |
| Web | OPFS o IndexedDB del navegador, ligado al **origen y perfil** |

En web los datos se pierden si se borran los datos del sitio o si se usa una
ventana de incógnito, porque el almacenamiento del navegador es por origen y
por perfil. No hay sincronización entre dispositivos: cada instalación guarda
lo suyo.

## 6. Pruebas automatizadas

`flutter test` ejecuta 27 pruebas en tres archivos:

| Archivo | Qué cubre |
|---|---|
| `test/validacion_titulo_test.dart` | Validación de entradas: vacío, solo espacios, tabuladores, longitud máxima y normalización de espacios. |
| `test/persistencia_tareas_test.dart` | CRUD real contra SQLite: INSERT, SELECT, UPDATE de título y de estado, DELETE, IDs únicos, errores con IDs inexistentes, consulta reactiva y **cierre/reapertura de un archivo real** (P1 automatizada). |
| `test/widget_test.dart` | La interfaz contra una base en memoria: pantalla inicial, alta desde el formulario, rechazo de título vacío y marcado con el checkbox. |

Las pruebas usan `NativeDatabase.memory()` y archivos temporales: nunca tocan
la base real del usuario.

## 7. Funcionalidades del enunciado

| ID | Requisito | Dónde está |
|---|---|---|
| F1 | Alta, rechazando títulos vacíos | `TareasRepository.agregarTarea` + `validarTitulo` |
| F2 | Consulta persistente | `observarTareas` / `listarTareas` |
| F3 | Edición del título | `editarTitulo` |
| F4 | Cambio de estado | `cambiarEstado` |
| F5 | Eliminación por ID | `eliminarTarea` |
| F6 | Sin conexión | No hay `http` ni ningún paquete de red en `pubspec.yaml` |
| F7 | Multiplataforma | `driftDatabase()` en `app_database.dart` |
| F8 | Calidad | Errores envueltos en `ErrorAlmacenamiento`, `cerrar()` en `dispose`, cero SQL en `build()` |
