import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/validaciones.dart';

/// Prueba 1 de las dos obligatorias: validación de entradas (F1).
void main() {
  test('rechaza títulos vacíos o formados solo por espacios', () {
    expect(validarTitulo(''), isNotNull);
    expect(validarTitulo('     '), isNotNull);
    expect(validarTitulo('\t\n '), isNotNull);
  });

  test('acepta un título normal y rechaza uno demasiado largo', () {
    expect(validarTitulo('Entregar la práctica'), isNull);
    expect(validarTitulo('a' * kMaxLargoTitulo), isNull);
    expect(validarTitulo('a' * (kMaxLargoTitulo + 1)), isNotNull);
  });

  test('normaliza los espacios sobrantes', () {
    expect(normalizarTitulo('  comprar   pan  '), 'comprar pan');
  });
}
