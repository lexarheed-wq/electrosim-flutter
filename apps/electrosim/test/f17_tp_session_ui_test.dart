import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _ensureTopOpen(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'M10 teacher publishes, starts collectively, and student submits the same TP session',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            sessionNavigation: true,
            role: F9UserRole.teacher,
            tpSessionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _ensureTopOpen(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tp-create-draft')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.draft);
      await tester.tap(find.byKey(const Key('tp-publish')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.published);
      expect(find.byKey(const Key('tp-teacher-start')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tp-teacher-start')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.started);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            sessionNavigation: true,
            role: F9UserRole.student,
            tpSessionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _ensureTopOpen(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tp-student-start')), findsNothing);
      expect(controller.lifecycle, TpLifecycle.started);
      expect(find.text('Recherche de dérangement'), findsWidgets);

      await tester.tap(find.byKey(const Key('tp-student-submit')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.submitted);
      expect(controller.readOnly, isTrue);
      expect(
        find.byKey(const Key('tp-student-readonly-message')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('F17-R6 teacher can enter score and close submitted TP', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    controller.createDraft();
    controller.publish();
    controller.startTeacher();
    controller.submitStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          sessionNavigation: true,
          role: F9UserRole.teacher,
          tpSessionController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _ensureTopOpen(tester);
    await tester.tap(find.byKey(const Key('session-manage-action')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tp-teacher-score')), '85');
    await tester.tap(find.byKey(const Key('tp-evaluate')));
    await tester.pumpAndSettle();

    expect(controller.lifecycle, TpLifecycle.evaluated);
    expect(controller.evaluation!.score, 85);
    expect(find.text('Score : 85/100'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tp-close')));
    await tester.pumpAndSettle();
    expect(controller.lifecycle, TpLifecycle.closed);
    expect(tester.takeException(), isNull);
  });
  testWidgets('M10 published student waits for collective teacher start', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    controller.createDraft();
    controller.publish();

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          sessionNavigation: true,
          role: F9UserRole.student,
          tpSessionController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _ensureTopOpen(tester);
    await tester.tap(find.byKey(const Key('session-manage-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tp-student-waiting-start')), findsOneWidget);
    expect(find.byKey(const Key('tp-student-start')), findsNothing);
    expect(controller.lifecycle, TpLifecycle.published);
  });
}
