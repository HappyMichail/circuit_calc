import 'dart:math' as math;
import '../math/complex.dart';
import 'circuit_branch.dart';
import 'circuit_node.dart';

enum CalculationMethod {
  equivalentReduction,
  kirchhoff,
  meshCurrents,
  nodalPotentials,
  superposition,
  theveninNorton,
  complexMethod,
}

extension CalculationMethodX on CalculationMethod {
  String get title {
    switch (this) {
      case CalculationMethod.equivalentReduction:
        return 'Метод эквивалентных преобразований';
      case CalculationMethod.kirchhoff:
        return 'Законы Кирхгофа';
      case CalculationMethod.meshCurrents:
        return 'Метод контурных токов';
      case CalculationMethod.nodalPotentials:
        return 'Метод узловых потенциалов';
      case CalculationMethod.superposition:
        return 'Метод наложения (суперпозиции)';
      case CalculationMethod.theveninNorton:
        return 'Метод эквивалентного генератора (Тевенина / Нортона)';
      case CalculationMethod.complexMethod:
        return 'Комплексный метод (AC)';
    }
  }

  String get shortTitle {
    switch (this) {
      case CalculationMethod.equivalentReduction:
        return 'Свёртывание';
      case CalculationMethod.kirchhoff:
        return 'Кирхгоф';
      case CalculationMethod.meshCurrents:
        return 'Контурные токи';
      case CalculationMethod.nodalPotentials:
        return 'Узловые потенциалы';
      case CalculationMethod.superposition:
        return 'Наложение';
      case CalculationMethod.theveninNorton:
        return 'Тевенин / Нортон';
      case CalculationMethod.complexMethod:
        return 'Комплексный (AC)';
    }
  }
}

class CircuitValidationException implements Exception {
  final String message;
  const CircuitValidationException(this.message);

  @override
  String toString() => message;
}

/// Complete electrical circuit model.
class Circuit {
  final String name;
  final bool isAc;
  final double frequencyHz;
  final List<CircuitNode> nodes;
  final List<CircuitBranch> branches;
  final String? referenceNodeId;
  final String? targetBranchId;

  const Circuit({
    required this.name,
    this.isAc = false,
    this.frequencyHz = 50.0,
    required this.nodes,
    required this.branches,
    this.referenceNodeId,
    this.targetBranchId,
  });

  double get omega => 2 * math.pi * frequencyHz;

  Complex impedanceOf(CircuitBranch b) =>
      b.impedance(isAc: isAc, omega: omega);

  Complex emfOf(CircuitBranch b) => b.emf(isAc: isAc);

  Complex currentSourceOf(CircuitBranch b) => b.currentSource(isAc: isAc);

  String effectiveReferenceNodeId() {
    if (referenceNodeId != null &&
        nodes.any((n) => n.id == referenceNodeId)) {
      return referenceNodeId!;
    }
    return nodes.first.id;
  }

  String effectiveTargetBranchId() {
    if (targetBranchId != null &&
        branches.any((b) => b.id == targetBranchId)) {
      return targetBranchId!;
    }
    return branches.first.id;
  }

  /// Validates connectivity, parameter finiteness, uniqueness, and topology.
  void validate() {
    if (nodes.length < 2) {
      throw const CircuitValidationException(
          'Схема должна содержать минимум 2 узла.');
    }
    if (branches.isEmpty) {
      throw const CircuitValidationException(
          'Схема должна содержать хотя бы одну ветвь.');
    }
    if (isAc && (!frequencyHz.isFinite || frequencyHz <= 0)) {
      throw const CircuitValidationException(
          'Частота переменного тока должна быть положительным конечным числом.');
    }

    final nodeIds = <String>{};
    for (final n in nodes) {
      if (!nodeIds.add(n.id)) {
        throw CircuitValidationException(
            'Обнаружен повторяющийся идентификатор узла: ${n.id}.');
      }
    }

    if (referenceNodeId != null && !nodeIds.contains(referenceNodeId)) {
      throw const CircuitValidationException(
          'Выбранный базовый узел не найден в схеме.');
    }

    final branchIds = <String>{};
    for (final b in branches) {
      if (!branchIds.add(b.id)) {
        throw CircuitValidationException(
            'Обнаружен повторяющийся идентификатор ветви: ${b.id}.');
      }
      if (!nodeIds.contains(b.fromNodeId) || !nodeIds.contains(b.toNodeId)) {
        throw CircuitValidationException(
            'Ветвь ${b.name} ссылается на несуществующий узел.');
      }
      if (b.fromNodeId == b.toNodeId) {
        throw CircuitValidationException(
            'Ветвь ${b.name} замкнута сама на себя (одинаковые узлы).');
      }

      final nums = [
        b.rOhm,
        b.lHenry,
        b.cFarad,
        if (b.xlOhmOverride != null) b.xlOhmOverride!,
        if (b.xcOhmOverride != null) b.xcOhmOverride!,
        b.eMagnitude,
        b.ePhaseDeg,
        b.jMagnitude,
        b.jPhaseDeg,
      ];
      if (nums.any((v) => !v.isFinite)) {
        throw CircuitValidationException(
            'Ветвь ${b.name} содержит некорректное числовое значение (NaN/Inf).');
      }
      if (b.rOhm < 0 ||
          b.lHenry < 0 ||
          b.cFarad < 0 ||
          (b.xlOhmOverride != null && b.xlOhmOverride! < 0) ||
          (b.xcOhmOverride != null && b.xcOhmOverride! < 0)) {
        throw CircuitValidationException(
            'Ветвь ${b.name}: значения R, L, C, XL, XC не могут быть отрицательными.');
      }
    }

    if (targetBranchId != null && !branchIds.contains(targetBranchId)) {
      throw const CircuitValidationException(
          'Выбранная целевая ветвь не найдена в схеме.');
    }

    // Check connectivity via BFS
    final adj = <String, List<String>>{for (final n in nodes) n.id: []};
    for (final b in branches) {
      adj[b.fromNodeId]!.add(b.toNodeId);
      adj[b.toNodeId]!.add(b.fromNodeId);
    }
    final visited = <String>{nodes.first.id};
    final queue = <String>[nodes.first.id];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final nxt in adj[cur]!) {
        if (visited.add(nxt)) queue.add(nxt);
      }
    }
    if (visited.length != nodes.length) {
      throw const CircuitValidationException(
          'Схема несвязна: есть изолированные узлы или компоненты.');
    }
  }

  Circuit copyWith({
    String? name,
    bool? isAc,
    double? frequencyHz,
    List<CircuitNode>? nodes,
    List<CircuitBranch>? branches,
    String? referenceNodeId,
    String? targetBranchId,
    bool clearReferenceNode = false,
    bool clearTargetBranch = false,
  }) {
    return Circuit(
      name: name ?? this.name,
      isAc: isAc ?? this.isAc,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      nodes: nodes ?? this.nodes,
      branches: branches ?? this.branches,
      referenceNodeId:
          clearReferenceNode ? null : (referenceNodeId ?? this.referenceNodeId),
      targetBranchId:
          clearTargetBranch ? null : (targetBranchId ?? this.targetBranchId),
    );
  }
}
