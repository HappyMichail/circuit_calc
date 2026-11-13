import '../math/complex.dart';
import '../math/linear_solver.dart';
import '../model/circuit.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class KirchhoffSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.kirchhoff,
  }) {
    circuit.validate();
    final branches = circuit.branches;
    final bCount = branches.length;
    final branchIdx = <String, int>{
      for (var i = 0; i < bCount; i++) branches[i].id: i,
    };

    final jBranchIds =
        branches.where((b) => b.hasCurrentSource).map((b) => b.id).toSet();
    final tree = SolverUtils.buildSpanningTree(circuit, preferChords: jBranchIds);

    final a = <List<Complex>>[];
    final rhs = <Complex>[];
    final kclLatex = <String>[];
    final kvlLatex = <String>[];

    // 1. KCL equations for (N - 1) nodes
    final refId = circuit.effectiveReferenceNodeId();
    for (final node in circuit.nodes) {
      if (node.id == refId) continue;
      final row = List<Complex>.filled(bCount, Complex.zero);
      final terms = <String>[];
      for (var i = 0; i < bCount; i++) {
        final b = branches[i];
        if (b.toNodeId == node.id) {
          row[i] = Complex.one;
          terms.add('+I_{${b.name}}');
        } else if (b.fromNodeId == node.id) {
          row[i] = -Complex.one;
          terms.add('-I_{${b.name}}');
        }
      }
      a.add(row);
      rhs.add(Complex.zero);
      final eq = terms.join(' ').replaceFirst(RegExp(r'^\+'), '');
      kclLatex.add('\\text{Узел } ${node.label}: \\; $eq = 0');
    }

    // 2. Known current source equations: I_j = J_j
    for (var i = 0; i < bCount; i++) {
      final b = branches[i];
      if (!b.hasCurrentSource) continue;
      final row = List<Complex>.filled(bCount, Complex.zero);
      row[i] = Complex.one;
      final jVal = circuit.currentSourceOf(b);
      a.add(row);
      rhs.add(jVal);
      kclLatex.add(
          'I_{${b.name}} = ${jVal.toLatex(isAc: circuit.isAc, digits: 2)}\\text{ А}');
    }

    // 3. KVL equations for fundamental loops without current sources
    var loopNum = 1;
    for (final loop in tree.loops) {
      if (loop.edges.any((e) => e.branch.hasCurrentSource)) {
        continue;
      }
      final row = List<Complex>.filled(bCount, Complex.zero);
      var sumE = Complex.zero;
      final lhsTerms = <String>[];
      final rhsTerms = <String>[];

      for (final edge in loop.edges) {
        final idx = branchIdx[edge.branch.id]!;
        final z = circuit.impedanceOf(edge.branch);
        final e = circuit.emfOf(edge.branch);
        final dir = Complex(edge.dir.toDouble(), 0);
        row[idx] = row[idx] + z * dir;
        sumE = sumE + e * dir;

        final signStr = edge.dir > 0 ? '+' : '-';
        final zStr = z.toLatex(isAc: circuit.isAc, digits: 2);
        lhsTerms.add('$signStr ($zStr) \\cdot I_{${edge.branch.name}}');
        if (!e.isZero()) {
          rhsTerms.add('$signStr (${e.toLatex(isAc: circuit.isAc, digits: 2)})');
        }
      }

      a.add(row);
      rhs.add(sumE);
      final lhsStr = lhsTerms.join(' ').replaceFirst(RegExp(r'^\+'), '');
      final rhsStr = rhsTerms.isEmpty
          ? '0'
          : rhsTerms.join(' ').replaceFirst(RegExp(r'^\+'), '');
      kvlLatex.add('\\text{Контур } $loopNum: \\; $lhsStr = $rhsStr');
      loopNum++;
    }

    if (a.length != bCount) {
      throw const CircuitValidationException(
          'Не удалось составить полную систему по законам Кирхгофа '
          '(возможно, источники тока образуют сечение).');
    }

    final sol = LinearSolver.solve(a, rhs);
    final currents = <String, Complex>{
      for (var i = 0; i < bCount; i++) branches[i].id: sol[i],
    };

    final steps = <SolutionStep>[
      SolutionStep(
        title: '1. Топология схемы',
        description:
            'Число узлов N = ${circuit.nodes.length}, число ветвей B = $bCount. '
            'Независимых уравнений по 1-му закону Кирхгофа: ${circuit.nodes.length - 1}, '
            'по 2-му закону Кирхгофа: ${loopNum - 1}'
            '${jBranchIds.isNotEmpty ? ', заданных источников тока: ${jBranchIds.length}' : ''}.',
      ),
      SolutionStep(
        title: '2. Уравнения по 1-му закону Кирхгофа (для узлов)',
        description: 'Алгебраическая сумма токов в каждом узле равна нулю.',
        latexEquations: kclLatex,
      ),
      if (kvlLatex.isNotEmpty)
        SolutionStep(
          title: '3. Уравнения по 2-му закону Кирхгофа (для контуров)',
          description:
              'Сумма падений напряжений в замкнутом контуре равна алгебраической сумме ЭДС.',
          latexEquations: kvlLatex,
        ),
      SolutionStep(
        title: '4. Решение системы линейных уравнений',
        description: 'Найденные токи ветвей:',
        latexEquations: [
          for (final b in branches)
            'I_{${b.name}} = ${currents[b.id]!.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}'
                '${circuit.isAc ? ' \\; (${currents[b.id]!.toLatexPolar(digits: 3)})' : ''}',
        ],
      ),
    ];

    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: currents,
      steps: steps,
    );
  }
}
