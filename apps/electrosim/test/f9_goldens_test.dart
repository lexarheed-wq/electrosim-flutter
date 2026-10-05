import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWorkspace(
    WidgetTester tester,
    Size size, {
    String? selected,
    F9UserRole role = F9UserRole.teacher,
    String workspace = 'Câblage',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: app.F9WorkspaceDemoPage(
          initialSelectedElementId: selected,
          role: role,
          initialWorkspace: workspace,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> captureProfile(
    WidgetTester tester, {
    required Size size,
    required String prefix,
    required bool needsPanelButton,
  }) async {
    await pumpWorkspace(tester, size);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/${prefix}_base.png'),
    );

    if (needsPanelButton) {
      await tester.tap(find.text('Palette').last);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/${prefix}_palette.png'),
    );

    await pumpWorkspace(tester, size, selected: 'switch-1');
    if (needsPanelButton) {
      await tester.tap(find.text('Propriétés').last);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/${prefix}_properties.png'),
    );
  }

  testWidgets('compact 390x844 reference set', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await captureProfile(
      tester,
      size: const Size(390, 844),
      prefix: 'f9_compact',
      needsPanelButton: true,
    );
  });

  testWidgets('medium 820x1180 reference set', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await captureProfile(
      tester,
      size: const Size(820, 1180),
      prefix: 'f9_medium',
      needsPanelButton: true,
    );
  });

  testWidgets('expanded 1440x900 reference set', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await captureProfile(
      tester,
      size: const Size(1440, 900),
      prefix: 'f9_expanded',
      needsPanelButton: false,
    );
  });

  testWidgets('student troubleshooting diagnostic reference', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWorkspace(
      tester,
      const Size(390, 844),
      role: F9UserRole.student,
      workspace: 'Recherche de dérangement',
    );
    await tester.tap(find.text('Propriétés').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnostic-tab')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/f9_compact_student_diagnostic.png'),
    );
  });
}
