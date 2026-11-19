import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/math/complex.dart';
import '../../core/model/circuit.dart';
import '../../core/model/circuit_branch.dart';
import '../../core/model/circuit_node.dart';
import '../../core/model/solution.dart';
import '../theme/app_theme.dart';

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
  final ValueChanged<Circuit>? onGeometryChanged;
  final ValueChanged<CircuitBranch> onEditBranch;
  final ValueChanged<CircuitBranch>? onSelectBranch;
  final String? selectedBranchId;
  final TransformationController? transformationController;

  const CircuitCanvas({
    super.key,
    required this.circuit,
    required this.solution,
    required this.activeTool,
    required this.onCircuitChanged,
    this.onGeometryChanged,
    required this.onEditBranch,
    this.onSelectBranch,
    this.selectedBranchId,
    this.transformationController,
  });

  @override
  State<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends State<CircuitCanvas> {
  String? _draggingNodeId;
  String? _draggingBranchId;
  String? _pendingBranchFromId;
  bool _isDraggingItem = false;

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

  Offset _branchControlPoint(CircuitBranch b, List<CircuitBranch> allBranches) {
    if (b.controlX != null && b.controlY != null) {
      return Offset(b.controlX!, b.controlY!);
    }
    final from = widget.circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
    final to = widget.circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
    final p1 = Offset(from.x, from.y);
    final p2 = Offset(to.x, to.y);
    final mid = (p1 + p2) / 2;

    final siblings = allBranches
        .where((other) =>
            (other.fromNodeId == b.fromNodeId && other.toNodeId == b.toNodeId) ||
            (other.fromNodeId == b.toNodeId && other.toNodeId == b.fromNodeId))
        .toList();

    if (siblings.length <= 1) return mid;

    final idx = siblings.indexWhere((s) => s.id == b.id);
    final offsetIndex = idx - (siblings.length - 1) / 2.0;

    final canonical =
        b.fromNodeId.compareTo(b.toNodeId) <= 0 ? (p2 - p1) : (p1 - p2);
    final len = canonical.distance;
    if (len < 1e-3) return mid;
    final perp = Offset(-canonical.dy / len, canonical.dx / len);
    return mid + perp * (offsetIndex * 76.0);
  }

  CircuitBranch? _hitTestBranch(Offset pos) {
    for (final b in widget.circuit.branches) {
      final from =
          widget.circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
      final to = widget.circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
      final p0 = Offset(from.x, from.y);
      final p2 = Offset(to.x, to.y);
      final ctrl = _branchControlPoint(b, widget.circuit.branches);

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

  void _handleSecondaryTapDown(TapDownDetails details) {
    final pos = details.localPosition;
    final hitBranch = _hitTestBranch(pos);
    if (hitBranch != null) {
      widget.onSelectBranch?.call(hitBranch);
      widget.onEditBranch(hitBranch);
      return;
    }
    final hitNode = _hitTestNode(pos);
    if (hitNode != null) {
      widget.onCircuitChanged(
        widget.circuit.copyWith(referenceNodeId: hitNode.id),
      );
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final pos = details.localPosition;
    final hitNode = _hitTestNode(pos);
    final hitBranch = hitNode == null ? _hitTestBranch(pos) : null;

    switch (widget.activeTool) {
      case CanvasTool.selectMove:
        if (hitBranch != null) {
          widget.onSelectBranch?.call(hitBranch);
        } else if (hitNode != null) {
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
              clearReferenceNode: widget.circuit.referenceNodeId == hitNode.id,
            ),
          );
        } else if (hitBranch != null && widget.circuit.branches.length > 1) {
          final remainingBranches = widget.circuit.branches
              .where((b) => b.id != hitBranch.id)
              .toList();
          widget.onCircuitChanged(
            widget.circuit.copyWith(
              branches: remainingBranches,
              clearTargetBranch: widget.circuit.targetBranchId == hitBranch.id,
            ),
          );
        }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.activeTool != CanvasTool.selectMove) return;
    final pos = event.localPosition;
    final hitNode = _hitTestNode(pos);
    if (hitNode != null) {
      setState(() {
        _draggingNodeId = hitNode.id;
        _isDraggingItem = true;
      });
      return;
    }
    final hitBranch = _hitTestBranch(pos);
    if (hitBranch != null) {
      widget.onSelectBranch?.call(hitBranch);
      setState(() {
        _draggingBranchId = hitBranch.id;
        _isDraggingItem = true;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDraggingItem) return;
    final pos = event.localPosition;
    if (_draggingNodeId != null) {
      final updatedNodes = widget.circuit.nodes.map((n) {
        if (n.id != _draggingNodeId) return n;
        return n.copyWith(
          x: _snap(pos.dx.clamp(40, 1200)),
          y: _snap(pos.dy.clamp(40, 900)),
        );
      }).toList();
      final updated = widget.circuit.copyWith(nodes: updatedNodes);
      if (widget.onGeometryChanged != null) {
        widget.onGeometryChanged!(updated);
      } else {
        widget.onCircuitChanged(updated);
      }
      return;
    }

    if (_draggingBranchId != null) {
      final snappedMid = Offset(
        _snap(pos.dx.clamp(40, 1200)),
        _snap(pos.dy.clamp(40, 900)),
      );
      final updatedBranches = widget.circuit.branches.map((b) {
        if (b.id != _draggingBranchId) return b;
        final from =
            widget.circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
        final to = widget.circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
        final p0 = Offset(from.x, from.y);
        final p2 = Offset(to.x, to.y);
        final ctrl = snappedMid * 2.0 - (p0 + p2) * 0.5;
        return b.copyWith(controlX: ctrl.dx, controlY: ctrl.dy);
      }).toList();
      final updated = widget.circuit.copyWith(branches: updatedBranches);
      if (widget.onGeometryChanged != null) {
        widget.onGeometryChanged!(updated);
      } else {
        widget.onCircuitChanged(updated);
      }
    }
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    if (_isDraggingItem) {
      setState(() {
        _draggingNodeId = null;
        _draggingBranchId = null;
        _isDraggingItem = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CircuitColors>() ??
        CircuitColors.dark;

    return Container(
      color: ext.canvasBg,
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        panEnabled: !_isDraggingItem,
        minScale: 0.5,
        maxScale: 2.5,
        constrained: false,
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUpOrCancel,
          onPointerCancel: _handlePointerUpOrCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onSecondaryTapDown: _handleSecondaryTapDown,
            child: CustomPaint(
              size: const Size(820, 560),
              painter: _SchematicPainter(
                circuit: widget.circuit,
                solution: widget.solution,
                pendingBranchFromId: _pendingBranchFromId,
                selectedBranchId: widget.selectedBranchId,
                colorScheme: Theme.of(context).colorScheme,
                ext: ext,
                controlPointBuilder: (b) =>
                    _branchControlPoint(b, widget.circuit.branches),
              ),
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
  final String? selectedBranchId;
  final ColorScheme colorScheme;
  final CircuitColors ext;
  final Offset Function(CircuitBranch) controlPointBuilder;

  _SchematicPainter({
    required this.circuit,
    required this.solution,
    required this.pendingBranchFromId,
    required this.selectedBranchId,
    required this.colorScheme,
    required this.ext,
    required this.controlPointBuilder,
  });

  Offset _bezierAt(Offset p0, Offset ctrl, Offset p2, double t) {
    final mt = 1 - t;
    return p0 * (mt * mt) + ctrl * (2 * mt * t) + p2 * (t * t);
  }

  double _tangentAngleAt(Offset p0, Offset ctrl, Offset p2, double t) {
    final d = (ctrl - p0) * (2 * (1 - t)) + (p2 - ctrl) * (2 * t);
    return math.atan2(d.dy, d.dx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawDotGrid(canvas, size);

    final refId = circuit.effectiveReferenceNodeId();
    final targetId = circuit.effectiveTargetBranchId();

    for (final b in circuit.branches) {
      final fromNode = circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
      final toNode = circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
      final p0 = Offset(fromNode.x, fromNode.y);
      final p2 = Offset(toNode.x, toNode.y);
      final ctrl = controlPointBuilder(b);
      final isTarget = b.id == targetId;
      final isSelected = b.id == selectedBranchId;

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);

      if (isTarget || isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = ext.accent.withValues(alpha: 0.28)
            ..strokeWidth = 6.5
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );

      // Draw sequential symbols along the branch
      final hasPassive =
          !b.hasCurrentSource && !circuit.impedanceOf(b).isZero();
      if (b.hasCurrentSource) {
        final pt = _bezierAt(p0, ctrl, p2, 0.5);
        final ang = _tangentAngleAt(p0, ctrl, p2, 0.5);
        _drawCurrentSourceSymbol(canvas, pt, ang, b.jAlignedWithBranch);
      } else if (b.hasEmf && hasPassive) {
        final ptEmf = _bezierAt(p0, ctrl, p2, 0.36);
        final angEmf = _tangentAngleAt(p0, ctrl, p2, 0.36);
        _drawEmfSymbol(canvas, ptEmf, angEmf, b.eAlignedWithBranch);

        final ptZ = _bezierAt(p0, ctrl, p2, 0.64);
        final angZ = _tangentAngleAt(p0, ctrl, p2, 0.64);
        _drawImpedanceSymbol(canvas, ptZ, angZ, isTarget);
      } else if (b.hasEmf) {
        final pt = _bezierAt(p0, ctrl, p2, 0.5);
        final ang = _tangentAngleAt(p0, ctrl, p2, 0.5);
        _drawEmfSymbol(canvas, pt, ang, b.eAlignedWithBranch);
      } else {
        final pt = _bezierAt(p0, ctrl, p2, 0.5);
        final ang = _tangentAngleAt(p0, ctrl, p2, 0.5);
        _drawImpedanceSymbol(canvas, pt, ang, isTarget);
      }

      // Draw branch current arrow at t = 0.22 if solved
      final res = solution?.branchResults[b.id];
      if (res != null && !res.current.isZero(1e-6)) {
        final arrowPt = _bezierAt(p0, ctrl, p2, 0.2);
        var arrowAng = _tangentAngleAt(p0, ctrl, p2, 0.2);
        if (!circuit.isAc && res.current.re < 0) {
          arrowAng += math.pi;
        }
        _drawFilledArrow(canvas, arrowPt, arrowAng, colorScheme.primary);
      }

      final mid = _bezierAt(p0, ctrl, p2, 0.5);
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
          17,
          Paint()
            ..color = colorScheme.primary.withValues(alpha: 0.28)
            ..style = PaintingStyle.fill,
        );
      }

      final nodeFill =
          isRef ? const Color(0xFF78350F) : const Color(0xFF1E40AF);
      final nodeStroke = isRef ? ext.accent : colorScheme.primary;

      canvas.drawCircle(
        pos,
        10.5,
        Paint()
          ..color = nodeFill
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        10.5,
        Paint()
          ..color = nodeStroke
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );

      // Node label inside circle
      final numTp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numTp.paint(
        canvas,
        pos - Offset(numTp.width / 2, numTp.height / 2),
      );

      // Ground symbol for reference node
      if (isRef) {
        final gp = Paint()
          ..color = ext.accent
          ..strokeWidth = 2.0;
        canvas.drawLine(
            pos + const Offset(0, 11), pos + const Offset(0, 22), gp);
        canvas.drawLine(
            pos + const Offset(-11, 22), pos + const Offset(11, 22), gp);
        canvas.drawLine(
            pos + const Offset(-7, 26), pos + const Offset(7, 26), gp);
        canvas.drawLine(
            pos + const Offset(-3, 30), pos + const Offset(3, 30), gp);
      }

      // Potential pill
      final pot = solution?.nodePotentials[n.id];
      final labelText = pot != null
          ? (isRef
              ? 'φ${n.label} = 0 В (База)'
              : 'φ${n.label} = ${pot.toStringRect(digits: 1)} В')
          : 'Узел ${n.label}';
      final pillOffset = isRef ? const Offset(-46, 35) : const Offset(-38, -34);
      _drawTextPill(
        canvas,
        labelText,
        pos + pillOffset,
        textColor: isRef ? ext.accent : colorScheme.primary,
        bgColor: ext.surfaceContainer,
        borderColor: isRef ? ext.accent : ext.outline,
        fontSize: 11,
      );
    }
  }

  void _drawDotGrid(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = ext.canvasGrid;
    const step = 24.0;
    for (double x = 12; x < size.width; x += step) {
      for (double y = 12; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }
  }

  void _drawImpedanceSymbol(
      Canvas canvas, Offset center, double angle, bool isTarget) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: 38, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = ext.surfaceContainer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = isTarget ? ext.accent : colorScheme.primary
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  void _drawEmfSymbol(
      Canvas canvas, Offset center, double angle, bool aligned) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()..color = ext.surfaceContainer,
    );
    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..color = ext.accent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
    final dir = aligned ? 1.0 : -1.0;
    canvas.drawLine(
      const Offset(-10, 0),
      const Offset(10, 0),
      Paint()
        ..color = ext.accent
        ..strokeWidth = 2.0,
    );
    _drawFilledArrow(
      canvas,
      Offset(10 * dir, 0),
      dir > 0 ? 0 : math.pi,
      ext.accent,
      size: 6,
    );
    canvas.restore();
  }

  void _drawCurrentSourceSymbol(
      Canvas canvas, Offset center, double angle, bool aligned) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, 15, Paint()..color = ext.surfaceContainer);
    final stroke = Paint()
      ..color = ext.accent
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 15, stroke);
    canvas.drawCircle(Offset.zero, 11, stroke);
    final dir = aligned ? 1.0 : -1.0;
    _drawFilledArrow(
      canvas,
      Offset(7 * dir, 0),
      dir > 0 ? 0 : math.pi,
      ext.accent,
      size: 6,
    );
    canvas.restore();
  }

  void _drawFilledArrow(Canvas canvas, Offset tip, double angle, Color color,
      {double size = 8}) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(size * 0.5, 0)
      ..lineTo(-size * 0.7, -size * 0.5)
      ..lineTo(-size * 0.7, size * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _drawBranchLabels(
    Canvas canvas,
    Offset mid,
    CircuitBranch b,
    bool isTarget,
  ) {
    final summary = b.summary(isAc: circuit.isAc, omega: circuit.omega);
    final tp = TextPainter(
      text: TextSpan(
        text: '${b.name}: $summary',
        style: TextStyle(
          color: isTarget ? ext.accent : colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: isTarget ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, mid + Offset(-tp.width / 2, 18));

    final res = solution?.branchResults[b.id];
    if (res != null) {
      final star = isTarget ? ' ★' : '';
      final iStr = circuit.isAc
          ? 'I${b.name}=${res.current.toStringPolar(digits: 2)} А$star'
          : 'I${b.name}=${Complex.fmt(res.current.re, 2)} А$star';
      _drawTextPill(
        canvas,
        iStr,
        mid + const Offset(-40, -34),
        textColor: isTarget ? ext.accent : colorScheme.primary,
        bgColor: ext.surfaceContainer.withValues(alpha: 0.92),
        borderColor: isTarget ? ext.accent : ext.outline,
        fontSize: 11,
      );
    }
  }

  void _drawTextPill(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
    double fontSize = 11,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromLTWH(
      offset.dx - 6,
      offset.dy - 3,
      tp.width + 12,
      tp.height + 6,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SchematicPainter oldDelegate) =>
      oldDelegate.circuit != circuit ||
      oldDelegate.solution != solution ||
      oldDelegate.pendingBranchFromId != pendingBranchFromId ||
      oldDelegate.selectedBranchId != selectedBranchId ||
      oldDelegate.colorScheme != colorScheme;
}
