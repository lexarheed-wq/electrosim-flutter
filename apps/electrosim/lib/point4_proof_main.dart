import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f18_session_coordinator.dart';
import 'f9_ui_context.dart';
import 'runtime/electrosim_tp_session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Point4ProofApp());
}

class _Point4ProofApp extends StatelessWidget {
  const _Point4ProofApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: _Point4ProofScreen(
        screen: Uri.base.queryParameters['screen'] ?? 'manage-published',
      ),
    );
  }
}

class _Point4ProofScreen extends StatefulWidget {
  const _Point4ProofScreen({required this.screen});

  final String screen;

  @override
  State<_Point4ProofScreen> createState() => _Point4ProofScreenState();
}

class _Point4ProofScreenState extends State<_Point4ProofScreen> {
  final List<ElectroSimTpSessionController> _controllers =
      <ElectroSimTpSessionController>[];

  ElectroSimTpSessionController _controller() {
    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    _controllers.add(controller);
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.screen) {
      case 'manage-closed':
        final ElectroSimTpSessionController controller = _controller()
          ..createDraft()
          ..publish()
          ..startTeacher()
          ..cancelTeacher();
        return Scaffold(
          backgroundColor: ElectroSimColors.background,
          body: Center(
            child: F17TpSessionDialog(
              controller: controller,
              role: F9UserRole.teacher,
              onStudentStarted: (_) {},
              onCloseClassroomSession: () {},
            ),
          ),
        );
      case 'supervision':
        final ElectroSimTpSessionController teacher = _controller()
          ..createDraft()
          ..publish()
          ..startTeacher();

        final ElectroSimTpSessionController awa =
            teacher.createStudentReplica();
        _controllers.add(awa);
        awa.submitStudent();

        final ElectroSimTpSessionController moussa =
            teacher.createStudentReplica();
        _controllers.add(moussa);

        final ElectroSimTpSessionController fatimata =
            teacher.createStudentReplica();
        _controllers.add(fatimata);
        fatimata.submitStudent();
        fatimata.evaluateTeacher(score: 92);

        final ElectroSimTpSessionController ibrahim =
            teacher.createStudentReplica();
        _controllers.add(ibrahim);
        ibrahim.submitStudent();
        ibrahim.evaluateTeacher(score: 84);
        ibrahim.closeTeacher();

        return F18SessionSupervisionPage(
          controller: teacher,
          proofStudents: <F17StudentSupervisionItem>[
            F17StudentSupervisionItem(
              clientId: 'awa-001',
              displayName: 'Awa Ouédraogo',
              connected: true,
              session: awa.session,
            ),
            F17StudentSupervisionItem(
              clientId: 'moussa-001',
              displayName: 'Moussa Traoré',
              connected: true,
              session: moussa.session,
            ),
            F17StudentSupervisionItem(
              clientId: 'fatimata-001',
              displayName: 'Fatimata Kaboré',
              connected: true,
              session: fatimata.session,
            ),
            F17StudentSupervisionItem(
              clientId: 'ibrahim-001',
              displayName: 'Ibrahim Sawadogo',
              connected: false,
              session: ibrahim.session,
            ),
          ],
          onGradeStudentOverride: (_) {},
          onCloseStudentOverride: (_) {},
        );
      case 'manage-published':
      default:
        final ElectroSimTpSessionController controller = _controller()
          ..createDraft()
          ..publish();
        return Scaffold(
          backgroundColor: ElectroSimColors.background,
          body: Center(
            child: F17TpSessionDialog(
              controller: controller,
              role: F9UserRole.teacher,
              onStudentStarted: (_) {},
              onCloseClassroomSession: () {},
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    for (final ElectroSimTpSessionController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
