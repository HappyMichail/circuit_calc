import 'package:material_ui/material_ui.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/solution.dart';
import 'phasor_diagram.dart';

class SolutionPanel extends StatefulWidget {
  final Circuit circuit;
  final CircuitSolution? solution;
  final String? errorMessage;

  const SolutionPanel({
    super.key,
    required this.circuit,
    required this.solution,
    this.errorMessage,
  });

  @override
  State<SolutionPanel> createState() => _SolutionPanelState();
}

class _SolutionPanelState extends State<SolutionPanel> {
  bool _showDetailed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.errorMessage != null) {
      return Center(
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 36,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(height: 8),
                Text(
                  'Ошибка расчёта',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer),
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Method & Power balance banner
        Card(
          color: sol.isPowerBalanced
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sol.method.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      sol.isPowerBalanced
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Баланс мощностей: P_ист = ${Complex.fmt(sol.totalSourcePowerP, 2)} Вт, '
                        'P_потр = ${Complex.fmt(sol.totalLoadPowerP, 2)} Вт',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Warnings (e.g. irreducible circuit hint)
        for (final w in sol.warnings)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w)),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Compact summary table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итоговые значения по ветвям',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 52,
                    columns: [
                      const DataColumn(label: Text('Ветвь')),
                      const DataColumn(label: Text('Ток I, А')),
                      const DataColumn(label: Text('Напр. U, В')),
                      const DataColumn(label: Text('P, Вт')),
                      if (sol.isAc) const DataColumn(label: Text('Q, вар')),
                    ],
                    rows: [
                      for (final r in sol.branchResults.values)
                        DataRow(cells: [
                          DataCell(Text(r.branchName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(
                            sol.isAc
                                ? '${r.current.toStringPolar(digits: 2)}\n(${r.current.toStringRect(digits: 2)})'
                                : Complex.fmt(r.current.re, 3),
                          )),
                          DataCell(Text(
                            sol.isAc
                                ? r.voltage.toStringPolar(digits: 2)
                                : Complex.fmt(r.voltage.re, 3),
                          )),
                          DataCell(Text(Complex.fmt(r.powerActive, 2))),
                          if (sol.isAc)
                            DataCell(Text(Complex.fmt(r.powerReactive, 2))),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Node potentials
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Потенциалы узлов',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final n in widget.circuit.nodes)
                      Chip(
                        label: Text(
                          'φ_${n.label} = ${sol.isAc ? sol.nodePotentials[n.id]!.toStringPolar(digits: 2) : Complex.fmt(sol.nodePotentials[n.id]!.re, 3)} В',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (sol.isAc) ...[
          const SizedBox(height: 8),
          PhasorDiagram(solution: sol),
        ],

        const SizedBox(height: 12),

        // Hybrid toggle button
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _showDetailed = !_showDetailed),
          icon: Icon(_showDetailed ? Icons.expand_less : Icons.school_outlined),
          label: Text(
            _showDetailed
                ? 'Скрыть подробное решение'
                : 'Показать подробное решение',
          ),
        ),

        if (_showDetailed) ...[
          const SizedBox(height: 12),
          for (final step in sol.steps)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    if (step.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(step.description),
                    ],
                    if (step.latexEquations.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
