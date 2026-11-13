import 'dart:math' as math;
import '../math/complex.dart';
import '../model/circuit.dart';
import '../model/solution.dart';
import 'kirchhoff_solver.dart';
import 'mesh_solver.dart';
import 'nodal_solver.dart';
import 'reduction_solver.dart';
import 'superposition_solver.dart';
import 'thevenin_norton_solver.dart';

class ComplexSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod baseMethod = CalculationMethod.nodalPotentials,
  }) {
    final acCircuit = circuit.isAc ? circuit : circuit.copyWith(isAc: true);
    acCircuit.validate();

    final omega = acCircuit.omega;
    final zEqs = <String>[];
    for (final b in acCircuit.branches) {
      if (b.hasCurrentSource) {
        final j = acCircuit.currentSourceOf(b);
        zEqs.add('\\underline{J}_{${b.name}} = ${j.toLatexPolar(digits: 2)}\\text{ А}');
      } else {
        final z = acCircuit.impedanceOf(b);
        final e = acCircuit.emfOf(b);
        var line = '\\underline{Z}_{${b.name}} = ${z.toLatex(isAc: true, digits: 2)}\\text{ Ом}';
        if (!e.isZero()) {
          line += ', \\quad \\underline{E}_{${b.name}} = ${e.toLatexPolar(digits: 2)}\\text{ В}';
        }
        zEqs.add(line);
      }
    }

    final introStep = SolutionStep(
      title: '0. Переход к комплексной форме (f = ${Complex.fmt(acCircuit.frequencyHz, 1)} Гц)',
      description:
          'Вычисляем комплексные сопротивления ветвей и комплексные действующие значения источников '
          '(ω = 2πf = ${Complex.fmt(omega, 2)} рад/с). Базовый алгоритм: ${baseMethod.title}.',
      latexEquations: zEqs,
    );

    final CircuitSolution inner;
    switch (baseMethod) {
      case CalculationMethod.equivalentReduction:
        inner = ReductionSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
      case CalculationMethod.kirchhoff:
        inner = KirchhoffSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
      case CalculationMethod.meshCurrents:
        inner = MeshSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
      case CalculationMethod.superposition:
        inner = SuperpositionSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
      case CalculationMethod.theveninNorton:
        inner = TheveninNortonSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
      case CalculationMethod.nodalPotentials:
      case CalculationMethod.complexMethod:
        inner = NodalSolver.solve(acCircuit,
            reportAs: CalculationMethod.complexMethod);
    }

    final instEqs = <String>[];
    for (final b in acCircuit.branches) {
      final i = inner.branchResults[b.id]!.current;
      final amp = i.abs * math.sqrt2;
      final deg = i.angleDeg;
      final sign = deg >= 0 ? '+' : '-';
      instEqs.add(
          'i_{${b.name}}(t) = ${Complex.fmt(amp, 2)} \\sin(\\omega t $sign ${Complex.fmt(deg.abs(), 1)}^\\circ)\\text{ А}');
    }

    final instStep = SolutionStep(
      title: 'Мгновенные значения токов во временной области',
      description: 'Переход от комплексных действующих значений к мгновенным:',
      latexEquations: instEqs,
    );

    return CircuitSolution(
      method: CalculationMethod.complexMethod,
      isAc: true,
      omega: omega,
      branchResults: inner.branchResults,
      nodePotentials: inner.nodePotentials,
      steps: [introStep, ...inner.steps, instStep],
      totalSourcePowerP: inner.totalSourcePowerP,
      totalLoadPowerP: inner.totalLoadPowerP,
      warnings: inner.warnings,
    );
  }
}
