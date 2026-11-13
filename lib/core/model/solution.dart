import '../math/complex.dart';
import 'circuit.dart';

class BranchResult {
  final String branchId;
  final String branchName;
  final Complex current; // I (from -> to)
  final Complex voltage; // U = phi_from - phi_to
  final double powerActive; // P in Watts (absorbed by passive elements)
  final double powerReactive; // Q in VAr

  const BranchResult({
    required this.branchId,
    required this.branchName,
    required this.current,
    required this.voltage,
    required this.powerActive,
    required this.powerReactive,
  });
}

class SolutionStep {
  final String title;
  final String description;
  final List<String> latexEquations;

  const SolutionStep({
    required this.title,
    required this.description,
    this.latexEquations = const [],
  });
}

class CircuitSolution {
  final CalculationMethod method;
  final bool isAc;
  final double omega;
  final Map<String, BranchResult> branchResults;
  final Map<String, Complex> nodePotentials;
  final List<SolutionStep> steps;
  final double totalSourcePowerP;
  final double totalLoadPowerP;
  final List<String> warnings;

  const CircuitSolution({
    required this.method,
    required this.isAc,
    required this.omega,
    required this.branchResults,
    required this.nodePotentials,
    required this.steps,
    required this.totalSourcePowerP,
    required this.totalLoadPowerP,
    this.warnings = const [],
  });

  bool get isPowerBalanced =>
      (totalSourcePowerP - totalLoadPowerP).abs() <
      1e-3 * (1.0 + totalSourcePowerP.abs());
}
