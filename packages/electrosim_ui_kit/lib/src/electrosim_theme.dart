import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'typography_tokens.dart';

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
      scaffoldBackgroundColor: ElectroSimColors.background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: ElectroSimTypography.apply(base.textTheme),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          borderSide: const BorderSide(color: ElectroSimColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          borderSide: const BorderSide(color: ElectroSimColors.focus, width: 2),
        ),
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
      tabBarTheme: const TabBarThemeData(
        labelColor: ElectroSimColors.primary,
        unselectedLabelColor: ElectroSimColors.textSecondary,
        indicatorColor: ElectroSimColors.primary,
        dividerColor: ElectroSimColors.workspaceDivider,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      focusColor: ElectroSimColors.focus.withValues(alpha: 0.18),
    );
  }
}
