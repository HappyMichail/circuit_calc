import '../math/complex.dart';
import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class TheveninNortonSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.theveninNorton,
  }) {
    circuit.validate();
    final targetId = circuit.effectiveTargetBranchId();
    final target = circuit.branches.firstWhere((b) => b.id == targetId);
    final nodeA = circuit.nodes.firstWhere((n) => n.id == target.fromNodeId);
    final nodeB = circuit.nodes.firstWhere((n) => n.id == target.toNodeId);

    final restBranches =
        circuit.branches.where((b) => b.id != target.id).toList();

    if (restBranches.isEmpty) {
      throw const CircuitValidationException(
          'В схеме только одна ветвь; невозможно выделить активный двухполюсник.');
    }

    // Check if remaining circuit connects nodeA and nodeB
    final restCircuit = circuit.copyWith(
      branches: restBranches,
      referenceNodeId: nodeB.id,
      clearTargetBranch: true,
    );

    try {
      restCircuit.validate();
    } catch (_) {
      throw CircuitValidationException(
          'При удалении ветви ${target.name} схема распадается на несвязные части. '
          'Выберите другую целевую ветвь (внутри замкнутого контура).');
    }

    // 1. Open-circuit voltage U_xx = phi_A - phi_B
    final mnaOpen = SolverUtils.solveMnaRaw(restCircuit);
    final uXx = mnaOpen.potentials[nodeA.id]! - mnaOpen.potentials[nodeB.id]!;

    // 2. Equivalent impedance Z_eq: zero all sources, inject 1 A from B -> A
    final passiveBranches = <CircuitBranch>[];
    for (final b in restBranches) {
      if (b.hasCurrentSource) continue; // open-circuit J
      passiveBranches.add(b.copyWith(eMagnitude: 0.0, ePhaseDeg: 0.0));
    }
    passiveBranches.add(CircuitBranch(
      id: '__test_1A__',
      name: 'I_test',
      fromNodeId: nodeB.id,
      toNodeId: nodeA.id,
      hasCurrentSource: true,
      jMagnitude: 1.0,
      jAlignedWithBranch: true,
    ));

    // Extract connected component containing nodeA & nodeB (prunes nodes isolated by open-circuited J)
    final zAdj = <String, List<String>>{};
    for (final b in passiveBranches) {
      zAdj.putIfAbsent(b.fromNodeId, () => []).add(b.toNodeId);
      zAdj.putIfAbsent(b.toNodeId, () => []).add(b.fromNodeId);
    }
    final compNodes = <String>{nodeB.id};
    final queue = <String>[nodeB.id];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final nxt in zAdj[cur] ?? const <String>[]) {
        if (compNodes.add(nxt)) queue.add(nxt);
      }
    }
    final zNodes =
        circuit.nodes.where((n) => compNodes.contains(n.id)).toList();
    final zBranches = passiveBranches
        .where((b) =>
            compNodes.contains(b.fromNodeId) && compNodes.contains(b.toNodeId))
        .toList();

    final zCircuit = restCircuit.copyWith(
      nodes: zNodes,
      branches: zBranches,
      referenceNodeId: nodeB.id,
      clearTargetBranch: true,
    );
    final mnaZ = SolverUtils.solveMnaRaw(zCircuit);
    final zEq = mnaZ.potentials[nodeA.id]! - mnaZ.potentials[nodeB.id]!;

    // 3. Target branch current
    final Complex iTarget;
    final String targetEq;
    if (target.hasCurrentSource) {
      iTarget = circuit.currentSourceOf(target);
      targetEq =
          'I_{${target.name}} = J_{${target.name}} = ${iTarget.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}';
    } else {
      final zT = circuit.impedanceOf(target);
      final eT = circuit.emfOf(target);
      final denom = zEq + zT;
      if (denom.isZero()) {
        throw const CircuitValidationException(
            'Короткое замыкание: Z_экв + Z_ветви = 0.');
      }
      iTarget = (uXx + eT) / denom;
      final ePart =
          eT.isZero() ? '' : ' + (${eT.toLatex(isAc: circuit.isAc, digits: 2)})';
      targetEq = 'I_{${target.name}} = \\frac{U_{\\text{хх}}$ePart}{Z_{\\text{экв}} + Z_{${target.name}}} '
          '= \\frac{${uXx.toLatex(isAc: circuit.isAc, digits: 2)}$ePart}'
          '{${zEq.toLatex(isAc: circuit.isAc, digits: 2)} + ${zT.toLatex(isAc: circuit.isAc, digits: 2)}} '
          '= ${iTarget.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}';
    }

    final iKzStr = zEq.isZero()
        ? '\\infty'
        : '${(uXx / zEq).toLatex(isAc: circuit.isAc, digits: 3)}\\text{ А}';

    final steps = <SolutionStep>[
      SolutionStep(
        title: '1. Выделение целевой ветви ${target.name}',
        description:
            'Размыкаем ветвь ${target.name} между узлами ${nodeA.label} и ${nodeB.label}. '
            'Оставшуюся часть схемы заменяем эквивалентным генератором.',
      ),
      SolutionStep(
        title: '2. Напряжение холостого хода (Тевенин)',
        description:
            'Разность потенциалов между зажимами ${nodeA.label} и ${nodeB.label} при разомкнутой ветви:',
        latexEquations: [
          'U_{\\text{хх}} = E_{\\text{экв}} = \\varphi_{${nodeA.label}} - \\varphi_{${nodeB.label}} '
              '= ${uXx.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ В}',
        ],
      ),
      SolutionStep(
        title: '3. Входное сопротивление и ток КЗ (Нортон)',
        description:
            'При отключённых источниках (ЭДС закорочены, ИТ разомкнуты) находим Z_экв:',
        latexEquations: [
          'Z_{\\text{экв}} = ${zEq.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}',
          'I_{\\text{кз}} = J_{\\text{Н}} = \\frac{U_{\\text{хх}}}{Z_{\\text{экв}}} = $iKzStr',
        ],
      ),
      SolutionStep(
        title: '4. Расчёт тока в ветви ${target.name}',
        description: 'Подключаем целевую ветвь обратно к эквивалентному генератору:',
        latexEquations: [targetEq],
      ),
    ];

    // Full circuit MNA for complete node potentials and remaining branches
    final fullMna = SolverUtils.solveMnaRaw(circuit);
    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: fullMna.currents,
      potentials: fullMna.potentials,
      steps: steps,
    );
  }
}
