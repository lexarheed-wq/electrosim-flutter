import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_home.dart';
import 'f18_session_coordinator.dart';
import 'f18_shell_navigation.dart';
import 'f18_v1_navigation_flow.dart';
import 'main.dart' as product;
import 'runtime/electrosim_tp_session_controller.dart';

void main() {
  runApp(const _NavigationProofApp());
}

class _NavigationProofApp extends StatelessWidget {
  const _NavigationProofApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: _ProofScreen(screen: Uri.base.queryParameters['screen'] ?? 'home'),
    );
  }
}

class _ProofScreen extends StatefulWidget {
  const _ProofScreen({required this.screen});

  final String screen;

  @override
  State<_ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<_ProofScreen> {
  @override
  Widget build(BuildContext context) {
    switch (widget.screen) {
      case 'waiting':
        return F18SessionWaitingRoomPage(
          sessionName: 'Atelier BEP1',
          sessionCode: 'ABC234',
          connectedStudents: 2,
          onHome: () {},
          onContinue: () {},
          sharingStatus: 'Partage réseau prêt pour la session.',
        );
      case 'dashboard':
        return F18SessionShellPage(
          sessionName: 'Atelier BEP1',
          onHome: () {},
          onWiring: () {},
          onTroubleshooting: () {},
          onSupervision: () {},
          onManageSession: () {},
        );
      case 'setup':
        return F18ActivitySetupPage(
          pageKey: const Key('proof-setup'),
          title: 'Préparer une activité de câblage',
          description:
              'Préparez l’activité professeur avant d’ouvrir l’atelier.',
          parentLabel: 'tableau de bord',
          onBack: () {},
          onOpenWorkshop: () {},
        );
      case 'supervision':
        return const _ProofSupervisionPage();
      case 'maintenance':
        return F18MaintenanceCenterPage(
          onHome: () {},
          onTroubleshooting: () {},
          onFaultLibrary: () {},
          onStudentValidation: () {},
        );
      case 'validation':
        return F18StudentSituationValidationPage(
          onBack: () {},
          onLaunch: (String reference, String fault) {},
        );
      case 'design':
        return F18DesignCenterPage(
          onHome: () {},
          onWiring: () {},
          onSchemaLibrary: () {},
        );
      case 'workshop':
        return product.F18WorkspacePage(
          entryLabel: 'Centre de conception',
          initialWorkspace: 'Câblage',
          onExitWorkspace: () {},
        );
      case 'create':
        return Stack(
          children: <Widget>[
            F18HomeSurface(
              onCreateSession: () {},
              onMaintenance: () {},
              onDesign: () {},
              onJoinSession: () {},
            ),
            const ModalBarrier(
              dismissible: false,
              color: Color(0x73000000),
            ),
            const Center(child: F18CreateSessionDialog()),
          ],
        );
      case 'home':
      default:
        return F18HomeSurface(
          onCreateSession: () {},
          onMaintenance: () {},
          onDesign: () {},
          onJoinSession: () {},
        );
    }
  }
}

class _ProofSupervisionPage extends StatefulWidget {
  const _ProofSupervisionPage();

  @override
  State<_ProofSupervisionPage> createState() => _ProofSupervisionPageState();
}

class _ProofSupervisionPageState extends State<_ProofSupervisionPage> {
  late final ElectroSimTpSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ElectroSimTpSessionController();
  }

  @override
  Widget build(BuildContext context) {
    return F18SessionSupervisionPage(controller: _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
