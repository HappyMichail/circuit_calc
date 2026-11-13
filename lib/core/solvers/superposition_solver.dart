import '../math/complex.dart';
import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class SuperpositionSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.superposition,
  }) {
    circuit.validate();

    // Identify all active independent sources
    final sourceBranches = circuit.branches
        .where((b) => b.hasCurrentSource || b.hasEmf)
        .toList();

    if (sourceBranches.isEmpty) {
      final zeroCurrents = {
        for (final b in circuit.branches) b.id: Complex.zero,
      };
      return SolverUtils.buildSolution(
        circuit: circuit,
        method: reportAs,
        currents: zeroCurrents,
        steps: const [
          SolutionStep(
            title: 'Источники энергии отсутствуют',
            description: 'Все токи в пассивной цепи равны нулю.',
          ),
        ],
      );
    }

    final partialCurrents = <String, List<Complex>>{
      for (final b in circuit.branches) b.id: [],
    };
    final steps = <SolutionStep>[];

    for (var k = 0; k < sourceBranches.length; k++) {
      final activeSrc = sourceBranches[k];
      final subBranches = <CircuitBranch>[];
      for (final b in circuit.branches) {
        if (b.id == activeSrc.id) {
          subBranches.add(b);
        } else if (b.hasCurrentSource) {
          // Turn off other current sources -> open circuit (remove branch)
          continue;
        } else {
          // Turn off other EMFs -> short circuit (E = 0, keep Z)
          subBranches.add(b.copyWith(eMagnitude: 0.0, ePhaseDeg: 0.0));
        }
      }

      // Filter nodes still referenced by subBranches
      final usedNodeIds = <String>{
        for (final b in subBranches) ...[b.fromNodeId, b.toNodeId],
      };
      final subNodes =
          circuit.nodes.where((n) => usedNodeIds.contains(n.id)).toList();

      final subCircuit = circuit.copyWith(
        nodes: subNodes,
        branches: subBranches,
        referenceNodeId: usedNodeIds.contains(circuit.effectiveReferenceNodeId())
            ? circuit.effectiveReferenceNodeId()
            : subNodes.first.id,
        clearTargetBranch: true,
      );

      final mna = SolverUtils.solveMnaRaw(subCircuit);
      final eqs = <String>[];
      for (final b in circuit.branches) {
        final cur = mna.currents[b.id] ?? Complex.zero;
        partialCurrents[b.id]!.add(cur);
        eqs.add(
            'I_{${b.name}}^{(${k + 1})} = ${cur.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}');
      }

      final srcDesc = activeSrc.hasCurrentSource
          ? 'источник тока J_${activeSrc.name}'
          : 'ЭДС E_${activeSrc.name}';
      steps.add(SolutionStep(
        title: 'Шаг ${k + 1}. Действует только $srcDesc',
        description:
            'Остальные источники ЭДС закорочены (E = 0), остальные источники тока разомкнуты (J = 0).',
        latexEquations: eqs,
      ));
    }

    // Sum partial currents
    final totalCurrents = <String, Complex>{};
    final sumEqs = <String>[];
    for (final b in circuit.branches) {
      var sum = Complex.zero;
      final parts = <String>[];
      for (var k = 0; k < sourceBranches.length; k++) {
        final p = partialCurrents[b.id]![k];
        sum = sum + p;
        parts.add(p.toLatex(isAc: circuit.isAc, digits: 3));
      }
      totalCurrents[b.id] = sum;
      sumEqs.add(
          'I_{${b.name}} = ${parts.join(' + ')} = ${sum.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}');
    }

    steps.add(SolutionStep(
      title: 'Итоговое наложение (суммирование частичных токов)',
      description: 'Ток в каждой ветви равен сумме частичных токов от каждого источника:',
      latexEquations: sumEqs,
    ));

    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: totalCurrents,
      steps: steps,
    );
  }
}
