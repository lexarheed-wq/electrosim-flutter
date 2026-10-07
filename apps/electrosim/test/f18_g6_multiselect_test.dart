import 'package:electrosim/f9_component_visuals.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

Future<void> _pumpWorkspace(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: app.F9WorkspaceDemoPage(
        initialCircuit: buildRegressionFixtureCircuit(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _modifierTap(
  WidgetTester tester,
  LogicalKeyboardKey key,
  String visualId,
) async {
  await tester.sendKeyDownEvent(key);
  await tester.tapAt(
    tester.getCenter(find.byKey(ValueKey<String>('board-v1-visual-$visualId'))),
  );
  await tester.pump();
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

Set<String> _selection(WidgetTester tester) => tester
    .widget<F9CanvasVisualOverlay>(find.byType(F9CanvasVisualOverlay))
    .selectedElementIds;

void main() {
  testWidgets('multi-selection requires Ctrl Cmd or Shift and can be toggled', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpWorkspace(tester);

    await _modifierTap(tester, LogicalKeyboardKey.controlLeft, 'switch-1');
    await _modifierTap(tester, LogicalKeyboardKey.controlLeft, 'lamp-1');
    expect(_selection(tester), containsAll(<String>['switch-1', 'lamp-1']));
    expect(_selection(tester).length, 2);

    await _modifierTap(tester, LogicalKeyboardKey.shiftLeft, 'switch-1');
    expect(_selection(tester), <String>{'lamp-1'});

    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey<String>('board-v1-visual-switch-1')),
      ),
    );
    await tester.pump();
    expect(
      _selection(tester),
      <String>{'switch-1'},
      reason: 'plain click must collapse any prior multi-selection',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('top Delete removes every modifier-selected item', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpWorkspace(tester);

    await _modifierTap(tester, LogicalKeyboardKey.metaLeft, 'switch-1');
    await _modifierTap(tester, LogicalKeyboardKey.metaLeft, 'lamp-1');
    expect(_selection(tester).length, 2);

    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-delete-action')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    expect(
      canvas.circuit.components.map((ComponentInstance item) => item.id.value),
      isNot(contains('switch-1')),
    );
    expect(
      canvas.circuit.components.map((ComponentInstance item) => item.id.value),
      isNot(contains('lamp-1')),
    );
    expect(_selection(tester), isEmpty);
    expect(
      (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
      contains('Suppression multiple'),
    );
    expect(tester.takeException(), isNull);
  });
}
