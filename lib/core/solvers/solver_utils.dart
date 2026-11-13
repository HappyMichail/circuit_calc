import '../math/complex.dart';
import '../math/linear_solver.dart';
import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/solution.dart';

class LoopEdge {
  final CircuitBranch branch;
  final int dir; // +1 if from->to, -1 if to->from
  const LoopEdge(this.branch, this.dir);
}

class FundamentalLoop {
  final CircuitBranch chord;
  final List<LoopEdge> edges; // includes chord with dir = +1
  const FundamentalLoop({required this.chord, required this.edges});
}

class SpanningTreeResult {
  final Set<String> treeBranchIds;
  final List<CircuitBranch> chords;
  final List<FundamentalLoop> loops;

  const SpanningTreeResult({
    required this.treeBranchIds,
    required this.chords,
    required this.loops,
  });
}

class SolverUtils {
  /// Builds a spanning tree and fundamental loops.
  /// Branches in [preferChords] are avoided in the tree if possible.
  static SpanningTreeResult buildSpanningTree(
    Circuit circuit, {
    Set<String> preferChords = const {},
  }) {
    final parent = <String, String>{
      for (final n in circuit.nodes) n.id: n.id,
    };

    String find(String x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]!]!;
        x = parent[x]!;
      }
      return x;
    }

    bool union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra == rb) return false;
      parent[ra] = rb;
      return true;
    }

    final treeBranches = <CircuitBranch>[];
    final treeBranchIds = <String>{};
    final chords = <CircuitBranch>[];

    // Pass 1: non-preferred-chord branches
    for (final b in circuit.branches) {
      if (preferChords.contains(b.id)) continue;
      if (union(b.fromNodeId, b.toNodeId)) {
        treeBranches.add(b);
        treeBranchIds.add(b.id);
      } else {
        chords.add(b);
      }
    }

    // Pass 2: preferred-chord branches (only added to tree if needed for connectivity)
    for (final b in circuit.branches) {
      if (!preferChords.contains(b.id)) continue;
      if (union(b.fromNodeId, b.toNodeId)) {
        treeBranches.add(b);
        treeBranchIds.add(b.id);
      } else {
        chords.add(b);
      }
    }

    // Build adjacency list for tree
    final treeAdj = <String, List<LoopEdge>>{
      for (final n in circuit.nodes) n.id: [],
    };
    for (final b in treeBranches) {
      treeAdj[b.fromNodeId]!.add(LoopEdge(b, 1));
      treeAdj[b.toNodeId]!.add(LoopEdge(b, -1));
    }

    // For each chord (u -> v), find path in tree from v -> u
    final loops = <FundamentalLoop>[];
    for (final chord in chords) {
      final path = _findTreePath(treeAdj, chord.toNodeId, chord.fromNodeId);
      loops.add(FundamentalLoop(
        chord: chord,
        edges: [LoopEdge(chord, 1), ...path],
      ));
    }

    return SpanningTreeResult(
      treeBranchIds: treeBranchIds,
      chords: chords,
      loops: loops,
    );
  }

  static List<LoopEdge> _findTreePath(
    Map<String, List<LoopEdge>> treeAdj,
    String start,
    String target,
  ) {
    final visited = <String>{start};
    final parentEdge = <String, LoopEdge>{};
    final parentNode = <String, String>{};
    final queue = <String>[start];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur == target) break;
      for (final edge in treeAdj[cur]!) {
        final next = edge.dir == 1 ? edge.branch.toNodeId : edge.branch.fromNodeId;
        if (visited.add(next)) {
          parentNode[next] = cur;
          parentEdge[next] = edge;
          queue.add(next);
        }
      }
    }

    final path = <LoopEdge>[];
    var cur = target;
    while (cur != start) {
      final edge = parentEdge[cur]!;
      path.add(edge);
      cur = parentNode[cur]!;
    }
    return path.reversed.toList();
  }

  /// Modified Nodal Analysis (MNA) raw solver.
  /// Returns (nodePotentials, branchCurrents).
  static ({
    Map<String, Complex> potentials,
    Map<String, Complex> currents,
    List<List<Complex>> matrixA,
    List<Complex> vectorB,
    List<String> unknownNames,
  }) solveMnaRaw(Circuit circuit) {
    circuit.validate();
    final refId = circuit.effectiveReferenceNodeId();
    final nonRefNodes = circuit.nodes.where((n) => n.id != refId).toList();
    final nodeIndex = <String, int>{
      for (var i = 0; i < nonRefNodes.length; i++) nonRefNodes[i].id: i,
    };

    // Ideal voltage branches (Z == 0 and not current source) need extra current variables
    final idealEmfBranches = <CircuitBranch>[];
    for (final b in circuit.branches) {
      if (!b.hasCurrentSource && circuit.impedanceOf(b).isZero()) {
        idealEmfBranches.add(b);
      }
    }

    final nNodes = nonRefNodes.length;
    final nIdeal = idealEmfBranches.length;
    final dim = nNodes + nIdeal;

    final a = List.generate(dim, (_) => List<Complex>.filled(dim, Complex.zero));
    final rhs = List<Complex>.filled(dim, Complex.zero);

    for (final b in circuit.branches) {
      final u = nodeIndex[b.fromNodeId];
      final v = nodeIndex[b.toNodeId];

      if (b.hasCurrentSource) {
        final j = circuit.currentSourceOf(b);
        // Current leaves fromNode, enters toNode
        if (u != null) rhs[u] = rhs[u] - j;
        if (v != null) rhs[v] = rhs[v] + j;
      } else {
        final z = circuit.impedanceOf(b);
        final e = circuit.emfOf(b);
        if (z.isZero()) {
          // Handled via idealEmfBranches constraint
          continue;
        }
        final y = Complex.one / z;
        // Admittance stamps
        if (u != null) a[u][u] = a[u][u] + y;
        if (v != null) a[v][v] = a[v][v] + y;
        if (u != null && v != null) {
          a[u][v] = a[u][v] - y;
          a[v][u] = a[v][u] - y;
        }
        // Norton equivalent current: I_eq = E * Y flowing from -> to
        final iEq = e * y;
        if (u != null) rhs[u] = rhs[u] - iEq;
        if (v != null) rhs[v] = rhs[v] + iEq;
      }
    }

    // Stamp ideal EMF branches: phi_to - phi_from = E  =>  phi_from - phi_to = -E
    for (var k = 0; k < nIdeal; k++) {
      final b = idealEmfBranches[k];
      final row = nNodes + k;
      final u = nodeIndex[b.fromNodeId];
      final v = nodeIndex[b.toNodeId];
      final e = circuit.emfOf(b);

      if (u != null) {
        a[u][row] = a[u][row] + Complex.one;
        a[row][u] = a[row][u] + Complex.one;
      }
      if (v != null) {
        a[v][row] = a[v][row] - Complex.one;
        a[row][v] = a[row][v] - Complex.one;
      }
      rhs[row] = -e;
    }

    final sol = LinearSolver.solve(a, rhs);

    final potentials = <String, Complex>{refId: Complex.zero};
    for (var i = 0; i < nNodes; i++) {
      potentials[nonRefNodes[i].id] = sol[i];
    }

    final currents = <String, Complex>{};
    var idealIdx = 0;
    for (final b in circuit.branches) {
      if (b.hasCurrentSource) {
        currents[b.id] = circuit.currentSourceOf(b);
      } else {
        final z = circuit.impedanceOf(b);
        if (z.isZero()) {
          currents[b.id] = sol[nNodes + idealIdx];
          idealIdx++;
        } else {
          final phiFrom = potentials[b.fromNodeId]!;
          final phiTo = potentials[b.toNodeId]!;
          final e = circuit.emfOf(b);
          currents[b.id] = (phiFrom - phiTo + e) / z;
        }
      }
    }

    final unknownNames = <String>[
      ...nonRefNodes.map((n) => '\\varphi_{${n.label}}'),
      ...idealEmfBranches.map((b) => 'I_{${b.name}}'),
    ];

    return (
      potentials: potentials,
      currents: currents,
      matrixA: a,
      vectorB: rhs,
      unknownNames: unknownNames,
    );
  }

  /// Builds complete [CircuitSolution] with branch voltages and power balance.
  static CircuitSolution buildSolution({
    required Circuit circuit,
    required CalculationMethod method,
    required Map<String, Complex> currents,
    Map<String, Complex>? potentials,
    required List<SolutionStep> steps,
    List<String> warnings = const [],
  }) {
    final resolvedPotentials =
        potentials ?? solveMnaRaw(circuit).potentials;

    final branchResults = <String, BranchResult>{};
    var totalSourceP = 0.0;
    var totalLoadP = 0.0;

    for (final b in circuit.branches) {
      final i = currents[b.id] ?? Complex.zero;
      final phiFrom = resolvedPotentials[b.fromNodeId] ?? Complex.zero;
      final phiTo = resolvedPotentials[b.toNodeId] ?? Complex.zero;
      final u = phiFrom - phiTo;

      double pActive = 0.0;
      double pReactive = 0.0;

      if (b.hasCurrentSource) {
        // Current source delivers S = -U * I*
        final sDeliv = -(u * i.conj);
        totalSourceP += sDeliv.re;
        pActive = -sDeliv.re;
        pReactive = -sDeliv.im;
      } else {
        final z = circuit.impedanceOf(b);
        final e = circuit.emfOf(b);
        final i2 = i.absSquared;
        pActive = i2 * z.re;
        pReactive = i2 * z.im;
        totalLoadP += pActive;

        final sEmf = e * i.conj;
        totalSourceP += sEmf.re;
      }

      branchResults[b.id] = BranchResult(
        branchId: b.id,
        branchName: b.name,
        current: i,
        voltage: u,
        powerActive: pActive,
        powerReactive: pReactive,
      );
    }

    // Add power balance verification step
    final balanceStep = SolutionStep(
      title: 'Проверка баланса мощностей',
      description: 'Суммарная активная мощность источников должна равняться '
          'суммарной активной мощности, потребляемой элементами цепи.',
      latexEquations: [
        'P_{\\text{ист}} = ${Complex.fmt(totalSourceP, 3)}\\text{ Вт}, \\quad '
            'P_{\\text{потр}} = ${Complex.fmt(totalLoadP, 3)}\\text{ Вт}',
      ],
    );

    return CircuitSolution(
      method: method,
      isAc: circuit.isAc,
      omega: circuit.omega,
      branchResults: branchResults,
      nodePotentials: resolvedPotentials,
      steps: [...steps, balanceStep],
      totalSourcePowerP: totalSourceP,
      totalLoadPowerP: totalLoadP,
      warnings: warnings,
    );
  }
}
