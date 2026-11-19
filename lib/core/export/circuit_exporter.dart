import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../math/complex.dart';
import '../model/circuit.dart';
import '../model/circuit_branch.dart';
import '../model/solution.dart';

class _SvgBox {
  final double x;
  final double y;
  final double w;
  final double h;
  const _SvgBox(this.x, this.y, this.w, this.h);

  double overlapArea(_SvgBox o) {
    final ix = math.max(0.0, math.min(x + w, o.x + o.w) - math.max(x, o.x));
    final iy = math.max(0.0, math.min(y + h, o.y + o.h) - math.max(y, o.y));
    return ix * iy;
  }
}

class _SvgLabelPlacer {
  final List<_SvgBox> _occupied = [];

  void reserve(double cx, double cy, double w, double h) =>
      _occupied.add(_SvgBox(cx - w / 2, cy - h / 2, w, h));

  (double cx, double cy) place(
    double w,
    double h,
    List<(double cx, double cy)> candidates,
  ) {
    var best = candidates.first;
    var bestCost = double.infinity;
    const pad = 4.0;

    for (final c in candidates) {
      final box =
          _SvgBox(c.$1 - w / 2 - pad, c.$2 - h / 2 - pad, w + pad * 2, h + pad * 2);
      var cost = 0.0;
      for (final occ in _occupied) {
        cost += box.overlapArea(occ);
      }
      if (cost == 0.0) {
        _occupied.add(box);
        return c;
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = c;
      }
    }
    _occupied.add(_SvgBox(
        best.$1 - w / 2 - pad, best.$2 - h / 2 - pad, w + pad * 2, h + pad * 2));
    return best;
  }
}

class CircuitExporter {
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const Map<String, String> _cyrToLat = {
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'E',
    'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
    'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
    'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
    'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'φ': 'U', '∠': '<', '°': ' deg', '★': '*',
  };

