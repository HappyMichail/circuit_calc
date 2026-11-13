import 'dart:math' as math;
import '../math/complex.dart';

/// A branch connecting two nodes (`fromNodeId` -> `toNodeId`).
/// Positive branch current flows from `fromNodeId` to `toNodeId`.
class CircuitBranch {
  final String id;
  final String name;
  final String fromNodeId;
  final String toNodeId;

  // Passive parameters
  final double rOhm;
  final double lHenry;
  final double cFarad;
  final double? xlOhmOverride;
  final double? xcOhmOverride;

  // Independent voltage source (EMF) in series
  final double eMagnitude;
  final double ePhaseDeg;
  final bool eAlignedWithBranch;

  // Independent current source (ideal current source branch)
  final bool hasCurrentSource;
  final double jMagnitude;
  final double jPhaseDeg;
  final bool jAlignedWithBranch;

  const CircuitBranch({
    required this.id,
    required this.name,
    required this.fromNodeId,
    required this.toNodeId,
    this.rOhm = 0.0,
    this.lHenry = 0.0,
    this.cFarad = 0.0,
    this.xlOhmOverride,
    this.xcOhmOverride,
    this.eMagnitude = 0.0,
    this.ePhaseDeg = 0.0,
    this.eAlignedWithBranch = true,
    this.hasCurrentSource = false,
    this.jMagnitude = 0.0,
    this.jPhaseDeg = 0.0,
    this.jAlignedWithBranch = true,
  });

  bool get hasEmf => !hasCurrentSource && eMagnitude.abs() > 1e-12;

  /// Complex impedance Z = R + j(XL - XC).
  Complex impedance({required bool isAc, required double omega}) {
    if (!isAc) {
      return Complex(rOhm, 0);
    }
    final xl = xlOhmOverride ?? (omega * lHenry);
    final xc = xcOhmOverride ??
        (cFarad > 0 && omega > 0 ? 1.0 / (omega * cFarad) : 0.0);
    return Complex(rOhm, xl - xc);
  }

  /// Signed complex EMF aligned with branch direction (from -> to).
  Complex emf({required bool isAc}) {
    if (hasCurrentSource || eMagnitude.abs() < 1e-12) return Complex.zero;
    final val = isAc
        ? Complex.fromPolar(eMagnitude, ePhaseDeg)
        : Complex(eMagnitude, 0);
    return eAlignedWithBranch ? val : -val;
  }

  /// Signed complex current source value aligned with branch direction (from -> to).
  Complex currentSource({required bool isAc}) {
    if (!hasCurrentSource) return Complex.zero;
    final val = isAc
        ? Complex.fromPolar(jMagnitude, jPhaseDeg)
        : Complex(jMagnitude, 0);
    return jAlignedWithBranch ? val : -val;
  }

  /// Short human-readable summary of elements in this branch.
  String summary({required bool isAc, required double omega}) {
    final parts = <String>[];
    if (hasCurrentSource) {
      final jStr = isAc
          ? '${Complex.fmt(jMagnitude, 2)}∠${Complex.fmt(jPhaseDeg, 0)}° А'
          : '${Complex.fmt(jMagnitude, 2)} А';
      parts.add('J=$jStr');
    } else {
      if (rOhm > 0) parts.add('R=${Complex.fmt(rOhm, 2)} Ом');
      if (isAc) {
        final xl = xlOhmOverride ?? (omega * lHenry);
        final xc = xcOhmOverride ??
            (cFarad > 0 && omega > 0 ? 1.0 / (omega * cFarad) : 0.0);
        if (xl > 1e-9) parts.add('XL=${Complex.fmt(xl, 2)} Ом');
        if (xc > 1e-9) parts.add('XC=${Complex.fmt(xc, 2)} Ом');
      }
      if (eMagnitude.abs() > 1e-9) {
        final eStr = isAc
            ? '${Complex.fmt(eMagnitude, 2)}∠${Complex.fmt(ePhaseDeg, 0)}° В'
            : '${Complex.fmt(eMagnitude, 2)} В';
        parts.add('E=$eStr');
      }
      if (parts.isEmpty) {
        parts.add('Перемычка (0 Ом)');
      }
    }
    return parts.join(', ');
  }

  double get omegaDefault => 2 * math.pi * 50.0;

  CircuitBranch copyWith({
    String? id,
    String? name,
    String? fromNodeId,
    String? toNodeId,
    double? rOhm,
    double? lHenry,
    double? cFarad,
    double? xlOhmOverride,
    double? xcOhmOverride,
    bool clearXlOverride = false,
    bool clearXcOverride = false,
    double? eMagnitude,
    double? ePhaseDeg,
    bool? eAlignedWithBranch,
    bool? hasCurrentSource,
    double? jMagnitude,
    double? jPhaseDeg,
    bool? jAlignedWithBranch,
  }) {
    return CircuitBranch(
      id: id ?? this.id,
      name: name ?? this.name,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      rOhm: rOhm ?? this.rOhm,
      lHenry: lHenry ?? this.lHenry,
      cFarad: cFarad ?? this.cFarad,
      xlOhmOverride:
          clearXlOverride ? null : (xlOhmOverride ?? this.xlOhmOverride),
      xcOhmOverride:
          clearXcOverride ? null : (xcOhmOverride ?? this.xcOhmOverride),
      eMagnitude: eMagnitude ?? this.eMagnitude,
      ePhaseDeg: ePhaseDeg ?? this.ePhaseDeg,
      eAlignedWithBranch: eAlignedWithBranch ?? this.eAlignedWithBranch,
      hasCurrentSource: hasCurrentSource ?? this.hasCurrentSource,
      jMagnitude: jMagnitude ?? this.jMagnitude,
      jPhaseDeg: jPhaseDeg ?? this.jPhaseDeg,
      jAlignedWithBranch: jAlignedWithBranch ?? this.jAlignedWithBranch,
    );
  }
}
