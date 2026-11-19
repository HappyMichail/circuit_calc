import '../math/complex.dart';
import '../model/circuit.dart';
import '../model/solution.dart';
import 'solver_utils.dart';

class _RedEdge {
  String id;
  String name;
  String u;
  String v;
  Complex z;
  Complex e; // aligned u -> v
  bool isCurrentSource;
  Complex j; // aligned u -> v

  _RedEdge({
    required this.id,
    required this.name,
    required this.u,
    required this.v,
    required this.z,
    required this.e,
    this.isCurrentSource = false,
    this.j = Complex.zero,
  });

  bool get isPassive => !isCurrentSource && e.isZero();
}

class ReductionSolver {
  static CircuitSolution solve(
    Circuit circuit, {
    CalculationMethod reportAs = CalculationMethod.equivalentReduction,
  }) {
    circuit.validate();

    final edges = <_RedEdge>[
      for (final b in circuit.branches)
        _RedEdge(
          id: b.id,
          name: b.name,
          u: b.fromNodeId,
          v: b.toNodeId,
          z: circuit.impedanceOf(b),
          e: circuit.emfOf(b),
          isCurrentSource: b.hasCurrentSource,
          j: circuit.currentSourceOf(b),
        ),
    ];
    final activeNodes = <String>{for (final n in circuit.nodes) n.id};
    final nodeLabels = <String, String>{
      for (final n in circuit.nodes) n.id: n.label,
    };

    final steps = <SolutionStep>[];
    final warnings = <String>[];
    var stepNum = 1;
    var starCounter = 1;

    bool changed = true;
    while (changed && edges.length > 1) {
      changed = false;

      // 1. Try Parallel reduction (same pair of nodes)
      final parallelPair = _findParallelPair(edges);
      if (parallelPair != null) {
        final (e1, e2) = parallelPair;
        final combined = _combineParallel(e1, e2, stepNum, circuit.isAc, steps);
        if (combined != null) {
          edges.remove(e1);
          edges.remove(e2);
          edges.add(combined);
          stepNum++;
          changed = true;
          continue;
        }
      }

      // 2. Try Series reduction (degree-2 node)
      final seriesInfo = _findSeriesNode(edges, activeNodes);
      if (seriesInfo != null) {
        final (nodeId, e1, e2) = seriesInfo;
        final combined = _combineSeries(
          nodeId,
          nodeLabels[nodeId] ?? nodeId,
          e1,
          e2,
          stepNum,
          circuit.isAc,
          steps,
        );
        if (combined != null) {
          edges.remove(e1);
          edges.remove(e2);
          edges.add(combined);
          activeNodes.remove(nodeId);
          stepNum++;
          changed = true;
          continue;
        }
      }

      // 3. Try Delta -> Star on passive triangle
      final delta = _findPassiveDelta(edges);
      if (delta != null) {
        final (eAb, eBc, eCa, a, b, c) = delta;
        final s = eAb.z + eBc.z + eCa.z;
        if (!s.isZero()) {
          final centerId = '__star_$starCounter';
          final centerLabel = 'O$starCounter';
          starCounter++;
          activeNodes.add(centerId);
          nodeLabels[centerId] = centerLabel;

          final zA = (eAb.z * eCa.z) / s;
          final zB = (eAb.z * eBc.z) / s;
          final zC = (eBc.z * eCa.z) / s;

          edges.remove(eAb);
          edges.remove(eBc);
          edges.remove(eCa);

          edges.add(_RedEdge(
            id: '${eAb.id}_yA',
            name: 'Z_{${nodeLabels[a] ?? a}$centerLabel}',
            u: a,
            v: centerId,
            z: zA,
            e: Complex.zero,
          ));
          edges.add(_RedEdge(
            id: '${eBc.id}_yB',
            name: 'Z_{${nodeLabels[b] ?? b}$centerLabel}',
            u: b,
            v: centerId,
            z: zB,
            e: Complex.zero,
          ));
          edges.add(_RedEdge(
            id: '${eCa.id}_yC',
            name: 'Z_{${nodeLabels[c] ?? c}$centerLabel}',
            u: c,
            v: centerId,
            z: zC,
            e: Complex.zero,
          ));

          steps.add(SolutionStep(
            title: 'Шаг $stepNum. Преобразование треугольник → звезда (Δ → Y)',
            description:
                'Пассивный треугольник между узлами '
                '${nodeLabels[a]}, ${nodeLabels[b]}, ${nodeLabels[c]} '
                'заменён на звезду с центром $centerLabel.',
            latexEquations: [
              'Z_\\Sigma = ${eAb.z.toLatex(isAc: circuit.isAc, digits: 2)} + '
                  '${eBc.z.toLatex(isAc: circuit.isAc, digits: 2)} + '
                  '${eCa.z.toLatex(isAc: circuit.isAc, digits: 2)} = '
                  '${s.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}',
              'Z_{${nodeLabels[a]}} = ${zA.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}, \\quad '
                  'Z_{${nodeLabels[b]}} = ${zB.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}, \\quad '
                  'Z_{${nodeLabels[c]}} = ${zC.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}',
            ],
          ));
          stepNum++;
          changed = true;
        }
      }
    }

    if (edges.length == 1) {
      final finalEdge = edges.first;
      steps.add(SolutionStep(
        title: 'Итог свёртывания схемы',
        description:
            'Схема полностью свёрнута к одной эквивалентной ветви.',
        latexEquations: [
          'Z_{\\text{экв}} = ${finalEdge.z.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ Ом}, \\quad '
              'E_{\\text{экв}} = ${finalEdge.e.toLatex(isAc: circuit.isAc, digits: 3)}\\text{ В}',
        ],
      ));
    } else {
      warnings.add(
        'Схема не может быть полностью свёрнута элементарными преобразованиями '
        '(осталось ${edges.length} ветвей). Токи ветвей вычислены универсальным '
        'методом узловых потенциалов; для полного аналитического вывода '
        'рекомендуется «Метод узловых потенциалов» или «Метод контурных токов».',
      );
      steps.add(SolutionStep(
        title: 'Предел элементарного свёртывания',
        description: warnings.last,
      ));
    }

    // Compute exact currents & potentials for all original branches
    final mna = SolverUtils.solveMnaRaw(circuit);
    return SolverUtils.buildSolution(
      circuit: circuit,
      method: reportAs,
      currents: mna.currents,
      potentials: mna.potentials,
      steps: steps,
      warnings: warnings,
    );
  }

