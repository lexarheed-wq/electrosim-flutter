import 'dart:async';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f18_component_archetypes.dart';
import 'f18_home.dart';
import 'f18_magicpath_parity.dart';
import 'f18_session_coordinator.dart';
import 'f18_shell_navigation.dart';
import 'f18_workspace_wire_safety.dart';
import 'f9_auto_placement.dart';
import 'f9_component_palette.dart';
import 'f9_wiring_policy.dart';
import 'f9_ui_context.dart';
import 'f9_context_panels.dart';
import 'f9_component_visuals.dart';
import 'f9_element_editor.dart';
import 'f9_canvas_interaction.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_persistence_controller.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrosim_tp_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ElectroSimPersistenceController persistenceController =
      await ElectroSimPersistenceController.createDefault();
  runApp(ElectroSimApp(persistenceController: persistenceController));
}

class ElectroSimApp extends StatelessWidget {
  const ElectroSimApp({super.key, this.persistenceController});

  final ElectroSimPersistenceController? persistenceController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroSim',
      theme: ElectroSimTheme.light(),
      home: F9HomePage(persistenceController: persistenceController),
    );
  }
}

class F9HomePage extends StatelessWidget {
  const F9HomePage({super.key, this.persistenceController});

  final ElectroSimPersistenceController? persistenceController;

  @override
  Widget build(BuildContext context) {
    return F18HomeSurface(
      onCreateSession: () => _openSessionShell(
        context,
        persistenceController,
      ),
      onMaintenance: () => _openMaintenanceCenter(
        context,
        persistenceController,
      ),
      onDesign: () => _openDesignCenter(
        context,
        persistenceController,
      ),
      onJoinSession: () => _joinLanSession(
        context,
        persistenceController,
      ),
    );
  }

  static Future<void> _joinLanSession(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) async {
    final _NetworkJoinRequest? request =
        await showDialog<_NetworkJoinRequest>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const _NetworkJoinDialog(),
    );
    if (request == null || !context.mounted) return;

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
      controller: controller,
      sessionCode: request.sessionCode,
      clientId: ElectroSimLanSyncClient.generateClientId(),
    );
    try {
      await client.connect(request.endpoint);
      if (!context.mounted) {
        await client.close();
        controller.dispose();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => F18WorkspacePage(
            entryLabel: 'Session élève',
            initialWorkspace: 'Recherche de dérangement',
            sessionNavigation: true,
            role: F9UserRole.student,
            tpSessionController: controller,
            persistenceController: persistenceController,
            syncClient: client,
          ),
        ),
      );
    } on Object catch (error) {
      await client.close();
      controller.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Connexion à la session impossible : $error',
            ),
          ),
        );
    }
  }

  static void _openDesignCenter(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => F18DesignCenterPage(
          onHome: () => Navigator.of(routeContext).popUntil(
            (Route<dynamic> route) => route.isFirst,
          ),
          onWiring: () => _openWorkspace(
            routeContext,
            'Centre de conception',
            initialWorkspace: 'Câblage',
            persistenceController: persistenceController,
          ),
          onSchemaLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const F18PlaceholderPage(
                pageKey: Key('design-schema-library-page'),
                title: 'Bibliothèque de schémas',
                description:
                    'Les schémas sains seront gérés dans la bibliothèque de conception F18.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _openMaintenanceCenter(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => F18MaintenanceCenterPage(
          onHome: () => Navigator.of(routeContext).popUntil(
            (Route<dynamic> route) => route.isFirst,
          ),
          onTroubleshooting: () => _openWorkspace(
            routeContext,
            'Centre de maintenance',
            initialWorkspace: 'Recherche de dérangement',
            persistenceController: persistenceController,
          ),
          onFaultLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const F18PlaceholderPage(
                pageKey: Key('maintenance-fault-library-page'),
                title: 'Bibliothèque de pannes',
                description:
                    'Les circuits défectueux autonomes seront gérés dans la bibliothèque de maintenance F18.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _openSessionShell(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) =>
            F18TeacherSessionCoordinatorPage(
          workspaceBuilder: (
            BuildContext workspaceContext,
            ElectroSimTpSessionController controller,
            String workspace,
            VoidCallback onDashboard,
            VoidCallback onManageSession,
          ) =>
              F18WorkspacePage(
            entryLabel: 'Session active',
            initialWorkspace: workspace,
            sessionNavigation: true,
            tpSessionController: controller,
            persistenceController: persistenceController,
            onSessionDashboard: onDashboard,
            onSessionManage: onManageSession,
          ),
        ),
      ),
    );
  }

  static void _openWorkspace(
    BuildContext context,
    String entryLabel, {
    required String initialWorkspace,
    bool sessionNavigation = false,
    ElectroSimPersistenceController? persistenceController,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => F18WorkspacePage(
          entryLabel: entryLabel,
          initialWorkspace: initialWorkspace,
          sessionNavigation: sessionNavigation,
          persistenceController: persistenceController,
        ),
      ),
    );
  }
}

final class _NetworkJoinRequest {
  const _NetworkJoinRequest({
    required this.endpoint,
    required this.sessionCode,
  });

  final Uri endpoint;
  final String sessionCode;
}

class _NetworkJoinDialog extends StatefulWidget {
  const _NetworkJoinDialog();

  @override
  State<_NetworkJoinDialog> createState() => _NetworkJoinDialogState();
}

class _NetworkJoinDialogState extends State<_NetworkJoinDialog> {
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejoindre une session'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const Key('join-session-endpoint'),
              controller: _endpoint,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Adresse du professeur',
                hintText: 'ws://192.168.1.20:12345/electrosim-sync',
              ),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            TextField(
              key: const Key('join-session-code'),
              controller: _code,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code de session',
                hintText: 'ABC234',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.sm),
              Text(
                _error!,
                key: const Key('join-session-error'),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('join-session-submit'),
          onPressed: _submit,
          child: const Text('Rejoindre'),
        ),
      ],
    );
  }

  void _submit() {
    final String rawEndpoint = _endpoint.text.trim();
    final String rawCode = _code.text.trim().toUpperCase();
    final Uri? endpoint = Uri.tryParse(
      rawEndpoint.startsWith('ws://') || rawEndpoint.startsWith('wss://')
          ? rawEndpoint
          : 'ws://$rawEndpoint',
    );
    if (endpoint == null ||
        (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') ||
        endpoint.host.isEmpty) {
      setState(() {
        _error = 'Adresse réseau invalide.';
      });
      return;
    }
    if (rawCode.length != 6 ||
        RegExp(r'[^A-Z2-9]').hasMatch(rawCode)) {
      setState(() {
        _error = 'Le code de session doit contenir 6 caractères.';
      });
      return;
    }
    Navigator.of(context).pop(
      _NetworkJoinRequest(
        endpoint: endpoint,
        sessionCode: rawCode,
      ),
    );
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _code.dispose();
    super.dispose();
  }
}

class F9WorkspaceDemoPage extends F18WorkspacePage {
  const F9WorkspaceDemoPage({
    super.key,
    super.entryLabel = 'Centre de conception',
    super.initialWorkspace = 'Câblage',
    super.sessionNavigation = false,
    super.initialSelectedElementId,
    super.initialCircuit,
    super.role = F9UserRole.teacher,
    super.tpSessionController,
    super.persistenceController,
    super.syncClient,
    super.onSessionDashboard,
    super.onSessionManage,
  });
}

class F18WorkspacePage extends StatefulWidget {
  const F18WorkspacePage({
    super.key,
    this.entryLabel = 'Centre de conception',
    this.initialWorkspace = 'Câblage',
    this.sessionNavigation = false,
    this.initialSelectedElementId,
    this.initialCircuit,
    this.role = F9UserRole.teacher,
    this.tpSessionController,
    this.persistenceController,
    this.syncClient,
    this.onSessionDashboard,
    this.onSessionManage,
  });

  final String entryLabel;
  final String initialWorkspace;
  final bool sessionNavigation;
  final String? initialSelectedElementId;
  final CircuitState? initialCircuit;
  final F9UserRole role;
  final ElectroSimTpSessionController? tpSessionController;
  final ElectroSimPersistenceController? persistenceController;
  final ElectroSimLanSyncClient? syncClient;
  final VoidCallback? onSessionDashboard;
  final VoidCallback? onSessionManage;

