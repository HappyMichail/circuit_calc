import '../math/complex.dart';
import '../math/linear_solver.dart';
import '../model/circuit.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class MeshSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.meshCurrents,
  }) {
    circuit.validate();
    final jBranchIds = circuit.branches
        .where((b) => b.hasCurrentSource)
        .map((b) => b.id)
        .toSet();
    final tree = SolverUtils.buildSpanningTree(circuit, preferChords: jBranchIds);
    final loops = tree.loops;

    if (loops.isEmpty) {
      throw const CircuitValidationException(
          'В схеме нет замкнутых контуров для метода контурных токов.');
    }

    // Separate loops with known current (chord is a current source) vs unknown
    final unknownLoopIndices = <int>[];
    final knownLoopCurrents = <int, Complex>{};

    for (var i = 0; i < loops.length; i++) {
      final chord = loops[i].chord;
      if (chord.hasCurrentSource) {
        knownLoopCurrents[i] = circuit.currentSourceOf(chord);
      } else {
        if (loops[i].edges.any((e) => e.branch.hasCurrentSource)) {
          throw const CircuitValidationException(
              'Источник тока попал в дерево схемы; используйте метод узловых потенциалов.');
        }
        unknownLoopIndices.add(i);
      }
    }

    final m = unknownLoopIndices.length;
    final zMat = List.generate(m, (_) => List<Complex>.filled(m, Complex.zero));
    final eVec = List<Complex>.filled(m, Complex.zero);

    // Map branch -> (loopIndex, dir)
    final branchInLoops = <String, List<({int loopIdx, int dir})>>{};
    for (var li = 0; li < loops.length; li++) {
      for (final edge in loops[li].edges) {
        branchInLoops.putIfAbsent(edge.branch.id, () => []).add((
          loopIdx: li,
          dir: edge.dir,
        ));
      }
    }

    // Helper: mutual impedance between loop a and loop b
    Complex mutualZ(int la, int lb) {
      var sum = Complex.zero;
      for (final ea in loops[la].edges) {
        for (final eb in loops[lb].edges) {
          if (ea.branch.id == eb.branch.id) {
            final z = circuit.impedanceOf(ea.branch);
            sum = sum + z.scale((ea.dir * eb.dir).toDouble());
          }
        }
      }
      return sum;
    }

    for (var r = 0; r < m; r++) {
      final li = unknownLoopIndices[r];
      for (var c = 0; c < m; c++) {
        final lj = unknownLoopIndices[c];
        zMat[r][c] = mutualZ(li, lj);
      }

      var eLoop = Complex.zero;
      for (final edge in loops[li].edges) {
        final e = circuit.emfOf(edge.branch);
        eLoop = eLoop + e.scale(edge.dir.toDouble());
      }

      // Subtract contributions of known current-source loops
      for (final entry in knownLoopCurrents.entries) {
        final zij = mutualZ(li, entry.key);
        eLoop = eLoop - zij * entry.value;
      }
      eVec[r] = eLoop;
    }

    final solvedUnknowns =
        m > 0 ? LinearSolver.solve(zMat, eVec) : <Complex>[];

    final allLoopCurrents = List<Complex>.filled(loops.length, Complex.zero);
    for (var r = 0; r < m; r++) {
      allLoopCurrents[unknownLoopIndices[r]] = solvedUnknowns[r];
    }
    for (final entry in knownLoopCurrents.entries) {
      allLoopCurrents[entry.key] = entry.value;
    }

    // Compute branch currents
    final branchCurrents = <String, Complex>{};
    final branchEqs = <String>[];
    for (final b in circuit.branches) {
      var iSum = Complex.zero;
      final terms = <String>[];
      for (final occ in branchInLoops[b.id] ?? const []) {
        final iLoop = allLoopCurrents[occ.loopIdx];
        iSum = iSum + iLoop.scale(occ.dir.toDouble());
        final sign = occ.dir > 0 ? '+' : '-';
        terms.add('${sign}I_{\\text{к}${occ.loopIdx + 1}}');
      }
      branchCurrents[b.id] = iSum;
      final expr = terms.isEmpty
          ? '0'
          : terms.join(' ').replaceFirst(RegExp(r'^\+'), '');
      branchEqs.add(
          'I_{${b.name}} = $expr = ${iSum.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}');
    }

    final loopDesc = <String>[];
    for (var i = 0; i < loops.length; i++) {
      final pathStr = loops[i]
          .edges
          .map((e) => '${e.dir > 0 ? '' : '-'}${e.branch.name}')
          .join(', ');
      loopDesc.add(
          '\\text{Контур } ${i + 1} \\; (\\text{хорда } ${loops[i].chord.name}): \\; [$pathStr]');
    }

    final unknownNames = [
      for (final idx in unknownLoopIndices) 'I_{\\text{к}${idx + 1}}',
    ];

    final steps = <SolutionStep>[
      SolutionStep(
        title: '1. Выбор независимых контуров',
        description:
            'Количество независимых контуров: M = B - N + 1 = ${loops.length}. '
            'Контурные токи направлены по обходу соответствующих хорд.',
        latexEquations: loopDesc,
      ),
      if (knownLoopCurrents.isNotEmpty)
        SolutionStep(
          title: '2. Контуры с источниками тока',
          description:
              'Контурные токи хорд с источниками тока заданы напрямую:',
          latexEquations: [
            for (final entry in knownLoopCurrents.entries)
              'I_{\\text{к}${entry.key + 1}} = ${entry.value.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}',
          ],
        ),
      if (m > 0)
        SolutionStep(
          title: '${knownLoopCurrents.isNotEmpty ? 3 : 2}. Система уравнений контурных токов',
          description: 'Матричная запись Z_к · I_к = E_к:',
          latexEquations: [
            LinearSolver.formatSystemLatex(
              zMat,
              unknownNames,
              eVec,
              isAc: circuit.isAc,
            ),
          ],
        ),
      SolutionStep(
        title: 'Найденные контурные токи',
        description: 'Значения контурных токов:',
        latexEquations: [
          for (var i = 0; i < loops.length; i++)
            'I_{\\text{к}${i + 1}} = ${allLoopCurrents[i].toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}',
        ],
      ),
      SolutionStep(
        title: 'Токи в ветвях схемы',
        description: 'Алгебраическая сумма контурных токов, проходящих через ветвь:',
        latexEquations: branchEqs,
      ),
    ];

    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: branchCurrents,
      steps: steps,
    );
  }
}