  /// Ensures string is Latin-1 safe for pdf package's internal SVG Helvetica font.
  static String _toAsciiSafe(String input) {
    var s = input
        .replaceAll('Ом', 'Ohm')
        .replaceAll('Перемычка', 'Wire')
        .replaceAll('В', 'V')
        .replaceAll('А', 'A');
    final out = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      if (_cyrToLat.containsKey(ch)) {
        out.write(_cyrToLat[ch]);
      } else if (rune >= 32 && rune <= 126) {
        out.write(ch);
      } else {
        out.write(' ');
      }
    }
    return out.toString();
  }

  static (double x, double y) _branchControlPoint(
    Circuit circuit,
    CircuitBranch b,
  ) {
    if (b.controlX != null && b.controlY != null) {
      return (b.controlX!, b.controlY!);
    }
    final from = circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
    final to = circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
    final mx = (from.x + to.x) / 2;
    final my = (from.y + to.y) / 2;

    final siblings = circuit.branches
        .where((other) =>
            (other.fromNodeId == b.fromNodeId && other.toNodeId == b.toNodeId) ||
            (other.fromNodeId == b.toNodeId && other.toNodeId == b.fromNodeId))
        .toList();

    if (siblings.length <= 1) return (mx, my);

    final idx = siblings.indexWhere((s) => s.id == b.id);
    final offsetIndex = idx - (siblings.length - 1) / 2.0;

    final dx = b.fromNodeId.compareTo(b.toNodeId) <= 0
        ? (to.x - from.x)
        : (from.x - to.x);
    final dy = b.fromNodeId.compareTo(b.toNodeId) <= 0
        ? (to.y - from.y)
        : (from.y - to.y);
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-3) return (mx, my);
    final px = -dy / len;
    final py = dx / len;
    return (mx + px * offsetIndex * 76.0, my + py * offsetIndex * 76.0);
  }

  static (double x, double y) _bezierAt(
    double x0,
    double y0,
    double cx,
    double cy,
    double x2,
    double y2,
    double t,
  ) {
    final mt = 1 - t;
    return (
      x0 * mt * mt + cx * 2 * mt * t + x2 * t * t,
      y0 * mt * mt + cy * 2 * mt * t + y2 * t * t,
    );
  }

  static double _tangentDegAt(
    double x0,
    double y0,
    double cx,
    double cy,
    double x2,
    double y2,
    double t,
  ) {
    final dx = (cx - x0) * 2 * (1 - t) + (x2 - cx) * 2 * t;
    final dy = (cy - y0) * 2 * (1 - t) + (y2 - cy) * 2 * t;
    return math.atan2(dy, dx) * 180.0 / math.pi;
  }

  /// Generates a complete standalone SVG with schematic and (optionally) results table.
  static String buildSvg(
    Circuit circuit,
    CircuitSolution? solution, {
    bool includeResultsTable = true,
    bool asciiUnits = false,
  }) {
    // Compute bounding box of nodes & control points
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final n in circuit.nodes) {
      minX = math.min(minX, n.x);
      minY = math.min(minY, n.y);
      maxX = math.max(maxX, n.x);
      maxY = math.max(maxY, n.y);
    }
    for (final b in circuit.branches) {
      final (cx, cy) = _branchControlPoint(circuit, b);
      minX = math.min(minX, cx);
      minY = math.min(minY, cy);
      maxX = math.max(maxX, cx);
      maxY = math.max(maxY, cy);
    }

    const pad = 90.0;
    final ox = minX - pad;
    final oy = minY - pad;
    final schematicW = math.max(520.0, (maxX - minX) + pad * 2);
    final schematicH = math.max(320.0, (maxY - minY) + pad * 2);

    final tableRows =
        (includeResultsTable && solution != null) ? circuit.branches.length : 0;
    final tableH = tableRows > 0 ? (90.0 + tableRows * 24.0) : 0.0;
    final totalH = schematicH + tableH;

    final buf = StringBuffer();
    buf.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${schematicW.toStringAsFixed(0)}" '
      'height="${totalH.toStringAsFixed(0)}" '
      'viewBox="0 0 ${schematicW.toStringAsFixed(0)} ${totalH.toStringAsFixed(0)}">',
    );
    buf.writeln('<rect width="100%" height="100%" fill="#FFFFFF"/>');
    buf.writeln(
      '<defs><style>'
      '.lbl { font-family: Arial, sans-serif; font-size: 11px; fill: #1E293B; }'
      '.curr { font-family: monospace; font-size: 11px; font-weight: bold; fill: #1D4ED8; }'
      '.tgt { font-family: monospace; font-size: 11px; font-weight: bold; fill: #D97706; }'
      '.node-t { font-family: Arial, sans-serif; font-size: 11px; font-weight: bold; fill: #FFFFFF; }'
      '.hdr { font-family: Arial, sans-serif; font-size: 13px; font-weight: bold; fill: #0F172A; }'
      '</style></defs>',
    );

    final refId = circuit.effectiveReferenceNodeId();
    final targetId = circuit.effectiveTargetBranchId();
    final placer = _SvgLabelPlacer();

    for (final n in circuit.nodes) {
      final nx = n.x - ox;
      final ny = n.y - oy;
      placer.reserve(nx, ny, 26, n.id == refId ? 42 : 26);
    }

    final branchLabels = <({
      CircuitBranch b,
      double mx,
      double my,
      double tx,
      double ty,
      double nx,
      double ny,
      bool isTarget,
    })>[];

    // Draw branches
    for (final b in circuit.branches) {
      final from = circuit.nodes.firstWhere((n) => n.id == b.fromNodeId);
      final to = circuit.nodes.firstWhere((n) => n.id == b.toNodeId);
      final (cx, cy) = _branchControlPoint(circuit, b);

      final x0 = from.x - ox;
      final y0 = from.y - oy;
      final x1 = cx - ox;
      final y1 = cy - oy;
      final x2 = to.x - ox;
      final y2 = to.y - oy;
      final isTarget = b.id == targetId;

      if (isTarget) {
        buf.writeln(
          '<path d="M $x0 $y0 Q $x1 $y1 $x2 $y2" fill="none" '
          'stroke="#F59E0B" stroke-opacity="0.3" stroke-width="6"/>',
        );
      }
      buf.writeln(
        '<path d="M $x0 $y0 Q $x1 $y1 $x2 $y2" fill="none" '
        'stroke="#1E40AF" stroke-width="2"/>',
      );

      final customDeg = b.symbolAngleDeg;
      final syms = <String>[];
      if (b.hasCurrentSource) {
        syms.add('J');
      } else {
        if (b.hasEmf) syms.add('E');
        if (b.rOhm > 0) syms.add('R');
        if (circuit.isAc) {
          final xl = b.xlOhmOverride ?? (circuit.omega * b.lHenry);
          final xc = b.xcOhmOverride ??
              (b.cFarad > 0 && circuit.omega > 0
                  ? 1.0 / (circuit.omega * b.cFarad)
                  : 0.0);
          if (xl > 1e-9) syms.add('L');
          if (xc > 1e-9) syms.add('C');
        }
        if (syms.isEmpty) syms.add('R');
      }

      for (var si = 0; si < syms.length; si++) {
        final t = syms.length == 1
            ? 0.5
            : 0.28 + (0.44 * si) / (syms.length - 1);
        final (sx, sy) = _bezierAt(x0, y0, x1, y1, x2, y2, t);
        final ang = customDeg ?? _tangentDegAt(x0, y0, x1, y1, x2, y2, t);
        switch (syms[si]) {
          case 'J':
            _svgCurrentSource(buf, sx, sy, ang, b.jAlignedWithBranch);
            placer.reserve(sx, sy, 32, 32);
          case 'E':
            _svgEmf(buf, sx, sy, ang, b.eAlignedWithBranch);
            placer.reserve(sx, sy, 32, 32);
          case 'L':
            _svgInductor(buf, sx, sy, ang, isTarget);
            placer.reserve(sx, sy, 38, 24);
          case 'C':
            _svgCapacitor(buf, sx, sy, ang, isTarget);
            placer.reserve(sx, sy, 28, 28);
          default:
            _svgImpedance(buf, sx, sy, ang, isTarget);
            placer.reserve(sx, sy, 38, 24);
        }
      }

      final (mx, my) = _bezierAt(x0, y0, x1, y1, x2, y2, 0.5);
      final angRad =
          _tangentDegAt(x0, y0, x1, y1, x2, y2, 0.5) * math.pi / 180.0;
      final tx = math.cos(angRad);
      final ty = math.sin(angRad);
      branchLabels.add((
        b: b,
        mx: mx,
        my: my,
        tx: tx,
        ty: ty,
        nx: -ty,
        ny: tx,
        isTarget: isTarget,
      ));
    }

    // Draw nodes & non-overlapping potential labels
    for (final n in circuit.nodes) {
      final nx = n.x - ox;
      final ny = n.y - oy;
      final isRef = n.id == refId;
      final fill = isRef ? '#B45309' : '#1E40AF';
      final stroke = isRef ? '#F59E0B' : '#3B82F6';

      final nodeLbl = asciiUnits ? _toAsciiSafe(n.label) : n.label;
      buf.writeln(
        '<circle cx="$nx" cy="$ny" r="10" fill="$fill" stroke="$stroke" stroke-width="2"/>',
      );
      buf.writeln(
        '<text x="$nx" y="${ny + 4}" text-anchor="middle" class="node-t">${_esc(nodeLbl)}</text>',
      );

      if (isRef) {
        buf.writeln(
          '<line x1="$nx" y1="${ny + 10}" x2="$nx" y2="${ny + 20}" stroke="#F59E0B" stroke-width="2"/>'
          '<line x1="${nx - 10}" y1="${ny + 20}" x2="${nx + 10}" y2="${ny + 20}" stroke="#F59E0B" stroke-width="2"/>'
          '<line x1="${nx - 6}" y1="${ny + 24}" x2="${nx + 6}" y2="${ny + 24}" stroke="#F59E0B" stroke-width="2"/>',
        );
      }

      final pot = solution?.nodePotentials[n.id];
      if (pot != null) {
        final rawPot = isRef
            ? 'φ${n.label}=0 В'
            : 'φ${n.label}=${pot.toStringRect(digits: 1)} В';
        final potStr = asciiUnits ? _toAsciiSafe(rawPot) : rawPot;
        final estW = potStr.length * 6.8 + 8;
        final (lx, ly) = placer.place(
          estW,
          16,
          isRef
              ? [
                  (nx, ny + 38),
                  (nx, ny - 22),
                  (nx + 48, ny),
                  (nx - 48, ny),
                ]
              : [
                  (nx, ny - 22),
                  (nx, ny + 26),
                  (nx + 48, ny),
                  (nx - 48, ny),
                ],
        );
        buf.writeln(
          '<text x="${lx.toStringAsFixed(1)}" y="${(ly + 4).toStringAsFixed(1)}" '
          'text-anchor="middle" class="curr">${_esc(potStr)}</text>',
        );
      }
    }

    // Place non-overlapping branch labels
    for (final bl in branchLabels) {
      final res = solution?.branchResults[bl.b.id];
      if (res != null) {
        final star = bl.isTarget ? ' *' : '';
        var iStr = circuit.isAc
            ? 'I${bl.b.name}=${res.current.toStringPolar(digits: 2)} A$star'
            : 'I${bl.b.name}=${Complex.fmt(res.current.re, 2)} A$star';
        if (asciiUnits) iStr = _toAsciiSafe(iStr);
        final estW = iStr.length * 6.8 + 8;
        final (lx, ly) = placer.place(estW, 16, [
          (bl.mx - bl.nx * 26, bl.my - bl.ny * 26),
          (bl.mx + bl.nx * 26, bl.my + bl.ny * 26),
          (bl.mx - bl.nx * 44, bl.my - bl.ny * 44),
          (bl.mx + bl.nx * 44, bl.my + bl.ny * 44),
          (bl.mx + bl.tx * 34 - bl.nx * 26, bl.my + bl.ty * 34 - bl.ny * 26),
        ]);
        buf.writeln(
          '<text x="${lx.toStringAsFixed(1)}" y="${(ly + 4).toStringAsFixed(1)}" '
          'text-anchor="middle" class="${bl.isTarget ? 'tgt' : 'curr'}">${_esc(iStr)}</text>',
        );
      }

      var summaryText =
          '${bl.b.name}: ${bl.b.summary(isAc: circuit.isAc, omega: circuit.omega)}';
      if (asciiUnits) {
        summaryText = _toAsciiSafe(summaryText);
      }
      final estW = summaryText.length * 6.4 + 8;
      final (sx, sy) = placer.place(estW, 16, [
        (bl.mx + bl.nx * 26, bl.my + bl.ny * 26),
        (bl.mx - bl.nx * 26, bl.my - bl.ny * 26),
        (bl.mx + bl.nx * 44, bl.my + bl.ny * 44),
        (bl.mx - bl.nx * 44, bl.my - bl.ny * 44),
        (bl.mx + bl.tx * 36 + bl.nx * 26, bl.my + bl.ty * 36 + bl.ny * 26),
      ]);
      buf.writeln(
        '<text x="${sx.toStringAsFixed(1)}" y="${(sy + 4).toStringAsFixed(1)}" '
        'text-anchor="middle" class="lbl">${_esc(summaryText)}</text>',
      );
    }

    // Optional results summary inside SVG
    if (includeResultsTable && solution != null) {
      var ty = schematicH + 16;
      buf.writeln(
        '<line x1="16" y1="$schematicH" x2="${schematicW - 16}" y2="$schematicH" stroke="#CBD5E1"/>',
      );
      buf.writeln(
        '<text x="20" y="$ty" class="hdr">${_esc(solution.method.title)} '
        '(P_ист=${Complex.fmt(solution.totalSourcePowerP, 2)} Вт, '
        'P_потр=${Complex.fmt(solution.totalLoadPowerP, 2)} Вт)</text>',
      );
      ty += 24;
      for (final r in solution.branchResults.values) {
        final iTxt = solution.isAc
            ? r.current.toStringPolar(digits: 2)
            : Complex.fmt(r.current.re, 3);
        final uTxt = solution.isAc
            ? r.voltage.toStringPolar(digits: 2)
            : Complex.fmt(r.voltage.re, 3);
        buf.writeln(
          '<text x="20" y="$ty" class="lbl">'
          '${_esc("Ветвь ${r.branchName}: I = $iTxt А, U = $uTxt В, P = ${Complex.fmt(r.powerActive, 2)} Вт")}'
          '</text>',
        );
        ty += 22;
      }
    }

    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _svgImpedance(
      StringBuffer buf, double x, double y, double angleDeg, bool isTarget) {
    final stroke = isTarget ? '#F59E0B' : '#1E40AF';
    buf.writeln(
      '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) rotate(${angleDeg.toStringAsFixed(1)})">'
      '<rect x="-18" y="-9" width="36" height="18" rx="2" fill="#FFFFFF" stroke="$stroke" stroke-width="2"/>'
      '</g>',
    );
  }

  static void _svgInductor(
      StringBuffer buf, double x, double y, double angleDeg, bool isTarget) {
    final stroke = isTarget ? '#F59E0B' : '#1E40AF';
    buf.writeln(
      '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) rotate(${angleDeg.toStringAsFixed(1)})">'
      '<rect x="-18" y="-10" width="36" height="20" fill="#FFFFFF"/>'
      '<path d="M -18 0 A 6 6 0 0 1 -6 0 A 6 6 0 0 1 6 0 A 6 6 0 0 1 18 0" fill="none" stroke="$stroke" stroke-width="2"/>'
      '</g>',
    );
  }

  static void _svgCapacitor(
      StringBuffer buf, double x, double y, double angleDeg, bool isTarget) {
    final stroke = isTarget ? '#F59E0B' : '#1E40AF';
    buf.writeln(
      '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) rotate(${angleDeg.toStringAsFixed(1)})">'
      '<rect x="-5" y="-12" width="10" height="24" fill="#FFFFFF"/>'
      '<line x1="-4" y1="-11" x2="-4" y2="11" stroke="$stroke" stroke-width="2.2"/>'
      '<line x1="4" y1="-11" x2="4" y2="11" stroke="$stroke" stroke-width="2.2"/>'
      '</g>',
    );
  }

  static void _svgEmf(
      StringBuffer buf, double x, double y, double angleDeg, bool aligned) {
    final dir = aligned ? 1 : -1;
    buf.writeln(
      '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) rotate(${angleDeg.toStringAsFixed(1)})">'
      '<circle cx="0" cy="0" r="14" fill="#FFFFFF" stroke="#F59E0B" stroke-width="2"/>'
      '<line x1="-9" y1="0" x2="9" y2="0" stroke="#F59E0B" stroke-width="2"/>'
      '<polygon points="${9 * dir},0 ${3 * dir},-4 ${3 * dir},4" fill="#F59E0B"/>'
      '</g>',
    );
  }

  static void _svgCurrentSource(
      StringBuffer buf, double x, double y, double angleDeg, bool aligned) {
    final dir = aligned ? 1 : -1;
    buf.writeln(
      '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) rotate(${angleDeg.toStringAsFixed(1)})">'
      '<circle cx="0" cy="0" r="14" fill="#FFFFFF" stroke="#F59E0B" stroke-width="1.8"/>'
      '<circle cx="0" cy="0" r="10" fill="none" stroke="#F59E0B" stroke-width="1.8"/>'
      '<polygon points="${7 * dir},0 ${1 * dir},-4 ${1 * dir},4" fill="#F59E0B"/>'
      '</g>',
    );
  }

  /// Generates a multi-page PDF report with vector schematic, tables, and steps.
  static Future<Uint8List> buildPdf(
    Circuit circuit,
    CircuitSolution? solution, {
    ByteData? regularFontData,
    ByteData? boldFontData,
  }) async {
    final regData = regularFontData ??
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bldData = boldFontData ??
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final ttfRegular = pw.Font.ttf(regData);
    final ttfBold = pw.Font.ttf(bldData);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
    );

    final schematicSvg = buildSvg(
      circuit,
      solution,
      includeResultsTable: false,
      asciiUnits: true,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'CircuitCalc — Отчёт по расчёту электрической цепи',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Схема: ${circuit.name} • Режим: ${circuit.isAc ? 'AC (${Complex.fmt(circuit.frequencyHz, 1)} Гц)' : 'DC'}'
            '${solution != null ? ' • Метод: ${solution.method.title}' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Center(
              child: pw.SvgImage(svg: schematicSvg, height: 220),
            ),
          ),
          if (solution != null) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Баланс мощностей: P_ист = ${Complex.fmt(solution.totalSourcePowerP, 3)} Вт, '
              'P_потр = ${Complex.fmt(solution.totalLoadPowerP, 3)} Вт '
              '(${solution.isPowerBalanced ? 'сошёлся' : 'расхождение'})',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Токи, напряжения и мощности по ветвям',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              headers: [
                'Ветвь',
                'Параметры',
                'Ток I, А',
                'Напр. U, В',
                'P, Вт',
                if (solution.isAc) 'Q, вар',
              ],
              data: [
                for (final b in circuit.branches)
                  () {
                    final r = solution.branchResults[b.id]!;
                    return [
                      r.branchName,
                      b.summary(isAc: circuit.isAc, omega: circuit.omega),
                      solution.isAc
                          ? r.current.toStringPolar(digits: 2)
                          : Complex.fmt(r.current.re, 3),
                      solution.isAc
                          ? r.voltage.toStringPolar(digits: 2)
                          : Complex.fmt(r.voltage.re, 3),
                      Complex.fmt(r.powerActive, 2),
                      if (solution.isAc) Complex.fmt(r.powerReactive, 2),
                    ];
                  }(),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Потенциалы узлов',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final n in circuit.nodes)
                  pw.Text(
                    'φ${n.label} = ${solution.isAc ? solution.nodePotentials[n.id]!.toStringPolar(digits: 2) : Complex.fmt(solution.nodePotentials[n.id]!.re, 3)} В',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Ход решения',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            for (final step in solution.steps) ...[
              pw.Text(
                step.title,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (step.description.isNotEmpty)
                pw.Text(step.description, style: const pw.TextStyle(fontSize: 9)),
              for (final eq in step.latexEquations)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 3),
                  child: _buildPdfEquation(eq),
                ),
              pw.SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Renders a LaTeX equation into a clean PDF widget (tables for matrices, readable Unicode for formulas).
  static pw.Widget _buildPdfEquation(String latex) {
    final pmatrixRe = RegExp(r'\\begin\{pmatrix\}([\s\S]*?)\\end\{pmatrix\}');
    final matches = pmatrixRe.allMatches(latex).toList();
    if (matches.length == 3) {
      final matA = _parseMatrix(matches[0].group(1)!);
      final vecX = _parseMatrix(matches[1].group(1)!);
      final vecB = _parseMatrix(matches[2].group(1)!);
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _pdfMatrixBox(matA),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text('·', style: const pw.TextStyle(fontSize: 11)),
            ),
            _pdfMatrixBox(vecX),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text('=', style: const pw.TextStyle(fontSize: 11)),
            ),
            _pdfMatrixBox(vecB),
          ],
        ),
      );
    }

    return pw.Text(
      formatLatexReadable(latex),
      style: const pw.TextStyle(fontSize: 9.5),
    );
  }

  static List<List<String>> _parseMatrix(String body) {
    return body
        .split(r'\\')
        .map((row) => row
            .split('&')
            .map((cell) => formatLatexReadable(cell.trim()))
            .toList())
        .toList();
  }

  static pw.Widget _pdfMatrixBox(List<List<String>> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 1.2, color: PdfColors.grey800),
          right: pw.BorderSide(width: 1.2, color: PdfColors.grey800),
        ),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (final row in rows)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                for (var i = 0; i < row.length; i++)
                  pw.Padding(
                    padding: pw.EdgeInsets.symmetric(
                        horizontal: row.length > 1 ? 5 : 2, vertical: 1),
                    child: pw.Text(
                      row[i],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Converts LaTeX math strings into clean Unicode mathematical notation for PDF text.
  static String formatLatexReadable(String input) {
    var s = input;

    // Unwrap \text{...} and \underline{...}
    s = s.replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m.group(1)!);
    s = s.replaceAllMapped(
        RegExp(r'\\underline\{([^}]*)\}'), (m) => m.group(1)!);

    // Format subscripts _{...} BEFORE \frac so nested braces inside \frac are flattened.
    // Use plain digits/text (e.g. φ0, I1, P_ист) because Roboto lacks U+2080..U+2089 glyphs.
    s = s.replaceAllMapped(RegExp(r'_\{([^}]*)\}'), (m) {
      final inner = m.group(1)!;
      if (RegExp(r'^[0-9]+$').hasMatch(inner)) {
        return inner;
      }
      return '_$inner';
    });

    // Replace \frac{a}{b}
    final fracRe = RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}');
    while (fracRe.hasMatch(s)) {
      s = s.replaceAllMapped(
        fracRe,
        (m) => '(${m.group(1)}) / (${m.group(2)})',
      );
    }

    // Standard LaTeX symbols -> Unicode (supported by Roboto)
    s = s
        .replaceAll(r'\varphi', 'φ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\Sigma', 'Σ')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\angle', '∠')
        .replaceAll(r'^\circ', '°')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\quad', '   ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\,', ' ');

    // Clean superscripts ^{(...)}
    s = s.replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) => '^${m.group(1)}');

    // Collapse extra whitespace
    s = s.replaceAll(RegExp(r' {2,}'), ' ').trim();
    return s;
  }

  /// Returns a default writable file path for exporting SVG or PDF.
  static String defaultExportPath(String ext) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'circuit_calc_$stamp.$ext';

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final downloads = Directory('$userProfile\\Downloads');
      if (downloads.existsSync()) {
        return '${downloads.path}\\$fileName';
      }
    }
    return '${Directory.current.path}${Platform.pathSeparator}$fileName';
  }
}
