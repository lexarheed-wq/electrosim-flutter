import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f17_tp_supervision_panel.dart';
import 'f18_home.dart';
import 'f18_shell_navigation.dart';
import 'f18_v1_navigation_flow.dart';
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
        return const _ProofWorkshopPage();
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
    return Scaffold(
      key: const Key('proof-supervision-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Supervision'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(ElectroSimSpacing.md),
              child: F17TpSupervisionPanel(controller: _controller),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ProofWorkshopPage extends StatelessWidget {
  const _ProofWorkshopPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('proof-workshop-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        title: const Text('Atelier · Câblage'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Quitter l’atelier'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 220,
              child: _ProofPanel(
                title: 'Composants',
                body: 'Palette de composants',
                icon: Icons.view_list_outlined,
              ),
            ),
            const SizedBox(width: ElectroSimSpacing.md),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ElectroSimColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(ElectroSimRadii.card),
                  border: Border.all(color: ElectroSimColors.outline),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.grid_on_outlined, size: 46),
                      SizedBox(height: ElectroSimSpacing.sm),
                      Text('Canvas de simulation'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: ElectroSimSpacing.md),
            const SizedBox(
              width: 250,
              child: _ProofPanel(
                title: 'Propriétés',
                body: 'Aucun composant sélectionné',
                icon: Icons.tune_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofPanel extends StatelessWidget {
  const _ProofPanel({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: ElectroSimColors.primary),
            const SizedBox(height: ElectroSimSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: ElectroSimSpacing.xs),
            Text(body),
          ],
        ),
      ),
    );
  }
}