  static (_RedEdge, _RedEdge)? _findParallelPair(List<_RedEdge> edges) {
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final a = edges[i];
        final b = edges[j];
        final sameDir = a.u == b.u && a.v == b.v;
        final oppDir = a.u == b.v && a.v == b.u;
        if (sameDir || oppDir) {
          return (a, b);
        }
      }
    }
    return null;
  }

  static _RedEdge? _combineParallel(
    _RedEdge a,
    _RedEdge b,
    int stepNum,
    bool isAc,
    List<SolutionStep> steps,
  ) {
    // Align b to a's direction (u -> v)
    final sameDir = a.u == b.u && a.v == b.v;
    final bE = sameDir ? b.e : -b.e;
    final bJ = sameDir ? b.j : -b.j;

    // Both passive
    if (a.isPassive && b.isPassive) {
      final sumZ = a.z + b.z;
      if (sumZ.isZero()) return null;
      final zEq = (a.z * b.z) / sumZ;
      steps.add(SolutionStep(
        title: 'Шаг $stepNum. Параллельное соединение (${a.name} || ${b.name})',
        description: 'Заменяем две параллельные пассивные ветви одной:',
        latexEquations: [
          'Z_{\\text{экв}} = \\frac{Z_{${a.name}} \\cdot Z_{${b.name}}}{Z_{${a.name}} + Z_{${b.name}}} = '
              '${zEq.toLatex(isAc: isAc, digits: 3)}\\text{ Ом}',
        ],
      ));
      return _RedEdge(
        id: '${a.id}||${b.id}',
        name: '(${a.name}||${b.name})',
        u: a.u,
        v: a.v,
        z: zEq,
        e: Complex.zero,
      );
    }

    // Active parallel branches via Norton admittance sum
    if ((!a.isCurrentSource && a.z.isZero()) ||
        (!b.isCurrentSource && b.z.isZero())) {
      return null; // ideal voltage sources in parallel
    }

    final yA = a.isCurrentSource ? Complex.zero : Complex.one / a.z;
    final yB = b.isCurrentSource ? Complex.zero : Complex.one / b.z;
    final yEq = yA + yB;
    if (yEq.isZero()) return null;

    final jA = a.isCurrentSource ? a.j : a.e * yA;
    final jB = b.isCurrentSource ? bJ : bE * yB;
    final jEq = jA + jB;
    final zEq = Complex.one / yEq;
    final eEq = jEq * zEq;

    steps.add(SolutionStep(
      title: 'Шаг $stepNum. Параллельное объединение активных ветвей (${a.name} || ${b.name})',
      description:
          'Преобразуем параллельные ветви к эквивалентному генератору (E ↔ J):',
      latexEquations: [
        'Y_{\\text{экв}} = ${yEq.toLatex(isAc: isAc, digits: 3)}\\text{ См}, \\quad '
            'Z_{\\text{экв}} = ${zEq.toLatex(isAc: isAc, digits: 3)}\\text{ Ом}',
        'E_{\\text{экв}} = ${eEq.toLatex(isAc: isAc, digits: 3)}\\text{ В}',
      ],
    ));

    return _RedEdge(
      id: '${a.id}||${b.id}',
      name: '(${a.name}||${b.name})',
      u: a.u,
      v: a.v,
      z: zEq,
      e: eEq,
    );
  }

  static (String, _RedEdge, _RedEdge)? _findSeriesNode(
    List<_RedEdge> edges,
    Set<String> activeNodes,
  ) {
    for (final nodeId in activeNodes) {
      final incident =
          edges.where((e) => e.u == nodeId || e.v == nodeId).toList();
      if (incident.length == 2) {
        if (!incident[0].isCurrentSource && !incident[1].isCurrentSource) {
          return (nodeId, incident[0], incident[1]);
        }
      }
    }
    return null;
  }

  static _RedEdge? _combineSeries(
    String midNodeId,
    String midLabel,
    _RedEdge e1,
    _RedEdge e2,
    int stepNum,
    bool isAc,
    List<SolutionStep> steps,
  ) {
    // Orient path as: startNode -> midNodeId -> endNode
    final startNode = e1.u == midNodeId ? e1.v : e1.u;
    final e1Aligned = e1.v == midNodeId ? e1.e : -e1.e;

    final endNode = e2.u == midNodeId ? e2.v : e2.u;
    final e2Aligned = e2.u == midNodeId ? e2.e : -e2.e;

    if (startNode == endNode) {
      // Single closed loop of 2 series edges! Combine into 1 edge representing the loop
      final zLoop = e1.z + e2.z;
      final eLoop = e1Aligned + e2Aligned;
      steps.add(SolutionStep(
        title: 'Шаг $stepNum. Последовательное соединение (${e1.name} + ${e2.name})',
        description:
            'Узел $midLabel соединяет две последовательные ветви в замкнутый контур:',
        latexEquations: [
          'Z_{\\text{экв}} = ${e1.z.toLatex(isAc: isAc, digits: 2)} + ${e2.z.toLatex(isAc: isAc, digits: 2)} = '
              '${zLoop.toLatex(isAc: isAc, digits: 3)}\\text{ Ом}',
          if (!eLoop.isZero())
            'E_{\\text{экв}} = ${eLoop.toLatex(isAc: isAc, digits: 3)}\\text{ В}',
        ],
      ));
      return _RedEdge(
        id: '${e1.id}+${e2.id}',
        name: '(${e1.name}+${e2.name})',
        u: startNode,
        v: midNodeId,
        z: zLoop,
        e: eLoop,
      );
    }

    final zSum = e1.z + e2.z;
    final eSum = e1Aligned + e2Aligned;

    steps.add(SolutionStep(
      title: 'Шаг $stepNum. Последовательное соединение (${e1.name} + ${e2.name})',
      description: 'Исключаем узел $midLabel между последовательными ветвями:',
      latexEquations: [
        'Z_{\\text{экв}} = ${e1.z.toLatex(isAc: isAc, digits: 2)} + ${e2.z.toLatex(isAc: isAc, digits: 2)} = '
            '${zSum.toLatex(isAc: isAc, digits: 3)}\\text{ Ом}',
        if (!eSum.isZero())
          'E_{\\text{экв}} = ${eSum.toLatex(isAc: isAc, digits: 3)}\\text{ В}',
      ],
    ));

    return _RedEdge(
      id: '${e1.id}+${e2.id}',
      name: '(${e1.name}+${e2.name})',
      u: startNode,
      v: endNode,
      z: zSum,
      e: eSum,
    );
  }

  static (_RedEdge, _RedEdge, _RedEdge, String, String, String)?
      _findPassiveDelta(List<_RedEdge> edges) {
    final passive = edges.where((e) => e.isPassive).toList();
    bool connects(_RedEdge e, String x, String y) =>
        (e.u == x && e.v == y) || (e.u == y && e.v == x);

    for (var i = 0; i < passive.length; i++) {
      for (var j = i + 1; j < passive.length; j++) {
        for (var k = j + 1; k < passive.length; k++) {
          final e1 = passive[i];
          final e2 = passive[j];
          final e3 = passive[k];
          final nodes = <String>{e1.u, e1.v, e2.u, e2.v, e3.u, e3.v};
          if (nodes.length == 3) {
            final list = nodes.toList();
            final a = list[0];
            final b = list[1];
            final c = list[2];
            final triple = [e1, e2, e3];
            _RedEdge? eAb;
            _RedEdge? eBc;
            _RedEdge? eCa;
            for (final e in triple) {
              if (eAb == null && connects(e, a, b)) {
                eAb = e;
              } else if (eBc == null && connects(e, b, c)) {
                eBc = e;
              } else if (eCa == null && connects(e, c, a)) {
                eCa = e;
              }
            }
            if (eAb != null && eBc != null && eCa != null) {
              return (eAb, eBc, eCa, a, b, c);
            }
          }
        }
      }
    }
    return null;
  }
}
