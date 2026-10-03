import 'dart:io';

import 'package:electrosim/f17_tp_session_dialog.dart';
import 'package:electrosim/f18_session_coordinator.dart';
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/runtime/electrosim_lan_sync.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for Point 4 state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('V1 parity Point 4 teacher TP management and supervision', () {
    test('teacher can delete draft, published and closed activities safely', () {
      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();

      controller.createDraft();
      controller.deleteTeacherActivity();
      expect(controller.session, isNull);

      controller.createDraft();
      controller.publish();
      controller.deleteTeacherActivity();
      expect(controller.session, isNull);

      controller.createDraft();
      controller.publish();
      controller.startTeacher();
      expect(
        controller.deleteTeacherActivity,
        throwsStateError,
      );

      controller.cancelTeacher();
      expect(controller.lifecycle, TpLifecycle.closed);
      controller.deleteTeacherActivity();
      expect(controller.session, isNull);
    });

    test(
        'student already connected before publication receives publish start grade and close lifecycle',
        () async {
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'P4SYNC',
        sessionName: 'BEP1 Maintenance',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );
      final ElectroSimTpSessionController student =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: student,
        sessionCode: 'P4SYNC',
        clientId: 'awa-001',
        displayName: 'Awa Ouédraogo',
        autoReconnect: false,
      );

      addTearDown(client.close);
      addTearDown(host.close);
      addTearDown(teacher.dispose);
      addTearDown(student.dispose);

      await client.connect(info.preferredEndpoint);
      expect(client.synchronized, isTrue);
      expect(student.session, isNull);
      expect(host.studentSupervisionStates.single.displayName, 'Awa Ouédraogo');

      teacher.createDraft();
      await _waitFor(() => student.lifecycle == TpLifecycle.draft);

      teacher.publish();
      await _waitFor(() => student.lifecycle == TpLifecycle.published);

      teacher.startTeacher();
      await _waitFor(() => student.lifecycle == TpLifecycle.started);

      student.submitStudent();
      await _waitFor(
        () => host.studentSessions['awa-001']?.lifecycle ==
            TpLifecycle.submitted,
      );
      expect(student.readOnly, isTrue);

      host.evaluateStudent('awa-001', score: 91);
      await _waitFor(
        () =>
            student.lifecycle == TpLifecycle.evaluated &&
            student.evaluation?.score == 91,
      );
      expect(student.readOnly, isTrue);

      host.closeStudent('awa-001');
      await _waitFor(() => student.lifecycle == TpLifecycle.closed);
      expect(student.readOnly, isTrue);
    });

    testWidgets('publish and delete controls mutate the real teacher activity',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: F17TpSessionDialog(
              controller: controller,
              role: F9UserRole.teacher,
              onStudentStarted: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tp-create-draft')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.draft);

      await tester.tap(find.byKey(const Key('tp-publish')));
      await tester.pumpAndSettle();
      expect(controller.lifecycle, TpLifecycle.published);
      expect(find.byKey(const Key('tp-delete')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tp-delete')));
      await tester.pumpAndSettle();
      expect(controller.session, isNull);
      expect(find.byKey(const Key('tp-create-draft')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'teacher supervision shows the real student submission and accepts individual grade',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      teacher.createDraft();
      teacher.publish();
      teacher.startTeacher();

      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'P4VIEW',
        sessionName: 'Atelier BEP1',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );
      final ElectroSimTpSessionController student =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: student,
        sessionCode: 'P4VIEW',
        clientId: 'fatimata-001',
        displayName: 'Fatimata Kaboré',
        autoReconnect: false,
      );

      addTearDown(client.close);
      addTearDown(host.close);
      addTearDown(teacher.dispose);
      addTearDown(student.dispose);

      await client.connect(info.preferredEndpoint);
      await _waitFor(() => student.lifecycle == TpLifecycle.started);
      student.submitStudent();
      await _waitFor(
        () => host.studentSessions['fatimata-001']?.lifecycle ==
            TpLifecycle.submitted,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: F18SessionSupervisionPage(
            controller: teacher,
            lanHost: host,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatimata Kaboré'), findsOneWidget);
      expect(
        find.byKey(
          const Key('supervision-student-state-fatimata-001'),
        ),
        findsOneWidget,
      );
      expect(find.text('TP remis — à noter'), findsWidgets);
      expect(
        find.byKey(const Key('supervision-grade-input-fatimata-001')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('supervision-grade-input-fatimata-001')),
        '92',
      );
      await tester.tap(
        find.byKey(const Key('supervision-grade-submit-fatimata-001')),
      );
      await tester.runAsync(
        () => _waitFor(
          () =>
              host.studentSessions['fatimata-001']?.lifecycle ==
              TpLifecycle.evaluated,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        host.studentSessions['fatimata-001']?.evaluation?.score,
        92,
      );
      expect(
        find.byKey(const Key('supervision-student-score-fatimata-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('supervision-close-student-fatimata-001')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('supervision-close-student-fatimata-001')),
      );
      await tester.runAsync(
        () => _waitFor(
          () =>
              host.studentSessions['fatimata-001']?.lifecycle ==
              TpLifecycle.closed,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        host.studentSessions['fatimata-001']?.lifecycle,
        TpLifecycle.closed,
      );
      expect(student.readOnly, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
