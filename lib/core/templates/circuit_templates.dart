import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/circuit_node.dart';

class CircuitTemplates {
  static List<Circuit> all() => [
        twoLoopDc(),
        mixedReductionDc(),
        wheatstoneBridgeDc(),
        currentSourceDc(),
        threeBranchAc(),
        resonantAc(),
      ];

  /// Classic 2-loop DC circuit with 2 EMFs (ideal for Kirchhoff, Mesh, Superposition, Thevenin).
  static Circuit twoLoopDc() {
    return const Circuit(
      name: 'Двухконтурная цепь (DC)',
      isAc: false,
      nodes: [
        CircuitNode(id: 'n1', label: '1', x: 140, y: 120),
        CircuitNode(id: 'n2', label: '2', x: 360, y: 120),
        CircuitNode(id: 'n0', label: '0', x: 250, y: 280),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 10,
          eMagnitude: 24,
          eAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b2',
          name: '2',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          rOhm: 20,
        ),
        CircuitBranch(
          id: 'b3',
          name: '3',
          fromNodeId: 'n1',
          toNodeId: 'n0',
          rOhm: 30,
        ),
        CircuitBranch(
          id: 'b4',
          name: '4',
          fromNodeId: 'n2',
          toNodeId: 'n0',
          rOhm: 15,
          eMagnitude: 12,
          eAlignedWithBranch: false,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b3',
    );
  }

  /// Mixed series-parallel DC circuit (ideal for Equivalent Reduction).
  static Circuit mixedReductionDc() {
    return const Circuit(
      name: 'Смешанное соединение (DC)',
      isAc: false,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 100, y: 260),
        CircuitNode(id: 'n1', label: '1', x: 100, y: 100),
        CircuitNode(id: 'n2', label: '2', x: 260, y: 100),
        CircuitNode(id: 'n3', label: '3', x: 420, y: 180),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 2,
          eMagnitude: 36,
          eAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b2',
          name: '2',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          rOhm: 4,
        ),
        CircuitBranch(
          id: 'b3',
          name: '3',
          fromNodeId: 'n2',
          toNodeId: 'n3',
          rOhm: 6,
        ),
        CircuitBranch(
          id: 'b4',
          name: '4',
          fromNodeId: 'n2',
          toNodeId: 'n0',
          rOhm: 12,
        ),
        CircuitBranch(
          id: 'b5',
          name: '5',
          fromNodeId: 'n3',
          toNodeId: 'n0',
          rOhm: 6,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b5',
    );
  }

  /// Wheatstone bridge (tests Delta -> Star reduction!).
  static Circuit wheatstoneBridgeDc() {
    return const Circuit(
      name: 'Мост Уитстона (Δ → Y)',
      isAc: false,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 100, y: 200),
        CircuitNode(id: 'n1', label: '1', x: 250, y: 80),
        CircuitNode(id: 'n2', label: '2', x: 250, y: 320),
        CircuitNode(id: 'n3', label: '3', x: 400, y: 200),
      ],
      branches: [
        CircuitBranch(
          id: 'b_src',
          name: 'E',
          fromNodeId: 'n0',
          toNodeId: 'n3',
          rOhm: 1,
          eMagnitude: 20,
          eAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 10,
        ),
        CircuitBranch(
          id: 'b2',
          name: '2',
          fromNodeId: 'n0',
          toNodeId: 'n2',
          rOhm: 20,
        ),
        CircuitBranch(
          id: 'b3',
          name: '3',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          rOhm: 15,
        ),
        CircuitBranch(
          id: 'b4',
          name: '4',
          fromNodeId: 'n1',
          toNodeId: 'n3',
          rOhm: 30,
        ),
        CircuitBranch(
          id: 'b5',
          name: '5',
          fromNodeId: 'n2',
          toNodeId: 'n3',
          rOhm: 10,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b3',
    );
  }

  /// Circuit with both Current Source J and EMF E (Nodal / Mesh / Superposition).
  static Circuit currentSourceDc() {
    return const Circuit(
      name: 'Цепь с источником тока J и ЭДС E',
      isAc: false,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 250, y: 280),
        CircuitNode(id: 'n1', label: '1', x: 120, y: 120),
        CircuitNode(id: 'n2', label: '2', x: 380, y: 120),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          hasCurrentSource: true,
          jMagnitude: 3,
          jAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b2',
          name: '2',
          fromNodeId: 'n1',
          toNodeId: 'n0',
          rOhm: 10,
        ),
        CircuitBranch(
          id: 'b3',
          name: '3',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          rOhm: 5,
        ),
        CircuitBranch(
          id: 'b4',
          name: '4',
          fromNodeId: 'n2',
          toNodeId: 'n0',
          rOhm: 20,
          eMagnitude: 15,
          eAlignedWithBranch: false,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b3',
    );
  }

  /// Classic 3-branch sinusoidal AC circuit (Complex method + Phasor diagram).
  static Circuit threeBranchAc() {
    return const Circuit(
      name: 'Трёхветвевая цепь (AC, 50 Гц)',
      isAc: true,
      frequencyHz: 50,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 250, y: 280),
        CircuitNode(id: 'n1', label: '1', x: 140, y: 120),
        CircuitNode(id: 'n2', label: '2', x: 360, y: 120),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: '1',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 10,
          xlOhmOverride: 15,
          eMagnitude: 220,
          ePhaseDeg: 0,
          eAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b2',
          name: '2',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          rOhm: 20,
          xcOhmOverride: 25,
        ),
        CircuitBranch(
          id: 'b3',
          name: '3',
          fromNodeId: 'n1',
          toNodeId: 'n0',
          rOhm: 15,
          xlOhmOverride: 10,
        ),
        CircuitBranch(
          id: 'b4',
          name: '4',
          fromNodeId: 'n2',
          toNodeId: 'n0',
          rOhm: 12,
          eMagnitude: 110,
          ePhaseDeg: 30,
          eAlignedWithBranch: false,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b3',
    );
  }

  /// Parallel RLC AC circuit with L and C specified in Henry / Farad.
  static Circuit resonantAc() {
    return const Circuit(
      name: 'Параллельный RLC-контур (AC)',
      isAc: true,
      frequencyHz: 50,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 240, y: 280),
        CircuitNode(id: 'n1', label: '1', x: 240, y: 100),
      ],
      branches: [
        CircuitBranch(
          id: 'b1',
          name: 'E',
          fromNodeId: 'n0',
          toNodeId: 'n1',
          rOhm: 2,
          eMagnitude: 100,
          ePhaseDeg: 0,
          eAlignedWithBranch: true,
        ),
        CircuitBranch(
          id: 'b2',
          name: 'L',
          fromNodeId: 'n1',
          toNodeId: 'n0',
          rOhm: 8,
          lHenry: 0.05,
        ),
        CircuitBranch(
          id: 'b3',
          name: 'C',
          fromNodeId: 'n1',
          toNodeId: 'n0',
          rOhm: 0,
          cFarad: 0.0002,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b2',
    );
  }
}
