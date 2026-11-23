import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/validaciones.dart';

/// Prueba 1 de las dos obligatorias: validación de entradas (F1).
///
/// Cubre los casos que la interfaz debe rechazar antes de tocar SQLite:
/// cadena vacía, solo espacios, solo tabuladores/saltos de línea y títulos
/// más largos que la columna. También comprueba la normalización, para que
/// "  comprar   pan  " no entre a la base con espacios de más.
void main() {
  group('validarTitulo', () {
    test('rechaza una cadena vacía', () {
      expect(validarTitulo(''), isNotNull);
    });

    test('rechaza null', () {
      expect(validarTitulo(null), isNotNull);
    });

    test('rechaza un título formado solo por espacios', () {
      expect(validarTitulo('     '), isNotNull);
    });

    test('rechaza espacios en blanco invisibles (tabulador y salto de línea)',
        () {
      expect(validarTitulo('\t\n  \t'), isNotNull);
    });

    test('acepta un título normal', () {
      expect(validarTitulo('Entregar la práctica'), isNull);
    });

    test('acepta un título con espacios alrededor', () {
      expect(validarTitulo('   Estudiar SQL   '), isNull);
    });

    test('rechaza un título más largo que el máximo de la columna', () {
      expect(validarTitulo('a' * (kMaxLargoTitulo + 1)), isNotNull);
    });

    test('acepta un título exactamente del largo máximo', () {
      expect(validarTitulo('a' * kMaxLargoTitulo), isNull);
    });
  });

  group('normalizarTitulo', () {
    test('quita espacios al inicio y al final', () {
      expect(normalizarTitulo('  comprar pan  '), 'comprar pan');
    });

    test('colapsa espacios repetidos entre palabras', () {
      expect(normalizarTitulo('comprar     pan'), 'comprar pan');
    });

    test('convierte tabuladores y saltos de línea en un solo espacio', () {
      expect(normalizarTitulo('comprar\t\npan'), 'comprar pan');
    });
  });
}
