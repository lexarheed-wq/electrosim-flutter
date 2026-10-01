import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F18-G1 mapped colors match the approved MagicPath source', () {
    expect(ElectroSimColors.primary, const Color(0xFF174D89));
    expect(ElectroSimColors.onPrimary, const Color(0xFFFFFFFF));
    expect(ElectroSimColors.primaryStrong, const Color(0xFF123B73));
    expect(ElectroSimColors.secondary, const Color(0xFF344054));
    expect(ElectroSimColors.background, const Color(0xFFF4F7FA));
    expect(ElectroSimColors.surface, const Color(0xFFFFFFFF));
    expect(ElectroSimColors.surfaceElevated, const Color(0xFFFFFFFF));
    expect(ElectroSimColors.surfaceMuted, const Color(0xFFF1F5F9));
    expect(ElectroSimColors.outline, const Color(0xFF8492A6));
    expect(ElectroSimColors.textPrimary, const Color(0xFF132033));
    expect(ElectroSimColors.textSecondary, const Color(0xFF5A6D83));
    expect(ElectroSimColors.textDisabled, const Color(0xFF99A5B2));
    expect(ElectroSimColors.success, const Color(0xFF067647));
    expect(ElectroSimColors.warning, const Color(0xFFB54708));
    expect(ElectroSimColors.danger, const Color(0xFFB42318));
    expect(ElectroSimColors.info, const Color(0xFF175CD3));
    expect(ElectroSimColors.focus, const Color(0xFF2563EB));
  });

  test('F18-G1 electrical colors preserve the approved semantic separation', () {
    expect(ElectroSimColors.dcPositive, const Color(0xFFD92D20));
    expect(ElectroSimColors.dcNegative, const Color(0xFF101828));
    expect(ElectroSimColors.phaseL1, const Color(0xFFB42318));
    expect(ElectroSimColors.phaseL2, const Color(0xFFF79009));
    expect(ElectroSimColors.phaseL3, const Color(0xFF475467));
    expect(ElectroSimColors.neutral, const Color(0xFF1570EF));
    expect(ElectroSimColors.protectiveEarth, const Color(0xFF039855));
    expect(ElectroSimColors.primary, isNot(ElectroSimColors.dcPositive));
  });

  test('F18-G1 geometry spacing radii and motion match mapping', () {
    expect(
      <double>[
        ElectroSimSpacing.xxs,
        ElectroSimSpacing.xs,
        ElectroSimSpacing.sm,
        ElectroSimSpacing.md,
        ElectroSimSpacing.lg,
        ElectroSimSpacing.xl,
      ],
      <double>[4, 8, 12, 16, 24, 32],
    );
    expect(ElectroSimRadii.compact, 8);
    expect(ElectroSimRadii.panel, 12);
    expect(ElectroSimRadii.card, 16);
    expect(ElectroSimRadii.dialog, 16);
    expect(ElectroSimGeometry.minimumTouchTarget, greaterThanOrEqualTo(48));
    expect(ElectroSimGeometry.desktopTopBarHeight, 64);
    expect(ElectroSimGeometry.compactTopBarHeight, 56);
    expect(ElectroSimGeometry.expandedPaletteWidth, 264);
    expect(ElectroSimGeometry.expandedContextWidth, 304);
    expect(ElectroSimGeometry.mediumPanelWidth, 288);
    expect(ElectroSimGeometry.statusBarHeight, 40);
    expect(ElectroSimGeometry.terminalHitTarget, 48);
    expect(ElectroSimGeometry.terminalVisualDiameter, 16);
    expect(ElectroSimMotion.instantFeedback, const Duration(milliseconds: 90));
    expect(ElectroSimMotion.shortTransition, const Duration(milliseconds: 160));
    expect(ElectroSimMotion.panelTransition, const Duration(milliseconds: 220));
  });

  test('F18-G1 typography metrics match mapping', () {
    expect(ElectroSimTypographyTokens.display.fontSize, 40);
    expect(ElectroSimTypographyTokens.display.height, 48 / 40);
    expect(ElectroSimTypographyTokens.display.fontWeight, FontWeight.w700);
    expect(ElectroSimTypographyTokens.bodyM.fontSize, 14);
    expect(ElectroSimTypographyTokens.bodyM.height, 20 / 14);
    expect(ElectroSimTypographyTokens.bodyM.fontWeight, FontWeight.w400);
    expect(ElectroSimTypographyTokens.technicalValue.fontSize, 22);
    expect(ElectroSimTypographyTokens.technicalUnit.fontSize, 12);
    expect(ElectroSimTypographyTokens.diagnosticMono.fontSize, 12);
  });

  test('F18-G1 component and electrical visual tokens expose qualified contracts', () {
    expect(ElectroSimComponentTokens.controlHeight, 40);
    expect(ElectroSimComponentTokens.compactControlHeight, 32);
    expect(ElectroSimComponentTokens.quickPaletteItemCount, 5);
    expect(ElectroSimComponentTokens.paletteExpansionLabel, 'Voir tous');
    expect(ElectroSimElectricalVisualTokens.terminalVisualDiameter, 16);
    expect(ElectroSimElectricalVisualTokens.terminalHitTarget, 48);
    expect(ElectroSimElectricalVisualTokens.selectionHaloWidth, 2);
  });

  test('breakpoints remain behaviorally identical', () {
    expect(ElectroSimBreakpoints.classify(390), ElectroSimWindowClass.compact);
    expect(ElectroSimBreakpoints.classify(820), ElectroSimWindowClass.medium);
    expect(ElectroSimBreakpoints.classify(1440), ElectroSimWindowClass.expanded);
  });
}
