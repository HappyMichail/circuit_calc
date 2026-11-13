import 'complex.dart';

class SingularMatrixException implements Exception {
  final String message;
  const SingularMatrixException(this.message);

  @override
  String toString() => 'SingularMatrixException: $message';
}

/// Solves complex linear systems A * x = b using Gaussian elimination with partial pivoting.
class LinearSolver {
  static List<Complex> solve(List<List<Complex>> matrixA, List<Complex> vectorB) {
    final n = vectorB.length;
    if (n == 0) return [];
    if (matrixA.length != n || matrixA.any((row) => row.length != n)) {
      throw ArgumentError('Matrix dimensions must match vector length ($n).');
    }

    // Deep copy into augmented matrix [A | b]
    final a = List.generate(
      n,
      (i) => [...matrixA[i], vectorB[i]],
    );

    for (var col = 0; col < n; col++) {
      // Partial pivoting: find row with largest |a[row][col]|
      var pivotRow = col;
      var maxAbs = a[col][col].abs;
      for (var row = col + 1; row < n; row++) {
        final v = a[row][col].abs;
        if (v > maxAbs) {
          maxAbs = v;
          pivotRow = row;
        }
      }

      if (maxAbs < 1e-12) {
        throw const SingularMatrixException(
          'Система уравнений вырождена (определитель равен нулю). '
          'Проверьте связность схемы, отсутствие короткого замыкания источников ЭДС '
          'или разрыва источников тока.',
        );
      }

      if (pivotRow != col) {
        final tmp = a[col];
        a[col] = a[pivotRow];
        a[pivotRow] = tmp;
      }

      final pivot = a[col][col];
      for (var row = col + 1; row < n; row++) {
        final factor = a[row][col] / pivot;
        if (factor.isZero(1e-15)) continue;
        a[row][col] = Complex.zero;
        for (var k = col + 1; k <= n; k++) {
          a[row][k] = a[row][k] - factor * a[col][k];
        }
      }
    }

    // Back substitution
    final x = List<Complex>.filled(n, Complex.zero);
    for (var i = n - 1; i >= 0; i--) {
      var sum = a[i][n];
      for (var k = i + 1; k < n; k++) {
        sum = sum - a[i][k] * x[k];
      }
      x[i] = sum / a[i][i];
    }

    return x;
  }

  /// Formats a matrix equation A * X = B in LaTeX (for small/medium systems).
  static String formatSystemLatex(
    List<List<Complex>> a,
    List<String> unknownNames,
    List<Complex> b, {
    bool isAc = false,
  }) {
    final n = b.length;
    if (n == 0) return '';
    if (n > 8) {
      return '\\text{Система порядка } $n \\times $n \\text{ решена матричным методом.}';
    }

    final rowsA = <String>[];
    for (var i = 0; i < n; i++) {
      rowsA.add(a[i].map((c) => c.toLatex(isAc: isAc, digits: 2)).join(' & '));
    }
    final vecX = unknownNames.join(' \\\\ ');
    final vecB = b.map((c) => c.toLatex(isAc: isAc, digits: 2)).join(' \\\\ ');

    return '\\begin{pmatrix} ${rowsA.join(' \\\\ ')} \\end{pmatrix} '
        '\\cdot \\begin{pmatrix} $vecX \\end{pmatrix} '
        '= \\begin{pmatrix} $vecB \\end{pmatrix}';
  }
}
