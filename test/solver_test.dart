import 'package:circuit_calc/core/math/complex.dart';
import 'package:circuit_calc/core/model/circuit.dart';
import 'package:circuit_calc/core/solvers/circuit_solver.dart';
import 'package:circuit_calc/core/templates/circuit_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('All 7 calculation methods agree on DC & AC circuits', () {
    test('Two-loop DC circuit: all 6 DC methods match & power balances', () {
      final circuit = CircuitTemplates.twoLoopDc();
      final baseline =
          CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      expect(baseline.isPowerBalanced, isTrue);

      for (final method in [
        CalculationMethod.kirchhoff,
        CalculationMethod.meshCurrents,
        CalculationMethod.superposition,
        CalculationMethod.theveninNorton,
        CalculationMethod.equivalentReduction,
      ]) {
        final sol = CircuitSolver.solve(circuit, method);
        expect(sol.isPowerBalanced, isTrue, reason: '${method.title} power');
        for (final b in circuit.branches) {
          final diff = (sol.branchResults[b.id]!.current -
                  baseline.branchResults[b.id]!.current)
              .abs;
          expect(diff, lessThan(1e-6),
              reason: '${method.title} branch ${b.name}');
        }
      }
    });

    test('Mixed reduction DC circuit: ReductionSolver fully reduces & matches', () {
      final circuit = CircuitTemplates.mixedReductionDc();
      final red =
          CircuitSolver.solve(circuit, CalculationMethod.equivalentReduction);
      expect(red.warnings, isEmpty);
      expect(red.isPowerBalanced, isTrue);

      final nodal =
          CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      for (final b in circuit.branches) {
        final diff = (red.branchResults[b.id]!.current -
                nodal.branchResults[b.id]!.current)
            .abs;
        expect(diff, lessThan(1e-6));
      }
    });

    test('Wheatstone bridge DC: Delta->Star reduction works & matches', () {
      final circuit = CircuitTemplates.wheatstoneBridgeDc();
      final red =
          CircuitSolver.solve(circuit, CalculationMethod.equivalentReduction);
      expect(red.warnings, isEmpty);
      expect(red.isPowerBalanced, isTrue);

      final mesh = CircuitSolver.solve(circuit, CalculationMethod.meshCurrents);
      for (final b in circuit.branches) {
        final diff = (red.branchResults[b.id]!.current -
                mesh.branchResults[b.id]!.current)
            .abs;
        expect(diff, lessThan(1e-6));
      }
    });

    test('Current source + EMF DC circuit: all methods match & power balances', () {
      final circuit = CircuitTemplates.currentSourceDc();
      final nodal =
          CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      expect(nodal.isPowerBalanced, isTrue);

      for (final method in [
        CalculationMethod.kirchhoff,
        CalculationMethod.meshCurrents,
        CalculationMethod.superposition,
        CalculationMethod.theveninNorton,
        CalculationMethod.equivalentReduction,
      ]) {
        final sol = CircuitSolver.solve(circuit, method);
        expect(sol.isPowerBalanced, isTrue, reason: '${method.title} power');
        for (final b in circuit.branches) {
          final diff = (sol.branchResults[b.id]!.current -
                  nodal.branchResults[b.id]!.current)
              .abs;
          expect(diff, lessThan(1e-6),
              reason: '${method.title} branch ${b.name}');
        }
      }
    });

    test('Three-branch AC circuit: Complex method with all base algorithms matches', () {
      final circuit = CircuitTemplates.threeBranchAc();
      final baseline = CircuitSolver.solve(
        circuit,
        CalculationMethod.complexMethod,
        acBaseMethod: CalculationMethod.nodalPotentials,
      );
      expect(baseline.isPowerBalanced, isTrue);

      for (final base in [
        CalculationMethod.kirchhoff,
        CalculationMethod.meshCurrents,
        CalculationMethod.superposition,
        CalculationMethod.theveninNorton,
      ]) {
        final sol = CircuitSolver.solve(
          circuit,
          CalculationMethod.complexMethod,
          acBaseMethod: base,
        );
        expect(sol.isPowerBalanced, isTrue, reason: '${base.title} AC power');
        for (final b in circuit.branches) {
          final diff = (sol.branchResults[b.id]!.current -
                  baseline.branchResults[b.id]!.current)
              .abs;
          expect(diff, lessThan(1e-6),
              reason: '${base.title} AC branch ${b.name}');
        }
      }
    });

    test('Parallel RLC AC circuit (L in H, C in F) balances power', () {
      final circuit = CircuitTemplates.resonantAc();
      final sol =
          CircuitSolver.solve(circuit, CalculationMethod.complexMethod);
      expect(sol.isPowerBalanced, isTrue);
      // Capacitor branch has R=0 so active power ~ 0
      expect(sol.branchResults['b3']!.powerActive.abs(), lessThan(1e-9));
      expect(sol.branchResults['b3']!.powerReactive, lessThan(0));
    });

    test('Complex arithmetic sanity check', () {
      const a = Complex(3, 4);
      const b = Complex(1, -2);
      expect(a.abs, closeTo(5.0, 1e-9));
      expect((a * b), equals(const Complex(11, -2)));
      expect(((a / b) * b).re, closeTo(3.0, 1e-9));
      expect(((a / b) * b).im, closeTo(4.0, 1e-9));
    });
  });
}
