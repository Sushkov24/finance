import 'package:flutter/material.dart';

abstract final class AppColors {
  static const seed = Color(0xFF3B82F6);
  static const primaryBright = Color(0xFF60A5FA);
  static const primaryDeep = Color(0xFF1E40AF);
  static const expense = Color(0xFFF43F5E);
  static const income = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const navyTop = Color(0xFF0E2A5C);
  static const navyBottom = Color(0xFF050A16);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBright, primaryDeep],
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.light).copyWith(
          surface: const Color(0xFFF4F7FF),
          surfaceContainerLow: Colors.white,
          surfaceContainer: const Color(0xFFEAF0FD),
          surfaceContainerHigh: const Color(0xFFE2EAFB),
        ),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: Brightness.dark).copyWith(
          primary: AppColors.primaryBright,
          onPrimary: Colors.white,
          secondary: const Color(0xFF38BDF8),
          tertiary: const Color(0xFF818CF8),
          surface: const Color(0xFF0B1220),
          onSurface: const Color(0xFFF1F5F9),
          onSurfaceVariant: const Color(0xFF94A3B8),
          outlineVariant: const Color(0xFF243352),
          surfaceContainerLow: const Color(0xFF111B2E),
          surfaceContainer: const Color(0xFF15223B),
          surfaceContainerHigh: const Color(0xFF1B2B47),
          surfaceContainerHighest: const Color(0xFF223456),
        ),
      );

  /// Full-screen backdrop behind every page (scaffolds are transparent).
  static BoxDecoration backdrop(Brightness brightness) => brightness == Brightness.dark
      ? const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyTop, AppColors.navyBottom],
            stops: [0.0, 0.55],
          ),
        )
      : const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD6E4FF), Color(0xFFF4F7FF)],
            stops: [0.0, 0.5],
          ),
        );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(24);
    final glass = isDark ? const Color(0x14FFFFFF) : const Color(0xCCFFFFFF);
    final glassBorder = isDark ? const Color(0x1FFFFFFF) : const Color(0x143B82F6);
    final solidSurface = isDark ? const Color(0xFF0E1628) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: glassBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: glass,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: glassBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: solidSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: solidSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0x14FFFFFF) : const Color(0xFFEEF3FD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: glassBorder),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: glassBorder, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: solidSurface,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
