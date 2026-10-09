import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _menu(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('workspace-more-actions')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

SimulatorCanvas _canvas(WidgetTester tester) =>
    tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));

Offset _worldToGlobal(WidgetTester tester, Offset world) {
  final canvas = _canvas(tester);
  return tester.getTopLeft(find.byType(SimulatorCanvas)) +
      canvas.viewportController!.worldToScreen(world);
}

Future<void> _prepare(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: F9WorkspaceDemoPage()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('P2 user drags, resizes and deletes a physical DIN rail', (
    tester,
  ) async {
    await _prepare(tester);
    final before = _canvas(tester).circuit;
    await _menu(tester, 'workspace-add-din-rail');
    var fixture = _canvas(tester).layout.cabinetLayout.fixtures.single;
    final original = fixture.bounds;
    final source = _worldToGlobal(tester, original.center);
    await tester.dragFrom(source, const Offset(80, 0));
    await tester.pumpAndSettle();
    fixture = _canvas(tester).layout.cabinetLayout.fixtures.single;
    expect(fixture.bounds.left, closeTo(original.left + 80, 1.5));

    final handle = _worldToGlobal(tester, fixture.bounds.bottomRight);
    await tester.dragFrom(handle, const Offset(85, 24));
    await tester.pumpAndSettle();
    fixture = _canvas(tester).layout.cabinetLayout.fixtures.single;
    expect(fixture.bounds.width, closeTo(original.width + 85, 2));
    expect(fixture.bounds.height, closeTo(original.height + 24, 2));
    expect(_canvas(tester).circuit, before);

    await tester.tap(find.byKey(const Key('workspace-delete-action')));
    await tester.pumpAndSettle();
    expect(_canvas(tester).layout.cabinetLayout.fixtures, isEmpty);
    expect(_canvas(tester).circuit, before);
  });

  testWidgets('P2 placement DIN assisté activates via workspace More menu', (
    tester,
  ) async {
    await _prepare(tester);
    await _menu(tester, 'workspace-add-din-rail');
    await _menu(tester, 'workspace-toggle-din-snap');
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Placement DIN assisté : activé'), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-toggle-din-snap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Placement DIN assisté : désactivé'), findsOneWidget);
  });

  testWidgets('P2 wiring route remains available without source or load', (
    tester,
  ) async {
    await _prepare(tester);
    await _menu(tester, 'workspace-add-wire-duct');
    await _menu(tester, 'workspace-route-wiring-duct');
    expect(
      _canvas(tester).layout.cabinetLayout.fixtures.single.kind,
      CabinetFixtureKind.wireDuct,
    );
  });
}
