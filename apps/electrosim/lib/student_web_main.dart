// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_ui_context.dart';
import 'f18_workspace_page.dart';
import 'runtime/electrosim_student_web_sync.dart';
import 'runtime/electrosim_tp_session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElectroSimStudentWebApp());
}

class ElectroSimStudentWebApp extends StatelessWidget {
  const ElectroSimStudentWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final String? proof = Uri.base.queryParameters['proof'];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroSim Élève',
      theme: ElectroSimTheme.light(),
      home: proof == null
          ? const _LiveStudentPortal()
          : _StudentProofScreen(mode: proof),
    );
  }
}

class _LiveStudentPortal extends StatefulWidget {
  const _LiveStudentPortal();

  @override
  State<_LiveStudentPortal> createState() => _LiveStudentPortalState();
}

class _LiveStudentPortalState extends State<_LiveStudentPortal> {
  final TextEditingController _name = TextEditingController();
  ElectroSimTpSessionController? _tpController;
  ElectroSimBrowserSessionBridge? _bridge;
  String? _error;

  String get _sessionCode {
    final List<String> parts = Uri.base.pathSegments;
    if (parts.length >= 2 && parts.first == 'join') {
      return parts[1].trim().toUpperCase();
    }
    return Uri.base.queryParameters['code']?.trim().toUpperCase() ?? '';
  }

  Uri get _webSocketEndpoint {
    final Uri page = Uri.parse(html.window.location.href);
    return page.replace(
      scheme: page.scheme == 'https' ? 'wss' : 'ws',
      path: '/electrosim-sync',
      query: null,
      fragment: null,
    );
  }

  Future<void> _join() async {
    final String displayName = _name.text.trim();
    if (displayName.length < 2) {
      setState(() {
        _error = 'Saisissez votre nom avant de rejoindre la séance.';
      });
      return;
    }
    if (_sessionCode.length != 6) {
      setState(() {
        _error = 'Lien de session invalide.';
      });
      return;
    }
    final ElectroSimTpSessionController tp = ElectroSimTpSessionController();
    final ElectroSimBrowserSessionBridge bridge =
        ElectroSimBrowserSessionBridge(
          controller: tp,
          sessionCode: _sessionCode,
          displayName: displayName,
          endpoint: _webSocketEndpoint,
        );
    bridge.addListener(_onBridgeChanged);
    setState(() {
      _tpController = tp;
      _bridge = bridge;
      _error = null;
    });
    try {
      await bridge.connect();
    } on Object {
      if (mounted) setState(() {});
    }
  }

  void _onBridgeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ElectroSimBrowserSessionBridge? bridge = _bridge;
    final ElectroSimTpSessionController? tp = _tpController;
    if (bridge == null || tp == null) {
      return _StudentJoinPage(
        sessionCode: _sessionCode,
        nameController: _name,
        error: _error,
        onJoin: _join,
      );
    }
    if (bridge.status == ElectroSimBrowserSessionStatus.connecting) {
      return const _StudentMessagePage(
        icon: Icons.wifi_tethering,
        title: 'Connexion à la séance…',
        message: 'ElectroSim récupère la session du professeur.',
        progress: true,
      );
    }
    if (bridge.status == ElectroSimBrowserSessionStatus.ended) {
      return _StudentClosedPage(replaced: bridge.replaced);
    }
    if (bridge.status == ElectroSimBrowserSessionStatus.failed) {
      return _StudentMessagePage(
        pageKey: const Key('student-web-connection-lost'),
        icon: Icons.wifi_off_outlined,
        title: 'Connexion interrompue',
        message:
            bridge.lastError ??
            'Vérifiez que vous êtes connecté au même réseau que le professeur.',
        onRetry: () => unawaited(bridge.retry()),
      );
    }
    return _StudentHubPage(bridge: bridge, controller: tp);
  }

  @override
  void dispose() {
    _name.dispose();
    final ElectroSimBrowserSessionBridge? bridge = _bridge;
    if (bridge != null) {
      bridge.removeListener(_onBridgeChanged);
      bridge.dispose();
    }
    _tpController?.dispose();
    super.dispose();
  }
}

class _StudentJoinPage extends StatelessWidget {
  const _StudentJoinPage({
    required this.sessionCode,
    required this.nameController,
    required this.error,
    required this.onJoin,
  });

