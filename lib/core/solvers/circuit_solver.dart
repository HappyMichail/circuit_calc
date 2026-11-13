import '../model/circuit.dart';
import '../model/solution.dart';
import 'complex_solver.dart';
import 'kirchhoff_solver.dart';
import 'mesh_solver.dart';
import 'nodal_solver.dart';
import 'reduction_solver.dart';
import 'superposition_solver.dart';
import 'thevenin_norton_solver.dart';

class CircuitSolver {
  static CircuitSolution solve(
    Circuit circuit,
    CalculationMethod method, {
    CalculationMethod acBaseMethod = CalculationMethod.nodalPotentials,
  }) {
    if (circuit.isAc && method != CalculationMethod.complexMethod) {
      // In AC mode, wrap with ComplexSolver using the chosen method as base
      return ComplexSolver.solve(circuit, baseMethod: method);
    }

    switch (method) {
      case CalculationMethod.equivalentReduction:
        return ReductionSolver.solve(circuit);
      case CalculationMethod.kirchhoff:
        return KirchhoffSolver.solve(circuit);
      case CalculationMethod.meshCurrents:
        return MeshSolver.solve(circuit);
      case CalculationMethod.nodalPotentials:
        return NodalSolver.solve(circuit);
      case CalculationMethod.superposition:
        return SuperpositionSolver.solve(circuit);
      case CalculationMethod.theveninNorton:
        return TheveninNortonSolver.solve(circuit);
      case CalculationMethod.complexMethod:
        return ComplexSolver.solve(circuit, baseMethod: acBaseMethod);
    }
  }
}
