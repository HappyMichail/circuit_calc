import 'dart:io';
import 'package:material_ui/material_ui.dart';
import '../../core/export/circuit_exporter.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/model/solution.dart';
import '../../core/solvers/circuit_solver.dart';
import '../../core/templates/circuit_templates.dart';
import '../theme/app_theme.dart';
import '../widgets/circuit_canvas.dart';
import '../widgets/element_editor_dialog.dart';
import '../widgets/solution_panel.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

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
  Duration? _solveDuration;
  String? _error;
  String? _selectedBranchId;

  late TabController _tabController;
  final TextEditingController _freqCtrl = TextEditingController(text: '50');
  final TransformationController _canvasTransform = TransformationController();
  String? _freqError;

  @override
  void initState() {
    super.initState();
    _circuit = CircuitTemplates.twoLoopDc();
    _selectedBranchId = _circuit.effectiveTargetBranchId();
    _tabController = TabController(length: 2, vsync: this);
    _solve();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _freqCtrl.dispose();
    _canvasTransform.dispose();
    super.dispose();
  }

  void _solve({bool switchToResultOnMobile = false}) {
    final sw = Stopwatch()..start();
    setState(() {
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
      if (switchToResultOnMobile && MediaQuery.of(context).size.width < 960) {
        _tabController.animateTo(1);
      }
    });
  }

  void _loadTemplate(Circuit template) {
    setState(() {
      _circuit = template;
      _selectedBranchId = template.effectiveTargetBranchId();
      _freqCtrl.text = template.frequencyHz.toString();
      _freqError = null;
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
      _selectedBranchId = res.branch.id;
      _circuit = _circuit.copyWith(
        branches: updatedBranches,
        targetBranchId: res.setAsTarget ? res.branch.id : null,
        clearTargetBranch:
            !res.setAsTarget && _circuit.targetBranchId == res.branch.id,
      );
    });
    _solve();
  }

  void _zoomBy(double factor) {
    final m = _canvasTransform.value.clone()..scaleByDouble(factor, factor, factor, 1.0);
    _canvasTransform.value = m;
  }

  void _resetZoom() {
    _canvasTransform.value = Matrix4.identity();
  }

  Future<void> _exportAs(String extType) async {
    final defaultPath = CircuitExporter.defaultExportPath(extType);
    final pathCtrl = TextEditingController(text: defaultPath);

    final chosenPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Экспорт схемы и результатов (${extType.toUpperCase()})'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: pathCtrl,
            decoration: const InputDecoration(
              labelText: 'Путь сохранения файла',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(pathCtrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    pathCtrl.dispose();

    if (chosenPath == null || chosenPath.isEmpty || !mounted) return;

    try {
      final file = File(chosenPath);
      await file.parent.create(recursive: true);
      if (extType == 'svg') {
        final svg = CircuitExporter.buildSvg(_circuit, _solution);
        await file.writeAsString(svg);
      } else {
        final bytes = await CircuitExporter.buildPdf(_circuit, _solution);
        await file.writeAsBytes(bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл сохранён: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  CircuitBranch _inspectedBranch() {
    final id = _selectedBranchId ?? _circuit.effectiveTargetBranchId();
    return _circuit.branches.firstWhere(
      (b) => b.id == id,
      orElse: () => _circuit.branches.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;
    final ext =
        Theme.of(context).extension<CircuitColors>() ?? CircuitColors.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            isWide
                ? _buildDesktopHeader(context, ext, cs)
                : _buildMobileHeader(context, ext, cs),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildDesktopWorkspace(context, ext, cs),
                        ),
                        VerticalDivider(width: 1, color: ext.outline),
                        SizedBox(
                          width: 470,
                          child: SolutionPanel(
                            circuit: _circuit,
                            solution: _solution,
                            errorMessage: _error,
                            solveDuration: _solveDuration,
                          ),
                        ),
                      ],
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMobileSchemaTab(context, ext, cs),
                        SolutionPanel(
                          circuit: _circuit,
                          solution: _solution,
                          errorMessage: _error,
                          solveDuration: _solveDuration,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context, CircuitColors ext, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.electric_bolt, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 8),
        const Text(
          'CircuitCalc',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: ext.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ext.outline),
          ),
          child: Text(
            'ТОЭ',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ext.surfaceContainer,
        border: Border(bottom: BorderSide(color: ext.outline)),
      ),
      child: Row(
        children: [
          _buildBrand(context, ext, cs),
          const Spacer(),
          // DC / AC toggle
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
          if (_circuit.isAc) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _freqCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'f (Гц)',
                  errorText: _freqError,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: _onFreqChanged,
              ),
            ),
          ],
          const SizedBox(width: 10),
          // Method dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ext.outline),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CalculationMethod>(
                  isDense: true,
                  isExpanded: true,
                  value: _method,
                  items: [
                    for (final m in CalculationMethod.values)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: _onMethodChanged,
                ),
              ),
            ),
          ),
          if (_method == CalculationMethod.complexMethod) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ext.outline),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CalculationMethod>(
                  isDense: true,
                  value: _acBaseMethod,
                  items: [
                    for (final m in CalculationMethod.values
                        .where((x) => x != CalculationMethod.complexMethod))
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          'База: ${m.shortTitle}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (m) {
                    if (m == null) return;
                    setState(() => _acBaseMethod = m);
                    _solve();
                  },
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _buildTemplatesButton(ext, cs, showLabel: true),
          const SizedBox(width: 8),
          _buildExportButton(ext, cs, showLabel: true),
          const Spacer(),
          IconButton(
            tooltip: 'Переключить тему',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _solve(),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Рассчитать'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: ext.surfaceContainer,
        border: Border(bottom: BorderSide(color: ext.outline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildBrand(context, ext, cs),
                const Spacer(),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                const SizedBox(width: 6),
                _buildTemplatesButton(ext, cs, showLabel: false),
                const SizedBox(width: 4),
                _buildExportButton(ext, cs, showLabel: false),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Тема',
                  onPressed: widget.onToggleTheme,
                  icon: Icon(
                    widget.themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            tabs: [
              const Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schema_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Схема'),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.functions, size: 16),
                    const SizedBox(width: 6),
                    const Text('Решение'),
                    if (_solution != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ext.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(
    CircuitColors ext,
    ColorScheme cs, {
    required bool showLabel,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Экспорт схемы и результатов',
      onSelected: _exportAs,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 18),
              SizedBox(width: 8),
              Text('Экспорт в PDF (.pdf)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'svg',
          child: Row(
            children: [
              Icon(Icons.image_outlined, size: 18),
              SizedBox(width: 8),
              Text('Экспорт в SVG (.svg)'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10 : 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: ext.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ext.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 16, color: cs.primary),
            if (showLabel) ...[
              const SizedBox(width: 6),
              const Text('Экспорт', style: TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesButton(
    CircuitColors ext,
    ColorScheme cs, {
    required bool showLabel,
  }) {
    return PopupMenuButton<Circuit>(
      tooltip: 'Шаблоны ТОЭ',
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
                  color: tpl.isAc ? cs.primary : ext.accent,
                ),
                const SizedBox(width: 8),
                Text(tpl.name),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10 : 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: ext.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ext.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, size: 16, color: ext.accent),
            if (showLabel) ...[
              const SizedBox(width: 6),
              const Text('Шаблоны', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 16, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopWorkspace(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    final refNode = _circuit.nodes
        .firstWhere((n) => n.id == _circuit.effectiveReferenceNodeId());
    final targetBranch = _circuit.branches
        .firstWhere((b) => b.id == _circuit.effectiveTargetBranchId());
    final inspected = _inspectedBranch();
    final res = _solution?.branchResults[inspected.id];

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CircuitCanvas(
                  circuit: _circuit,
                  solution: _solution,
                  activeTool: _tool,
                  selectedBranchId: _selectedBranchId,
                  transformationController: _canvasTransform,
                  onSelectBranch: (b) =>
                      setState(() => _selectedBranchId = b.id),
                  onGeometryChanged: (c) => setState(() => _circuit = c),
                  onCircuitChanged: (c) {
                    setState(() => _circuit = c);
                    _solve();
                  },
                  onEditBranch: _editBranch,
                ),
              ),
              // Floating Top-Left Toolstrip
              Positioned(
                top: 12,
                left: 12,
                child: _buildFloatingToolstrip(ext, cs, vertical: false),
              ),
              // Floating Top-Right Legend Badges
              Positioned(
                top: 12,
                right: 12,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _legendBadge(
                      ext,
                      dotColor: ext.accent,
                      label: 'Базовый узел: ${refNode.label} (φ=0 В)',
                    ),
                    _legendBadge(
                      ext,
                      dotColor: cs.primary,
                      label: 'Целевая ветвь: ${targetBranch.name}',
                    ),
                  ],
                ),
              ),
              // Floating Bottom Hints
              Positioned(
                bottom: 10,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ext.surfaceContainer.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ext.outline),
                  ),
                  child: Text(
                    _hintForTool(_tool),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Quick Branch Inspector Drawer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ext.surfaceContainer,
            border: Border(top: BorderSide(color: ext.outline)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ext.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ext.accent.withValues(alpha: 0.35)),
                ),
                child: Icon(Icons.tune, size: 16, color: ext.accent),
              ),
              const SizedBox(width: 10),
              Text(
                'Ветвь ${inspected.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        inspected.summary(
                            isAc: _circuit.isAc, omega: _circuit.omega),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (res != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'I = ${_circuit.isAc ? res.current.toStringPolar(digits: 2) : Complex.fmt(res.current.re, 3)} А',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'P = ${Complex.fmt(res.powerActive, 2)} Вт',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: ext.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _editBranch(inspected),
                child: const Text('Изменить...'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSchemaTab(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    final inspected = _inspectedBranch();
    final res = _solution?.branchResults[inspected.id];

    return Column(
      children: [
        // Method selector pill
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ext.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ext.outline),
            ),
            child: Row(
              children: [
                Text(
                  'Метод:',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CalculationMethod>(
                      isDense: true,
                      isExpanded: true,
                      value: _method,
                      items: [
                        for (final m in CalculationMethod.values)
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      onChanged: _onMethodChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ext.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CircuitCanvas(
                      circuit: _circuit,
                      solution: _solution,
                      activeTool: _tool,
                      selectedBranchId: _selectedBranchId,
                      transformationController: _canvasTransform,
                      onSelectBranch: (b) =>
                          setState(() => _selectedBranchId = b.id),
                      onGeometryChanged: (c) => setState(() => _circuit = c),
                      onCircuitChanged: (c) {
                        setState(() => _circuit = c);
                        _solve();
                      },
                      onEditBranch: _editBranch,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildFloatingToolstrip(ext, cs, vertical: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Mini Power Balance bar
        if (_solution != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ext.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_solution!.isPowerBalanced ? ext.success : cs.error)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 15,
                        color: _solution!.isPowerBalanced
                            ? ext.success
                            : cs.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Баланс: ${Complex.fmt(_solution!.totalSourcePowerP, 2)} Вт',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'P_потр: ${Complex.fmt(_solution!.totalLoadPowerP, 2)} Вт',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Bottom Action Sheet
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ext.surfaceContainer,
            border: Border(top: BorderSide(color: ext.outline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ветвь ${inspected.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (res != null)
                    Text(
                      'I = ${_circuit.isAc ? res.current.toStringPolar(digits: 2) : Complex.fmt(res.current.re, 3)} А',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: ext.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _editBranch(inspected),
                      child: const Text('Параметры...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _solve(switchToResultOnMobile: true),
                      child: const Text('Рассчитать →'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingToolstrip(
    CircuitColors ext,
    ColorScheme cs, {
    required bool vertical,
  }) {
    final items = [
      _toolBtn(CanvasTool.selectMove, Icons.near_me, 'Выбор / Перемещение', cs),
      _toolBtn(CanvasTool.addNode, Icons.add_circle_outline, 'Добавить узел', cs),
      _toolBtn(CanvasTool.addBranch, Icons.timeline, 'Добавить ветвь', cs),
      _toolBtn(CanvasTool.delete, Icons.delete_outline, 'Удалить', cs),
      if (!vertical) ...[
        Container(width: 1, height: 22, color: ext.outline),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Увеличить',
          onPressed: () => _zoomBy(1.2),
          icon: const Icon(Icons.zoom_in, size: 18),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Уменьшить',
          onPressed: () => _zoomBy(0.83),
          icon: const Icon(Icons.zoom_out, size: 18),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Сбросить масштаб',
          onPressed: _resetZoom,
          icon: const Icon(Icons.fit_screen, size: 18),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ext.surfaceContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.outline),
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: items)
          : Row(mainAxisSize: MainAxisSize.min, children: items),
    );
  }

  Widget _toolBtn(
      CanvasTool tool, IconData icon, String tooltip, ColorScheme cs) {
    final selected = _tool == tool;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: selected ? cs.primary : Colors.transparent,
        foregroundColor: selected ? cs.onPrimary : cs.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => setState(() => _tool = tool),
      icon: Icon(icon, size: 18),
    );
  }

  Widget _legendBadge(
    CircuitColors ext, {
    required Color dotColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ext.surfaceContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ext.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  void _onFreqChanged(String v) {
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
  }

  void _onMethodChanged(CalculationMethod? m) {
    if (m == null) return;
    setState(() {
      _method = m;
      if (m == CalculationMethod.complexMethod && !_circuit.isAc) {
        _circuit = _circuit.copyWith(isAc: true);
      }
    });
    _solve();
  }

  String _hintForTool(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.selectMove:
        return 'ПКМ по ветви — параметры, по узлу — базовый (φ=0). Перетаскивание — сдвиг узлов и элементов.';
      case CanvasTool.addNode:
        return 'Нажмите на свободное место холста, чтобы добавить новый узел.';
      case CanvasTool.addBranch:
        return 'Нажмите на начальный, затем на конечный узел для создания ветви.';
      case CanvasTool.delete:
        return 'Нажмите на узел или ветвь для удаления.';
    }
  }
}
