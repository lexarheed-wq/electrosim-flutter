import 'package:flutter/material.dart';

abstract final class ElectroSimColors {
  static const Color primary = Color(0xFF174D89);
  static const Color primaryStrong = Color(0xFF123B73);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF344054);
  static const Color background = Color(0xFFF4F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color canvasSurface = Color(0xFFF8FAFC);
  static const Color outline = Color(0xFF8492A6);
  static const Color textPrimary = Color(0xFF132033);
  static const Color textSecondary = Color(0xFF5A6D83);
  static const Color textDisabled = Color(0xFF99A5B2);
  static const Color success = Color(0xFF067647);
  static const Color warning = Color(0xFFB54708);
  static const Color danger = Color(0xFFB42318);
  static const Color info = Color(0xFF175CD3);
  static const Color focus = Color(0xFF2563EB);

  // Electrical colors are intentionally separate from interface colors.
  static const Color dcPositive = Color(0xFFD92D20);
  static const Color dcNegative = Color(0xFF101828);
  static const Color phaseL1 = Color(0xFFB42318);
  static const Color phaseL2 = Color(0xFFF79009);
  static const Color phaseL3 = Color(0xFF475467);
  static const Color neutral = Color(0xFF1570EF);
  static const Color protectiveEarth = Color(0xFF039855);
}

abstract final class ElectroSimSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class ElectroSimRadii {
  static const double compact = 8;
  static const double panel = 12;
  static const double card = 16;
  static const double dialog = 16;
  static const double pill = 999;
}

abstract final class ElectroSimMotion {
  static const Duration instantFeedback = Duration(milliseconds: 90);
  static const Duration shortTransition = Duration(milliseconds: 160);
  static const Duration panelTransition = Duration(milliseconds: 220);
}

abstract final class ElectroSimGeometry {
  static const double minimumTouchTarget = 48;
  static const double desktopTopBarHeight = 64;
  static const double compactTopBarHeight = 56;
  static const double expandedPaletteWidth = 264;
  static const double expandedContextWidth = 304;
  static const double mediumPanelWidth = 288;
  static const double statusBarHeight = 40;
  static const double terminalHitTarget = 48;
  static const double terminalVisualDiameter = 16;
}
