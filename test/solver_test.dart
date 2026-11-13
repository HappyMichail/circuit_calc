import 'package:circuit_calc/core/math/complex.dart';
import 'package:circuit_calc/core/model/circuit.dart';
import 'package:circuit_calc/core/model/circuit_branch.dart';
import 'package:circuit_calc/core/model/circuit_node.dart';
import 'package:circuit_calc/core/model/solution.dart';
import 'package:circuit_calc/core/solvers/circuit_solver.dart';
import 'package:circuit_calc/core/templates/circuit_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void _verifyKirchhoffAndOhm(Circuit circuit, CircuitSolution sol) {
  // 1. KCL at every node: sum(I_in) - sum(I_out) == 0
  for (final n in circuit.nodes) {
    var netIn = Complex.zero;
    for (final b in circuit.branches) {
      final i = sol.branchResults[b.id]!.current;
      if (b.toNodeId == n.id) netIn = netIn + i;
      if (b.fromNodeId == n.id) netIn = netIn - i;
    }
    expect(netIn.abs, lessThan(1e-6), reason: 'KCL failed at node ${n.label}');
  }

  // 2. Generalized Ohm's law on every non-current-source branch: U = Z*I - E
  for (final b in circuit.branches) {
    if (b.hasCurrentSource) continue;
    final res = sol.branchResults[b.id]!;
    final z = circuit.impedanceOf(b);
    final e = circuit.emfOf(b);
    final expectedU = z * res.current - e;
    expect((res.voltage - expectedU).abs, lessThan(1e-6),
        reason: 'Ohm law failed on branch ${b.name}');
  }

  expect(sol.isPowerBalanced, isTrue);
}

