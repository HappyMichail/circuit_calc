import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/model/solution.dart';
import '../theme/app_theme.dart';

/// Instantaneous sinusoidal waveform oscillogram i(t) for AC circuits.
class WaveformChart extends StatelessWidget {
  final CircuitSolution solution;

  const WaveformChart({super.key, required this.solution});

  @override
  Widget build(BuildContext context) {
    final ext =
        Theme.of(context).extension<CircuitColors>() ?? CircuitColors.dark;
    final cs = Theme.of(context).colorScheme;
    final results = solution.branchResults.values.toList();
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
      const Color(0xFF2DD4BF),
    ];

    return Container(
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
                'ОСЦИЛЛОГРАММА ТОКОВ i(t)',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '1.5 периода (ωt: 0..3π)',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                results: results,
                colors: colors,
                gridColor: ext.outline,
                textColor: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (var i = 0; i < results.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 3,
                      color: colors[i % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'i${results[i].branchName}(t)',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<BranchResult> results;
  final List<Color> colors;
  final Color gridColor;
  final Color textColor;

  _WaveformPainter({
    required this.results,
    required this.colors,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final ampH = size.height * 0.42;

    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Horizontal center line & ±peak guides
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);
    canvas.drawLine(
      Offset(0, midY - ampH),
      Offset(size.width, midY - ampH),
      axisPaint..color = gridColor.withValues(alpha: 0.35),
    );
    canvas.drawLine(
      Offset(0, midY + ampH),
      Offset(size.width, midY + ampH),
      axisPaint,
    );

    // Vertical quarter-period grid lines (0, π, 2π, 3π)
    for (var k = 1; k <= 3; k++) {
      final x = size.width * (k / 3.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), axisPaint);
    }

    final maxPeak = results.fold<double>(
      1e-6,
      (m, r) => math.max(m, r.current.abs * math.sqrt2),
    );

    const samples = 120;
    const totalRad = 3 * math.pi;

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      final peak = r.current.abs * math.sqrt2;
      if (peak < 1e-9) continue;
      final phase = r.current.angleRad;

      final path = Path();
      for (var s = 0; s <= samples; s++) {
        final frac = s / samples;
        final x = frac * size.width;
        final val = peak * math.sin(frac * totalRad + phase);
        final y = midY - (val / maxPeak) * ampH;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = colors[i % colors.length]
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.results != results || oldDelegate.gridColor != gridColor;
}