  @override
  State<F18WorkspacePage> createState() => _F18WorkspacePageState();
}

class _F18WorkspacePageState extends State<F18WorkspacePage> {
  static const OrthogonalWireRouter _g2aRouter = OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 120,
  );
  static const CircuitWireLayoutEngine _g2aWireLayoutEngine =
      CircuitWireLayoutEngine(router: _g2aRouter);
  static const WirePreviewPlanner _g2aWirePreviewPlanner =
      WirePreviewPlanner(
        router: _g2aRouter,
        terminalSnapRadius: 24,
      );
  static const DcRectangularArrangePolicy _dcArrangePolicy =
      DcRectangularArrangePolicy(
        grid: 24,
        bendKeepOut: 48,
        minimumTerminalStub: 24,
        minimumComponentGap: 48,
      );

  late CircuitState _circuit;
  late CircuitVisualLayout _layout;
  final ViewportController _viewport = ViewportController(scale: 1, translation: const Offset(40, 40));
  final GlobalKey _canvasDropKey = GlobalKey(debugLabel: 'f18-canvas-drop-target');
  late String? _selected;
  String _status = 'ElectroSim F18 — espace de travail prêt';
  late String _workspace;
  bool _simulationMode = false;
  int _canvasInteractionEpoch = 0;
  final HitTestEngine _hitTest = const HitTestEngine();
  TerminalId? _wiringPendingTerminal;
  TerminalId? _wiringHoverTerminal;
  int? _activeCanvasPointer;
  String? _directDragElementId;
  Offset? _directDragGrabDelta;
  Offset? _lastCanvasPointerLocal;
  bool _backgroundPanActive = false;
  bool _directPointerMoved = false;
  bool _trackpadPanZoomActive = false;
  double _trackpadLastScale = 1;
  late final ElectroSimTpSessionController _tpController;
  late final bool _ownsTpController;
  ElectroSimLanSyncHost? _lanHost;
  ElectroSimLanHostInfo? _lanHostInfo;

  bool get _studentTpReadOnly =>
      widget.role == F9UserRole.student && _tpController.readOnly;

  @override
  void initState() {
    super.initState();
    _circuit = widget.initialCircuit ?? _buildDemoCircuit();
    _workspace = widget.initialWorkspace;
    _selected = widget.initialSelectedElementId;
    _ownsTpController = widget.tpSessionController == null;
    _tpController =
        widget.tpSessionController ?? ElectroSimTpSessionController();
    widget.syncClient?.addListener(_onLanSyncChanged);
    final TpSession? tp = _tpController.session;
    if (widget.role == F9UserRole.student &&
        tp != null &&
        tp.lifecycle != TpLifecycle.draft &&
        tp.lifecycle != TpLifecycle.published) {
      _circuit = tp.studentCircuit;
      _workspace = 'Recherche de dérangement';
    }
    _layout = _layoutForCircuit(_circuit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitViewportToMagicPath();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ElectroSimRuntimeSnapshot runtimeSnapshot =
        const ElectroSimRuntimeEngine().evaluate(_circuit);
    final F9ElementDetails? selectedDetails =
        F9ElementEditor.describe(_circuit, _selected);
    final bool canTransformSelection =
        selectedDetails != null && !_studentTpReadOnly && !_simulationMode;
    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _cancelCanvasInteraction,
            const SingleActivator(LogicalKeyboardKey.equal, shift: true): () => _viewport.zoomAt(const Offset(400, 300), 1.1),
            const SingleActivator(LogicalKeyboardKey.minus): () => _viewport.zoomAt(const Offset(400, 300), 0.9),
          },
          child: Focus(
            autofocus: true,
            child: ElectroSimWorkspaceShell(
          topBar: _WorkspaceTopBar(
            entryLabel: widget.entryLabel,
            workspace: _workspace,
            sessionNavigation: widget.sessionNavigation,
            onHome: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
            onDashboard: widget.sessionNavigation
                ? (widget.onSessionDashboard ?? _showDashboard)
                : null,
            onManageSession: widget.sessionNavigation
                ? (widget.onSessionManage ?? _showManageSession)
                : null,
            onSave: widget.persistenceController == null ? null : _saveWorkspace,
            onOpen: widget.persistenceController == null ? null : _openLatestWorkspace,
            studentTroubleshooting:
                widget.role == F9UserRole.student &&
                    _workspace == 'Recherche de dérangement',
            studentSubtitle:
                _tpController.session?.definition.title ??
                    'TP 04 · Circuit d’éclairage 24 V',
            studentSessionLabel:
                _tpController.session?.definition.id.value ?? 'LOCAL',
            simulationMode: _simulationMode,
            onModeChanged: (bool simulation) {
              setState(() {
                _simulationMode = simulation;
                _status = simulation
                    ? 'Simulation active — édition du montage verrouillée.'
                    : 'Mode édition — le montage peut être modifié.';
              });
            },
            onRecenter: _fitViewportToMagicPath,
          ),
          palette: F9ComponentPalette(
            onStatus: _setStatus,
            onQuickAdd: _quickAddFromPalette,
          ),
          contextPanel: _workspace == 'Supervision' && widget.role == F9UserRole.teacher
              ? F17TpSupervisionPanel(controller: _tpController)
              : F9ContextPanels(
            circuit: _circuit,
            selectedId: _selected,
            status: _status,
            workspace: _workspace,
            role: widget.role,
            onTogglePrimaryState: _selected == null ? null : _toggleSelectedPrimaryState,
            onReplaceSelected: _selected == null ? null : _replaceSelectedElement,
            onSelectElement: (String? id) {
              setState(() {
                _selected = id;
                _status = id == null ? 'Sélection effacée' : 'Sélection clavier : $id';
              });
            },
            runtimeSnapshot: runtimeSnapshot,
            tpSessionController:
                widget.sessionNavigation || widget.tpSessionController != null
                    ? _tpController
                    : null,
          ),
          statusBar: _StatusBar(circuit: _circuit, status: _status),
          showStatusBar: false,
          showCompactPanelSwitcher: false,
          showMediumPanelSwitcher: false,
          mediumPanelInitiallyVisible:
              widget.role == F9UserRole.student &&
                  _workspace == 'Recherche de dérangement',
          expandedPaletteWidth: ElectroSimGeometry.expandedPaletteWidth,
          expandedContextWidth: ElectroSimGeometry.expandedContextWidth,
          mediumPanelWidth: 288,
          canvas: KeyedSubtree(
            key: const Key('f18-canvas-drop-region'),
            child: DragTarget<F9PaletteDefinition>(
              key: _canvasDropKey,
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: _acceptPaletteDrop,
              builder: (
                BuildContext context,
                List<F9PaletteDefinition?> candidateData,
                List<dynamic> rejectedData,
              ) {
                return ClipRect(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: candidateData.isEmpty
                          ? null
                          : Border.all(color: ElectroSimColors.primary, width: 2),
                    ),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onCanvasPointerDown,
                      onPointerMove: _onCanvasPointerMove,
                      onPointerUp: _onCanvasPointerUp,
                      onPointerCancel: _onCanvasPointerCancel,
                      onPointerHover: _onCanvasPointerHover,
                      onPointerSignal: _onCanvasPointerSignal,
                      onPointerPanZoomStart: _onCanvasPointerPanZoomStart,
                      onPointerPanZoomUpdate: _onCanvasPointerPanZoomUpdate,
                      onPointerPanZoomEnd: _onCanvasPointerPanZoomEnd,
                      child: Stack(
                      clipBehavior: Clip.hardEdge,
                      fit: StackFit.expand,
                      children: <Widget>[
                        SimulatorCanvas(
                        key: ValueKey<int>(_canvasInteractionEpoch),
                        circuit: _circuit,
                        layout: _layout,
                        viewportController: _viewport,
                        selectedElementId: _selected,
                        onSelectionChanged: (String? id) {
                          setState(() {
                            _selected = id;
                            _status = id == null ? 'Sélection effacée' : 'Sélection : $id';
                          });
                        },
                        onElementMoved: (String id, Offset position) {
                          _commitElementMoveIfSafe(id, position);
                        },
                        onConnectionRequested: _handleConnectionRequested,
                        onContextAction: (CanvasHitResult hit) {
                          setState(() {
                            _status = 'Action contextuelle : ${hit.kind.name}. Les mêmes actions sont disponibles dans Propriétés.';
                          });
                        },
                        enableInteraction: false,
                        wireLayoutEngine: _g2aWireLayoutEngine,
                        wirePreviewPlanner: _g2aWirePreviewPlanner,
                        elementVisualPainter: (
                          Canvas canvas,
                          Rect screenRect,
                          String elementId,
                          String modelType,
                          bool source,
                          bool selected,
                          double viewportScale,
                        ) {
                          bool active = true;
                          bool fault = false;
                          if (source) {
                            for (final SourceInstance item in _circuit.sources) {
                              if (item.id.value == elementId) {
                                active = item.enabled;
                                break;
                              }
                            }
                          } else {
                            ComponentInstance? instance;
                            for (final ComponentInstance item
                                in _circuit.components) {
                              if (item.id.value == elementId) {
                                instance = item;
                                break;
                              }
                            }
                            if (instance != null) {
                              fault =
                                  instance.condition != ComponentCondition.normal;
                              final Object? closed =
                                  instance.controlState['closed'];
                              active = instance.condition !=
                                      ComponentCondition.disabled &&
                                  closed != false;

                              final String type = modelType.toLowerCase();
                              final bool currentDrivenVisual =
                                  type.contains('lamp') ||
                                      type.contains('motor') ||
                                      type.contains('fan') ||
                                      type.contains('buzzer') ||
                                      type.contains('relay_coil') ||
                                      type.contains('contactor');
                              if (currentDrivenVisual &&
                                  runtimeSnapshot.dcResult != null) {
                                try {
                                  final double? current = runtimeSnapshot.dcResult!
                                      .branch('component:$elementId')
                                      .currentA;
                                  active = current != null &&
                                      current.abs() > 1e-6;
                                } on StateError {
                                  // Some UI-only components are intentionally
                                  // absent from the solver branch inventory.
                                }
                              }
                            }
                          }
                          paintF18MagicPathCanvasElement(
                            canvas,
                            screenRect,
                            elementId,
                            modelType,
                            source,
                            selected,
                            viewportScale,
                            active: active,
                            fault: fault,
                          );
                        },
                        showElementLabels: false,
                        preserveCommittedWireRoutes: true,
                      ),
                      F18CircuitZoneOverlay(
                        circuit: _circuit,
                        layout: _layout,
                        viewport: _viewport,
                        title: _workspace == 'Recherche de dérangement'
                            ? 'Circuit de recherche de dérangement'
                            : 'Circuit 24 V DC · commande simple',
                        framePadding:
                            widget.role == F9UserRole.student &&
                                    _workspace == 'Recherche de dérangement'
                                ? const EdgeInsets.fromLTRB(34, 115, 46, 114)
                                : MediaQuery.sizeOf(context).width <
                                        ElectroSimBreakpoints.compactUpperBound
                                    ? const EdgeInsets.fromLTRB(28, 92, 16, 81)
                                    : const EdgeInsets.fromLTRB(55, 84, 41, 35),
                      ),
                      AnimatedBuilder(
                        animation: _viewport,
                        builder: (BuildContext context, Widget? child) => F9CanvasVisualOverlay(
                          circuit: _circuit,
                          layout: _layout,
                          viewport: _viewport,
                          pendingTerminalId: _wiringPendingTerminal,
                          hoverTerminalId: _wiringHoverTerminal,
                          pointerWorldPosition: _lastCanvasPointerLocal == null
                              ? null
                              : _viewport.screenToWorld(_lastCanvasPointerLocal!),
                          wirePreviewPlanner: _g2aWirePreviewPlanner,
                          paintElementGlyphs: false,
                          showFaultMarkers:
                              widget.role != F9UserRole.student,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 14,
                        child: F18CanvasToolbar(
                          onRecenter: _fitViewportToMagicPath,
                          onStatus: _setStatus,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 14,
                        child: _selected == null
                            ? F18ZoomChip(viewport: _viewport)
                            : F18SelectionToolbar(
                                onRotate: canTransformSelection
                                    ? _rotateSelectedElement
                                    : null,
                                onDelete: canTransformSelection
                                    ? _deleteSelectedElement
                                    : null,
                              ),
                      ),
                      if (widget.role == F9UserRole.student &&
                          _workspace == 'Recherche de dérangement' &&
                          MediaQuery.sizeOf(context).width >=
                              ElectroSimBreakpoints.compactUpperBound)
                        const Positioned(
                          left: 20,
                          right: 20,
                          top: 490,
                          child: F18TroubleshootingProgressCard(),
                        ),
                      if (_selected == null)
                        Positioned(
                          right: 16,
                          top: 14,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0,
                              child: F18SelectionToolbar(
                                onRotate: null,
                                onDelete: null,
                              ),
                            ),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
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

  Future<void> _showDashboard() async {
    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Tableau de bord'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DashboardDestination(
                key: const Key('dashboard-wiring'),
                icon: Icons.cable_outlined,
                title: 'Câblage',
                description: 'Préparer ou suivre une activité de câblage.',
                onTap: () => Navigator.of(dialogContext).pop('Câblage'),
              ),
              const SizedBox(height: ElectroSimSpacing.xs),
              _DashboardDestination(
                key: const Key('dashboard-troubleshooting'),
                icon: Icons.troubleshoot_outlined,
                title: 'Recherche de dérangement',
                description: 'Préparer ou suivre un diagnostic sur scénario défectueux.',
                onTap: () => Navigator.of(dialogContext).pop('Recherche de dérangement'),
              ),
              const SizedBox(height: ElectroSimSpacing.xs),
              _DashboardDestination(
                key: const Key('dashboard-supervision'),
                icon: Icons.monitor_heart_outlined,
                title: 'Supervision',
                description: 'Consulter la progression et les résultats de la session.',
                onTap: () => Navigator.of(dialogContext).pop('Supervision'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _workspace = selected;
      _status = 'Espace UI : $selected';
    });
  }

  Future<void> _saveWorkspace() async {
    final ElectroSimPersistenceController? persistence =
        widget.persistenceController;
    if (persistence == null) return;
    try {
      final saved = await persistence.saveWorkspace(
        circuit: _circuit,
        workspace: _workspace,
        tpController: _tpController,
      );
      if (!mounted) return;
      _setStatus(
        'Sauvegarde locale : révision ${saved.circuit.revision} — ${saved.saveId}',
      );
    } catch (error) {
      if (!mounted) return;
      _setStatus('Échec de sauvegarde locale : $error');
    }
  }

  Future<void> _openLatestWorkspace() async {
    final ElectroSimPersistenceController? persistence =
        widget.persistenceController;
    if (persistence == null) return;
    try {
      final restored = await persistence.openLatest(tpController: _tpController);
      if (!mounted) return;
      if (restored == null) {
        _setStatus('Aucune sauvegarde locale disponible.');
        return;
      }
      setState(() {
        _circuit = restored.circuit;
        _workspace = restored.workspace;
        _selected = null;
        _layout = _layoutForCircuit(_circuit);
        _status =
            'Session reprise : révision ${_circuit.revision} — ${restored.saveId}';
      });
    } catch (error) {
      if (!mounted) return;
      _setStatus('Échec de reprise locale : $error');
    }
  }

  Future<ElectroSimLanHostInfo> _enableLanSharing() async {
    final ElectroSimLanSyncHost? existing = _lanHost;
    final ElectroSimLanHostInfo? existingInfo = _lanHostInfo;
    if (existing != null && existingInfo != null) return existingInfo;

    final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
      controller: _tpController,
      sessionCode: ElectroSimLanSyncHost.generateSessionCode(),
    );
    try {
      final ElectroSimLanHostInfo info = await host.start();
      _lanHost = host;
      _lanHostInfo = info;
      if (mounted) {
        _setStatus(
          'Partage réseau actif — code ${info.sessionCode}',
        );
      }
      return info;
    } on Object {
      await host.close();
      rethrow;
    }
  }

  void _onLanSyncChanged() {
    if (!mounted) return;
    final ElectroSimLanSyncClient? client = widget.syncClient;
    if (client == null) return;
    final TpSession? session = _tpController.session;

    var circuitChanged = false;
    if (widget.role == F9UserRole.student &&
        session != null &&
        session.lifecycle != TpLifecycle.draft &&
        session.lifecycle != TpLifecycle.published &&
        (session.studentCircuit.circuitId != _circuit.circuitId ||
            session.studentCircuit.revision != _circuit.revision)) {
      _circuit = session.studentCircuit;
      _layout = _layoutForCircuit(_circuit);
      _workspace = 'Recherche de dérangement';
      _selected = null;
      circuitChanged = true;
    }

    setState(() {
      if (client.lastError != null) {
        _status = 'Synchronisation : ${client.lastError}';
      } else if (client.status == ElectroSimLanSyncStatus.reconnecting) {
        _status = 'Reconnexion au professeur…';
      } else if (client.status == ElectroSimLanSyncStatus.disconnected) {
        _status = 'Connexion professeur interrompue.';
      } else if (circuitChanged) {
        _status = 'Montage synchronisé avec le professeur.';
      }
    });
  }

  Future<void> _showManageSession() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => F17TpSessionDialog(
        controller: _tpController,
        role: widget.role,
        initialLanHostInfo: _lanHostInfo,
        onEnableLanSharing:
            widget.role == F9UserRole.teacher ? _enableLanSharing : null,
        onStudentStarted: (TpSession session) {
          setState(() {
            _circuit = session.studentCircuit;
            _layout = _layoutForCircuit(_circuit);
            _selected = null;
            _workspace = 'Recherche de dérangement';
            _status = 'TP commencé — montage élève chargé.';
          });
        },
      ),
    );
    if (!mounted) {
      return;
    }
    final TpSession? session = _tpController.session;
    if (session != null) {
      setState(() {
        _status =
            'TP ${session.definition.id.value} — ${session.lifecycle.name}';
      });
    }
  }

  void _acceptPaletteDrop(DragTargetDetails<F9PaletteDefinition> details) {
    final BuildContext? dropContext = _canvasDropKey.currentContext;
    if (dropContext == null) {
      _setStatus('Ajout impossible : zone de dépôt indisponible.');
      return;
    }
    final RenderObject? renderObject = dropContext.findRenderObject();
    if (renderObject is! RenderBox) {
      _setStatus('Ajout impossible : géométrie de la platine indisponible.');
      return;
    }
    final Offset local = renderObject.globalToLocal(details.offset);
    _addPaletteDefinition(details.data, _viewport.screenToWorld(local));
  }

  void _quickAddFromPalette(F9PaletteDefinition definition) {
    final RenderObject? renderObject = _canvasDropKey.currentContext?.findRenderObject();
    final Size size = renderObject is RenderBox ? renderObject.size : const Size(800, 520);
    final Offset topLeft = _viewport.screenToWorld(Offset.zero);
    final Offset bottomRight = _viewport.screenToWorld(Offset(size.width, size.height));
    final Rect visibleWorldRect = Rect.fromPoints(topLeft, bottomRight);
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(_circuit, _layout);
    final List<List<Offset>> polylines = <List<Offset>>[];
    for (final Connection connection in _circuit.connections) {
      final Offset? start = geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      polylines.add(<Offset>[start, ..._layout.routeFor(connection.id.value), end]);
    }
    final Offset? position = F9AutoPlacement.findPosition(
      visibleWorldRect: visibleWorldRect,
      elementSize: _layout.defaultElementSize,
      occupiedElements: geometry.elementRects.values,
      occupiedPolylines: polylines,
    );
    if (position == null) {
      _setStatus(
        'Ajout rapide impossible : aucune zone libre visible. Glissez le composant sur la platine.',
      );
      return;
    }
    _addPaletteDefinition(definition, position);
  }

  String _allocateElementId(String keyName) {
    final Set<String> usedIds = <String>{
      ..._circuit.components.map((ComponentInstance item) => item.id.value),
      ..._circuit.sources.map((SourceInstance item) => item.id.value),
    };
    var serial = 1;
    while (usedIds.contains('$keyName-$serial')) {
      serial += 1;
    }
    return '$keyName-$serial';
  }

  void _addPaletteDefinition(F9PaletteDefinition definition, Offset worldPosition) {
    if (_blockStudentTpMutation()) return;
    final String elementId = _allocateElementId(definition.keyName);
    final List<Terminal> terminals = _buildPaletteTerminals(definition, elementId);
    final List<ComponentInstance> components = <ComponentInstance>[..._circuit.components];
    final List<SourceInstance> sources = <SourceInstance>[..._circuit.sources];

    if (definition.kind == F9PaletteElementKind.source) {
      sources.add(
        SourceInstance(
          id: SourceId(elementId),
          modelType: definition.modelType,
          terminals: terminals,
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      );
    } else {
      components.add(
        ComponentInstance(
          id: ComponentId(elementId),
          modelType: definition.modelType,
          terminals: terminals,
          parameters: _defaultParametersFor(definition.keyName),
          controlState: _defaultControlStateFor(definition.keyName),
        ),
      );
    }

    final CircuitState nextCircuit = CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: _circuit.mode,
      components: components,
      connections: _circuit.connections,
      sources: sources,
      settings: _circuit.settings,
      metadata: _circuit.metadata,
    );

    setState(() {
      _circuit = nextCircuit;
      _layout = _routeWithG2A(_circuit, _layout.moveElement(elementId, worldPosition));
      _selected = elementId;
      _status = 'Ajout : ${definition.title} — $elementId';
    });
    _syncStudentTpCircuit();
  }

  List<Terminal> _buildPaletteTerminals(F9PaletteDefinition definition, String elementId) {
    if (definition.kind == F9PaletteElementKind.source) {
      return <Terminal>[
        Terminal(
          id: TerminalId('$elementId-pos'),
          name: '+',
          role: TerminalRole.positive,
          phase: PhaseTag.dcPositive,
        ),
        Terminal(
          id: TerminalId('$elementId-neg'),
          name: '−',
          role: TerminalRole.negative,
          phase: PhaseTag.dcNegative,
        ),
      ];
    }
    final List<String> labels = definition.terminalLabels.length >= 2
        ? definition.terminalLabels
        : const <String>['1', '2'];
    return <Terminal>[
      Terminal(
        id: TerminalId('$elementId-a'),
        name: labels.first,
        role: _roleForTerminalLabel(labels.first, fallback: TerminalRole.input),
        phase: _phaseForTerminalLabel(labels.first),
      ),
      Terminal(
        id: TerminalId('$elementId-b'),
        name: labels[1],
        role: _roleForTerminalLabel(labels[1], fallback: TerminalRole.output),
        phase: _phaseForTerminalLabel(labels[1]),
      ),
    ];
  }

  PhaseTag _phaseForTerminalLabel(String label) {
    if (label == '+') {
      return PhaseTag.dcPositive;
    }
    if (label == '−') {
      return PhaseTag.dcNegative;
    }
    return PhaseTag.none;
  }

  TerminalRole _roleForTerminalLabel(String label, {required TerminalRole fallback}) {
    if (label == '+') {
      return TerminalRole.positive;
    }
    if (label == '−') {
      return TerminalRole.negative;
    }
    return fallback;
  }

  Map<String, Object?> _defaultParametersFor(String keyName) => switch (keyName) {
    'lamp' => const <String, Object?>{'resistanceOhm': 24.0},
    'resistor' => const <String, Object?>{'resistanceOhm': 100.0},
    'buzzer' => const <String, Object?>{'resistanceOhm': 48.0},
    'fan-dc' => const <String, Object?>{'resistanceOhm': 12.0},
    'motor-dc' => const <String, Object?>{'resistanceOhm': 8.0},
    'relay-coil' => const <String, Object?>{'resistanceOhm': 120.0},
    _ => const <String, Object?>{},
  };

  Map<String, Object?> _defaultControlStateFor(String keyName) => switch (keyName) {
    'switch-no' => const <String, Object?>{'closed': false},
    'push-button-no' => const <String, Object?>{'closed': false},
    'breaker' => const <String, Object?>{'closed': true, 'tripped': false},
    'fuse' => const <String, Object?>{'blown': false},
    _ => const <String, Object?>{},
  };

  CanvasHitResult _f9CanvasHit(Offset localPosition) => _hitTest.hitTest(
    worldPoint: _viewport.screenToWorld(localPosition),
    circuit: _circuit,
    layout: _layout,
    viewportScale: _viewport.scale,
  );

  void _onCanvasPointerDown(PointerDownEvent event) {
    if (_activeCanvasPointer != null) {
      return;
    }
    // MagicPath canvas chrome occupies the first 64 logical pixels. Those
    // controls must not also trigger background selection/pan handlers.
    if (event.localPosition.dy < 64) {
      return;
    }
    final CanvasHitResult hit = _f9CanvasHit(event.localPosition);
    _activeCanvasPointer = event.pointer;
    _lastCanvasPointerLocal = event.localPosition;
    _directPointerMoved = false;
    _backgroundPanActive = false;
    _directDragElementId = null;
    _directDragGrabDelta = null;

    if (hit.kind == CanvasHitKind.terminal && hit.terminalId != null) {
      if (_studentTpReadOnly) {
        _setStatus('TP remis : câblage en lecture seule.');
        _clearDirectPointerState();
        return;
      }
      final TerminalId terminal = hit.terminalId!;
      final TerminalId? pending = _wiringPendingTerminal;
      if (pending != null && pending != terminal) {
        _handleConnectionRequested(pending, terminal);
        _clearDirectPointerState();
        return;
      }
      setState(() {
        if (pending == null) {
          _wiringPendingTerminal = terminal;
          _wiringHoverTerminal = terminal;
          _status = 'Câblage : borne ${terminal.value} sélectionnée. Choisissez une cible.';
        } else {
          _wiringPendingTerminal = null;
          _wiringHoverTerminal = null;
          _status = 'Câblage annulé : borne de départ désélectionnée.';
        }
      });
      return;
    }

    if (hit.kind == CanvasHitKind.component || hit.kind == CanvasHitKind.source) {
      final String id = hit.elementId!;
      final Offset? current = _layout.positionOf(id);
      if (current == null) {
        return;
      }
      final Offset world = _viewport.screenToWorld(event.localPosition);
      setState(() {
        _selected = id;
        if (!_studentTpReadOnly) {
          _directDragElementId = id;
          _directDragGrabDelta = current - world;
        }
        _status = _studentTpReadOnly
            ? 'Sélection : $id — TP en lecture seule'
            : 'Sélection : $id';
      });
      return;
    }

    if (hit.kind == CanvasHitKind.wire) {
      setState(() {
        _selected = hit.connectionId?.value;
        _status = 'Sélection : ${hit.connectionId?.value ?? 'fil'}';
      });
      return;
    }

    if (hit.kind == CanvasHitKind.background) {
      _backgroundPanActive = true;
      if (_wiringPendingTerminal != null) {
        setState(() {
          _wiringPendingTerminal = null;
          _wiringHoverTerminal = null;
          _status = 'Câblage annulé par clic sur le fond.';
        });
      }
    }
  }

  void _onCanvasPointerMove(PointerMoveEvent event) {
    if (_activeCanvasPointer != event.pointer) {
      return;
    }
    final Offset? previous = _lastCanvasPointerLocal;
    _lastCanvasPointerLocal = event.localPosition;
    if (previous != null && (event.localPosition - previous).distance > 0.1) {
      _directPointerMoved = true;
    }

    final String? draggingId = _directDragElementId;
    final Offset? grabDelta = _directDragGrabDelta;
    if (draggingId != null && grabDelta != null) {
      final Offset world = _viewport.screenToWorld(event.localPosition);
      final Offset nextPosition = world + grabDelta;
      _commitElementMoveIfSafe(
        draggingId,
        nextPosition,
        moving: true,
      );
      return;
    }

    if (_backgroundPanActive && previous != null) {
      final Offset proposed = _viewport.translation + (event.localPosition - previous);
      _setBoundedViewportTranslation(proposed);
      return;
    }

    _updateWiringHover(event.localPosition);
  }

  void _onCanvasPointerUp(PointerUpEvent event) {
    if (_activeCanvasPointer != event.pointer) {
      return;
    }
    final String? movedId = _directDragElementId;
    final bool moved = _directPointerMoved && movedId != null;
    if (moved) {
      setState(() {
        _status = 'Position graphique mise à jour : $movedId';
      });
    } else if (_backgroundPanActive && !_directPointerMoved && _wiringPendingTerminal == null) {
      setState(() {
        _selected = null;
        _status = 'Sélection effacée';
      });
    }
    _clearDirectPointerState();
  }

  void _onCanvasPointerCancel(PointerCancelEvent event) {
    if (_activeCanvasPointer == event.pointer) {
      _clearDirectPointerState();
    }
  }

  void _clearDirectPointerState() {
    _activeCanvasPointer = null;
    _directDragElementId = null;
    _directDragGrabDelta = null;
    _lastCanvasPointerLocal = null;
    _backgroundPanActive = false;
    _directPointerMoved = false;
  }

  void _onCanvasPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _trackpadPanZoomActive) {
      return;
    }
    // macOS trackpads commonly expose a two-finger translation as scroll.
    // Treat it as canvas pan; pinch zoom is handled by PointerPanZoom events.
    _setBoundedViewportTranslation(_viewport.translation - event.scrollDelta);
  }

  void _onCanvasPointerPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadPanZoomActive = true;
    _trackpadLastScale = 1;
    _clearDirectPointerState();
  }

  void _onCanvasPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_trackpadPanZoomActive) {
      return;
    }

    if (event.localPanDelta != Offset.zero) {
      _setBoundedViewportTranslation(_viewport.translation + event.localPanDelta);
    }

    final double cumulativeScale = event.scale;
    if (cumulativeScale.isFinite && cumulativeScale > 0) {
      final double factor = cumulativeScale / _trackpadLastScale;
      if ((factor - 1).abs() > 0.0005) {
        _viewport.zoomAt(event.localPosition, factor);
        _clampCurrentViewport();
      }
      _trackpadLastScale = cumulativeScale;
    }
  }

  void _onCanvasPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadPanZoomActive = false;
    _trackpadLastScale = 1;
    _clampCurrentViewport();
  }

  void _onCanvasPointerHover(PointerHoverEvent event) => _updateWiringHover(event.localPosition);

  void _fitViewportToMagicPath() {
    final Size viewportSize = _canvasViewportSize();
    if (viewportSize.isEmpty) {
      return;
    }
    final double windowWidth = MediaQuery.sizeOf(context).width;
    final ElectroSimWindowClass windowClass =
        ElectroSimBreakpoints.classify(windowWidth);
    final bool compact = windowClass == ElectroSimWindowClass.compact;
    final bool medium = windowClass == ElectroSimWindowClass.medium;
    final bool studentTroubleshooting =
        widget.role == F9UserRole.student &&
            _workspace == 'Recherche de dérangement';
    final double padding = compact ? 24 : (medium ? 38 : 34);
    // MagicPath composition is specified against the full product viewport,
    // not the remaining Canvas width after palette/inspector deduction.
    final double horizontalAlignment = studentTroubleshooting
        ? .44
        : compact
            ? .68
            : medium
                ? .75
                : .46;
    final double verticalAlignment = studentTroubleshooting
        ? .27
        : compact
            ? .33
            : medium
                ? .26
                : .385;
    final double maximumScale = studentTroubleshooting ? .786 : 1;
    final F18ViewportFitResult fit = F18MagicPathViewportFitter.fit(
      circuit: _circuit,
      layout: _layout,
      viewportSize: viewportSize,
      padding: padding,
      minScale: _viewport.minScale,
      maxScale: maximumScale,
      horizontalAlignment: horizontalAlignment,
      verticalAlignment: verticalAlignment,
    );
    _viewport.reset(
      scale: fit.scale,
      translation: fit.translation,
    );
  }

  void _setBoundedViewportTranslation(Offset proposed) {
    final Size size = _canvasViewportSize();
    final Offset bounded = F9ViewportBounds.clampTranslation(
      circuit: _circuit,
      layout: _layout,
      viewportSize: size,
      scale: _viewport.scale,
      translation: proposed,
    );
    _viewport.reset(scale: _viewport.scale, translation: bounded);
  }

  void _clampCurrentViewport() => _setBoundedViewportTranslation(_viewport.translation);

  Size _canvasViewportSize() {
    final RenderObject? renderObject = _canvasDropKey.currentContext?.findRenderObject();
    return renderObject is RenderBox ? renderObject.size : const Size(800, 520);
  }

  void _updateWiringHover(Offset localPosition) {
    if (_wiringPendingTerminal == null) {
      return;
    }
    final CanvasHitResult hit = _f9CanvasHit(localPosition);
    final TerminalId? next = hit.kind == CanvasHitKind.terminal ? hit.terminalId : null;
    if (next == _wiringHoverTerminal) {
      return;
    }
    setState(() {
      _wiringHoverTerminal = next;
    });
  }

  void _handleConnectionRequested(TerminalId from, TerminalId to) {
    if (_blockStudentTpMutation()) return;
    final F9WiringDecision decision =
        F9WiringPolicy.evaluateAndBuild(_circuit, from, to);
    final Connection? connection = decision.connection;
    if (!decision.accepted || connection == null) {
      setState(() {
        _wiringPendingTerminal = null;
        _wiringHoverTerminal = null;
        _status = decision.message;
      });
      _announce(decision.message);
      return;
    }

    final CircuitState nextCircuit =
        F9WiringPolicy.append(_circuit, connection);
    final CircuitVisualLayout nextLayout =
        _routeWithG2A(nextCircuit, _layout);
    if (!F18WorkspaceWireSafety.isCrossingFree(
      circuit: nextCircuit,
      layout: nextLayout,
    )) {
      const String message =
          'Connexion refusée : aucun routage automatique sans croisement de nets différents.';
      setState(() {
        _wiringPendingTerminal = null;
        _wiringHoverTerminal = null;
        _status = message;
      });
      _announce(message);
      return;
    }

    setState(() {
      _circuit = nextCircuit;
      _layout = nextLayout;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _status = decision.message;
    });
    _syncStudentTpCircuit();
    _announce(decision.message);
  }

  void _commitElementMoveIfSafe(
    String elementId,
    Offset position, {
    bool moving = false,
  }) {
    final CircuitVisualLayout candidate = _routeWithG2A(
      _circuit,
      _layout.moveElement(elementId, position),
    );
    if (!F18WorkspaceWireSafety.isCrossingFree(
      circuit: _circuit,
      layout: candidate,
    )) {
      setState(() {
        _status =
            'Déplacement refusé : ce placement créerait un croisement automatique entre nets.';
      });
      return;
    }
    setState(() {
      _layout = candidate;
      _status = moving
          ? 'Déplacement : $elementId'
          : 'Position graphique mise à jour : $elementId';
    });
  }

  void _cancelCanvasInteraction() {
    setState(() {
      _canvasInteractionEpoch += 1;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _clearDirectPointerState();
      _status = 'Interaction de câblage annulée (Échap).';
    });
    _announce(_status);
  }

  void _announce(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _replaceSelectedElement() async {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null) {
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(_circuit, selected);
    if (details == null || details.kind != F9ElementKind.component) {
      _setStatus('Remplacement indisponible pour cet élément.');
      return;
    }
    final List<F9PaletteDefinition> candidates = f9PaletteCatalog
        .where((F9PaletteDefinition item) => item.kind == F9PaletteElementKind.component)
        .toList(growable: false);
    final F9PaletteDefinition? replacement = await showDialog<F9PaletteDefinition>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remplacer le composant'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView(
            children: candidates.map((F9PaletteDefinition item) => ListTile(
              key: Key('replace-${item.keyName}'),
              leading: F18ComponentArchetypeGlyph(modelType: item.modelType),
              title: Text(item.title),
              subtitle: Text(item.subtitle ?? item.category),
              onTap: () => Navigator.of(dialogContext).pop(item),
            )).toList(growable: false),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
        ],
      ),
    );
    if (!mounted || replacement == null) {
      return;
    }
    final CircuitState next = F9ElementEditor.replaceComponent(
      _circuit,
      selected,
      modelType: replacement.modelType,
      parameters: _defaultParametersFor(replacement.keyName),
      controlState: _defaultControlStateFor(replacement.keyName),
    );
    setState(() {
      _circuit = next;
      _layout = _routeWithG2A(_circuit, _layout);
      _status = 'Remplacement : $selected → ${replacement.title}';
    });
    _syncStudentTpCircuit();
    _announce(_status);
  }

  void _toggleSelectedPrimaryState() {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null) {
      return;
    }
    final CircuitState next = F9ElementEditor.togglePrimaryState(_circuit, selected);
    if (identical(next, _circuit)) {
      _setStatus('Aucun état commutable pour $selected');
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(next, selected);
    setState(() {
      _circuit = next;
      _status = 'État modifié : $selected — ${details?.stateLabel ?? 'mis à jour'}';
    });
    _syncStudentTpCircuit();
  }

  void _rotateSelectedElement() {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null ||
        F9ElementEditor.describe(_circuit, selected) == null) {
      _setStatus('Rotation impossible : aucun élément sélectionné.');
      return;
    }

    final CircuitVisualLayout rotated = _layout.rotateElement(selected);
    final CircuitVisualLayout candidate = _routeWithG2A(
      _circuit,
      CircuitVisualLayout(
        elementPositions: rotated.elementPositions,
        elementSizes: rotated.elementSizes,
        elementQuarterTurns: rotated.elementQuarterTurns,
        defaultElementSize: rotated.defaultElementSize,
      ),
    );
    if (!F18WorkspaceWireSafety.isCrossingFree(
      circuit: _circuit,
      layout: candidate,
    )) {
      _setStatus(
        'Rotation refusée : aucun routage sans croisement automatique.',
      );
      return;
    }

    setState(() {
      _layout = candidate;
      _status =
          'Rotation 90° : $selected · ${_layout.quarterTurnsOf(selected) * 90}°';
    });
    _announce(_status);
  }

  void _deleteSelectedElement() {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null) {
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(_circuit, selected);
    if (details == null) {
      _setStatus('Suppression impossible : élément introuvable.');
      return;
    }
    final Set<TerminalId> removedTerminalIds = <TerminalId>{};
    for (final ComponentInstance component in _circuit.components) {
      if (component.id.value == selected) {
        removedTerminalIds.addAll(component.terminals.map((Terminal item) => item.id));
      }
    }
    for (final SourceInstance source in _circuit.sources) {
      if (source.id.value == selected) {
        removedTerminalIds.addAll(source.terminals.map((Terminal item) => item.id));
      }
    }
    final Set<String> removedConnectionIds = _circuit.connections
        .where(
          (Connection connection) =>
              removedTerminalIds.contains(connection.fromTerminalId) ||
              removedTerminalIds.contains(connection.toTerminalId),
        )
        .map((Connection connection) => connection.id.value)
        .toSet();
    final CircuitState next = F9ElementEditor.deleteElement(_circuit, selected);
    final Map<String, Offset> positions = <String, Offset>{..._layout.elementPositions}..remove(selected);
    final Map<String, Size> sizes = <String, Size>{..._layout.elementSizes}
      ..remove(selected);
    final Map<String, int> rotations = <String, int>{
      ..._layout.elementQuarterTurns,
    }..remove(selected);
    final Map<String, List<Offset>> routes = <String, List<Offset>>{
      ..._layout.wireRoutes,
    }..removeWhere(
        (String key, List<Offset> value) => removedConnectionIds.contains(key),
      );
    setState(() {
      _circuit = next;
      _layout = _routeWithG2A(
        _circuit,
        CircuitVisualLayout(
          elementPositions: positions,
          elementSizes: sizes,
          wireRoutes: routes,
          elementQuarterTurns: rotations,
          defaultElementSize: _layout.defaultElementSize,
        ),
      );
      _selected = null;
      _status = 'Suppression : ${details.modelType} — $selected';
    });
    _syncStudentTpCircuit();
  }

  bool _blockStudentTpMutation() {
    if (!_studentTpReadOnly) {
      return false;
    }
    _setStatus('TP remis : montage en lecture seule.');
    return true;
  }

  void _syncStudentTpCircuit() {
    if (widget.role != F9UserRole.student ||
        _tpController.lifecycle != TpLifecycle.started) {
      return;
    }
    _tpController.updateStudentCircuit(_circuit);
  }

  CircuitVisualLayout _layoutForCircuit(CircuitState circuit) {
    if (circuit.circuitId.value == 'fault-f18-lighting-004' &&
        circuit.sources.any((SourceInstance item) => item.id.value == 'g1') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 'qf1') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 's1') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 'h1')) {
      return CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'g1': Offset(160, 288),
          'qf1': Offset(352, 288),
          's1': Offset(544, 288),
          'h1': Offset(736, 288),
        },
        elementSizes: const <String, Size>{
          'g1': Size(112, 104),
          'qf1': Size(98, 110),
          's1': Size(98, 100),
          'h1': Size(96, 108),
        },
        wireRoutes: const <String, List<Offset>>{
          'f18-w4': <Offset>[
            Offset(784, 430),
            Offset(104, 430),
          ],
        },
        defaultElementSize: const Size(76, 66),
      );
    }

    if (circuit.circuitId.value == 'f18-workspace-demo' &&
        circuit.sources.any((SourceInstance item) => item.id.value == 'source-24v') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 'breaker-1') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 'switch-1') &&
        circuit.components.any((ComponentInstance item) => item.id.value == 'lamp-1')) {
      final CircuitVisualLayout magicPathDemo = CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'source-24v': Offset(160, 288),
          'breaker-1': Offset(352, 288),
          'switch-1': Offset(544, 288),
          'lamp-1': Offset(736, 288),
        },
        elementSizes: const <String, Size>{
          'source-24v': Size(112, 104),
          'breaker-1': Size(98, 110),
          'switch-1': Size(98, 100),
          'lamp-1': Size(96, 108),
        },
        wireRoutes: const <String, List<Offset>>{
          // Qualified MagicPath composition: the positive branch remains
          // horizontal and the negative return is routed below the devices.
          'wire-4': <Offset>[
            Offset(784, 430),
            Offset(104, 430),
          ],
        },
        defaultElementSize: const Size(76, 66),
      );
      return magicPathDemo;
    }

    final Map<String, Offset> positions = <String, Offset>{};
    final List<String> ids = <String>[
      ...circuit.sources.map((SourceInstance item) => item.id.value),
      ...circuit.components.map((ComponentInstance item) => item.id.value),
    ];
    for (var index = 0; index < ids.length; index++) {
      final int column = index % 3;
      final int row = index ~/ 3;
      positions[ids[index]] = Offset(
        144 + (column * 240.0),
        192 + (row * 192.0),
      );
    }

    final CircuitVisualLayout base = CircuitVisualLayout(
      elementPositions: positions,
    );
    final CircuitVisualLayout arranged = _arrangeSimpleDcCircuit(
      circuit,
      base,
    );
    return _routeWithG2A(circuit, arranged);
  }

  CircuitVisualLayout _arrangeSimpleDcCircuit(
    CircuitState circuit,
    CircuitVisualLayout base,
  ) {
    if (!_isSimpleSeriesDc(circuit) ||
        circuit.sources.length != 1 ||
        circuit.components.isEmpty) {
      return base;
    }

    final ComponentInstance load = _preferredDcLoad(circuit.components);
    final List<ComponentInstance> inline = circuit.components
        .where((ComponentInstance item) => item.id != load.id)
        .toList(growable: false);

    final double width =
        576 + (inline.length > 1 ? (inline.length - 1) * 168.0 : 0);
    final DcRectangularArrangement arrangement = _dcArrangePolicy.arrange(
      topLeft: const Offset(168, 144),
      width: width,
      height: 336,
      sourceId: circuit.sources.single.id.value,
      loadId: load.id.value,
      topInlineElements: inline
          .map(
            (ComponentInstance item) => DcInlineElement(
              id: item.id.value,
              extent: base.sizeOf(item.id.value).width,
            ),
          )
          .toList(growable: false),
    );
    if (!arrangement.isResolved) {
      return base;
    }

    return CircuitVisualLayout(
      elementPositions: <String, Offset>{
        ...base.elementPositions,
        ...arrangement.positions,
      },
      elementSizes: base.elementSizes,
      elementQuarterTurns: base.elementQuarterTurns,
      defaultElementSize: base.defaultElementSize,
    );
  }

  bool _isSimpleSeriesDc(CircuitState circuit) {
    if (circuit.mode != ElectricalMode.dc ||
        circuit.sources.length != 1 ||
        circuit.connections.length != circuit.components.length + 1) {
      return false;
    }

    final Map<TerminalId, String> owners = <TerminalId, String>{};
    final SourceInstance source = circuit.sources.single;
    if (source.terminals.length != 2) {
      return false;
    }
    for (final Terminal terminal in source.terminals) {
      owners[terminal.id] = source.id.value;
    }
    for (final ComponentInstance component in circuit.components) {
      if (component.terminals.length != 2) {
        return false;
      }
      for (final Terminal terminal in component.terminals) {
        owners[terminal.id] = component.id.value;
      }
    }

    final Map<String, int> degree = <String, int>{
      source.id.value: 0,
      for (final ComponentInstance component in circuit.components)
        component.id.value: 0,
    };
    for (final Connection connection in circuit.connections) {
      final String? from = owners[connection.fromTerminalId];
      final String? to = owners[connection.toTerminalId];
      if (from == null || to == null || from == to) {
        return false;
      }
      degree[from] = (degree[from] ?? 0) + 1;
      degree[to] = (degree[to] ?? 0) + 1;
    }
    return degree.values.every((int value) => value == 2);
  }

  ComponentInstance _preferredDcLoad(List<ComponentInstance> components) {
    const Set<String> loadTypes = <String>{
      'lamp',
      'motor_dc',
      'fan_dc',
      'buzzer',
      'resistor',
    };
    for (final ComponentInstance component in components.reversed) {
      if (loadTypes.contains(component.modelType.toLowerCase())) {
        return component;
      }
    }
    return components.last;
  }

  CircuitVisualLayout _routeWithG2A(
    CircuitState circuit,
    CircuitVisualLayout layout,
  ) {
    return _g2aWireLayoutEngine.routeAll(
      circuit: circuit,
      layout: layout,
    );
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
    });
  }

  @override
  void dispose() {
    widget.syncClient?.removeListener(_onLanSyncChanged);
    final ElectroSimLanSyncHost? host = _lanHost;
    if (host != null) unawaited(host.close());
    final ElectroSimLanSyncClient? client = widget.syncClient;
    if (client != null) unawaited(client.close());
    _viewport.dispose();
    if (_ownsTpController || client != null) {
      _tpController.dispose();
    }
    super.dispose();
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.entryLabel,
    required this.workspace,
    required this.sessionNavigation,
    required this.onHome,
    required this.onDashboard,
    required this.onManageSession,
    required this.onSave,
    required this.onOpen,
    required this.studentTroubleshooting,
    required this.studentSubtitle,
    required this.studentSessionLabel,
    required this.simulationMode,
    required this.onModeChanged,
    required this.onRecenter,
  });

  final String entryLabel;
  final String workspace;
  final bool sessionNavigation;
  final VoidCallback onHome;
  final VoidCallback? onDashboard;
  final VoidCallback? onManageSession;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;
  final bool studentTroubleshooting;
  final String studentSubtitle;
  final String studentSessionLabel;
  final bool simulationMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          if (studentTroubleshooting) {
            return SizedBox(
              height: ElectroSimGeometry.desktopTopBarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    _F18TopBarIconButton(
                      key: const Key('session-home-action'),
                      tooltip: 'Retour',
                      onPressed: onHome,
                      icon: Icons.arrow_back,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ElectroSimColors.primaryStrong,
                        borderRadius:
                            BorderRadius.circular(ElectroSimRadii.compact),
                      ),
                      child: const Icon(
                        Icons.electrical_services_outlined,
                        size: 20,
                        color: ElectroSimColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Recherche de dérangement',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ElectroSimColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            studentSubtitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ElectroSimColors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 108),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ElectroSimColors.surfaceMuted,
                        border: Border.all(color: const Color(0xFFD7E0EA)),
                        borderRadius:
                            BorderRadius.circular(ElectroSimRadii.panel),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'ÉLÈVE',
                            style: TextStyle(
                              color: ElectroSimColors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Session $studentSessionLabel',
                            style: const TextStyle(
                              color: ElectroSimColors.textPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return SizedBox(
            height: compact
                ? ElectroSimGeometry.compactTopBarHeight
                : ElectroSimGeometry.desktopTopBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
              ),
              child: Row(
                children: <Widget>[
                  _F18TopBarIconButton(
                    key: const Key('session-home-action'),
                    tooltip: 'Retour',
                    onPressed: onHome,
                    icon: Icons.arrow_back,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: ElectroSimColors.primaryStrong,
                      borderRadius:
                          BorderRadius.circular(ElectroSimRadii.compact),
                    ),
                    child: const Icon(
                      Icons.electrical_services_outlined,
                      size: 20,
                      color: ElectroSimColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 190 : 230,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (compact)
                          Text(
                            entryLabel == 'Centre de conception'
                                ? 'TP Commande'
                                : entryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: ElectroSimColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'ElectroSim',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: ElectroSimColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF4FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'F18',
                                  style: TextStyle(
                                    color: ElectroSimColors.primary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 1),
                        Text(
                          compact
                              ? (workspace == 'Câblage'
                                  ? 'CC · 24 V'
                                  : workspace)
                              : (entryLabel.startsWith('Centre de')
                                  ? workspace
                                  : entryLabel.toUpperCase()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: ElectroSimColors.textSecondary,
                                    fontSize: 9,
                                    letterSpacing: .6,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 18),
                    _F18ModeSwitch(
                      simulationMode: simulationMode,
                      onChanged: onModeChanged,
                    ),
                    const Spacer(),
                    if (sessionNavigation)
                      OutlinedButton(
                        key: const Key('session-dashboard-action'),
                        onPressed: onDashboard,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          side: const BorderSide(
                            color: Color(0xFFD7E0EA),
                          ),
                        ),
                        child: const Text(
                          'Tableau de bord',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (sessionNavigation) const SizedBox(width: 8),
                    if (sessionNavigation)
                      OutlinedButton(
                        key: const Key('session-manage-action'),
                        onPressed: onManageSession,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          side: const BorderSide(
                            color: Color(0xFFD7E0EA),
                          ),
                        ),
                        child: const Text(
                          'Gérer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (onSave != null)
                      IconButton(
                        key: const Key('workspace-save-action'),
                        tooltip: 'Sauvegarder localement',
                        onPressed: onSave,
                        icon: const Icon(Icons.save_outlined, size: 19),
                      ),
                    if (onOpen != null)
                      IconButton(
                        key: const Key('workspace-open-action'),
                        tooltip: 'Reprendre la dernière sauvegarde',
                        onPressed: onOpen,
                        icon: const Icon(Icons.restore_outlined, size: 19),
                      ),
                  ] else ...<Widget>[
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (String value) {
                        switch (value) {
                          case 'edition':
                            onModeChanged(false);
                            break;
                          case 'simulation':
                            onModeChanged(true);
                            break;
                          case 'dashboard':
                            onDashboard?.call();
                            break;
                          case 'manage':
                            onManageSession?.call();
                            break;
                          case 'save':
                            onSave?.call();
                            break;
                          case 'open':
                            onOpen?.call();
                            break;
                          case 'recenter':
                            onRecenter();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value:
                              simulationMode ? 'edition' : 'simulation',
                          child: Text(
                            simulationMode
                                ? 'Passer en édition'
                                : 'Passer en simulation',
                          ),
                        ),
                        if (sessionNavigation)
                          const PopupMenuItem<String>(
                            value: 'dashboard',
                            child: Text('Tableau de bord'),
                          ),
                        if (sessionNavigation)
                          const PopupMenuItem<String>(
                            value: 'manage',
                            child: Text('Gérer la session'),
                          ),
                        if (onSave != null)
                          const PopupMenuItem<String>(
                            value: 'save',
                            child: Text('Sauvegarder'),
                          ),
                        if (onOpen != null)
                          const PopupMenuItem<String>(
                            value: 'open',
                            child: Text('Reprendre'),
                          ),
                        const PopupMenuItem<String>(
                          value: 'recenter',
                          child: Text('Recentrer'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _F18TopBarIconButton extends StatelessWidget {
  const _F18TopBarIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
      ),
    );
  }
}

class _F18ModeSwitch extends StatelessWidget {
  const _F18ModeSwitch({
    required this.simulationMode,
    required this.onChanged,
  });

  final bool simulationMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceMuted,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _F18ModeButton(
            label: 'Édition',
            selected: !simulationMode,
            onTap: () => onChanged(false),
          ),
          _F18ModeButton(
            label: 'Simulation',
            selected: simulationMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _F18ModeButton extends StatelessWidget {
  const _F18ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ElectroSimColors.surfaceElevated
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? ElectroSimColors.primaryStrong
                  : ElectroSimColors.textSecondary,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardDestination extends StatelessWidget {
  const _DashboardDestination({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minTileHeight: ElectroSimGeometry.minimumTouchTarget,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        side: const BorderSide(color: ElectroSimColors.outline),
      ),
      leading: Icon(icon, color: ElectroSimColors.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.circuit, required this.status});

  final CircuitState circuit;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          final int elementCount = circuit.components.length + circuit.sources.length;
          final String countLabel = compact
              ? '$elementCount élém. · ${circuit.sources.length} src.'
              : '$elementCount élément${elementCount == 1 ? '' : 's'} · '
                  '${circuit.sources.length} source${circuit.sources.length == 1 ? '' : 's'} · '
                  '${circuit.mode.name.toUpperCase()} · Révision ${circuit.revision}';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: ElectroSimSpacing.sm),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: ElectroSimSpacing.xs),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'État du simulateur',
                    child: Text(
                      status,
                      key: const Key('status-message'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: ElectroSimSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 104 : 320),
                  child: Text(
                    countLabel,
                    key: const Key('status-circuit-count'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

CircuitState _buildDemoCircuit() {
  final Terminal sourcePositive = Terminal(
    id: TerminalId('source-pos'),
    name: '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = Terminal(
    id: TerminalId('source-neg'),
    name: '−',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal breakerIn = Terminal(
    id: TerminalId('breaker-in'),
    name: '1',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal breakerOut = Terminal(
    id: TerminalId('breaker-out'),
    name: '2',
    role: TerminalRole.output,
    phase: PhaseTag.dcPositive,
  );
  final Terminal switchIn = Terminal(
    id: TerminalId('switch-in'),
    name: '1',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal switchOut = Terminal(
    id: TerminalId('switch-out'),
    name: '2',
    role: TerminalRole.output,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampIn = Terminal(
    id: TerminalId('lamp-in'),
    name: 'A',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampOut = Terminal(
    id: TerminalId('lamp-out'),
    name: 'B',
    role: TerminalRole.output,
    phase: PhaseTag.dcNegative,
  );

  return CircuitState(
    circuitId: CircuitId('f18-workspace-demo'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-24v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('breaker-1'),
        modelType: 'breaker',
        terminals: <Terminal>[breakerIn, breakerOut],
        controlState: const <String, Object?>{
          'closed': true,
          'tripped': false,
        },
      ),
      ComponentInstance(
        id: ComponentId('switch-1'),
        modelType: 'switch',
        terminals: <Terminal>[switchIn, switchOut],
        controlState: const <String, Object?>{'closed': true},
      ),
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'lamp',
        terminals: <Terminal>[lampIn, lampOut],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('wire-1'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: breakerIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-2'),
        fromTerminalId: breakerOut.id,
        toTerminalId: switchIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-3'),
        fromTerminalId: switchOut.id,
        toTerminalId: lampIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-4'),
        fromTerminalId: lampOut.id,
        toTerminalId: sourceNegative.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
  );
}
