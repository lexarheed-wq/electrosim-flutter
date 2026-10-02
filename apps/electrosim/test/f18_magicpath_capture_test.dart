import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _capture(
  WidgetTester tester,
  String filename,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('_capture/$filename'),
  );
}

void main() {
  setUp(() {});

  testWidgets('capture F18 home desktop', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(const app.ElectroSimApp());
    await _capture(tester, '01_flutter_home_desktop.png');
  });

  testWidgets('capture F18 workspace desktop', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(
          initialSelectedElementId: 'breaker-1',
        ),
      ),
    );
    await _capture(tester, '02_flutter_workspace_desktop.png');
  });

  testWidgets('capture F18 workspace compact', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(),
      ),
    );
    await _capture(tester, '03_flutter_workspace_compact.png');
  });

  testWidgets('capture F18 troubleshooting student', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(820, 1180));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.student,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder diagnostic = find.byKey(const Key('diagnostic-tab'));
    if (diagnostic.evaluate().isNotEmpty) {
      await tester.tap(diagnostic);
    }
    await _capture(tester, '04_flutter_troubleshooting_student.png');
  });
}
