import 'package:material_ui/material_ui.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/model/circuit_node.dart';
import '../../core/model/solution.dart';
import '../../core/solvers/circuit_solver.dart';
import '../../core/storage/project_storage.dart';
import '../../core/templates/circuit_templates.dart';
import '../widgets/circuit_canvas.dart';

class _EditorSnapshot {
  final Circuit circuit;
  final CalculationMethod method;
  final CalculationMethod acBaseMethod;
  const _EditorSnapshot(this.circuit, this.method, this.acBaseMethod);
}

/// Manages circuit state, Undo/Redo history, dirty flag, and solver execution.
class CircuitEditorController extends ChangeNotifier {
  static const int _maxHistory = 50;

  Circuit _circuit;
  CalculationMethod _method = CalculationMethod.nodalPotentials;
  CalculationMethod _acBaseMethod = CalculationMethod.nodalPotentials;
  CanvasTool _tool = CanvasTool.selectMove;

  CircuitSolution? _solution;
  Duration? _solveDuration;
  String? _error;
  String? _selectedBranchId;
  bool _isDirty = false;

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  CircuitEditorController({Circuit? initialCircuit})
      : _circuit = initialCircuit ?? CircuitTemplates.twoLoopDc() {
    _selectedBranchId = _circuit.effectiveTargetBranchId();
    solve();
  }

  Circuit get circuit => _circuit;
  CalculationMethod get method => _method;
  CalculationMethod get acBaseMethod => _acBaseMethod;
  CanvasTool get tool => _tool;
  CircuitSolution? get solution => _solution;
  Duration? get solveDuration => _solveDuration;
  String? get error => _error;
  String? get selectedBranchId => _selectedBranchId;
  bool get isDirty => _isDirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  CircuitBranch get inspectedBranch {
    final id = _selectedBranchId ?? _circuit.effectiveTargetBranchId();
    return _circuit.branches.firstWhere(
      (b) => b.id == id,
      orElse: () => _circuit.branches.first,
    );
  }