  final String sessionCode;
  final TextEditingController nameController;
  final String? error;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('student-web-join-page'),
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ElectroSimSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ElectroSimColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(ElectroSimRadii.card),
                  border: Border.all(color: ElectroSimColors.outline),
                  boxShadow: ElectroSimComponentTokens.cardElevation,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ElectroSimSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Icon(
                        Icons.electrical_services_outlined,
                        size: 56,
                        color: ElectroSimColors.primary,
                      ),
                      const SizedBox(height: ElectroSimSpacing.md),
                      Text(
                        'ElectroSim Élève',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: ElectroSimSpacing.xs),
                      Text(
                        'Session $sessionCode',
                        key: const Key('student-web-session-code'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: ElectroSimSpacing.lg),
                      const Text(
                        'Aucune installation n’est nécessaire. Cette version fonctionne dans votre navigateur tant que la séance du professeur est active.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: ElectroSimSpacing.lg),
                      TextField(
                        key: const Key('student-web-name'),
                        controller: nameController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onJoin(),
                        decoration: InputDecoration(
                          labelText: 'Nom et prénom',
                          errorText: error,
                        ),
                      ),
                      const SizedBox(height: ElectroSimSpacing.md),
                      FilledButton.icon(
                        key: const Key('student-web-join'),
                        onPressed: onJoin,
                        icon: const Icon(Icons.login),
                        label: const Text('Rejoindre la séance'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentHubPage extends StatelessWidget {
  const _StudentHubPage({required this.bridge, required this.controller});

  final ElectroSimBrowserSessionBridge bridge;
  final ElectroSimTpSessionController controller;

  @override
  Widget build(BuildContext context) {
    if (!bridge.sessionStarted) {
      return Scaffold(
        key: const Key('student-web-waiting-page'),
        backgroundColor: ElectroSimColors.background,
        body: const SafeArea(child: Center(child: _WaitingStudentCard())),
      );
    }
    final TpLifecycle? tpLifecycle = controller.lifecycle;
    final bool tpVisible =
        tpLifecycle != null && tpLifecycle != TpLifecycle.draft;
    final bool tpOpenable =
        tpLifecycle == TpLifecycle.started ||
        tpLifecycle == TpLifecycle.submitted ||
        tpLifecycle == TpLifecycle.evaluated ||
        tpLifecycle == TpLifecycle.closed;
    return Scaffold(
      key: const Key('student-web-hub-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        title: Text(bridge.sessionName),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ElectroSimSpacing.md),
            child: Center(child: Text('Connecté')),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.xl),
              children: <Widget>[
                Text(
                  'Espace élève',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Choisissez uniquement une activité autorisée par la séance du professeur.',
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                _StudentActionCard(
                  key: const Key('student-web-simulator-card'),
                  icon: Icons.electrical_services_outlined,
                  title: 'Simulateur',
                  description:
                      'Ouvrir l’atelier ElectroSim dans ce navigateur.',
                  enabled: bridge.simulatorEnabled,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => _StudentSessionGuard(
                        bridge: bridge,
                        child: F18WorkspacePage(
                          entryLabel: 'Session élève',
                          initialWorkspace: 'Câblage',
                          role: F9UserRole.student,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                _StudentActionCard(
                  key: const Key('student-web-tp-card'),
                  icon: Icons.assignment_outlined,
                  title: tpVisible
                      ? controller.session!.definition.title
                      : 'TP publié',
                  description: switch (tpLifecycle) {
                    TpLifecycle.published =>
                      'TP publié — en attente du démarrage par le professeur.',
                    TpLifecycle.started =>
                      'TP en cours — ouvrir ou reprendre le travail.',
                    TpLifecycle.submitted ||
                    TpLifecycle.evaluated ||
                    TpLifecycle.closed =>
                      'Travail remis — consulter le résultat en lecture seule.',
                    _ => 'Aucun TP n’est publié pour le moment.',
                  },
                  enabled: tpOpenable,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => _StudentSessionGuard(
                        bridge: bridge,
                        child: F18WorkspacePage(
                          entryLabel: 'TP élève',
                          sessionNavigation: true,
                          onSessionDashboard: () => Navigator.of(context).pop(),
                          onSessionHome: () => Navigator.of(context).pop(),
                          initialWorkspace:
                              controller.session?.definition.mode ==
                                  TpMode.wiring
                              ? 'Câblage'
                              : 'Recherche de dérangement',
                          role: F9UserRole.student,
                          initialCircuit: controller.studentCircuit,
                          tpSessionController: controller,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentActionCard extends StatelessWidget {
  const _StudentActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.lg),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: ElectroSimSpacing.xs),
                Text(description),
              ],
            );
            final Widget action = FilledButton(
              onPressed: enabled ? onPressed : null,
              child: const Text('Ouvrir'),
            );

            if (constraints.maxWidth < 440) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(icon, size: 42, color: ElectroSimColors.primary),
                      const SizedBox(width: ElectroSimSpacing.md),
                      Expanded(child: copy),
                    ],
                  ),
                  const SizedBox(height: ElectroSimSpacing.md),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Icon(icon, size: 42, color: ElectroSimColors.primary),
                const SizedBox(width: ElectroSimSpacing.lg),
                Expanded(child: copy),
                const SizedBox(width: ElectroSimSpacing.md),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentSessionGuard extends StatelessWidget {
  const _StudentSessionGuard({required this.bridge, required this.child});

  final ElectroSimBrowserSessionBridge bridge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bridge,
      builder: (BuildContext context, Widget? _) {
        if (bridge.status == ElectroSimBrowserSessionStatus.ended) {
          return _StudentClosedPage(replaced: bridge.replaced);
        }
        if (!bridge.sessionUsable) {
          return _StudentMessagePage(
            pageKey: const Key('student-web-reconnect-page'),
            icon: Icons.wifi_off_outlined,
            title: 'Reconnexion au professeur',
            message:
                bridge.lastError ??
                'La connexion a été interrompue. Votre séance n’est pas '
                    'considérée comme terminée.',
            progress:
                bridge.status == ElectroSimBrowserSessionStatus.connecting,
            onRetry: () => unawaited(bridge.retry()),
          );
        }
        return child;
      },
    );
  }
}

class _WaitingStudentCard extends StatelessWidget {
  const _WaitingStudentCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ElectroSimSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(ElectroSimSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.hourglass_top_outlined, size: 48),
                const SizedBox(height: ElectroSimSpacing.md),
                Text(
                  'Vous êtes connecté',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Le professeur n’a pas encore démarré la séance. Cette page s’ouvrira automatiquement dès le démarrage.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentClosedPage extends StatelessWidget {
  const _StudentClosedPage({this.replaced = false});
  final bool replaced;

  @override
  Widget build(BuildContext context) {
    return _StudentMessagePage(
      pageKey: const Key('student-web-closed-page'),
      icon: Icons.lock_clock_outlined,
      title: replaced
          ? 'Travail repris dans un autre onglet'
          : 'Séance terminée',
      message: replaced
          ? 'Votre travail continue dans le nouvel onglet. Vous pouvez fermer celui-ci.'
          : 'La session du professeur est fermée. ElectroSim Élève est maintenant verrouillé. Scannez le QR code d’une nouvelle séance pour continuer.',
    );
  }
}

class _StudentMessagePage extends StatelessWidget {
  const _StudentMessagePage({
    this.pageKey,
    required this.icon,
    required this.title,
    required this.message,
    this.progress = false,
    this.onRetry,
  });

  final Key? pageKey;
  final IconData icon;
  final String title;
  final String message;
  final bool progress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ElectroSimSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(ElectroSimSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 52),
                      const SizedBox(height: ElectroSimSpacing.md),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: ElectroSimSpacing.sm),
                      Text(message, textAlign: TextAlign.center),
                      if (progress) ...<Widget>[
                        const SizedBox(height: ElectroSimSpacing.lg),
                        const LinearProgressIndicator(),
                      ],
                      if (onRetry != null) ...<Widget>[
                        const SizedBox(height: ElectroSimSpacing.lg),
                        OutlinedButton.icon(
                          key: const Key('student-web-retry-connection'),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer la connexion'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentProofScreen extends StatelessWidget {
  const _StudentProofScreen({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case 'closed':
        return const _StudentClosedPage();
      case 'hub':
        return const _StudentProofHub();
      case 'waiting':
        return Scaffold(
          backgroundColor: ElectroSimColors.background,
          body: const SafeArea(child: Center(child: _WaitingStudentCard())),
        );
      case 'join':
      default:
        return _StudentJoinPage(
          sessionCode: 'ABC234',
          nameController: TextEditingController(text: 'Awa Ouédraogo'),
          error: null,
          onJoin: () {},
        );
    }
  }
}

class _StudentProofHub extends StatefulWidget {
  const _StudentProofHub();

  @override
  State<_StudentProofHub> createState() => _StudentProofHubState();
}

class _StudentProofHubState extends State<_StudentProofHub> {
  late final ElectroSimTpSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ElectroSimTpSessionController();
    _controller.createDraft();
    _controller.publish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('student-web-hub-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(title: const Text('Atelier BEP1')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.xl),
              children: <Widget>[
                Text(
                  'Espace élève',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Session active — accès limité aux activités autorisées.',
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                _StudentActionCard(
                  icon: Icons.electrical_services_outlined,
                  title: 'Simulateur',
                  description:
                      'Ouvrir l’atelier ElectroSim dans ce navigateur.',
                  enabled: true,
                  onPressed: () {},
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                _StudentActionCard(
                  icon: Icons.assignment_outlined,
                  title: _controller.title,
                  description:
                      'TP publié par le professeur et disponible pendant cette séance.',
                  enabled: true,
                  onPressed: () {},
                ),
              ],
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
