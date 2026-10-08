import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('breakpoints follow the F9 responsive contract', () {
    expect(ElectroSimBreakpoints.classify(390), ElectroSimWindowClass.compact);
    expect(
      ElectroSimBreakpoints.classify(599.9),
      ElectroSimWindowClass.compact,
    );
    expect(ElectroSimBreakpoints.classify(600), ElectroSimWindowClass.medium);
    expect(ElectroSimBreakpoints.classify(1000), ElectroSimWindowClass.medium);
    expect(
      ElectroSimBreakpoints.classify(1000.1),
      ElectroSimWindowClass.expanded,
    );
  });

  test('interface and electrical colors remain distinct tokens', () {
    expect(ElectroSimColors.primary, isNot(ElectroSimColors.dcPositive));
    expect(ElectroSimColors.secondary, isNot(ElectroSimColors.dcNegative));
    expect(ElectroSimColors.phaseL1, isNot(ElectroSimColors.phaseL2));
    expect(ElectroSimColors.background, isNot(ElectroSimColors.surface));
    expect(ElectroSimColors.focus, isNot(ElectroSimColors.dcPositive));
  });

  test('F18 qualified interaction geometry remains accessible', () {
    expect(ElectroSimGeometry.minimumTouchTarget, greaterThanOrEqualTo(48));
    expect(ElectroSimGeometry.terminalHitTarget, greaterThanOrEqualTo(48));
    expect(
      ElectroSimGeometry.terminalVisualDiameter,
      lessThan(ElectroSimGeometry.terminalHitTarget),
    );
    expect(ElectroSimComponentTokens.quickPaletteItemCount, 5);
    expect(ElectroSimComponentTokens.paletteExpansionLabel, 'Voir tous');
  });
}
