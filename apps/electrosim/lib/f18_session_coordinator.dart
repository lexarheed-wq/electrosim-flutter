import 'dart:async';

import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f18_live_supervision_panel.dart';
import 'f18_shell_navigation.dart';
import 'f18_v1_navigation_flow.dart';
import 'f9_ui_context.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_student_web_bundle.dart';
import 'runtime/electrosim_tp_session_controller.dart';

typedef F18SessionWorkspaceBuilder = Widget Function(
  BuildContext context,
  ElectroSimTpSessionController controller,
  String workspace,
  VoidCallback onDashboard,
  VoidCallback onManageSession,
);

class F18TeacherSessionCoordinatorPage extends StatefulWidget {
  const F18TeacherSessionCoordinatorPage({
    super.key,
    required this.workspaceBuilder,
    required this.sessionName,
    required this.sessionCode,
    this.controller,
  });

  final F18SessionWorkspaceBuilder workspaceBuilder;
  final String sessionName;
  final String sessionCode;
  final ElectroSimTpSessionController? controller;

  @override
  State<F18TeacherSessionCoordinatorPage> createState() =>
      _F18TeacherSessionCoordinatorPageState();
}

class _F18TeacherSessionCoordinatorPageState
    extends State<F18TeacherSessionCoordinatorPage> {
  late final ElectroSimTpSessionController _controller;
  late final bool _ownsController;
  ElectroSimLanSyncHost? _lanHost;
  ElectroSimLanHostInfo? _lanInfo;
  bool _waitingRoom = true;
  String? _waitingRoomNetworkStatus;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ElectroSimTpSessionController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_enableWaitingRoomSharing());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingRoom) {
      final ElectroSimLanSyncHost? host = _lanHost;
      return F18SessionWaitingRoomPage(
        sessionName: widget.sessionName,
        sessionCode: widget.sessionCode,
        connectedStudents: host?.connectedStudents.length ?? 0,
        connectedStudentNames: host?.connectedStudents
                .map((ElectroSimConnectedStudent student) => student.displayName)
                .toList(growable: false) ??
            const <String>[],
        joinUrl: _lanInfo?.preferredJoinUrl,
        sharingStatus: _waitingRoomNetworkStatus,
        canStart: _lanInfo != null,
        onHome: _goHome,
        onEnableSharing: () {
          unawaited(_enableWaitingRoomSharing());
        },
        onContinue: () {
          host?.setSessionStarted(true);
          setState(() {
            _waitingRoom = false;
          });
        },
      );
    }
    return F18SessionShellPage(
      sessionName: widget.sessionName,
      onHome: _goHome,
      onWiring: () => _openActivitySetup('Câblage'),
      onTroubleshooting: () => _openActivitySetup('Recherche de dérangement'),
      onSupervision: _openSupervision,
      onManageSession: () {
        unawaited(_showManageSession());
      },
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  void _openActivitySetup(String workspace) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: 'session-${workspace == 'Câblage' ? 'cabling' : 'troubleshooting'}-setup',
        ),
        builder: (BuildContext setupContext) => F18ActivitySetupPage(
          pageKey: Key(
            workspace == 'Câblage'
                ? 'session-cabling-setup-page'
                : 'session-troubleshooting-setup-page',
          ),
          title: workspace == 'Câblage'
              ? 'Préparer l’activité de câblage'
              : 'Préparer la recherche de dérangement',
          description: workspace == 'Câblage'
              ? 'Préparez l’activité avant d’ouvrir l’atelier de câblage.'
              : 'Préparez la situation de diagnostic avant d’ouvrir l’atelier.',
          parentLabel: 'tableau de bord',
          onBack: () => Navigator.of(setupContext).pop(),
          onOpenWorkshop: () => _openWorkspace(setupContext, workspace),
        ),
      ),
    );
  }

  void _openWorkspace(BuildContext setupContext, String workspace) {
    Navigator.of(setupContext).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: 'session-${workspace == 'Câblage' ? 'cabling' : 'troubleshooting'}-workspace',
        ),
        builder: (BuildContext routeContext) => widget.workspaceBuilder(
          routeContext,
          _controller,
          workspace,
          () => Navigator.of(routeContext).popUntil(
            (Route<dynamic> route) =>
                route.settings.name == 'teacher-session',
          ),
          () {
            unawaited(_showManageSession());
          },
        ),
      ),
    );
  }

  void _openSupervision() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => F18SessionSupervisionPage(
          controller: _controller,
          lanHost: _lanHost,
        ),
      ),
    );
  }

  Future<void> _showManageSession() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => F17TpSessionDialog(
        controller: _controller,
        role: F9UserRole.teacher,
        initialLanHostInfo: _lanInfo,
        onEnableLanSharing: _enableLanSharing,
        onStudentStarted: (_) {},
        onCloseClassroomSession: _closeClassroomSession,
      ),
    );
  }

  void _closeClassroomSession() {
    _lanHost?.closeClassroomSession();
    _goHome();
  }

  Future<void> _enableWaitingRoomSharing() async {
    setState(() {
      _waitingRoomNetworkStatus = 'Activation du partage réseau…';
    });
    try {
      final ElectroSimLanHostInfo info = await _enableLanSharing();
      if (!mounted) return;
      setState(() {
        _waitingRoomNetworkStatus =
            'Serveur local prêt : ${info.preferredJoinUrl}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _waitingRoomNetworkStatus = 'Partage réseau indisponible : $error';
      });
    }
  }

  Future<ElectroSimLanHostInfo> _enableLanSharing() async {
    final ElectroSimLanSyncHost? existingHost = _lanHost;
    final ElectroSimLanHostInfo? existingInfo = _lanInfo;
    if (existingHost != null &&
        existingHost.isRunning &&
        existingInfo != null) {
      return existingInfo;
    }

    final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
      controller: _controller,
      sessionCode: widget.sessionCode,
      sessionName: widget.sessionName,
      studentWebRoot: ElectroSimStudentWebBundleLocator.resolve(),
    );
    try {
      final ElectroSimLanHostInfo info = await host.start();
      if (!mounted) {
        await host.close();
        throw StateError('Session teacher shell disposed during LAN start.');
      }
      _lanHost = host;
      _lanInfo = info;
      host.addListener(_onLanHostChanged);
      return info;
    } on Object {
      await host.close();
      rethrow;
    }
  }

  void _onLanHostChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final ElectroSimLanSyncHost? host = _lanHost;
    _lanHost = null;
    _lanInfo = null;
    if (host != null) {
      host.removeListener(_onLanHostChanged);
      unawaited(host.close());
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }
}

