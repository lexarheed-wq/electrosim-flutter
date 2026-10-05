import 'package:flutter/material.dart';

abstract final class ElectroSimTypographyTokens {
  static const TextStyle display = TextStyle(
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headingL = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headingM = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headingS = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle titleL = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle titleM = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleS = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyL = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyM = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyS = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle labelL = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle labelM = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle labelS = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle technicalValue = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle technicalUnit = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle diagnosticMono = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
  );
}

abstract final class ElectroSimTypography {
  static TextStyle _apply(TextStyle? base, TextStyle token) {
    return (base ?? const TextStyle()).copyWith(
      fontSize: token.fontSize,
      height: token.height,
      fontWeight: token.fontWeight,
      letterSpacing: token.letterSpacing,
    );
  }

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      displayLarge: _apply(
        base.displayLarge,
        ElectroSimTypographyTokens.display,
      ),
      headlineLarge: _apply(
        base.headlineLarge,
        ElectroSimTypographyTokens.headingL,
      ),
      headlineMedium: _apply(
        base.headlineMedium,
        ElectroSimTypographyTokens.headingM,
      ),
      headlineSmall: _apply(
        base.headlineSmall,
        ElectroSimTypographyTokens.headingS,
      ),
      titleLarge: _apply(base.titleLarge, ElectroSimTypographyTokens.titleL),
      titleMedium: _apply(base.titleMedium, ElectroSimTypographyTokens.titleM),
      titleSmall: _apply(base.titleSmall, ElectroSimTypographyTokens.titleS),
      bodyLarge: _apply(base.bodyLarge, ElectroSimTypographyTokens.bodyL),
      bodyMedium: _apply(base.bodyMedium, ElectroSimTypographyTokens.bodyM),
      bodySmall: _apply(base.bodySmall, ElectroSimTypographyTokens.bodyS),
      labelLarge: _apply(base.labelLarge, ElectroSimTypographyTokens.labelL),
      labelMedium: _apply(base.labelMedium, ElectroSimTypographyTokens.labelM),
      labelSmall: _apply(base.labelSmall, ElectroSimTypographyTokens.labelS),
    );
  }
}
