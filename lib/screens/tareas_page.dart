import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../data/errores.dart';
import '../data/tareas_repository.dart';
import '../data/validaciones.dart';
import '../models/tarea.dart';

/// Pantalla principal: alta, consulta, edición, cambio de estado y borrado.
///
/// Ninguna consulta SQL se ejecuta dentro de `build()` (requisito F8): el
/// `Stream` se crea una sola vez en `initState` y `StreamBuilder` se limita a
/// pintar lo que Drift emite.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key, required this.repositorio});

  final TareasRepository repositorio;

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _controladorTitulo = TextEditingController();
  final FocusNode _focoTitulo = FocusNode();

  late final Stream<List<Tarea>> _flujoTareas;
  String? _errorTitulo;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _flujoTareas = widget.repositorio.observarTareas();
  }

  @override
  void dispose() {
    _controladorTitulo.dispose();
    _focoTitulo.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- acciones

  /// F1. Alta con validación previa.
  Future<void> _agregarTarea() async {
    final texto = _controladorTitulo.text;
    final error = validarTitulo(texto);
    if (error != null) {
      setState(() => _errorTitulo = error);
      _focoTitulo.requestFocus();
      return;
    }

    setState(() {
      _errorTitulo = null;
      _ocupado = true;
    });
    try {
      final tarea = await widget.repositorio.agregarTarea(texto);
      _controladorTitulo.clear();
      _avisar('Guardada en SQLite con ID ${tarea.id}.');
    } on ErrorAlmacenamiento catch (e) {
      _avisar(e.mensaje, esError: true);
    } catch (e) {
      _avisar('Error inesperado al guardar: $e', esError: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
      _focoTitulo.requestFocus();
    }
  }

  /// F4. Cambio de estado completada / pendiente.
  Future<void> _alternarCompletada(Tarea tarea, bool valor) async {
    try {
      await widget.repositorio.cambiarEstado(tarea.id, valor);
    } on ErrorAlmacenamiento catch (e) {
      _avisar(e.mensaje, esError: true);
    }
  }

  /// F3. Edición del título mediante un diálogo con validación.
  Future<void> _editarTarea(Tarea tarea) async {
    final controlador = TextEditingController(text: tarea.titulo);
    final claveFormulario = GlobalKey<FormState>();

    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Editar tarea'),
        content: Form(
          key: claveFormulario,
          child: TextFormField(
            controller: controlador,
            autofocus: true,
            maxLength: kMaxLargoTitulo,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: validarTitulo,
            onFieldSubmitted: (_) {
              if (claveFormulario.currentState!.validate()) {
                Navigator.of(contexto).pop(controlador.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (claveFormulario.currentState!.validate()) {
                Navigator.of(contexto).pop(controlador.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controlador.dispose();
    if (nuevoTitulo == null) return;

    try {
      await widget.repositorio.editarTitulo(tarea.id, nuevoTitulo);
      _avisar('Título actualizado en la base de datos.');
    } on ErrorAlmacenamiento catch (e) {
      _avisar(e.mensaje, esError: true);
    }
  }

  /// F5. Eliminación con confirmación previa.
  Future<void> _eliminarTarea(Tarea tarea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          'Se borrará de SQLite la tarea con ID ${tarea.id}.\n\n'
          '"${tarea.titulo}"\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(contexto).colorScheme.error,
            ),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await widget.repositorio.eliminarTarea(tarea.id);
      _avisar('Tarea ${tarea.id} eliminada.');
    } on ErrorAlmacenamiento catch (e) {
      _avisar(e.mensaje, esError: true);
    }
  }

  void _avisar(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    mensajero.hideCurrentSnackBar();
    mensajero.showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: esError ? 5 : 2),
        backgroundColor: esError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor de tareas'),
        backgroundColor: tema.colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'SQLite local · ${_descripcionPlataforma()}',
              style: tema.textTheme.labelSmall,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _formularioAlta(),
              const Divider(height: 1),
              Expanded(child: _listaTareas(tema)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formularioAlta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controladorTitulo,
            focusNode: _focoTitulo,
            autofocus: true,
            maxLength: kMaxLargoTitulo,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nueva tarea',
              hintText: 'Por ejemplo: entregar la práctica de SQLite',
              border: const OutlineInputBorder(),
              errorText: _errorTitulo,
              counterText: '',
              prefixIcon: const Icon(Icons.edit_note),
            ),
            onChanged: (_) {
              if (_errorTitulo != null) setState(() => _errorTitulo = null);
            },
            onSubmitted: (_) {
              if (!_ocupado) _agregarTarea();
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _ocupado ? null : _agregarTarea,
            icon: _ocupado
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Agregar tarea'),
          ),
        ],
      ),
    );
  }

  Widget _listaTareas(ThemeData tema) {
    return StreamBuilder<List<Tarea>>(
      stream: _flujoTareas,
      builder: (context, captura) {
        if (captura.hasError) {
          return _estadoError(tema, captura.error!);
        }
        if (!captura.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tareas = captura.data!;
        final completadas = tareas.where((t) => t.completada).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('Mis tareas', style: tema.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${tareas.length} guardadas · $completadas completadas',
                    style: tema.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: tareas.isEmpty
                  ? _estadoVacio(tema)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: tareas.length,
                      itemBuilder: (context, indice) =>
                          _tarjetaTarea(tema, tareas[indice]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetaTarea(ThemeData tema, Tarea tarea) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        leading: Checkbox(
          value: tarea.completada,
          onChanged: (valor) => _alternarCompletada(tarea, valor ?? false),
        ),
        title: Text(
          tarea.titulo,
          style: TextStyle(
            decoration: tarea.completada ? TextDecoration.lineThrough : null,
            color: tarea.completada ? tema.disabledColor : null,
          ),
        ),
        subtitle: Text(
          'ID: ${tarea.id} · ${tarea.completada ? "completada" : "pendiente"}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editarTarea(tarea),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _eliminarTarea(tarea),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVacio(ThemeData tema) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: tema.disabledColor),
            const SizedBox(height: 8),
            const Text('Todavía no hay tareas guardadas'),
            const SizedBox(height: 4),
            Text(
              'Lo que agregues seguirá aquí al cerrar y volver a abrir la app.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoError(ThemeData tema, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: tema.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              'No se pudo leer la base de datos',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _descripcionPlataforma() {
    if (kIsWeb) return 'web (sqlite3 WebAssembly, OPFS/IndexedDB)';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android (archivo .sqlite en los datos de la app)';
      case TargetPlatform.iOS:
        return 'iOS (archivo .sqlite en el sandbox)';
      case TargetPlatform.windows:
        return 'Windows (archivo .sqlite en AppData)';
      case TargetPlatform.linux:
        return 'Linux (archivo .sqlite en ~/.local/share)';
      case TargetPlatform.macOS:
        return 'macOS (archivo .sqlite en Application Support)';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
