import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_home.dart';
import 'f18_shell_navigation.dart';
import 'f18_v1_navigation_flow.dart';

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
  void initState() {
    super.initState();
    if (widget.screen == 'create') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<F18SessionCreationDraft>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const F18CreateSessionDialog(),
        );
      });
    }
  }

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
      case 'design':
        return F18DesignCenterPage(
          onHome: () {},
          onWiring: () {},
          onSchemaLibrary: () {},
        );
      case 'maintenance':
        return F18MaintenanceCenterPage(
          onHome: () {},
          onTroubleshooting: () {},
          onFaultLibrary: () {},
          onStudentValidation: () {},
        );
      case 'setup':
        return F18ActivitySetupPage(
          pageKey: const Key('proof-setup'),
          title: 'Préparer une activité de câblage',
          description:
              'Préparez l’activité avant d’ouvrir l’atelier de conception.',
          parentLabel: 'centre de conception',
          onBack: () {},
          onOpenWorkshop: () {},
        );
      case 'validation':
        return F18StudentSituationValidationPage(
          onBack: () {},
          onLaunch: (String reference, String fault) {},
        );
      case 'create':
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
