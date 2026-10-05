import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openTop(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('M12 compact workspace top bar fits a phone-width viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: app.F9WorkspaceDemoPage(sessionNavigation: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-home-action')), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsOneWidget);
    expect(find.byKey(const Key('session-manage-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-rotate-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-delete-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-more-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M12 secondary workspace actions are grouped in one menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-more-actions')), findsOneWidget);
    await _openTop(tester);
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-recenter-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