class F18SessionSupervisionPage extends StatelessWidget {
  const F18SessionSupervisionPage({
    super.key,
    required this.controller,
    this.lanHost,
    this.proofStudents,
    this.onGradeStudentOverride,
    this.onCloseStudentOverride,
    this.initialSelectedClientId,
  });

  final ElectroSimTpSessionController controller;
  final ElectroSimLanSyncHost? lanHost;
  final List<F17StudentSupervisionItem>? proofStudents;
  final ValueChanged<F17StudentGradeRequest>? onGradeStudentOverride;
  final ValueChanged<String>? onCloseStudentOverride;
  final String? initialSelectedClientId;

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables = <Listenable>[
      controller,
      if (lanHost != null) lanHost!,
    ];
    return Scaffold(
      key: const Key('session-supervision-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('session-supervision-back'),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Retour au tableau de bord',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Supervision'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(ElectroSimSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ElectroSimColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(ElectroSimRadii.card),
                  border: Border.all(
                    color: ElectroSimColors.outline.withValues(alpha: .55),
                  ),
                  boxShadow: ElectroSimComponentTokens.cardElevation,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge(listenables),
                  builder: (BuildContext context, Widget? child) {
                    final ElectroSimLanSyncHost? host = lanHost;
                    final List<F17StudentSupervisionItem> students =
                        proofStudents ??
                            host?.studentSupervisionStates
                                .map(
                                  (ElectroSimStudentSupervisionState state) =>
                                      F17StudentSupervisionItem(
                                    clientId: state.clientId,
                                    displayName: state.displayName,
                                    connected: state.connected,
                                    session: state.session,
                                    lastActivityAtUtc:
                                        state.lastActivityAtUtc,
                                  ),
                                )
                                .toList(growable: false) ??
                            const <F17StudentSupervisionItem>[];

                    return F18LiveSupervisionPanel(
                      controller: controller,
                      students: students,
                      initialSelectedClientId: initialSelectedClientId,
                      onGradeStudent: onGradeStudentOverride ??
                          (host == null
                              ? null
                              : (F17StudentGradeRequest request) {
                                  host.evaluateStudent(
                                    request.clientId,
                                    score: request.score,
                                  );
                                }),
                      onCloseStudent: onCloseStudentOverride ??
                          (host == null
                              ? null
                              : (String clientId) {
                                  host.closeStudent(clientId);
                                }),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

