import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/tareas_repository.dart';
import 'screens/tareas_page.dart';

/// Punto de entrada.
///
/// La base de datos se abre UNA sola vez aquí y se inyecta hacia abajo, para
/// no crear conexiones dentro de `build()` ni dentro de la pantalla.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repositorio = TareasRepository(AppDatabase());
  runApp(GestorTareasApp(repositorio: repositorio));
}

class GestorTareasApp extends StatefulWidget {
  const GestorTareasApp({super.key, required this.repositorio});

  final TareasRepository repositorio;

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  @override
  void dispose() {
    // F8: liberar la conexión a SQLite cuando la app termina.
    widget.repositorio.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(repositorio: widget.repositorio),
    );
  }
}
