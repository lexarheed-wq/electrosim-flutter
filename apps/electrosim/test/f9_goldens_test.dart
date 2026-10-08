import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: app.F9WorkspaceDemoPage(
          initialSelectedElementId: selected,
          initialCircuit: buildRegressionFixtureCircuit(),
          role: role,
          initialWorkspace: workspace,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPalette(WidgetTester tester) async {
    if (find
        .byKey(electroSimPaletteRegionKey)
        .hitTestable()
        .evaluate()
        .isEmpty) {
      await tester.tap(find.byKey(electroSimPaletteEdgeKey));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(electroSimPaletteRegionKey), findsOneWidget);
  }

  Future<void> openContext(WidgetTester tester) async {
    if (find
        .byKey(electroSimContextRegionKey)
        .hitTestable()
        .evaluate()
        .isEmpty) {
      await tester.tap(find.byKey(electroSimContextEdgeKey));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(electroSimContextRegionKey), findsOneWidget);
  }

  Future<void> captureProfile(
    WidgetTester tester, {
    required Size size,
    required String prefix,
  }) async {
    await pumpWorkspace(tester, size);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/${prefix}_base.png'),
    );

    if (size.width >= 1200) {
      tester
          .widget<ElectroSimWorkspaceShell>(
            find.byType(ElectroSimWorkspaceShell),
          )
          .layoutController!
          .setPanelVisible(ElectroSimWorkspacePanel.context, false);
      await tester.pumpAndSettle();
    }
    await openPalette(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/${prefix}_palette.png'),
    );

    await pumpWorkspace(tester, size, selected: 'switch-1');
    if (size.width >= 1200) {
      tester
          .widget<ElectroSimWorkspaceShell>(
            find.byType(ElectroSimWorkspaceShell),
          )
          .layoutController!
          .setPanelVisible(ElectroSimWorkspacePanel.palette, false);
      await tester.pumpAndSettle();
    }
    await openContext(tester);
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
    );
  });

  testWidgets('medium 820x1180 reference set', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await captureProfile(
      tester,
      size: const Size(820, 1180),
      prefix: 'f9_medium',
    );
  });

  testWidgets('expanded 1440x900 reference set', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await captureProfile(
      tester,
      size: const Size(1440, 900),
      prefix: 'f9_expanded',
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
    await openContext(tester);
    final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
    tabBar.controller!.animateTo(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-diagnostic-panel')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/f9_compact_student_diagnostic.png'),
    );
  });
}
