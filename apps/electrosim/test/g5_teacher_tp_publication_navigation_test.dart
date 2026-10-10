import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final watch = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (watch.elapsed > const Duration(seconds: 5)) {
      fail('Timed out waiting for widget: $finder');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _openTeacherDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-create-session')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('session-create-confirm')));
  await tester.pumpAndSettle();
  await _waitFor(tester, find.byKey(const Key('session-waiting-qr')));
  await tester.tap(find.byKey(const Key('session-waiting-continue')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
}

void main() {
  testWidgets('G5 wiring TP publication is reachable from dashboard setup', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openTeacherDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard-wiring')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-cabling-setup-page')), findsOneWidget);
    expect(find.byKey(const Key('activity-setup-publish-tp')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-setup-publish-tp')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tp-wiring-reference-example')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tp-wiring-reference-required')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('tp-create-draft')))
          .onPressed,
      isNull,
      reason: 'Do not publish an empty or implicit wiring reference.',
    );
    await tester.tap(find.byKey(const Key('tp-wiring-reference-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voyant CC autonome').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tp-create-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Mode : Câblage'), findsOneWidget);
    expect(find.byKey(const Key('tp-publish')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tp-publish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tp-teacher-start')), findsOneWidget);
    expect(find.text('État : Publié'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'G5 troubleshooting TP publication is reachable from dashboard setup',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openTeacherDashboard(tester);

      await tester.tap(find.byKey(const Key('dashboard-troubleshooting')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('session-troubleshooting-setup-page')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('activity-setup-publish-tp')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('tp-wiring-reference-example')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('tp-create-draft')));
      await tester.pumpAndSettle();
      expect(find.text('Mode : Recherche de dérangement'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tp-publish')));
      await tester.pumpAndSettle();
      expect(find.text('État : Publié'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'G5 wiring publication preserves reference, type and lifecycle on restore',
    () {
      final example = buildV2ProductExampleRepository().all.first;
      final teacher = ElectroSimTpSessionController();
      addTearDown(teacher.dispose);
      teacher.createDraft(
        mode: TpMode.wiring,
        wiringReferenceCircuit: example.circuit,
        activityTitle: 'TP de câblage — test',
      );
      teacher.publish();
      final replica = teacher.createStudentReplica();
      addTearDown(replica.dispose);

      expect(replica.session!.definition.mode, TpMode.wiring);
      expect(replica.session!.definition.title, 'TP de câblage — test');
      expect(replica.session!.definition.referenceCircuit, example.circuit);
      expect(replica.lifecycle, TpLifecycle.published);
      expect(replica.toPersistenceJson()['mode'], 'wiring');
      expect(teacher.toPersistenceJson()['mode'], 'wiring');
    },
  );

  test(
    'G5 empty wiring reference is rejected, legacy troubleshooting preserved',
    () {
      final controller = ElectroSimTpSessionController();
      addTearDown(controller.dispose);
      expect(
        () => controller.createDraft(mode: TpMode.wiring),
        throwsStateError,
      );
      expect(controller.session, isNull);
      controller.createDraft();
      expect(controller.session!.definition.mode, TpMode.troubleshooting);
    },
  );
}