  void _pushUndo() {
    _undoStack.add(_EditorSnapshot(_circuit, _method, _acBaseMethod));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void solve() {
    final sw = Stopwatch()..start();
    _error = null;
    try {
      _solution = CircuitSolver.solve(
        _circuit,
        _method,
        acBaseMethod: _acBaseMethod,
      );
      sw.stop();
      _solveDuration = sw.elapsed;
    } catch (e) {
      sw.stop();
      _solution = null;
      _solveDuration = null;
      _error = e.toString();
    }
    notifyListeners();
  }

  void setTool(CanvasTool tool) {
    if (_tool == tool) return;
    _tool = tool;
    notifyListeners();
  }

  void selectBranch(String branchId) {
    if (_selectedBranchId == branchId) return;
    _selectedBranchId = branchId;
    notifyListeners();
  }

  void beginGeometryDrag() {
    _pushUndo();
  }

  void updateGeometry(Circuit updated) {
    _circuit = updated;
    _isDirty = true;
    notifyListeners();
  }

  void applyCircuitChange(Circuit updated, {bool recordUndo = true}) {
    if (recordUndo) _pushUndo();
    _circuit = updated;
    _isDirty = true;
    if (_selectedBranchId != null &&
        !_circuit.branches.any((b) => b.id == _selectedBranchId)) {
      _selectedBranchId = _circuit.branches.isNotEmpty
          ? _circuit.effectiveTargetBranchId()
          : null;
    }
    solve();
  }

  void updateEditedBranch(CircuitBranch updatedBranch,
      {required bool setAsTarget}) {
    _pushUndo();
    final updatedBranches = _circuit.branches
        .map((b) => b.id == updatedBranch.id ? updatedBranch : b)
        .toList();
    _selectedBranchId = updatedBranch.id;
    _circuit = _circuit.copyWith(
      branches: updatedBranches,
      targetBranchId: setAsTarget ? updatedBranch.id : null,
      clearTargetBranch:
          !setAsTarget && _circuit.targetBranchId == updatedBranch.id,
    );
    _isDirty = true;
    solve();
  }

  void rotateSelectedBranch([double deltaDeg = 45.0]) {
    final target = inspectedBranch;
    _pushUndo();
    final nextAngle = ((target.symbolAngleDeg ?? 0.0) + deltaDeg) % 360.0;
    final updatedBranches = _circuit.branches
        .map((b) =>
            b.id == target.id ? b.copyWith(symbolAngleDeg: nextAngle) : b)
        .toList();
    _circuit = _circuit.copyWith(branches: updatedBranches);
    _isDirty = true;
    notifyListeners();
  }

  void deleteSelectedBranch() {
    if (_circuit.branches.length <= 1) return;
    final target = inspectedBranch;
    _pushUndo();
    final remaining =
        _circuit.branches.where((b) => b.id != target.id).toList();
    _circuit = _circuit.copyWith(
      branches: remaining,
      clearTargetBranch: _circuit.targetBranchId == target.id,
    );
    _selectedBranchId = _circuit.effectiveTargetBranchId();
    _isDirty = true;
    solve();
  }

  void setIsAc(bool isAc) {
    if (_circuit.isAc == isAc) return;
    _pushUndo();
    _circuit = _circuit.copyWith(isAc: isAc);
    if (isAc) {
      _method = CalculationMethod.complexMethod;
    } else if (_method == CalculationMethod.complexMethod) {
      _method = CalculationMethod.nodalPotentials;
    }
    _isDirty = true;
    solve();
  }

  void setFrequency(double frequencyHz) {
    if (!frequencyHz.isFinite || frequencyHz <= 0) return;
    _circuit = _circuit.copyWith(frequencyHz: frequencyHz);
    _isDirty = true;
    solve();
  }

  void setMethod(CalculationMethod m) {
    _method = m;
    if (m == CalculationMethod.complexMethod && !_circuit.isAc) {
      _circuit = _circuit.copyWith(isAc: true);
    }
    solve();
  }

  void setAcBaseMethod(CalculationMethod m) {
    _acBaseMethod = m;
    solve();
  }

  void loadTemplate(Circuit template) {
    _undoStack.clear();
    _redoStack.clear();
    _circuit = template;
    _selectedBranchId = template.effectiveTargetBranchId();
    if (template.isAc) {
      _method = CalculationMethod.complexMethod;
    } else if (_method == CalculationMethod.complexMethod) {
      _method = CalculationMethod.nodalPotentials;
    }
    _isDirty = false;
    solve();
  }

  void newProject() {
    _undoStack.clear();
    _redoStack.clear();
    _circuit = const Circuit(
      name: 'Новый проект',
      isAc: false,
      nodes: [
        CircuitNode(id: 'n0', label: '0', x: 180, y: 260),
        CircuitNode(id: 'n1', label: '1', x: 380, y: 140),
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
          rOhm: 10,
        ),
      ],
      referenceNodeId: 'n0',
      targetBranchId: 'b2',
    );
    _selectedBranchId = 'b2';
    _method = CalculationMethod.nodalPotentials;
    _isDirty = false;
    solve();
  }

  void loadSavedProject(SavedProject project) {
    project.circuit.validate();
    _undoStack.clear();
    _redoStack.clear();
    _circuit = project.circuit;
    _method = project.method;
    _acBaseMethod = project.acBaseMethod;
    _selectedBranchId = project.circuit.effectiveTargetBranchId();
    _isDirty = false;
    solve();
  }

  void markSaved({String? newName}) {
    if (newName != null && newName.isNotEmpty) {
      _circuit = _circuit.copyWith(name: newName);
    }
    _isDirty = false;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_EditorSnapshot(_circuit, _method, _acBaseMethod));
    final prev = _undoStack.removeLast();
    _circuit = prev.circuit;
    _method = prev.method;
    _acBaseMethod = prev.acBaseMethod;
    if (_selectedBranchId != null &&
        !_circuit.branches.any((b) => b.id == _selectedBranchId)) {
      _selectedBranchId = _circuit.effectiveTargetBranchId();
    }
    _isDirty = true;
    solve();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_EditorSnapshot(_circuit, _method, _acBaseMethod));
    final next = _redoStack.removeLast();
    _circuit = next.circuit;
    _method = next.method;
    _acBaseMethod = next.acBaseMethod;
    if (_selectedBranchId != null &&
        !_circuit.branches.any((b) => b.id == _selectedBranchId)) {
      _selectedBranchId = _circuit.effectiveTargetBranchId();
    }
    _isDirty = true;
    solve();
  }
}
