import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/solution.dart';
import '../theme/app_theme.dart';
import 'phasor_diagram.dart';
import 'waveform_chart.dart';

enum _InspectorTab { summary, latex }

class SolutionPanel extends StatefulWidget {
  final Circuit circuit;
  final CircuitSolution? solution;
  final String? errorMessage;
  final Duration? solveDuration;

  const SolutionPanel({
    super.key,
    required this.circuit,
    required this.solution,
    this.errorMessage,
    this.solveDuration,
  });

  @override
  State<SolutionPanel> createState() => _SolutionPanelState();
}

class _SolutionPanelState extends State<SolutionPanel> {
  bool _showDetailed = false;
  _InspectorTab _tab = _InspectorTab.summary;

  @override
  Widget build(BuildContext context) {
    final ext =
        Theme.of(context).extension<CircuitColors>() ?? CircuitColors.dark;
    final cs = Theme.of(context).colorScheme;

    if (widget.errorMessage != null) {
      return Center(
        child: Card(
          color: cs.errorContainer,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 36, color: cs.onErrorContainer),
                const SizedBox(height: 8),
                Text(
                  'Ошибка расчёта',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.onErrorContainer),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sol = widget.solution;
    if (sol == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Нажмите «Рассчитать», чтобы получить токи, напряжения и пошаговое решение.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final refId = widget.circuit.effectiveReferenceNodeId();
    final targetId = widget.circuit.effectiveTargetBranchId();
    final denom =
        sol.totalSourcePowerP.abs() < 1e-9 ? 1.0 : sol.totalSourcePowerP.abs();
    final deltaPct =
        ((sol.totalSourcePowerP - sol.totalLoadPowerP).abs() / denom) * 100.0;

    return Container(
      color: ext.surfaceContainer,
      child: Column(
        children: [
          // Panel Header & View Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: ext.outline)),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Результаты расчёта',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SegmentedButton<_InspectorTab>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _InspectorTab.summary,
                      label: Text('Сводка'),
                    ),
                    ButtonSegment(
                      value: _InspectorTab.latex,
                      label: Text('LaTeX'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ],
            ),
          ),

          Expanded(
            child: _tab == _InspectorTab.latex
                ? _buildLatexList(context, sol, ext, cs)
                : _buildSummaryList(
                    context,
                    sol,
                    ext,
                    cs,
                    refId,
                    targetId,
                    deltaPct,
                  ),
          ),

          // Footer Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: ext.outline)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Метод: ${sol.method.shortTitle}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.solveDuration != null
                      ? 'Время решения: ${(widget.solveDuration!.inMicroseconds / 1000.0).toStringAsFixed(1)} мс'
                      : 'Решатель: Gauss',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: ext.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList(
    BuildContext context,
    CircuitSolution sol,
    CircuitColors ext,
    ColorScheme cs,
    String refId,
    String targetId,
    double deltaPct,
  ) {
    final statusColor = sol.isPowerBalanced ? ext.success : cs.error;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Power Balance Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    sol.isPowerBalanced
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sol.isPowerBalanced
                          ? 'Баланс мощностей сошёлся'
                          : 'Расхождение баланса мощностей',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Δ = ${deltaPct.toStringAsFixed(3)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _powerTile(
                      'Σ P_источников',
                      '${Complex.fmt(sol.totalSourcePowerP, 3)} Вт',
                      ext,
                      cs,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _powerTile(
                      'Σ P_потребителей',
                      '${Complex.fmt(sol.totalLoadPowerP, 3)} Вт',
                      ext,
                      cs,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        for (final w in sol.warnings) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ext.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ext.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: ext.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(w, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Branch Results Table
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ext.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ext.surfaceContainerHigh,
                  border: Border(bottom: BorderSide(color: ext.outline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'ТОКИ И НАПРЯЖЕНИЯ В ВЕТВЯХ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.circuit.branches.length} ветвей • ${widget.circuit.nodes.length} узлов',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 34,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 48,
                  columns: [
                    const DataColumn(label: Text('Ветвь')),
                    const DataColumn(label: Text('Ток I, А')),
                    const DataColumn(label: Text('Напр. U, В')),
                    const DataColumn(label: Text('P, Вт')),
                    if (sol.isAc) const DataColumn(label: Text('Q, вар')),
                  ],
                  rows: [
                    for (final r in sol.branchResults.values)
                      DataRow(
                        color: r.branchId == targetId
                            ? WidgetStatePropertyAll(
                                ext.accent.withValues(alpha: 0.08))
                            : null,
                        cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: r.branchId == targetId
                                      ? ext.accent
                                      : cs.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${r.branchName}${r.branchId == targetId ? ' ★' : ''}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: r.branchId == targetId
                                      ? ext.accent
                                      : cs.primary,
                                ),
                              ),
                            ],
                          )),
                          DataCell(Text(
                            sol.isAc
                                ? r.current.toStringPolar(digits: 2)
                                : Complex.fmt(r.current.re, 3),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                          DataCell(Text(
                            sol.isAc
                                ? r.voltage.toStringPolar(digits: 2)
                                : Complex.fmt(r.voltage.re, 3),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: cs.onSurfaceVariant,
                            ),
                          )),
                          DataCell(Text(
                            Complex.fmt(r.powerActive, 2),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: ext.success,
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                          if (sol.isAc)
                            DataCell(Text(
                              Complex.fmt(r.powerReactive, 2),
                              style: const TextStyle(fontFamily: 'monospace'),
                            )),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Node Potentials Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ext.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'УЗЛОВЫЕ ПОТЕНЦИАЛЫ',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Базовый: узел ${widget.circuit.nodes.firstWhere((n) => n.id == refId).label}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: ext.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in widget.circuit.nodes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: ext.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: n.id == refId
                              ? ext.accent.withValues(alpha: 0.5)
                              : ext.outline,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            n.id == refId
                                ? 'Узел ${n.label} (База)'
                                : 'Узел ${n.label}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: n.id == refId
                                  ? ext.accent
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'φ${n.label} = ${sol.isAc ? sol.nodePotentials[n.id]!.toStringPolar(digits: 2) : Complex.fmt(sol.nodePotentials[n.id]!.re, 2)} В',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: n.id == refId ? ext.accent : cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (sol.isAc) ...[
          const SizedBox(height: 12),
          PhasorDiagram(solution: sol),
          const SizedBox(height: 12),
          WaveformChart(solution: sol),
        ],

        const SizedBox(height: 12),

        // Hybrid toggle button
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _showDetailed = !_showDetailed),
          icon: Icon(_showDetailed ? Icons.expand_less : Icons.menu_book),
          label: Text(
            _showDetailed
                ? 'Скрыть подробное решение'
                : 'Показать подробное решение',
          ),
        ),

        if (_showDetailed) ...[
          const SizedBox(height: 12),
          ...sol.steps.map((step) => _stepCard(context, step, ext, cs)),
        ],
      ],
    );
  }

  Widget _buildLatexList(
    BuildContext context,
    CircuitSolution sol,
    CircuitColors ext,
    ColorScheme cs,
  ) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final step in sol.steps) _stepCard(context, step, ext, cs),
      ],
    );
  }

  Widget _powerTile(
      String label, String value, CircuitColors ext, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ext.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ext.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(
    BuildContext context,
    SolutionStep step,
    CircuitColors ext,
    ColorScheme cs,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
          ),
          if (step.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              step.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
          if (step.latexEquations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ext.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ext.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final eq in step.latexEquations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Math.tex(
                          eq,
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                          onErrorFallback: (err) => SelectableText(
                            eq,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
