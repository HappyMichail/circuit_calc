import 'dart:math' as math;
import 'complex.dart';

class SingularMatrixException implements Exception {
  final String message;
  const SingularMatrixException(this.message);

  @override
  String toString() => 'SingularMatrixException: $message';
}

/// Solves complex linear systems A * x = b using Gaussian elimination with scaled partial pivoting.
class LinearSolver {
  static List<Complex> solve(List<List<Complex>> matrixA, List<Complex> vectorB) {
    final n = vectorB.length;
    if (n == 0) return [];
    if (matrixA.length != n || matrixA.any((row) => row.length != n)) {
      throw ArgumentError('Matrix dimensions must match vector length ($n).');
    }

    // Deep copy into augmented matrix [A | b] and compute row scale factors
    final a = List.generate(n, (i) => [...matrixA[i], vectorB[i]]);
    final rowScale = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i++) {
      var maxRow = 0.0;
      for (var j = 0; j < n; j++) {
        final v = a[i][j].abs;
        if (!v.isFinite) {
          throw const SingularMatrixException(
              'Матрица содержит некорректные значения (NaN или бесконечность).');
        }
        if (v > maxRow) maxRow = v;
      }
      if (maxRow == 0.0) {
        throw const SingularMatrixException(
          'Система уравнений вырождена (нулевая строка в матрице). '
          'Проверьте связность схемы и отсутствие изолированных подцепей.',
        );
      }
      rowScale[i] = maxRow;
    }

    for (var col = 0; col < n; col++) {
      // Scaled partial pivoting: maximize |a[row][col]| / rowScale[row]
      var pivotRow = col;
      var maxRatio = 0.0;
      for (var row = col; row < n; row++) {
        final ratio = a[row][col].abs / rowScale[row];
        if (ratio > maxRatio) {
          maxRatio = ratio;
          pivotRow = row;
        }
      }

      if (maxRatio < 1e-12) {
        throw const SingularMatrixException(
          'Система уравнений вырождена (определитель близок к нулю). '
          'Проверьте связность схемы, отсутствие короткого замыкания источников ЭДС '
          'или разрыва источников тока.',
        );
      }

      if (pivotRow != col) {
        final tmp = a[col];
        a[col] = a[pivotRow];
        a[pivotRow] = tmp;

        final tmpScale = rowScale[col];
        rowScale[col] = rowScale[pivotRow];
        rowScale[pivotRow] = tmpScale;
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
      final val = sum / a[i][i];
      if (!val.re.isFinite || !val.im.isFinite) {
        throw const SingularMatrixException(
            'Численное переполнение при решении системы уравнений.');
      }
      x[i] = val;
    }

    // Verify residual ||Ax - b||_inf
    var maxRes = 0.0;
    var normB = 0.0;
    var normX = 0.0;
    var normA = 0.0;
    for (var i = 0; i < n; i++) {
      normB = math.max(normB, vectorB[i].abs);
      normX = math.max(normX, x[i].abs);
      var ax = Complex.zero;
      var rowSum = 0.0;
      for (var j = 0; j < n; j++) {
        ax = ax + matrixA[i][j] * x[j];
        rowSum += matrixA[i][j].abs;
      }
      normA = math.max(normA, rowSum);
      maxRes = math.max(maxRes, (ax - vectorB[i]).abs);
    }
    final tol = 1e-5 * (normA * normX + normB + 1.0);
    if (!maxRes.isFinite || maxRes > tol) {
      throw const SingularMatrixException(
          'Система плохо обусловлена: невязка решения превышает допустимый порог.');
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
