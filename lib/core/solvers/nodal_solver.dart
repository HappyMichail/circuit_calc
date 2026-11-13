import '../math/linear_solver.dart';
import '../model/circuit.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class NodalSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.nodalPotentials,
  }) {
    circuit.validate();
    final refId = circuit.effectiveReferenceNodeId();
    final refNode = circuit.nodes.firstWhere((n) => n.id == refId);
    final mna = SolverUtils.solveMnaRaw(circuit);

    final ohmEqs = <String>[];
    for (final b in circuit.branches) {
      final fromLabel =
          circuit.nodes.firstWhere((n) => n.id == b.fromNodeId).label;
      final toLabel =
          circuit.nodes.firstWhere((n) => n.id == b.toNodeId).label;
      final iVal = mna.currents[b.id]!;
      if (b.hasCurrentSource) {
        ohmEqs.add(
            'I_{${b.name}} = J_{${b.name}} = ${iVal.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}');
      } else if (circuit.impedanceOf(b).isZero()) {
        ohmEqs.add(
            'I_{${b.name}} = ${iVal.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А} \\; (\\text{идеальная ветвь})');
      } else {
        final e = circuit.emfOf(b);
        final ePart = e.isZero()
            ? ''
            : ' + (${e.toLatex(isAc: circuit.isAc, digits: 2)})';
        final zStr = circuit.impedanceOf(b).toLatex(isAc: circuit.isAc, digits: 2);
        ohmEqs.add(
            'I_{${b.name}} = \\frac{\\varphi_{$fromLabel} - \\varphi_{$toLabel}$ePart}{$zStr} = '
            '${iVal.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}');
      }
    }

    final steps = <SolutionStep>[
      SolutionStep(
        title: '1. Выбор базового узла',
        description:
            'Принимаем потенциал узла ${refNode.label} равным нулю. '
            'Остаётся ${circuit.nodes.length - 1} неизвестных узловых потенциалов.',
        latexEquations: ['\\varphi_{${refNode.label}} = 0\\text{ В}'],
      ),
      SolutionStep(
        title: '2. Система узловых уравнений (Y · φ = I_узл)',
        description:
            'Составлена матрица проводимостей и вектор узловых токов:',
        latexEquations: [
          LinearSolver.formatSystemLatex(
            mna.matrixA,
            mna.unknownNames,
            mna.vectorB,
            isAc: circuit.isAc,
          ),
        ],
      ),
      SolutionStep(
        title: '3. Найденные узловые потенциалы',
        description: 'Потенциалы всех узлов схемы:',
        latexEquations: [
          for (final n in circuit.nodes)
            '\\varphi_{${n.label}} = ${mna.potentials[n.id]!.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ В}',
        ],
      ),
      SolutionStep(
        title: '4. Токи в ветвях по закону Ома',
        description:
            'Определение токов через разность потенциалов и ЭДС ветви:',
        latexEquations: ohmEqs,
      ),
    ];

    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: mna.currents,
      potentials: mna.potentials,
      steps: steps,
    );
  }
}
