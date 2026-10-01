import 'dart:async';

import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f18_shell_navigation.dart';
import 'f9_ui_context.dart';
import 'runtime/electrosim_lan_sync.dart';
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
    this.controller,
  });

  final F18SessionWorkspaceBuilder workspaceBuilder;
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

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ElectroSimTpSessionController();
  }

  @override
  Widget build(BuildContext context) {
    return F18SessionShellPage(
      onHome: _goHome,
      onWiring: () => _openWorkspace('Câblage'),
      onTroubleshooting: () => _openWorkspace('Recherche de dérangement'),
      onSupervision: _openSupervision,
      onManageSession: () {
        unawaited(_showManageSession());
      },
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  void _openWorkspace(String workspace) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => widget.workspaceBuilder(
          routeContext,
          _controller,
          workspace,
          () => Navigator.of(routeContext).pop(),
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
      ),
    );
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
      sessionCode: ElectroSimLanSyncHost.generateSessionCode(),
    );
    try {
      final ElectroSimLanHostInfo info = await host.start();
      if (!mounted) {
        await host.close();
        throw StateError('Session teacher shell disposed during LAN start.');
      }
      _lanHost = host;
      _lanInfo = info;
      return info;
    } on Object {
      await host.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    final ElectroSimLanSyncHost? host = _lanHost;
    _lanHost = null;
    _lanInfo = null;
    if (host != null) {
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
  });

  final ElectroSimTpSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('session-supervision-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Retour au tableau de bord',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Supervision'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
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
                child: F17TpSupervisionPanel(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
