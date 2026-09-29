import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class ElectroSimTheme {
  static ThemeData light() {
    const ColorScheme colors = ColorScheme.light(
      primary: ElectroSimColors.primary,
      onPrimary: ElectroSimColors.onPrimary,
      secondary: ElectroSimColors.secondary,
      onSecondary: Colors.white,
      surface: ElectroSimColors.surface,
      onSurface: ElectroSimColors.textPrimary,
      error: ElectroSimColors.danger,
      onError: Colors.white,
      outline: ElectroSimColors.outline,
    );

    final ThemeData base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: ElectroSimColors.surface,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ElectroSimColors.surfaceElevated,
        foregroundColor: ElectroSimColors.textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: const CardThemeData(
        color: ElectroSimColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: ElectroSimColors.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ElectroSimColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          borderSide: const BorderSide(color: ElectroSimColors.outline),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(ElectroSimGeometry.minimumTouchTarget),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, ElectroSimGeometry.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, ElectroSimGeometry.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          ),
        ),
      ),
      focusColor: ElectroSimColors.info.withValues(alpha: 0.18),
    );
  }
}
