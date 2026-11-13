import 'package:material_ui/material_ui.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/model/solution.dart';
import '../../core/solvers/circuit_solver.dart';
import '../../core/templates/circuit_templates.dart';
import '../widgets/circuit_canvas.dart';
import '../widgets/element_editor_dialog.dart';
import '../widgets/solution_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Circuit _circuit;
  CalculationMethod _method = CalculationMethod.nodalPotentials;
  CalculationMethod _acBaseMethod = CalculationMethod.nodalPotentials;
  CanvasTool _tool = CanvasTool.selectMove;

  CircuitSolution? _solution;
  String? _error;

  late TabController _tabController;
  final TextEditingController _freqCtrl = TextEditingController(text: '50');
  String? _freqError;

  @override
  void initState() {
    super.initState();
    _circuit = CircuitTemplates.twoLoopDc();
    _tabController = TabController(length: 2, vsync: this);
    _solve();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  void _solve({bool switchToResultOnMobile = false}) {
    setState(() {
      _error = null;
      try {
        _solution = CircuitSolver.solve(
          _circuit,
          _method,
          acBaseMethod: _acBaseMethod,
        );
        if (switchToResultOnMobile && MediaQuery.of(context).size.width < 900) {
          _tabController.animateTo(1);
        }
      } catch (e) {
        _solution = null;
        _error = e.toString();
        if (switchToResultOnMobile && MediaQuery.of(context).size.width < 900) {
          _tabController.animateTo(1);
        }
      }
    });
  }

  void _loadTemplate(Circuit template) {
    setState(() {
      _circuit = template;
      _freqCtrl.text = template.frequencyHz.toString();
      if (template.isAc) {
        _method = CalculationMethod.complexMethod;
      } else if (_method == CalculationMethod.complexMethod) {
        _method = CalculationMethod.nodalPotentials;
      }
    });
    _solve();
  }

  Future<void> _editBranch(CircuitBranch branch) async {
    final fromLabel =
        _circuit.nodes.firstWhere((n) => n.id == branch.fromNodeId).label;
    final toLabel =
        _circuit.nodes.firstWhere((n) => n.id == branch.toNodeId).label;

    final res = await showDialog<ElementEditorResult>(
      context: context,
      builder: (_) => ElementEditorDialog(
        branch: branch,
        isAc: _circuit.isAc,
        frequencyHz: _circuit.frequencyHz,
        isTargetBranch: _circuit.effectiveTargetBranchId() == branch.id,
        fromLabel: fromLabel,
        toLabel: toLabel,
      ),
    );
    if (res == null) return;

    setState(() {
      final updatedBranches = _circuit.branches
          .map((b) => b.id == res.branch.id ? res.branch : b)
          .toList();
      _circuit = _circuit.copyWith(
        branches: updatedBranches,
        targetBranchId: res.setAsTarget ? res.branch.id : null,
        clearTargetBranch:
            !res.setAsTarget && _circuit.targetBranchId == res.branch.id,
      );
    });
    _solve();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор электрических цепей (ТОЭ)'),
        actions: [
          PopupMenuButton<Circuit>(
            tooltip: 'Готовые шаблоны ТОЭ',
            icon: const Icon(Icons.library_books_outlined),
            onSelected: _loadTemplate,
            itemBuilder: (_) => [
              for (final tpl in CircuitTemplates.all())
                PopupMenuItem(
                  value: tpl,
                  child: Row(
                    children: [
                      Icon(
                        tpl.isAc ? Icons.waves : Icons.bolt,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(tpl.name),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: isWide
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.schema_outlined), text: 'Схема'),
                  Tab(icon: Icon(Icons.functions), text: 'Решение'),
                ],
              ),
      ),
      body: Column(
        children: [
          _buildControlBar(context),
          const Divider(height: 1),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      Expanded(flex: 6, child: _buildEditorPane(context)),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: SolutionPanel(
                          circuit: _circuit,
                          solution: _solution,
                          errorMessage: _error,
                        ),
                      ),
                    ],
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEditorPane(context),
                      SolutionPanel(
                        circuit: _circuit,
                        solution: _solution,
                        errorMessage: _error,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // DC / AC toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('DC')),
              ButtonSegment(value: true, label: Text('AC')),
            ],
            selected: {_circuit.isAc},
            onSelectionChanged: (s) {
              final isAc = s.first;
              setState(() {
                _circuit = _circuit.copyWith(isAc: isAc);
                if (isAc) {
                  _method = CalculationMethod.complexMethod;
                } else if (_method == CalculationMethod.complexMethod) {
                  _method = CalculationMethod.nodalPotentials;
                }
              });
              _solve();
            },
          ),

          if (_circuit.isAc)
            SizedBox(
              width: 120,
              child: TextField(
                controller: _freqCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'f (Гц)',
                  errorText: _freqError,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final f = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (f == null || !f.isFinite || f <= 0) {
                    setState(() => _freqError = 'f > 0');
                  } else {
                    setState(() {
                      _freqError = null;
                      _circuit = _circuit.copyWith(frequencyHz: f);
                    });
                    _solve();
                  }
                },
              ),
            ),

          // Calculation method selector
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CalculationMethod>(
                isExpanded: true,
                value: _method,
                borderRadius: BorderRadius.circular(8),
                items: [
                  for (final m in CalculationMethod.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (m) {
                  if (m == null) return;
                  setState(() {
                    _method = m;
                    if (m == CalculationMethod.complexMethod &&
                        !_circuit.isAc) {
                      _circuit = _circuit.copyWith(isAc: true);
                    }
                  });
                  _solve();
                },
              ),
            ),
          ),

          if (_method == CalculationMethod.complexMethod)
            DropdownButtonHideUnderline(
              child: DropdownButton<CalculationMethod>(
                value: _acBaseMethod,
                items: [
                  for (final m in CalculationMethod.values
                      .where((x) => x != CalculationMethod.complexMethod))
                    DropdownMenuItem(
                      value: m,
                      child: Text('База: ${m.shortTitle}'),
                    ),
                ],
                onChanged: (m) {
                  if (m == null) return;
                  setState(() => _acBaseMethod = m);
                  _solve();
                },
              ),
            ),

          FilledButton.icon(
            onPressed: () => _solve(switchToResultOnMobile: true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Рассчитать'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPane(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _toolChip(CanvasTool.selectMove, Icons.pan_tool_alt_outlined,
                  'Выбор / Перемещение'),
              _toolChip(CanvasTool.addNode, Icons.add_circle_outline, 'Узел'),
              _toolChip(CanvasTool.addBranch, Icons.timeline, 'Ветвь'),
              _toolChip(CanvasTool.delete, Icons.delete_outline, 'Удалить'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hintForTool(_tool),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CircuitCanvas(
              circuit: _circuit,
              solution: _solution,
              activeTool: _tool,
              onGeometryChanged: (c) => setState(() => _circuit = c),
              onCircuitChanged: (c) {
                setState(() => _circuit = c);
                _solve();
              },
              onEditBranch: _editBranch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(CanvasTool tool, IconData icon, String label) {
    final selected = _tool == tool;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() => _tool = tool),
    );
  }

  String _hintForTool(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.selectMove:
        return 'Нажмите на ветвь для редактирования R/L/C/E/J, на узел — чтобы сделать его базовым (φ=0), или перетащите узел.';
      case CanvasTool.addNode:
        return 'Нажмите на свободное место холста, чтобы добавить новый узел.';
      case CanvasTool.addBranch:
        return 'Последовательно нажмите на начальный и конечный узел, чтобы соединить их ветвью.';
      case CanvasTool.delete:
        return 'Нажмите на узел или ветвь для удаления.';
    }
  }
}
