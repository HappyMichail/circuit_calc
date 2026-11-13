import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/model/solution.dart';

class PhasorDiagram extends StatelessWidget {
  final CircuitSolution solution;

  const PhasorDiagram({super.key, required this.solution});

  @override
  Widget build(BuildContext context) {
    final results = solution.branchResults.values.toList();
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.green,
      Colors.indigo,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Векторная диаграмма токов (AC)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                painter: _PhasorPainter(
                  results: results,
                  colors: colors,
                  axisColor: Theme.of(context).dividerColor,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var i = 0; i < results.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'I_${results[i].branchName}: ${results[i].current.toStringPolar(digits: 2)} А',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhasorPainter extends CustomPainter {
  final List<BranchResult> results;
  final List<Color> colors;
  final Color axisColor;
  final Color textColor;

  _PhasorPainter({
    required this.results,
    required this.colors,
    required this.axisColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.0;

    // Axes & reference circle
    canvas.drawLine(
        Offset(center.dx - radius - 10, center.dy),
        Offset(center.dx + radius + 10, center.dy),
        axisPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy - radius - 10),
        Offset(center.dx, center.dy + radius + 10),
        axisPaint);
    canvas.drawCircle(
      center,
      radius,
      axisPaint..style = PaintingStyle.stroke,
    );

    final maxMag = results.fold<double>(
      1e-6,
      (m, r) => math.max(m, r.current.abs),
    );

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      if (r.current.isZero(1e-6)) continue;

      final color = colors[i % colors.length];
      final scale = radius / maxMag;
      final tip = Offset(
        center.dx + r.current.re * scale,
        center.dy - r.current.im * scale, // +j is upwards
      );

      final p = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, tip, p);

      // Arrowhead
      final angle = math.atan2(tip.dy - center.dy, tip.dx - center.dx);
      const head = 8.0;
      canvas.drawLine(
        tip,
        tip - Offset(head * math.cos(angle - 0.45), head * math.sin(angle - 0.45)),
        p,
      );
      canvas.drawLine(
        tip,
        tip - Offset(head * math.cos(angle + 0.45), head * math.sin(angle + 0.45)),
        p,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: 'I${r.branchName}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, tip + const Offset(4, -12));
    }
  }

  @override
  bool shouldRepaint(covariant _PhasorPainter oldDelegate) => true;
}
