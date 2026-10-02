import 'dart:convert';

import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('F17-R7 diagnostic answers are persisted in TpEngine student payload only',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    controller.createDraft();
    controller.publish();
    controller.startStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.student,
          tpSessionController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostic-tab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnostic-tab')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('diagnostic-location-recepteur-lampe')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('diagnostic-evidence')),
      'G1 = 24 V ; H1 = 0 V. La tension disparaît après S1.',
    );
    final Finder save =
        find.byKey(const Key('diagnostic-save'), skipOffstage: false);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(controller.session!.diagnosticSheet.entries, hasLength(3));
    expect(find.text('Entrées enregistrées : 3'), findsOneWidget);

    final String student =
        jsonEncode(controller.payloadFor(TpRole.student));
    final String teacher =
        jsonEncode(controller.payloadFor(TpRole.teacher));
    expect(student, contains('diagnosticSheet'));
    expect(student, contains('Récepteur / lampe'));
    expect(student, contains('S1 — Interrupteur'));
    expect(student, contains('La tension disparaît après S1.'));
    expect(teacher, isNot(contains('diagnosticSheet')));
    expect(teacher, isNot(contains('La tension disparaît après S1.')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F17-R7 teacher supervision reflects submission and final score',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    controller.createDraft();
    controller.publish();
    controller.startStudent();
    controller.submitStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialWorkspace: 'Supervision',
          sessionNavigation: true,
          role: F9UserRole.teacher,
          tpSessionController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tp-supervision-panel')), findsOneWidget);
    expect(find.text('TP remis — à noter'), findsOneWidget);
    expect(find.byKey(const Key('supervision-score')), findsOneWidget);

    controller.evaluateTeacher(score: 88);
    await tester.pumpAndSettle();

    expect(find.text('TP noté'), findsOneWidget);
    expect(find.text('88/100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
