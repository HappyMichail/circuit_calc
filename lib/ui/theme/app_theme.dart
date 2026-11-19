import 'package:material_ui/material_ui.dart';

/// CircuitCalc Design System tokens ("Technical Precision & Modern Workstation").
class CircuitColors extends ThemeExtension<CircuitColors> {
  final Color canvasBg;
  final Color canvasGrid;
  final Color accent;
  final Color success;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color outline;

  const CircuitColors({
    required this.canvasBg,
    required this.canvasGrid,
    required this.accent,
    required this.success,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
  });

  static const dark = CircuitColors(
    canvasBg: Color(0xFF0A0D14),
    canvasGrid: Color(0xFF1E2638),
    accent: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    surfaceContainer: Color(0xFF111827),
    surfaceContainerHigh: Color(0xFF1F2937),
    outline: Color(0xFF374151),
  );

  static const light = CircuitColors(
    canvasBg: Color(0xFFF8FAFC),
    canvasGrid: Color(0xFFE2E8F0),
    accent: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceContainerHigh: Color(0xFFF1F5F9),
    outline: Color(0xFFCBD5E1),
  );

  @override
  CircuitColors copyWith({
    Color? canvasBg,
    Color? canvasGrid,
    Color? accent,
    Color? success,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? outline,
  }) {
    return CircuitColors(
      canvasBg: canvasBg ?? this.canvasBg,
      canvasGrid: canvasGrid ?? this.canvasGrid,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      outline: outline ?? this.outline,
    );
  }

  @override
  CircuitColors lerp(ThemeExtension<CircuitColors>? other, double t) {
    if (other is! CircuitColors) return this;
    return CircuitColors(
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      canvasGrid: Color.lerp(canvasGrid, other.canvasGrid, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      onPrimary: Color(0xFF0C486C),
      secondary: Color(0xFFF59E0B),
      onSecondary: Color(0xFF111827),
      tertiary: Color(0xFFF59E0B),
      surface: Color(0xFF0B0F19),
      onSurface: Color(0xFFF9FAFB),
      onSurfaceVariant: Color(0xFF9CA3AF),
      outline: Color(0xFF374151),
      error: Color(0xFFEF4444),
      surfaceContainer: Color(0xFF111827),
      surfaceContainerHigh: Color(0xFF1F2937),
      surfaceContainerLow: Color(0xFF0B0F19),
      surfaceContainerLowest: Color(0xFF0A0D14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: const Color(0xFF374151),
      cardTheme: CardThemeData(
        color: const Color(0xFF0B0F19),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF374151)),
        ),
      ),
      extensions: const [CircuitColors.dark],
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: Color(0xFF1E40AF),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFFF59E0B),
      onSecondary: Color(0xFF0F172A),
      tertiary: Color(0xFFF59E0B),
      surface: Color(0xFFF8FAFC),
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: Color(0xFF475569),
      outline: Color(0xFFCBD5E1),
      error: Color(0xFFEF4444),
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFF1F5F9),
      surfaceContainerLow: Color(0xFFF8FAFC),
      surfaceContainerLowest: Color(0xFFF8FAFC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: const Color(0xFFCBD5E1),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      extensions: const [CircuitColors.light],
    );
  }
}
