import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'student restores full geometry and retains it on remote revision',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ElectroSimTpSessionController();
      addTearDown(controller.dispose);
      controller.createDraft();
      controller.publish();
      controller.startStudent();
      await tester.pumpWidget(
        MaterialApp(
          home: F18WorkspacePage(
            role: F9UserRole.student,
            tpSessionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout;
      final id = controller.studentCircuit!.components.first.id.value;
      final custom = original
          .moveElement(id, const Offset(600, 460))
          .rotateElement(id)
          .withCabinetLayout(
            CabinetLayout([
              CabinetFixture(
                id: 'resume-din',
                kind: CabinetFixtureKind.dinRail,
                bounds: const Rect.fromLTWH(80, 80, 720, 20),
              ),
            ]),
          );
      final saved = ElectroSimLayoutPersistence.encode(custom);
      await tester.pumpWidget(const SizedBox.shrink());
      CircuitVisualLayout? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: F18WorkspacePage(
            role: F9UserRole.student,
            tpSessionController: controller,
            initialVisualLayout: ElectroSimLayoutPersistence.decode(saved),
            onVisualLayoutChanged: (layout) => reported = layout,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        ElectroSimLayoutPersistence.encode(
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas)).layout,
        ),
        saved,
      );
      expect(ElectroSimLayoutPersistence.encode(reported!), saved);
      final json = controller.studentCircuit!.toJson();
      json['revision'] = controller.studentCircuit!.revision + 1;
      controller.updateStudentCircuit(CircuitState.fromJson(json));
      await tester.pumpAndSettle();
      expect(
        ElectroSimLayoutPersistence.encode(
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas)).layout,
        ),
        saved,
      );
      expect(ElectroSimLayoutPersistence.encode(reported!), saved);
      // Another TP using the same scenario/circuit must not inherit this geometry.
      controller.cancelTeacher();
      controller.deleteTeacherActivity();
      controller.createDraft();
      controller.publish();
      controller.startStudent();
      await tester.pumpAndSettle();
      final newLayout = tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout;
      expect(newLayout.cabinetLayout.fixtures, isEmpty);
      expect(newLayout.elementQuarterTurns, isEmpty);
      expect(ElectroSimLayoutPersistence.encode(newLayout), isNot(saved));
      reported = null;
      tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .onElementMoved!(id, const Offset(720, 760));
      controller.cancelTeacher();
      controller.deleteTeacherActivity();
      controller.createDraft();
      controller.publish();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(reported, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
