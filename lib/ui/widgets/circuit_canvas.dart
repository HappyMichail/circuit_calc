import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/model/circuit_node.dart';
import '../../core/model/solution.dart';

enum CanvasTool {
  selectMove,
  addNode,
  addBranch,
  delete,
}

class CircuitCanvas extends StatefulWidget {
  final Circuit circuit;
  final CircuitSolution? solution;
  final CanvasTool activeTool;
  final ValueChanged<Circuit> onCircuitChanged;
  final ValueChanged<CircuitBranch> onEditBranch;

  const CircuitCanvas({
    super.key,
    required this.circuit,
    required this.solution,
    required this.activeTool,
    required this.onCircuitChanged,
    required this.onEditBranch,
  });

  @override
  State<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends State<CircuitCanvas> {
  String? _draggingNodeId;
  String? _pendingBranchFromId;

  static const double _gridSize = 20.0;

  double _snap(double v) => (v / _gridSize).round() * _gridSize;

  CircuitNode? _hitTestNode(Offset pos) {
    for (final n in widget.circuit.nodes.reversed) {
      if ((Offset(n.x, n.y) - pos).distance <= 22) {
        return n;
      }
    }
    return null;
  }

  /// Compute curve control point for parallel branches between the same node pair.
  Offset _branchControlPoint(CircuitBranch b, List<CircuitBranch> allBranches) {
    final from = widget.circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
    final to = widget.circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
    final p1 = Offset(from.x, from.y);
    final p2 = Offset(to.x, to.y);
    final mid = (p1 + p2) / 2;

    // Group branches connecting the same unordered pair of nodes
    final siblings = allBranches.where((other) =>
        (other.fromNodeId == b.fromNodeId && other.toNodeId == b.toNodeId) ||
        (other.fromNodeId == b.toNodeId && other.toNodeId == b.fromNodeId)).toList();

    if (siblings.length <= 1) return mid;

    final idx = siblings.indexWhere((s) => s.id == b.id);
    final offsetIndex = idx - (siblings.length - 1) / 2.0;

    // Canonical direction so opposite-directed parallel branches spread apart
    final canonical = b.fromNodeId.compareTo(b.toNodeId) <= 0
        ? (p2 - p1)
        : (p1 - p2);
    final len = canonical.distance;
    if (len < 1e-3) return mid;
    final perp = Offset(-canonical.dy / len, canonical.dx / len);
    return mid + perp * (offsetIndex * 70.0);
  }

  CircuitBranch? _hitTestBranch(Offset pos) {
    for (final b in widget.circuit.branches) {
      final from =
          widget.circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
      final to = widget.circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
      final p0 = Offset(from.x, from.y);
      final p2 = Offset(to.x, to.y);
      final ctrl = _branchControlPoint(b, widget.circuit.branches);

      // Sample quadratic Bezier
      for (var t = 0.1; t <= 0.9; t += 0.05) {
        final mt = 1 - t;
        final pt = p0 * (mt * mt) + ctrl * (2 * mt * t) + p2 * (t * t);
        if ((pt - pos).distance <= 18) {
          return b;
        }
      }
    }
    return null;
  }

  void _handleTapDown(TapDownDetails details) {
    final pos = details.localPosition;
    final hitNode = _hitTestNode(pos);
    final hitBranch = hitNode == null ? _hitTestBranch(pos) : null;

    switch (widget.activeTool) {
      case CanvasTool.selectMove:
        if (hitBranch != null) {
          widget.onEditBranch(hitBranch);
        } else if (hitNode != null) {
          // Set as reference node on tap
          widget.onCircuitChanged(
            widget.circuit.copyWith(referenceNodeId: hitNode.id),
          );
        }
      case CanvasTool.addNode:
        if (hitNode == null) {
          final nextNum = widget.circuit.nodes.length;
          final newNode = CircuitNode(
            id: 'n_${DateTime.now().microsecondsSinceEpoch}',
            label: '$nextNum',
            x: _snap(pos.dx),
            y: _snap(pos.dy),
          );
          widget.onCircuitChanged(
            widget.circuit.copyWith(nodes: [...widget.circuit.nodes, newNode]),
          );
        }
      case CanvasTool.addBranch:
        if (hitNode != null) {
          if (_pendingBranchFromId == null) {
            setState(() => _pendingBranchFromId = hitNode.id);
          } else if (_pendingBranchFromId != hitNode.id) {
            final nextNum = widget.circuit.branches.length + 1;
            final newBranch = CircuitBranch(
              id: 'b_${DateTime.now().microsecondsSinceEpoch}',
              name: '$nextNum',
              fromNodeId: _pendingBranchFromId!,
              toNodeId: hitNode.id,
              rOhm: 10,
            );
            setState(() => _pendingBranchFromId = null);
            widget.onCircuitChanged(
              widget.circuit
                  .copyWith(branches: [...widget.circuit.branches, newBranch]),
            );
            widget.onEditBranch(newBranch);
          } else {
            setState(() => _pendingBranchFromId = null);
          }
        } else {
          setState(() => _pendingBranchFromId = null);
        }
      case CanvasTool.delete:
        if (hitNode != null && widget.circuit.nodes.length > 2) {
          final remainingNodes =
              widget.circuit.nodes.where((n) => n.id != hitNode.id).toList();
          final remainingBranches = widget.circuit.branches
              .where((b) =>
                  b.fromNodeId != hitNode.id && b.toNodeId != hitNode.id)
              .toList();
          widget.onCircuitChanged(
            widget.circuit.copyWith(
              nodes: remainingNodes,
              branches: remainingBranches,
            ),
          );
        } else if (hitBranch != null && widget.circuit.branches.length > 1) {
          final remainingBranches = widget.circuit.branches
              .where((b) => b.id != hitBranch.id)
              .toList();
          widget.onCircuitChanged(
            widget.circuit.copyWith(branches: remainingBranches),
          );
        }
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (widget.activeTool != CanvasTool.selectMove) return;
    final hit = _hitTestNode(details.localPosition);
    if (hit != null) {
      _draggingNodeId = hit.id;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggingNodeId == null) return;
    final pos = details.localPosition;
    final updatedNodes = widget.circuit.nodes.map((n) {
      if (n.id != _draggingNodeId) return n;
      return n.copyWith(
        x: _snap(pos.dx.clamp(40, 1200)),
        y: _snap(pos.dy.clamp(40, 900)),
      );
    }).toList();
    widget.onCircuitChanged(widget.circuit.copyWith(nodes: updatedNodes));
  }

  void _handlePanEnd(DragEndDetails details) {
    _draggingNodeId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 2.5,
        constrained: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: CustomPaint(
            size: const Size(800, 560),
            painter: _SchematicPainter(
              circuit: widget.circuit,
              solution: widget.solution,
              pendingBranchFromId: _pendingBranchFromId,
              colorScheme: Theme.of(context).colorScheme,
              controlPointBuilder: (b) =>
                  _branchControlPoint(b, widget.circuit.branches),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  final Circuit circuit;
  final CircuitSolution? solution;
  final String? pendingBranchFromId;
  final ColorScheme colorScheme;
  final Offset Function(CircuitBranch) controlPointBuilder;

  _SchematicPainter({
    required this.circuit,
    required this.solution,
    required this.pendingBranchFromId,
    required this.colorScheme,
    required this.controlPointBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    final refId = circuit.effectiveReferenceNodeId();
    final targetId = circuit.effectiveTargetBranchId();

    // Draw branches
    for (final b in circuit.branches) {
      final fromNode = circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
      final toNode = circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
      final p0 = Offset(fromNode.x, fromNode.y);
      final p2 = Offset(toNode.x, toNode.y);
      final ctrl = controlPointBuilder(b);
      final isTarget = b.id == targetId;

      final wirePaint = Paint()
        ..color = isTarget
            ? colorScheme.tertiary
            : colorScheme.onSurface.withValues(alpha: 0.85)
        ..strokeWidth = isTarget ? 2.8 : 2.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
      canvas.drawPath(path, wirePaint);

      // Midpoint on Bezier (t = 0.5)
      final mid = p0 * 0.25 + ctrl * 0.5 + p2 * 0.25;
      final tangent = (p2 - p0);
      final angle = math.atan2(tangent.dy, tangent.dx);

      _drawBranchSymbol(canvas, mid, angle, b, isTarget);
      _drawBranchLabels(canvas, mid, b, isTarget);
    }

    // Draw nodes
    for (final n in circuit.nodes) {
      final pos = Offset(n.x, n.y);
      final isRef = n.id == refId;
      final isPending = n.id == pendingBranchFromId;

      if (isPending) {
        canvas.drawCircle(
          pos,
          14,
          Paint()
            ..color = colorScheme.primary.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawCircle(
        pos,
        7,
        Paint()
          ..color = isRef ? colorScheme.secondary : colorScheme.primary
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        7,
        Paint()
          ..color = colorScheme.surface
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Ground symbol for reference node
      if (isRef) {
        final gp = Paint()
          ..color = colorScheme.secondary
          ..strokeWidth = 2;
        canvas.drawLine(pos + const Offset(0, 7), pos + const Offset(0, 17), gp);
        canvas.drawLine(
            pos + const Offset(-10, 17), pos + const Offset(10, 17), gp);
        canvas.drawLine(
            pos + const Offset(-6, 21), pos + const Offset(6, 21), gp);
        canvas.drawLine(
            pos + const Offset(-2, 25), pos + const Offset(2, 25), gp);
      }

      // Node label + potential
      final pot = solution?.nodePotentials[n.id];
      final labelText = pot != null
          ? '${n.label} (φ=${pot.toStringRect(digits: 1)} В)'
          : 'Узел ${n.label}';
      _drawText(
        canvas,
        labelText,
        pos + const Offset(10, -20),
        color: colorScheme.onSurface,
        fontSize: 12,
        bold: true,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 0.7;
    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawBranchSymbol(
    Canvas canvas,
    Offset center,
    double angle,
    CircuitBranch b,
    bool isTarget,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final fillPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = isTarget ? colorScheme.tertiary : colorScheme.onSurface
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (b.hasCurrentSource) {
      // Double circle for current source J
      canvas.drawCircle(Offset.zero, 14, fillPaint);
      canvas.drawCircle(Offset.zero, 14, strokePaint);
      canvas.drawCircle(Offset.zero, 10, strokePaint);
      final dir = b.jAlignedWithBranch ? 1.0 : -1.0;
      _drawArrowHead(canvas, Offset(6 * dir, 0), dir > 0 ? 0 : math.pi,
          strokePaint.color);
    } else if (b.hasEmf) {
      // Circle with arrow for EMF E
      canvas.drawCircle(Offset.zero, 14, fillPaint);
      canvas.drawCircle(Offset.zero, 14, strokePaint);
      final dir = b.eAlignedWithBranch ? 1.0 : -1.0;
      canvas.drawLine(const Offset(-9, 0), const Offset(9, 0), strokePaint);
      _drawArrowHead(canvas, Offset(9 * dir, 0), dir > 0 ? 0 : math.pi,
          strokePaint.color);
    } else {
      // Resistor / Impedance rectangle
      final rect = Rect.fromCenter(center: Offset.zero, width: 32, height: 14);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }

    canvas.restore();
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const len = 6.0;
    canvas.drawLine(
      tip,
      tip + Offset(-len * math.cos(angle - 0.5), -len * math.sin(angle - 0.5)),
      p,
    );
    canvas.drawLine(
      tip,
      tip + Offset(-len * math.cos(angle + 0.5), -len * math.sin(angle + 0.5)),
      p,
    );
  }

  void _drawBranchLabels(
    Canvas canvas,
    Offset mid,
    CircuitBranch b,
    bool isTarget,
  ) {
    final summary = b.summary(isAc: circuit.isAc, omega: circuit.omega);
    _drawText(
      canvas,
      '${b.name}: $summary',
      mid + const Offset(-45, 16),
      color: isTarget ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
      fontSize: 11,
      bold: isTarget,
    );

    final res = solution?.branchResults[b.id];
    if (res != null) {
      final iStr = circuit.isAc
          ? 'I=${res.current.toStringPolar(digits: 2)} А'
          : 'I=${Complex.fmt(res.current.re, 2)} А';
      _drawText(
        canvas,
        iStr,
        mid + const Offset(-35, -30),
        color: colorScheme.primary,
        fontSize: 11,
        bold: true,
        bgColor: colorScheme.primaryContainer.withValues(alpha: 0.85),
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    double fontSize = 12,
    bool bold = false,
    Color? bgColor,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (bgColor != null) {
      final rect = Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        tp.width + 8,
        tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = bgColor,
      );
    }
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SchematicPainter oldDelegate) => true;
}
