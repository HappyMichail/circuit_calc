import 'dart:math' as math;

/// Immutable complex number for DC and sinusoidal AC circuit analysis.
class Complex {
  final double re;
  final double im;

  const Complex(this.re, [this.im = 0.0]);

  static const Complex zero = Complex(0, 0);
  static const Complex one = Complex(1, 0);
  static const Complex j = Complex(0, 1);

  factory Complex.fromPolar(double magnitude, double angleDeg) {
    final rad = angleDeg * math.pi / 180.0;
    return Complex(
      magnitude * math.cos(rad),
      magnitude * math.sin(rad),
    );
  }

  double get abs => math.sqrt(re * re + im * im);
  double get absSquared => re * re + im * im;
  double get angleRad => math.atan2(im, re);
  double get angleDeg => angleRad * 180.0 / math.pi;

  Complex get conj => Complex(re, -im);

  bool isZero([double eps = 1e-10]) => abs < eps;

  Complex operator +(Complex other) => Complex(re + other.re, im + other.im);
  Complex operator -(Complex other) => Complex(re - other.re, im - other.im);
  Complex operator -() => Complex(-re, -im);

  Complex operator *(Complex other) => Complex(
        re * other.re - im * other.im,
        re * other.im + im * other.re,
      );

  Complex scale(double s) => Complex(re * s, im * s);

  Complex operator /(Complex other) {
    final denom = other.absSquared;
    if (denom < 1e-24) {
      throw StateError('Division by zero in Complex');
    }
    return Complex(
      (re * other.re + im * other.im) / denom,
      (im * other.re - re * other.im) / denom,
    );
  }

  static String fmt(double v, [int digits = 3]) {
    if (v.abs() < 1e-9) return '0';
    // Avoid -0
    final cleaned = v.abs() < 1e-12 ? 0.0 : v;
    String s = cleaned.toStringAsFixed(digits);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    if (s == '-0') return '0';
    return s;
  }

  String toStringRect({int digits = 3, bool forceSign = false}) {
    final r = re.abs() < 1e-9 ? 0.0 : re;
    final i = im.abs() < 1e-9 ? 0.0 : im;
    if (i == 0) {
      final s = fmt(r, digits);
      return forceSign && r > 0 ? '+$s' : s;
    }
    if (r == 0) {
      final absI = fmt(i.abs(), digits);
      if (i > 0) {
        final prefix = forceSign ? '+' : '';
        return absI == '1' ? '${prefix}j' : '${prefix}j$absI';
      } else {
        return absI == '1' ? '-j' : '-j$absI';
      }
    }
    final rStr = fmt(r, digits);
    final absI = fmt(i.abs(), digits);
    final jPart = absI == '1' ? 'j' : 'j$absI';
    final sign = i >= 0 ? '+' : '-';
    final res = '$rStr $sign $jPart';
    return forceSign ? '+($res)' : res;
  }

  String toStringPolar({int digits = 3}) {
    if (isZero()) return '0';
    return '${fmt(abs, digits)}∠${fmt(angleDeg, 1)}°';
  }

  String toLatex({bool isAc = true, int digits = 3}) {
    if (!isAc || im.abs() < 1e-9) {
      return fmt(re, digits);
    }
    return toStringRect(digits: digits);
  }

  String toLatexPolar({int digits = 3}) {
    if (isZero()) return '0';
    return '${fmt(abs, digits)} \\angle ${fmt(angleDeg, 1)}^\\circ';
  }

  @override
  String toString() => toStringRect();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complex &&
          (re - other.re).abs() < 1e-9 &&
          (im - other.im).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(re.toStringAsFixed(6), im.toStringAsFixed(6));
}
