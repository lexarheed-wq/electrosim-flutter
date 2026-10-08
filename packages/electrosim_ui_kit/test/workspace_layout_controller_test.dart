import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace breakpoints leave the home responsive contract alone', () {
    expect(
      classifyWorkspaceWidth(719.9),
      ElectroSimWorkspaceLayoutClass.compact,
    );
    expect(classifyWorkspaceWidth(720), ElectroSimWorkspaceLayoutClass.medium);
    expect(
      classifyWorkspaceWidth(1199.9),
      ElectroSimWorkspaceLayoutClass.medium,
    );
    expect(
      classifyWorkspaceWidth(1200),
      ElectroSimWorkspaceLayoutClass.expanded,
    );
    expect(ElectroSimBreakpoints.classify(600), ElectroSimWindowClass.medium);
  });
  test('default layout and independent electrical colors', () {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    expect(c.paletteWidth, 264);
    expect(c.contextWidth, 304);
    expect(c.paletteVisible, isTrue);
    expect(c.contextVisible, isTrue);
    expect(ElectroSimColors.workspaceHeader, isNot(ElectroSimColors.phaseL1));
  });
  test('widths clamp and ignore nonfinite input', () {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    c.setPaletteWidth(999);
    expect(c.paletteWidth, 360);
    c.setPaletteWidth(-1);
    expect(c.paletteWidth, 220);
    c.setContextWidth(999);
    expect(c.contextWidth, 440);
    c.setContextWidth(-1);
    expect(c.contextWidth, 280);
    c.setContextWidth(double.nan);
    c.setPaletteWidth(double.infinity);
    expect(c.paletteWidth, 220);
    expect(c.contextWidth, 280);
  });
  test('layout roundtrip and permanent command surfaces', () {
    final c = WorkspaceLayoutController();
    final restored = WorkspaceLayoutController();
    addTearDown(c.dispose);
    addTearDown(restored.dispose);
    c.setPaletteWidth(300);
    c.setPanelVisible(ElectroSimWorkspacePanel.palette, false);
    c.setPanelVisible(ElectroSimWorkspacePanel.top, false);
    restored.restore(c.toJson());
    expect(restored.paletteWidth, 300);
    expect(restored.paletteVisible, isFalse);
    expect(restored.contextVisible, isTrue);
    expect(restored.toJson(), c.toJson());
  });
  test('invalid preference fields recover to safe defaults', () {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    c.restore({
      'version': 1,
      'paletteWidth': 'large',
      'contextWidth': double.nan,
      'paletteVisible': 'yes',
    });
    expect(c.paletteWidth, 264);
    expect(c.contextWidth, 304);
    expect(c.paletteVisible, isTrue);
    c.setPaletteWidth(360);
    c.restore({'version': 999});
    expect(c.paletteWidth, 264);
  });
  test('unchanged state does not issue redundant notifications', () {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    var notifications = 0;
    c.addListener(() => notifications++);
    c.setPaletteWidth(264);
    c.setPanelVisible(ElectroSimWorkspacePanel.palette, true);
    expect(notifications, 0);
    c.setPaletteWidth(300);
    expect(notifications, 1);
  });
}
