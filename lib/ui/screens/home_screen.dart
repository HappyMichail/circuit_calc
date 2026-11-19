import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/templates/circuit_templates.dart';
import '../controllers/circuit_editor_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/circuit_canvas.dart';
import '../widgets/element_editor_dialog.dart';
import '../widgets/project_dialogs.dart';
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
  late final CircuitEditorController _ctrl;
  late final TabController _tabController;
  final TextEditingController _freqCtrl = TextEditingController(text: '50');
  final TransformationController _canvasTransform = TransformationController();
  String? _freqError;

  @override
  void initState() {
    super.initState();
    _ctrl = CircuitEditorController();
    _ctrl.addListener(_onControllerChanged);
    _tabController = TabController(length: 2, vsync: this);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _tabController.dispose();
    _freqCtrl.dispose();
    _canvasTransform.dispose();
    super.dispose();
  }

  void _syncFreqText() {
    _freqCtrl.text = _ctrl.circuit.frequencyHz.toString();
    _freqError = null;
  }

  Future<void> _loadTemplate(Circuit template) async {
    if (!await ProjectDialogs.confirmDiscardIfDirty(context, _ctrl)) return;
    _ctrl.loadTemplate(template);
    _syncFreqText();
  }

  Future<void> _handleProjectAction(String action) async {
    switch (action) {
      case 'new':
        if (!await ProjectDialogs.confirmDiscardIfDirty(context, _ctrl)) return;
        _ctrl.newProject();
        _syncFreqText();
      case 'save':
        await ProjectDialogs.showSaveProjectDialog(context, _ctrl);
      case 'open':
        if (!await ProjectDialogs.confirmDiscardIfDirty(context, _ctrl)) return;
        if (!mounted) return;
        final loaded =
            await ProjectDialogs.showOpenProjectDialog(context, _ctrl);
        if (loaded) _syncFreqText();
    }
  }

  Future<void> _editBranch(CircuitBranch branch) async {
    final c = _ctrl.circuit;
    final fromLabel = c.nodes.firstWhere((n) => n.id == branch.fromNodeId).label;
    final toLabel = c.nodes.firstWhere((n) => n.id == branch.toNodeId).label;

    final res = await showDialog<ElementEditorResult>(
      context: context,
      builder: (_) => ElementEditorDialog(
        branch: branch,
        isAc: c.isAc,
        frequencyHz: c.frequencyHz,
        isTargetBranch: c.effectiveTargetBranchId() == branch.id,
        fromLabel: fromLabel,
        toLabel: toLabel,
      ),
    );
    if (res == null) return;
    _ctrl.updateEditedBranch(res.branch, setAsTarget: res.setAsTarget);
  }

  void _zoomBy(double factor) {
    final m = _canvasTransform.value.clone()
      ..scaleByDouble(factor, factor, factor, 1.0);
    _canvasTransform.value = m;
  }

  void _resetZoom() {
    _canvasTransform.value = Matrix4.identity();
  }

  void _onFreqChanged(String v) {
    final f = double.tryParse(v.trim().replaceAll(',', '.'));
    if (f == null || !f.isFinite || f <= 0) {
      setState(() => _freqError = 'f > 0');
    } else {
      setState(() => _freqError = null);
      _ctrl.setFrequency(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;
    final ext =
        Theme.of(context).extension<CircuitColors>() ?? CircuitColors.dark;
    final cs = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _ctrl.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _ctrl.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): _ctrl.redo,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            ProjectDialogs.showSaveProjectDialog(context, _ctrl),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _ctrl.setTool(CanvasTool.selectMove),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                                circuit: _ctrl.circuit,
                                solution: _ctrl.solution,
                                errorMessage: _ctrl.error,
                                solveDuration: _ctrl.solveDuration,
                              ),
                            ),
                          ],
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMobileSchemaTab(context, ext, cs),
                            SolutionPanel(
                              circuit: _ctrl.circuit,
                              solution: _ctrl.solution,
                              errorMessage: _ctrl.error,
                              solveDuration: _ctrl.solveDuration,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context, CircuitColors ext, ColorScheme cs,
      {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 26 : 30,
          height: compact ? 26 : 30,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.electric_bolt,
              size: compact ? 16 : 18, color: cs.primary),
        ),
        const SizedBox(width: 6),
        Text(
          _ctrl.isDirty ? 'CircuitCalc •' : 'CircuitCalc',
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!compact) ...[
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
      ],
    );
  }

  Widget _buildDesktopHeader(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    final c = _ctrl.circuit;
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
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    selected: {c.isAc},
                    onSelectionChanged: (s) => _ctrl.setIsAc(s.first),
                  ),
                  if (c.isAc) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _freqCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'f (Гц)',
                          errorText: _freqError,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onChanged: _onFreqChanged,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ext.outline),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CalculationMethod>(
                          isDense: true,
                          isExpanded: true,
                          value: _ctrl.method,
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
                          onChanged: (m) {
                            if (m != null) _ctrl.setMethod(m);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_ctrl.method == CalculationMethod.complexMethod) ...[
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
                          value: _ctrl.acBaseMethod,
                          items: [
                            for (final m in CalculationMethod.values.where(
                                (x) => x != CalculationMethod.complexMethod))
                              DropdownMenuItem(
                                value: m,
                                child: Text(
                                  'База: ${m.shortTitle}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                          onChanged: (m) {
                            if (m != null) _ctrl.setAcBaseMethod(m);
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildProjectButton(ext, cs, showLabel: true),
                  const SizedBox(width: 6),
                  _buildTemplatesButton(ext, cs, showLabel: true),
                  const SizedBox(width: 6),
                  _buildExportButton(ext, cs, showLabel: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Отменить (Ctrl+Z)',
            onPressed: _ctrl.canUndo ? _ctrl.undo : null,
            icon: const Icon(Icons.undo, size: 19),
          ),
          IconButton(
            tooltip: 'Повторить (Ctrl+Y)',
            onPressed: _ctrl.canRedo ? _ctrl.redo : null,
            icon: const Icon(Icons.redo, size: 19),
          ),
          IconButton(
            tooltip: 'Переключить тему',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 19,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _ctrl.solve,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _buildBrand(context, ext, cs, compact: true),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                            selected: {_ctrl.circuit.isAc},
                            onSelectionChanged: (s) => _ctrl.setIsAc(s.first),
                          ),
                          const SizedBox(width: 4),
                          _buildProjectButton(ext, cs, showLabel: false),
                          const SizedBox(width: 4),
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
                height: 38,
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
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.functions, size: 16),
                    const SizedBox(width: 6),
                    const Text('Решение'),
                    if (_ctrl.solution != null) ...[
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

  Widget _buildProjectButton(
    CircuitColors ext,
    ColorScheme cs, {
    required bool showLabel,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Проекты',
      onSelected: _handleProjectAction,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'new',
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 18),
              SizedBox(width: 8),
              Text('Новый проект'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save_outlined, size: 18),
              SizedBox(width: 8),
              Text('Сохранить проект (.json)...'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open_outlined, size: 18),
              SizedBox(width: 8),
              Text('Открыть проект (.json)...'),
            ],
          ),
        ),
      ],
      child: _headerPill(ext, Icons.folder_outlined, cs.primary,
          showLabel ? 'Проект' : null),
    );
  }

  Widget _buildExportButton(
    CircuitColors ext,
    ColorScheme cs, {
    required bool showLabel,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Экспорт схемы и результатов',
      onSelected: (extType) =>
          ProjectDialogs.showExportDialog(context, _ctrl, extType),
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
      child: _headerPill(
          ext, Icons.download, cs.primary, showLabel ? 'Экспорт' : null),
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
      child: _headerPill(
          ext, Icons.auto_stories, ext.accent, showLabel ? 'Шаблоны' : null),
    );
  }

  Widget _headerPill(
      CircuitColors ext, IconData icon, Color iconColor, String? label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 10 : 7,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ext.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopWorkspace(
      BuildContext context, CircuitColors ext, ColorScheme cs) {
    final c = _ctrl.circuit;
    final refNode =
        c.nodes.firstWhere((n) => n.id == c.effectiveReferenceNodeId());
    final targetBranch =
        c.branches.firstWhere((b) => b.id == c.effectiveTargetBranchId());
    final inspected = _ctrl.inspectedBranch;
    final res = _ctrl.solution?.branchResults[inspected.id];

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CircuitCanvas(
                  circuit: c,
                  solution: _ctrl.solution,
                  activeTool: _ctrl.tool,
                  selectedBranchId: _ctrl.selectedBranchId,
                  transformationController: _canvasTransform,
                  onSelectBranch: (b) => _ctrl.selectBranch(b.id),
                  onGeometryDragStart: _ctrl.beginGeometryDrag,
                  onGeometryChanged: _ctrl.updateGeometry,
                  onCircuitChanged: _ctrl.applyCircuitChange,
                  onEditBranch: _editBranch,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _buildFloatingToolstrip(ext, cs, vertical: false),
              ),
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
                    _hintForTool(_ctrl.tool),
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
                        inspected.summary(isAc: c.isAc, omega: c.omega),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (res != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'I = ${c.isAc ? res.current.toStringPolar(digits: 2) : Complex.fmt(res.current.re, 3)} А',
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
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Повернуть элемент на 45°',
                onPressed: _ctrl.rotateSelectedBranch,
                icon: const Icon(Icons.rotate_right, size: 18),
              ),
              const SizedBox(width: 4),
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
    final c = _ctrl.circuit;
    final inspected = _ctrl.inspectedBranch;
    final res = _ctrl.solution?.branchResults[inspected.id];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ext.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ext.outline),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Метод:',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CalculationMethod>(
                          isDense: true,
                          isExpanded: true,
                          value: _ctrl.method,
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
                          onChanged: (m) {
                            if (m != null) _ctrl.setMethod(m);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (c.isAc) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _freqCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'f (Гц)',
                            errorText: _freqError,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                          ),
                          onChanged: _onFreqChanged,
                        ),
                      ),
                      if (_ctrl.method == CalculationMethod.complexMethod) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CalculationMethod>(
                              isDense: true,
                              isExpanded: true,
                              value: _ctrl.acBaseMethod,
                              items: [
                                for (final m in CalculationMethod.values.where(
                                    (x) =>
                                        x != CalculationMethod.complexMethod))
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      'База: ${m.shortTitle}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                              onChanged: (m) {
                                if (m != null) _ctrl.setAcBaseMethod(m);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
                      circuit: c,
                      solution: _ctrl.solution,
                      activeTool: _ctrl.tool,
                      selectedBranchId: _ctrl.selectedBranchId,
                      transformationController: _canvasTransform,
                      onSelectBranch: (b) => _ctrl.selectBranch(b.id),
                      onGeometryDragStart: _ctrl.beginGeometryDrag,
                      onGeometryChanged: _ctrl.updateGeometry,
                      onCircuitChanged: _ctrl.applyCircuitChange,
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
        if (_ctrl.solution != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ext.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_ctrl.solution!.isPowerBalanced
                          ? ext.success
                          : cs.error)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: _ctrl.solution!.isPowerBalanced
                              ? ext.success
                              : cs.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Баланс: ${Complex.fmt(_ctrl.solution!.totalSourcePowerP, 2)} Вт',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'P_потр: ${Complex.fmt(_ctrl.solution!.totalLoadPowerP, 2)} Вт',
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
                      'I = ${c.isAc ? res.current.toStringPolar(digits: 2) : Complex.fmt(res.current.re, 3)} А',
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Повернуть на 45°',
                    onPressed: _ctrl.rotateSelectedBranch,
                    icon: const Icon(Icons.rotate_right, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _editBranch(inspected),
                      child: const Text('Параметры...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _ctrl.solve();
                        _tabController.animateTo(1);
                      },
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
      _toolBtn(
          CanvasTool.addNode, Icons.add_circle_outline, 'Добавить узел', cs),
      _toolBtn(CanvasTool.addBranch, Icons.timeline, 'Добавить ветвь', cs),
      _toolBtn(CanvasTool.delete, Icons.delete_outline, 'Удалить', cs),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Повернуть элемент на 45°',
        onPressed: _ctrl.rotateSelectedBranch,
        icon: const Icon(Icons.rotate_right, size: 18),
      ),
      if (vertical) ...[
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Отменить',
          onPressed: _ctrl.canUndo ? _ctrl.undo : null,
          icon: const Icon(Icons.undo, size: 17),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Повторить',
          onPressed: _ctrl.canRedo ? _ctrl.redo : null,
          icon: const Icon(Icons.redo, size: 17),
        ),
      ] else ...[
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
    final selected = _ctrl.tool == tool;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: selected ? cs.primary : Colors.transparent,
        foregroundColor: selected ? cs.onPrimary : cs.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _ctrl.setTool(tool),
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

  String _hintForTool(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.selectMove:
        return 'ЛКМ — выбор/перетаскивание. ПКМ по ветви — параметры, по узлу — базовый (φ=0). Ctrl+Z/Y — отмена/повтор.';
      case CanvasTool.addNode:
        return 'Нажмите на свободное место холста, чтобы добавить новый узел.';
      case CanvasTool.addBranch:
        return 'Нажмите на начальный, затем на конечный узел для создания ветви.';
      case CanvasTool.delete:
        return 'Нажмите на узел или ветвь для удаления.';
    }
  }
}