void main() {
  group('All 7 calculation methods agree on DC & AC circuits', () {
    test('Two-loop DC circuit: all 6 DC methods match & satisfy KCL/Ohm', () {
      final circuit = CircuitTemplates.twoLoopDc();
      final baseline =
          CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      _verifyKirchhoffAndOhm(circuit, baseline);

      for (final method in [
        CalculationMethod.kirchhoff,
        CalculationMethod.meshCurrents,
        CalculationMethod.superposition,
        CalculationMethod.theveninNorton,
        CalculationMethod.equivalentReduction,
      ]) {
        final sol = CircuitSolver.solve(circuit, method);
        _verifyKirchhoffAndOhm(circuit, sol);
        for (final b in circuit.branches) {
          final diff = (sol.branchResults[b.id]!.current -
                  baseline.branchResults[b.id]!.current)
              .abs;
          expect(diff, lessThan(1e-6),
              reason: '${method.title} branch ${b.name}');
        }
      }
    });

    test('Hand-calculated DC benchmark: exact analytical currents & potentials', () {
      // Single node pair + 3 parallel branches:
      // Branch 1: E1 = 12V (n0 -> n1), R1 = 2 Ohm
      // Branch 2: R2 = 4 Ohm (n1 -> n0)
      // Branch 3: J3 = 1 A (n0 -> n1)
      // KCL at n1: (12 - phi1)/2 + 1 = phi1/4 => 6 - 0.5*phi1 + 1 = 0.25*phi1
      // => 0.75*phi1 = 7 => phi1 = 28/3 V = 9.333333... V
      // I1 = (12 - 28/3)/2 = 4/3 A, I2 = (28/3)/4 = 7/3 A, I3 = 1 A
      const circuit = Circuit(
        name: 'Analytical DC',
        isAc: false,
        nodes: [
          CircuitNode(id: 'n0', label: '0', x: 0, y: 0),
          CircuitNode(id: 'n1', label: '1', x: 100, y: 0),
        ],
        branches: [
          CircuitBranch(
            id: 'b1',
            name: '1',
            fromNodeId: 'n0',
            toNodeId: 'n1',
            rOhm: 2,
            eMagnitude: 12,
            eAlignedWithBranch: true,
          ),
          CircuitBranch(
            id: 'b2',
            name: '2',
            fromNodeId: 'n1',
            toNodeId: 'n0',
            rOhm: 4,
          ),
          CircuitBranch(
            id: 'b3',
            name: '3',
            fromNodeId: 'n0',
            toNodeId: 'n1',
            hasCurrentSource: true,
            jMagnitude: 1,
            jAlignedWithBranch: true,
          ),
        ],
        referenceNodeId: 'n0',
      );

      final sol = CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      _verifyKirchhoffAndOhm(circuit, sol);
      expect(sol.nodePotentials['n1']!.re, closeTo(28 / 3, 1e-9));
      expect(sol.branchResults['b1']!.current.re, closeTo(4 / 3, 1e-9));
      expect(sol.branchResults['b2']!.current.re, closeTo(7 / 3, 1e-9));
      expect(sol.branchResults['b3']!.current.re, closeTo(1.0, 1e-9));
    });

    test('Hand-calculated AC benchmark: series RL circuit at E = 100∠0° V', () {
      // Z = 3 + j4 Ohm => |Z| = 5 Ohm, I = 100 / (3 + j4) = 12 - j16 A (20∠-53.13° A)
      const circuit = Circuit(
        name: 'Analytical AC',
        isAc: true,
        frequencyHz: 50,
        nodes: [
          CircuitNode(id: 'n0', label: '0', x: 0, y: 0),
          CircuitNode(id: 'n1', label: '1', x: 100, y: 0),
        ],
        branches: [
          CircuitBranch(
            id: 'b1',
            name: '1',
            fromNodeId: 'n0',
            toNodeId: 'n1',
            rOhm: 3,
            xlOhmOverride: 4,
            eMagnitude: 100,
            ePhaseDeg: 0,
            eAlignedWithBranch: true,
          ),
          CircuitBranch(
            id: 'b2',
            name: '2',
            fromNodeId: 'n1',
            toNodeId: 'n0',
            rOhm: 0,
          ),
        ],
        referenceNodeId: 'n0',
      );

      final sol = CircuitSolver.solve(circuit, CalculationMethod.complexMethod);
      _verifyKirchhoffAndOhm(circuit, sol);
      expect(sol.branchResults['b1']!.current.re, closeTo(12.0, 1e-9));
      expect(sol.branchResults['b1']!.current.im, closeTo(-16.0, 1e-9));
      expect(sol.branchResults['b1']!.powerActive, closeTo(1200.0, 1e-9));
      expect(sol.branchResults['b1']!.powerReactive, closeTo(1600.0, 1e-9));
    });

    test('Mixed-scale circuit (1 mOhm and 1 MOhm) solves accurately', () {
      const circuit = Circuit(
        name: 'Mixed Scale',
        isAc: false,
        nodes: [
          CircuitNode(id: 'n0', label: '0', x: 0, y: 0),
          CircuitNode(id: 'n1', label: '1', x: 100, y: 0),
          CircuitNode(id: 'n2', label: '2', x: 200, y: 0),
        ],
        branches: [
          CircuitBranch(
            id: 'b1',
            name: '1',
            fromNodeId: 'n0',
            toNodeId: 'n1',
            rOhm: 1e-3,
            eMagnitude: 10,
            eAlignedWithBranch: true,
          ),
          CircuitBranch(
            id: 'b2',
            name: '2',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            rOhm: 1e6,
          ),
          CircuitBranch(
            id: 'b3',
            name: '3',
            fromNodeId: 'n2',
            toNodeId: 'n0',
            rOhm: 1e6,
          ),
        ],
        referenceNodeId: 'n0',
      );

      final sol = CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      _verifyKirchhoffAndOhm(circuit, sol);
      expect(sol.branchResults['b2']!.current.re, closeTo(5e-6, 1e-11));
    });

    test('Mixed reduction DC circuit: ReductionSolver fully reduces & matches', () {
      final circuit = CircuitTemplates.mixedReductionDc();
      final red =
          CircuitSolver.solve(circuit, CalculationMethod.equivalentReduction);
      expect(red.warnings, isEmpty);
      _verifyKirchhoffAndOhm(circuit, red);

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
      _verifyKirchhoffAndOhm(circuit, red);

      final mesh = CircuitSolver.solve(circuit, CalculationMethod.meshCurrents);
      for (final b in circuit.branches) {
        final diff = (red.branchResults[b.id]!.current -
                mesh.branchResults[b.id]!.current)
            .abs;
        expect(diff, lessThan(1e-6));
      }
    });

    test('Current source + EMF DC circuit: all methods match & satisfy KCL/Ohm', () {
      final circuit = CircuitTemplates.currentSourceDc();
      final nodal =
          CircuitSolver.solve(circuit, CalculationMethod.nodalPotentials);
      _verifyKirchhoffAndOhm(circuit, nodal);

      for (final method in [
        CalculationMethod.kirchhoff,
        CalculationMethod.meshCurrents,
        CalculationMethod.superposition,
        CalculationMethod.theveninNorton,
        CalculationMethod.equivalentReduction,
      ]) {
        final sol = CircuitSolver.solve(circuit, method);
        _verifyKirchhoffAndOhm(circuit, sol);
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
      _verifyKirchhoffAndOhm(circuit, baseline);

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
        _verifyKirchhoffAndOhm(circuit, sol);
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
      _verifyKirchhoffAndOhm(circuit, sol);
      expect(sol.branchResults['b3']!.powerActive.abs(), lessThan(1e-9));
      expect(sol.branchResults['b3']!.powerReactive, lessThan(0));
    });

    test('Circuit validation catches duplicate IDs, negative R, NaN, and bad freq', () {
      final base = CircuitTemplates.twoLoopDc();
      expect(
        () => base.copyWith(nodes: [...base.nodes, base.nodes.first]).validate(),
        throwsA(isA<CircuitValidationException>()),
      );
      expect(
        () => base
            .copyWith(
              branches: [
                base.branches.first.copyWith(rOhm: -5),
                ...base.branches.skip(1),
              ],
            )
            .validate(),
        throwsA(isA<CircuitValidationException>()),
      );
      expect(
        () => base.copyWith(isAc: true, frequencyHz: 0).validate(),
        throwsA(isA<CircuitValidationException>()),
      );
      expect(
        () => base
            .copyWith(
              branches: [
                base.branches.first.copyWith(eMagnitude: double.nan),
                ...base.branches.skip(1),
              ],
            )
            .validate(),
        throwsA(isA<CircuitValidationException>()),
      );

      final cleared = base.copyWith(clearTargetBranch: true);
      expect(cleared.targetBranchId, isNull);
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
