/// Validacion de entradas, separada de la interfaz para poder probarla con
/// `flutter test` sin construir widgets ni abrir la base de datos.
library;

/// Longitud maxima aceptada para el titulo (coincide con la columna TEXT).
const int kMaxLargoTitulo = 200;

/// Quita espacios sobrantes al inicio, al final y entre palabras.
String normalizarTitulo(String entrada) {
  return entrada.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Devuelve `null` si el titulo es valido, o el mensaje de error a mostrar.
///
/// F1 del enunciado: se rechazan titulos vacios o formados solo por espacios.
String? validarTitulo(String? entrada) {
  final texto = normalizarTitulo(entrada ?? '');
  if (texto.isEmpty) {
    return 'Escribe un título: no se aceptan tareas vacías.';
  }
  if (texto.length > kMaxLargoTitulo) {
    return 'El título no puede pasar de $kMaxLargoTitulo caracteres.';
  }
  return null;
}
