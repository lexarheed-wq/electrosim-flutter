import 'dart:io';

import 'package:electrosim/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitForClassroomQr(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Finder qr = find.byKey(const Key('session-waiting-qr'));
  final Stopwatch stopwatch = Stopwatch()..start();
  while (qr.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for the classroom QR code.');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
}

void _expectNoLegacyIdentity(WidgetTester tester) {
  expect(find.textContaining('Palette F9'), findsNothing);
  expect(find.textContaining('Canvas F8'), findsNothing);
  expect(find.textContaining('F9 final'), findsNothing);
}

void main() {
  test('production source keeps legacy workspace alias compatibility-only', () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(
      RegExp(r'F9WorkspaceDemoPage\s*\(').allMatches(source).length,
      1,
      reason:
          'Only the compatibility constructor may mention F9WorkspaceDemoPage.',
    );
    expect(source, isNot(contains('F9OrthogonalRouter')));
  });

  test('no user-visible legacy F8/F9 labels remain in application library', () {
    final Directory lib = Directory('lib');
    final List<String> forbidden = <String>[
      'Palette F9',
      'Canvas F8',
      'F9 final',
    ];

    for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String content = entity.readAsStringSync();
      for (final String marker in forbidden) {
        expect(
          content,
          isNot(contains(marker)),
          reason: '${entity.path} still exposes legacy marker "$marker".',
        );
      }
    }
  });

  testWidgets('Design Center enters F18 workspace identity',
      (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    _expectNoLegacyIdentity(tester);
  });

  testWidgets('Maintenance troubleshooting enters F18 workspace identity',
      (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-maintenance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maintenance-troubleshooting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
    await tester.pumpAndSettle();

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    _expectNoLegacyIdentity(tester);
  });

  testWidgets('teacher session wiring enters F18 workspace identity',
      (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-create-confirm')));
    await tester.pumpAndSettle();
    await _waitForClassroomQr(tester);
    await tester.tap(find.byKey(const Key('session-waiting-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-wiring')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
    await tester.pumpAndSettle();

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    _expectNoLegacyIdentity(tester);
  });
}
