import 'dart:async';
import 'dart:math' as math;

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
import 'f18_component_asset_visual.dart';
import 'f18_drag_preview.dart';
import 'f18_home.dart';
import 'f18_session_coordinator.dart';
import 'f18_selection_state.dart';
import 'f18_shell_navigation.dart';
import 'f18_v1_navigation_flow.dart';
import 'f18_workspace_wire_safety.dart';
import 'f9_auto_placement.dart';
import 'f9_component_palette.dart';
import 'f9_wiring_policy.dart';
import 'reference_components/reference_widgets.dart';
import 'f9_ui_context.dart';
import 'f9_context_panels.dart';
import 'f9_component_visuals.dart';
import 'f9_element_editor.dart';
import 'f9_canvas_interaction.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_persistence_controller.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrosim_simulation_controller.dart';
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
      onCreateSession: () => _openSessionShell(context, persistenceController),
      onMaintenance: () =>
          _openMaintenanceCenter(context, persistenceController),
      onDesign: () => _openDesignCenter(context, persistenceController),
      onJoinSession: () => _joinLanSession(context, persistenceController),
    );
  }

  static Future<void> _joinLanSession(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) async {
    final _NetworkJoinRequest? request = await showDialog<_NetworkJoinRequest>(
      context: context,
      builder: (BuildContext dialogContext) => const _NetworkJoinDialog(),
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
          SnackBar(content: Text('Connexion à la session impossible : $error')),
        );
    }
  }

  static void _openDesignCenter(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'design-center'),
        builder: (BuildContext routeContext) => F18DesignCenterPage(
          onHome: () => Navigator.of(
            routeContext,
          ).popUntil((Route<dynamic> route) => route.isFirst),
          onWiring: () => _openWorkspace(
            routeContext,
            'Centre de conception',
            initialWorkspace: 'Câblage',
            persistenceController: persistenceController,
            parentRouteName: 'design-center',
          ),
          onSchemaLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'design-schema-library'),
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
        settings: const RouteSettings(name: 'maintenance-center'),
        builder: (BuildContext routeContext) => F18MaintenanceCenterPage(
          onHome: () => Navigator.of(
            routeContext,
          ).popUntil((Route<dynamic> route) => route.isFirst),
          onTroubleshooting: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: 'maintenance-troubleshooting-setup',
              ),
              builder: (BuildContext setupContext) => F18ActivitySetupPage(
                pageKey: const Key('maintenance-troubleshooting-setup-page'),
                title: 'Préparer une recherche de dérangement',
                description:
                    'Préparez le diagnostic avant d’ouvrir l’atelier de maintenance.',
                parentLabel: 'centre de maintenance',
                onBack: () => Navigator.of(setupContext).pop(),
                onOpenWorkshop: () => _openWorkspace(
                  setupContext,
                  'Centre de maintenance',
                  initialWorkspace: 'Recherche de dérangement',
                  persistenceController: persistenceController,
                  parentRouteName: 'maintenance-center',
                ),
              ),
            ),
          ),
          onFaultLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'maintenance-fault-library'),
              builder: (BuildContext context) => const F18PlaceholderPage(
                pageKey: Key('maintenance-fault-library-page'),
                title: 'Bibliothèque de pannes',
                description:
                    'Les circuits défectueux autonomes seront gérés dans la bibliothèque de maintenance F18.',
              ),
            ),
          ),
          onStudentValidation: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: 'student-situation-validation',
              ),
              builder: (BuildContext validationContext) =>
                  F18StudentSituationValidationPage(
                    onBack: () => Navigator.of(validationContext).pop(),
                    onLaunch: (String referenceCircuit, String faultScenario) {
                      _openWorkspace(
                        validationContext,
                        'Validation en situation élève',
                        initialWorkspace: 'Recherche de dérangement',
                        persistenceController: persistenceController,
                        parentRouteName: 'maintenance-center',
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openSessionShell(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) async {
    final F18SessionCreationDraft? draft =
        await showDialog<F18SessionCreationDraft>(
          context: context,
          builder: (BuildContext dialogContext) =>
              const F18CreateSessionDialog(),
        );
    if (draft == null || !context.mounted) return;

    final String sessionCode = ElectroSimLanSyncHost.generateSessionCode();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'teacher-session'),
        builder: (BuildContext routeContext) =>
            F18TeacherSessionCoordinatorPage(
              sessionName: draft.name,
              sessionCode: sessionCode,
              workspaceBuilder:
                  (
                    BuildContext workspaceContext,
                    ElectroSimTpSessionController controller,
                    String workspace,
                    VoidCallback onDashboard,
                    VoidCallback onManageSession,
                  ) => F18WorkspacePage(
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
    String? parentRouteName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: initialWorkspace == 'Câblage'
              ? 'cabling-workspace'
              : 'troubleshooting-workspace',
        ),
        builder: (BuildContext workspaceContext) => F18WorkspacePage(
          entryLabel: entryLabel,
          initialWorkspace: initialWorkspace,
          sessionNavigation: sessionNavigation,
          persistenceController: persistenceController,
          onExitWorkspace: parentRouteName == null
              ? null
              : () => Navigator.of(workspaceContext).popUntil(
                  (Route<dynamic> route) =>
                      route.settings.name == parentRouteName,
                ),
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
              Text(_error!, key: const Key('join-session-error')),
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
    if (rawCode.length != 6 || RegExp(r'[^A-Z2-9]').hasMatch(rawCode)) {
      setState(() {
        _error = 'Le code de session doit contenir 6 caractères.';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_NetworkJoinRequest(endpoint: endpoint, sessionCode: rawCode));
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
    super.onExitWorkspace,
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
    this.onExitWorkspace,
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
  final VoidCallback? onExitWorkspace;

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
  static const WirePreviewPlanner _g2aWirePreviewPlanner = WirePreviewPlanner(
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
  final ViewportController _viewport = ViewportController(
    scale: 1,
    translation: const Offset(40, 40),
  );
  final GlobalKey _canvasDropKey = GlobalKey(
    debugLabel: 'f18-canvas-drop-target',
  );
  late F18SelectionState _selection;
  String? get _selected => _selection.primaryId;
  Set<String> get _selectedIds => _selection.selectedIds;

  set _selected(String? id) {
    _selection = id == null
        ? F18SelectionState.empty()
        : F18SelectionState.single(id);
  }
  String _status = 'ElectroSim F18 — espace de travail prêt';
  late String _workspace;
  int _canvasInteractionEpoch = 0;
  final HitTestEngine _hitTest = const HitTestEngine();
  TerminalId? _wiringPendingTerminal;
  TerminalId? _wiringHoverTerminal;
  int? _activeCanvasPointer;
  String? _directDragElementId;
  Offset? _directDragGrabDelta;
  CircuitVisualLayout? _directDragBaseLayout;
  Offset? _lastCanvasPointerLocal;
  bool _backgroundPanActive = false;
  bool _directPointerMoved = false;
  bool _selectionModifierAtPointerDown = false;
  bool _trackpadPanZoomActive = false;
  double _trackpadLastScale = 1;

  static const Duration _directControlDoubleTapWindow = Duration(
    milliseconds: 420,
  );
  static const double _directControlDoubleTapDistance = 28;
  DateTime? _lastDirectControlTapTime;
  String? _lastDirectControlTapElementId;
  Offset? _lastDirectControlTapLocal;
  final Map<String, Timer> _momentaryReleaseTimers = <String, Timer>{};
  late final ElectroSimTpSessionController _tpController;
  late final bool _ownsTpController;
  ElectroSimLanSyncHost? _lanHost;
  ElectroSimLanHostInfo? _lanHostInfo;
  late final ElectroSimSimulationController _simulation;

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
    _simulation = ElectroSimSimulationController(circuit: _circuit)
      ..addListener(_onSimulationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitCircuitToViewport();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ElectroSimRuntimeSnapshot runtimeSnapshot = _simulation.snapshot;
    final F9ElementDetails? selectedDetails = F9ElementEditor.describe(
      _circuit,
      _selected,
    );
    final bool canDeleteSelection =
        _selectedIds.isNotEmpty && !_studentTpReadOnly;
    final bool canRotateSelection =
        _selectedIds.length == 1 &&
        selectedDetails != null &&
        selectedDetails.kind != F9ElementKind.connection &&
        !_studentTpReadOnly;
    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape):
                _cancelCanvasInteraction,
            const SingleActivator(LogicalKeyboardKey.delete):
                _deleteSelectedElement,
            const SingleActivator(LogicalKeyboardKey.backspace):
                _deleteSelectedElement,
            const SingleActivator(LogicalKeyboardKey.equal, shift: true): () =>
                _viewport.zoomAt(const Offset(400, 300), 1.1),
            const SingleActivator(LogicalKeyboardKey.minus): () =>
                _viewport.zoomAt(const Offset(400, 300), 0.9),
          },
          child: Focus(
            autofocus: true,
            child: ElectroSimWorkspaceShell(
              topBar: _WorkspaceTopBar(
                entryLabel: widget.entryLabel,
                workspace: _workspace,
                sessionNavigation: widget.sessionNavigation,
                onHome: () => Navigator.of(
                  context,
                ).popUntil((Route<dynamic> route) => route.isFirst),
                onDashboard: widget.sessionNavigation
                    ? (widget.onSessionDashboard ?? _showDashboard)
                    : null,
                onManageSession: widget.sessionNavigation
                    ? (widget.onSessionManage ?? _showManageSession)
                    : null,
                onExitWorkspace: widget.onExitWorkspace,
                onSave: widget.persistenceController == null
                    ? null
                    : _saveWorkspace,
                onOpen: widget.persistenceController == null
                    ? null
                    : _openLatestWorkspace,
                onRotateSelected: canRotateSelection
                    ? _rotateSelectedElement
                    : null,
                onDeleteSelected: canDeleteSelection
                    ? _deleteSelectedElement
                    : null,
                onRecenter: _fitCircuitToViewport,
                electricalMode: _circuit.mode,
                onSelectElectricalMode: _requestElectricalModeChange,
                simulationRunning: _simulation.running,
                simulatedTime: _simulation.simulatedTime,
                onToggleSimulation: _simulation.toggle,
                onResetSimulation: _simulation.resetDynamics,
              ),
              palette: F9ComponentPalette(
                mode: _circuit.mode,
                onStatus: _setStatus,
                onQuickAdd: _quickAddFromPalette,
              ),
              contextPanel:
                  _workspace == 'Supervision' &&
                      widget.role == F9UserRole.teacher
                  ? F17TpSupervisionPanel(controller: _tpController)
                  : F9ContextPanels(
                      circuit: _circuit,
                      selectedId: _selected,
                      status: _status,
                      workspace: _workspace,
                      role: widget.role,
                      onTogglePrimaryState:
                          selectedDetails == null ||
                              _usesDirectCanvasControl(
                                selectedDetails.modelType,
                              )
                          ? null
                          : _toggleSelectedPrimaryState,
                      onReplaceSelected: _selectedIds.length == 1
                          ? _replaceSelectedElement
                          : null,
                      onSelectElement: (String? id) {
                        setState(() {
                          _selected = id;
                          _status = id == null
                              ? 'Sélection effacée'
                              : 'Sélection clavier : $id';
                        });
                      },
                      runtimeSnapshot: runtimeSnapshot,
                      tpSessionController:
                          widget.sessionNavigation ||
                              widget.tpSessionController != null
                          ? _tpController
                          : null,
                    ),
              statusBar: _StatusBar(
                circuit: _circuit,
                status: _status,
                simulationRunning: _simulation.running,
                simulatedTime: _simulation.simulatedTime,
              ),
              canvas: KeyedSubtree(
                key: const Key('f18-canvas-drop-region'),
                child: DragTarget<F9PaletteDefinition>(
                  key: _canvasDropKey,
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: _acceptPaletteDrop,
                  builder:
                      (
                        BuildContext context,
                        List<F9PaletteDefinition?> candidateData,
                        List<dynamic> rejectedData,
                      ) {
                        return ClipRect(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: candidateData.isEmpty
                                  ? null
                                  : Border.all(
                                      color: ElectroSimColors.primary,
                                      width: 2,
                                    ),
                            ),
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _onCanvasPointerDown,
                              onPointerMove: _onCanvasPointerMove,
                              onPointerUp: _onCanvasPointerUp,
                              onPointerCancel: _onCanvasPointerCancel,
                              onPointerHover: _onCanvasPointerHover,
                              onPointerSignal: _onCanvasPointerSignal,
                              onPointerPanZoomStart:
                                  _onCanvasPointerPanZoomStart,
                              onPointerPanZoomUpdate:
                                  _onCanvasPointerPanZoomUpdate,
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
                                        _status = id == null
                                            ? 'Sélection effacée'
                                            : 'Sélection : $id';
                                      });
                                    },
                                    onElementMoved:
                                        (String id, Offset position) {
                                          _commitElementMoveIfSafe(
                                            id,
                                            position,
                                          );
                                        },
                                    onConnectionRequested:
                                        _handleConnectionRequested,
                                    onContextAction: (CanvasHitResult hit) {
                                      setState(() {
                                        _status =
                                            'Action contextuelle : ${hit.kind.name}. Les mêmes actions sont disponibles dans Propriétés.';
                                      });
                                    },
                                    enableInteraction: false,
                                    paintElementChrome: false,
                                    wireLayoutEngine: _g2aWireLayoutEngine,
                                    wirePreviewPlanner: _g2aWirePreviewPlanner,
                                  ),
                                  AnimatedBuilder(
                                    animation: _viewport,
                                    builder:
                                        (
                                          BuildContext context,
                                          Widget? child,
                                        ) => F9CanvasVisualOverlay(
                                          circuit: _circuit,
                                          layout: _layout,
                                          viewport: _viewport,
                                          selectedElementIds: _selectedIds,
                                          pendingTerminalId:
                                              _wiringPendingTerminal,
                                          hoverTerminalId: _wiringHoverTerminal,
                                          pointerWorldPosition:
                                              _lastCanvasPointerLocal == null
                                              ? null
                                              : _viewport.screenToWorld(
                                                  _lastCanvasPointerLocal!,
                                                ),
                                          wirePreviewPlanner:
                                              _g2aWirePreviewPlanner,
                                          runtimeSnapshot: runtimeSnapshot,
                                          simulationRunning:
                                              _simulation.running,
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
                description:
                    'Préparer ou suivre un diagnostic sur scénario défectueux.',
                onTap: () =>
                    Navigator.of(dialogContext).pop('Recherche de dérangement'),
              ),
              const SizedBox(height: ElectroSimSpacing.xs),
              _DashboardDestination(
                key: const Key('dashboard-supervision'),
                icon: Icons.monitor_heart_outlined,
                title: 'Supervision',
                description:
                    'Consulter la progression et les résultats de la session.',
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
      final restored = await persistence.openLatest(
        tpController: _tpController,
      );
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
      _simulation.updateCircuit(_circuit);
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
        _setStatus('Partage réseau actif — code ${info.sessionCode}');
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

    if (circuitChanged) {
      _simulation.updateCircuit(_circuit);
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
        onEnableLanSharing: widget.role == F9UserRole.teacher
            ? _enableLanSharing
            : null,
        onStudentStarted: (TpSession session) {
          setState(() {
            _circuit = session.studentCircuit;
            _layout = _layoutForCircuit(_circuit);
            _selected = null;
            _workspace = 'Recherche de dérangement';
            _status = 'TP commencé — montage élève chargé.';
          });
          _simulation.updateCircuit(_circuit);
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

  Future<void> _requestElectricalModeChange(ElectricalMode mode) async {
    if (mode == _circuit.mode || _studentTpReadOnly) return;

    final bool hasContent =
        _circuit.components.isNotEmpty ||
        _circuit.sources.isNotEmpty ||
        _circuit.connections.isNotEmpty;
    if (hasContent) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Changer de domaine électrique'),
          content: Text(
            'Passer de ${_electricalModeLabel(_circuit.mode)} à '
            '${_electricalModeLabel(mode)} crée une nouvelle platine vide. '
            'Le circuit actuel doit être sauvegardé avant ce changement si '
            'vous souhaitez le conserver.',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('mode-change-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const Key('mode-change-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Créer la platine'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final CircuitState next = CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: mode,
      components: const <ComponentInstance>[],
      sources: const <SourceInstance>[],
      connections: const <Connection>[],
      settings: _defaultSettingsForMode(mode),
      metadata: <String, Object?>{
        ..._circuit.metadata,
        'electricalModeChangedFrom': _circuit.mode.name,
      },
    );

    setState(() {
      _circuit = next;
      _layout = _layoutForCircuit(next);
      _selected = null;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _status = 'Nouvelle platine ${_electricalModeLabel(mode)} prête.';
    });
    _simulation.updateCircuit(next);
    _simulation.resetDynamics();
    _syncStudentTpCircuit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitCircuitToViewport();
    });
  }

  Map<String, Object?> _defaultSettingsForMode(ElectricalMode mode) =>
      switch (mode) {
        ElectricalMode.dc => const <String, Object?>{},
        ElectricalMode.ac1 ||
        ElectricalMode.ac3 => const <String, Object?>{'frequencyHz': 50.0},
        ElectricalMode.pv => const <String, Object?>{
          'irradianceWm2': 1000.0,
          'cellTemperatureC': 25.0,
          'shadingPct': 0.0,
        },
      };

  String _electricalModeLabel(ElectricalMode mode) => switch (mode) {
    ElectricalMode.dc => 'CC',
    ElectricalMode.ac1 => 'AC 1φ',
    ElectricalMode.ac3 => 'AC 3φ',
    ElectricalMode.pv => 'PV',
  };

  void _quickAddFromPalette(F9PaletteDefinition definition) {
    final RenderObject? renderObject = _canvasDropKey.currentContext
        ?.findRenderObject();
    final Size size = renderObject is RenderBox
        ? renderObject.size
        : const Size(800, 520);
    final Offset topLeft = _viewport.screenToWorld(Offset.zero);
    final Offset bottomRight = _viewport.screenToWorld(
      Offset(size.width, size.height),
    );
    final Rect visibleWorldRect = Rect.fromPoints(topLeft, bottomRight);
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      _circuit,
      _layout,
    );
    final List<List<Offset>> polylines = <List<Offset>>[];
    for (final Connection connection in _circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      polylines.add(<Offset>[
        start,
        ..._layout.routeFor(connection.id.value),
        end,
      ]);
    }
    final Size elementSize =
        F18ReferenceComponentVisuals.supports(definition.renderedModelType)
        ? F18ReferenceComponentMetrics.boardSizeFor(
            definition.renderedModelType,
          )
        : _layout.defaultElementSize;
    Offset? position = F9AutoPlacement.findPosition(
      visibleWorldRect: visibleWorldRect,
      elementSize: elementSize,
      occupiedElements: geometry.elementRects.values,
      occupiedPolylines: polylines,
    );
    var requiresRefit = false;
    if (position == null) {
      final double expansion =
          math.max(elementSize.width, elementSize.height) + 96;
      position = F9AutoPlacement.findPosition(
        visibleWorldRect: visibleWorldRect.inflate(expansion),
        elementSize: elementSize,
        occupiedElements: geometry.elementRects.values,
        occupiedPolylines: polylines,
      );
      requiresRefit = position != null;
    }
    if (position == null) {
      _setStatus(
        'Ajout rapide impossible : aucune zone libre autour de la platine. '
        'Glissez le composant à l’endroit souhaité.',
      );
      return;
    }
    _addPaletteDefinition(definition, position);
    if (requiresRefit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitCircuitToViewport();
        }
      });
    }
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

  void _addPaletteDefinition(
    F9PaletteDefinition definition,
    Offset worldPosition,
  ) {
    if (_blockStudentTpMutation()) return;
    if (definition.kind == F9PaletteElementKind.component) {
      final ComponentModelContract? contract = CoreComponentModelContracts
          .registry
          .resolve(definition.modelType);
      if (contract != null && !contract.supportsMode(_circuit.mode)) {
        _setStatus(
          '${definition.title} n’est pas compatible avec le mode '
          '${_circuit.mode.name.toUpperCase()}.',
        );
        return;
      }
    }
    final String elementId = _allocateElementId(definition.keyName);
    final List<Terminal> terminals = _buildPaletteTerminals(
      definition,
      elementId,
    );
    final List<ComponentInstance> components = <ComponentInstance>[
      ..._circuit.components,
    ];
    final List<SourceInstance> sources = <SourceInstance>[..._circuit.sources];

    if (definition.kind == F9PaletteElementKind.source) {
      final Map<String, Object?> parameters = <String, Object?>{
        ...(definition.defaultParameters.isNotEmpty
            ? definition.defaultParameters
            : const <String, Object?>{'voltageV': 24.0}),
        if (definition.visualModelType != null)
          '_visualModelType': definition.visualModelType!,
        if (definition.visualVariant != null)
          '_visualVariant': definition.visualVariant!,
        if (definition.displayLabel != null)
          '_displayLabel': definition.displayLabel!,
      };
      sources.add(
        SourceInstance(
          id: SourceId(elementId),
          modelType: definition.modelType,
          terminals: terminals,
          parameters: parameters,
        ),
      );
    } else {
      Map<String, Object?> parameters = <String, Object?>{
        ...(definition.defaultParameters.isNotEmpty
            ? definition.defaultParameters
            : _defaultParametersFor(definition.keyName)),
        if (definition.visualModelType != null)
          '_visualModelType': definition.visualModelType!,
        if (definition.visualVariant != null)
          '_visualVariant': definition.visualVariant!,
        if (definition.displayLabel != null)
          '_displayLabel': definition.displayLabel!,
      };
      final bool contactorAux =
          definition.modelType == 'contactor_aux_no' ||
          definition.modelType == 'contactor_aux_nc';
      final bool relayAux =
          definition.modelType == 'relay_contact_no' ||
          definition.modelType == 'relay_contact_nc';
      if (contactorAux || relayAux) {
        final List<ComponentInstance> coils = components
            .where(
              (ComponentInstance item) => relayAux
                  ? item.modelType == 'relay_coil'
                  : item.modelType == 'contactor_ac1' ||
                        item.modelType == 'contactor_3p',
            )
            .toList(growable: false);
        ComponentInstance? linked;
        for (final ComponentInstance item in coils) {
          if (item.id.value == _selected) {
            linked = item;
            break;
          }
        }
        if (linked == null && coils.length == 1) {
          linked = coils.single;
        }
        if (linked != null) {
          parameters = <String, Object?>{
            ...parameters,
            relayAux ? 'linkedRelayId' : 'linkedContactorId': linked.id.value,
          };
        }
      }
      components.add(
        ComponentInstance(
          id: ComponentId(elementId),
          modelType: definition.modelType,
          terminals: terminals,
          parameters: parameters,
          controlState: definition.defaultControlState.isNotEmpty
              ? definition.defaultControlState
              : _defaultControlStateFor(definition.keyName),
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
      final CircuitVisualLayout moved = _layout.moveElement(
        elementId,
        worldPosition,
      );
      final Map<String, Size> sizes = <String, Size>{...moved.elementSizes};
      if (F18ReferenceComponentVisuals.supports(definition.renderedModelType)) {
        sizes[elementId] = F18ReferenceComponentMetrics.boardSizeFor(
          definition.renderedModelType,
        );
      }
      _layout = _routeWithG2A(
        _circuit,
        CircuitVisualLayout(
          elementPositions: moved.elementPositions,
          elementSizes: sizes,
          wireRoutes: moved.wireRoutes,
          elementQuarterTurns: moved.elementQuarterTurns,
          defaultElementSize: moved.defaultElementSize,
        ),
      );
      _selected = elementId;
      _status = 'Ajout : ${definition.title} — $elementId';
    });
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
  }

  List<Terminal> _buildPaletteTerminals(
    F9PaletteDefinition definition,
    String elementId,
  ) {
    if (definition.terminals.isNotEmpty) {
      return <Terminal>[
        for (var index = 0; index < definition.terminals.length; index++)
          Terminal(
            id: TerminalId(
              '$elementId-${definition.terminals[index].idSuffix ?? 't${index + 1}'}',
            ),
            name: definition.terminals[index].label,
            role: definition.terminals[index].role,
            phase: definition.terminals[index].phase,
          ),
      ];
    }

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

  TerminalRole _roleForTerminalLabel(
    String label, {
    required TerminalRole fallback,
  }) {
    if (label == '+') {
      return TerminalRole.positive;
    }
    if (label == '−') {
      return TerminalRole.negative;
    }
    if (label == 'A1') {
      return TerminalRole.coilA1;
    }
    if (label == 'A2') {
      return TerminalRole.coilA2;
    }
    return fallback;
  }

  Map<String, Object?> _defaultParametersFor(String keyName) =>
      switch (keyName) {
        'lamp' => const <String, Object?>{'resistanceOhm': 24.0},
        'resistor' => const <String, Object?>{'resistanceOhm': 100.0},
        'buzzer' => const <String, Object?>{'resistanceOhm': 48.0},
        'fan-dc' => const <String, Object?>{'resistanceOhm': 12.0},
        'motor-dc' => const <String, Object?>{'resistanceOhm': 8.0},
        'relay-coil' => const <String, Object?>{'resistanceOhm': 120.0},
        'breaker' => const <String, Object?>{
          ProtectionRating.ratedCurrentKey: 10.0,
        },
        'fuse' => const <String, Object?>{
          ProtectionRating.ratedCurrentKey: 10.0,
        },
        _ => const <String, Object?>{},
      };

  Map<String, Object?> _defaultControlStateFor(String keyName) =>
      switch (keyName) {
        'switch-no' => const <String, Object?>{'closed': false},
        'push-button-no' => const <String, Object?>{'pressed': false},
        'push-button-nc' => const <String, Object?>{'pressed': false},
        'breaker' => const <String, Object?>{'closed': true, 'tripped': false},
        'fuse' => const <String, Object?>{'closed': true, 'tripped': false},
        _ => const <String, Object?>{},
      };

  bool get _multiSelectionModifierPressed {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed;
  }

  String _selectionStatus(String prefix) {
    final int count = _selectedIds.length;
    if (count == 0) return 'Sélection effacée';
    if (count == 1) return '$prefix : ${_selection.primaryId}';
    return '$prefix multiple : $count éléments';
  }

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
    final CanvasHitResult hit = _f9CanvasHit(event.localPosition);
    _activeCanvasPointer = event.pointer;
    _lastCanvasPointerLocal = event.localPosition;
    _directPointerMoved = false;
    _selectionModifierAtPointerDown = _multiSelectionModifierPressed;
    _backgroundPanActive = false;
    _directDragElementId = null;
    _directDragGrabDelta = null;
    _directDragBaseLayout = null;

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
          _status =
              'Câblage : borne ${terminal.value} sélectionnée. Choisissez une cible.';
        } else {
          _wiringPendingTerminal = null;
          _wiringHoverTerminal = null;
          _status = 'Câblage annulé : borne de départ désélectionnée.';
        }
      });
      return;
    }

    if (hit.kind == CanvasHitKind.component ||
        hit.kind == CanvasHitKind.source) {
      final String id = hit.elementId!;
      final Offset? current = _layout.positionOf(id);
      if (current == null) {
        return;
      }
      final Offset world = _viewport.screenToWorld(event.localPosition);
      final bool additive = _selectionModifierAtPointerDown;
      setState(() {
        _selection = _selection.select(id, additive: additive);
        if (!additive && !_studentTpReadOnly) {
          _directDragElementId = id;
          _directDragGrabDelta = current - world;
          _directDragBaseLayout = _layout;
        }
        _status = _studentTpReadOnly
            ? '${_selectionStatus('Sélection')} — TP en lecture seule'
            : _selectionStatus('Sélection');
      });
      return;
    }

    if (hit.kind == CanvasHitKind.wire) {
      final String? id = hit.connectionId?.value;
      if (id == null) return;
      setState(() {
        _selection = _selection.select(
          id,
          additive: _selectionModifierAtPointerDown,
        );
        _status = _selectionStatus('Sélection');
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
      _commitElementMoveIfSafe(draggingId, nextPosition, moving: true);
      return;
    }

    if (_backgroundPanActive && previous != null) {
      final Offset proposed =
          _viewport.translation + (event.localPosition - previous);
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
      _finalizeDirectDrag(movedId);
      _resetDirectControlTapTracking();
    } else if (_backgroundPanActive &&
        !_directPointerMoved &&
        _wiringPendingTerminal == null &&
        !_selectionModifierAtPointerDown) {
      setState(() {
        _selected = null;
        _status = 'Sélection effacée';
      });
      _resetDirectControlTapTracking();
    } else if (!_directPointerMoved &&
        _wiringPendingTerminal == null &&
        !_selectionModifierAtPointerDown) {
      _handleDirectControlTap(event.localPosition);
    }
    _clearDirectPointerState();
  }

  void _onCanvasPointerCancel(PointerCancelEvent event) {
    if (_activeCanvasPointer == event.pointer) {
      final CircuitVisualLayout? base = _directDragBaseLayout;
      if (base != null) {
        setState(() => _layout = base);
      }
      _clearDirectPointerState();
    }
  }

  void _clearDirectPointerState() {
    _activeCanvasPointer = null;
    _directDragElementId = null;
    _directDragGrabDelta = null;
    _directDragBaseLayout = null;
    _lastCanvasPointerLocal = null;
    _backgroundPanActive = false;
    _directPointerMoved = false;
    _selectionModifierAtPointerDown = false;
  }

  ({String id, String modelType})? _directControlAt(Offset screenPosition) {
    final CanvasHitResult hit = _f9CanvasHit(screenPosition);
    if (hit.kind != CanvasHitKind.component || hit.elementId == null) {
      return null;
    }
    final String id = hit.elementId!;
    ComponentInstance? component;
    for (final ComponentInstance item in _circuit.components) {
      if (item.id.value == id) {
        component = item;
        break;
      }
    }
    if (component == null) return null;
    final String modelType = component.modelType.toLowerCase();

    final Size baseSize = _layout.sizeOf(id);
    final Offset? center = _layout.positionOf(id);
    if (center == null) return null;
    final Offset worldPoint = _viewport.screenToWorld(screenPosition);
    final Offset delta = worldPoint - center;
    final int turns = _layout.quarterTurnsOf(id) % 4;
    final Offset unrotatedDelta = switch (turns) {
      0 => delta,
      1 => Offset(delta.dy, -delta.dx),
      2 => Offset(-delta.dx, -delta.dy),
      _ => Offset(-delta.dy, delta.dx),
    };
    final Offset local = Offset(
      baseSize.width / 2 + unrotatedDelta.dx,
      baseSize.height / 2 + unrotatedDelta.dy,
    );

    final ReferenceDevice? device =
        F18ReferenceComponentVisuals.uploadedDeviceFor(modelType);
    if (device == ReferenceDevice.breaker ||
        device == ReferenceDevice.toggle ||
        device == ReferenceDevice.button) {
      if (ReferenceComponentView.hitsControlRegion(
        baseSize,
        local,
        device: device!,
      )) {
        return (id: id, modelType: modelType);
      }
      return null;
    }

    if (modelType == 'push_button_nc') {
      final Offset centerLocal = Offset(
        baseSize.width * .5,
        baseSize.height * (88 / 180),
      );
      final double radius =
          math.min(baseSize.width, baseSize.height) * (39 / 180);
      if ((local - centerLocal).distance <= radius) {
        return (id: id, modelType: modelType);
      }
    }
    return null;
  }

  void _handleDirectControlTap(Offset screenPosition) {
    final ({String id, String modelType})? target = _directControlAt(
      screenPosition,
    );
    if (target == null) {
      _resetDirectControlTapTracking();
      return;
    }

    final DateTime now = DateTime.now();
    final bool sameTarget = _lastDirectControlTapElementId == target.id;
    final bool withinTime =
        _lastDirectControlTapTime != null &&
        now.difference(_lastDirectControlTapTime!) <=
            _directControlDoubleTapWindow;
    final bool withinDistance =
        _lastDirectControlTapLocal != null &&
        (screenPosition - _lastDirectControlTapLocal!).distance <=
            _directControlDoubleTapDistance;

    if (sameTarget && withinTime && withinDistance) {
      _resetDirectControlTapTracking();
      _actuateDirectCanvasControl(target.id, target.modelType);
      return;
    }

    _lastDirectControlTapTime = now;
    _lastDirectControlTapElementId = target.id;
    _lastDirectControlTapLocal = screenPosition;
  }

  void _resetDirectControlTapTracking() {
    _lastDirectControlTapTime = null;
    _lastDirectControlTapElementId = null;
    _lastDirectControlTapLocal = null;
  }

  bool _usesDirectCanvasControl(String modelType) =>
      switch (modelType.toLowerCase()) {
        'switch' ||
        'switch_spst' ||
        'push_button_no' ||
        'push_button_nc' ||
        'breaker_dc' ||
        'breaker_ac1' ||
        'breaker' ||
        'breaker_3p' ||
        'breaker_4p' ||
        'isolator_3p' ||
        'isolator_4p' ||
        'thermal_overload_3p' => true,
        _ => false,
      };

  void _actuateDirectCanvasControl(String elementId, String modelType) {
    if (_blockStudentTpMutation()) return;
    final String type = modelType.toLowerCase();

    if (type == 'push_button_no' || type == 'push_button_nc') {
      _momentaryReleaseTimers.remove(elementId)?.cancel();
      final CircuitState pressed = F9ElementEditor.setPushButtonPressed(
        _circuit,
        elementId,
        pressed: true,
      );
      if (!identical(pressed, _circuit)) {
        setState(() {
          _circuit = pressed;
          _selected = elementId;
          _status = 'Commande directe : $elementId — appuyé';
        });
        _simulation.updateCircuit(_circuit);
        _syncStudentTpCircuit();
      }

      _momentaryReleaseTimers[elementId] = Timer(
        const Duration(milliseconds: 260),
        () {
          if (!mounted) return;
          final CircuitState released = F9ElementEditor.setPushButtonPressed(
            _circuit,
            elementId,
            pressed: false,
          );
          if (identical(released, _circuit)) return;
          setState(() {
            _circuit = released;
            _status = 'Commande directe : $elementId — relâché';
          });
          _simulation.updateCircuit(_circuit);
          _syncStudentTpCircuit();
        },
      );
      return;
    }

    final bool isProtectionReset =
        type == 'breaker_dc' ||
        type == 'breaker_ac1' ||
        type == 'breaker' ||
        type == 'breaker_3p' ||
        type == 'breaker_4p' ||
        type == 'thermal_overload_3p';
    if (isProtectionReset &&
        _simulation.snapshot.protectionTripped(ComponentId(elementId))) {
      final CircuitState closed = F9ElementEditor.setComponentClosed(
        _circuit,
        elementId,
        closed: true,
      );
      if (!identical(closed, _circuit)) {
        setState(() {
          _circuit = closed;
          _selected = elementId;
        });
        _simulation.updateCircuit(_circuit);
      }
      _simulation.rearmProtection(ComponentId(elementId));
      setState(() {
        _selected = elementId;
        _status = 'Commande directe : $elementId — protection réarmée';
      });
      _syncStudentTpCircuit();
      return;
    }

    final CircuitState next = F9ElementEditor.togglePrimaryState(
      _circuit,
      elementId,
    );
    if (identical(next, _circuit)) {
      _setStatus('Commande directe indisponible pour $elementId');
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(next, elementId);
    setState(() {
      _circuit = next;
      _selected = elementId;
      _status =
          'Commande directe : $elementId — ${details?.stateLabel ?? 'mis à jour'}';
    });
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
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
      _setBoundedViewportTranslation(
        _viewport.translation + event.localPanDelta,
      );
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

  void _onCanvasPointerHover(PointerHoverEvent event) =>
      _updateWiringHover(event.localPosition);

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

  void _clampCurrentViewport() =>
      _setBoundedViewportTranslation(_viewport.translation);

  void _fitCircuitToViewport() {
    final Size size = _canvasViewportSize();
    if (size.isEmpty) {
      return;
    }
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      _circuit,
      _layout,
    );
    if (geometry.elementRects.isEmpty) {
      _viewport.reset(scale: 1, translation: const Offset(40, 40));
      return;
    }

    Rect bounds = geometry.elementRects.values.first;
    for (final Rect rect in geometry.elementRects.values.skip(1)) {
      bounds = bounds.expandToInclude(rect);
    }
    for (final Connection connection in _circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      for (final Offset point in <Offset>[
        start,
        ..._layout.routeFor(connection.id.value),
        end,
      ]) {
        bounds = bounds.expandToInclude(
          Rect.fromCircle(center: point, radius: 1),
        );
      }
    }

    bounds = bounds.inflate(32);
    final double scaleX =
        (size.width - 32).clamp(120.0, double.infinity) / bounds.width;
    final double scaleY =
        (size.height - 32).clamp(120.0, double.infinity) / bounds.height;
    final double scale = math.min(scaleX, scaleY).clamp(0.75, 1.50).toDouble();
    final Offset translation = Offset(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    );
    _viewport.reset(scale: scale, translation: translation);
    _clampCurrentViewport();
  }

  Size _canvasViewportSize() {
    final RenderObject? renderObject = _canvasDropKey.currentContext
        ?.findRenderObject();
    return renderObject is RenderBox ? renderObject.size : const Size(800, 520);
  }

  void _updateWiringHover(Offset localPosition) {
    if (_wiringPendingTerminal == null) {
      return;
    }
    final CanvasHitResult hit = _f9CanvasHit(localPosition);
    final TerminalId? next = hit.kind == CanvasHitKind.terminal
        ? hit.terminalId
        : null;
    if (next == _wiringHoverTerminal) {
      return;
    }
    setState(() {
      _wiringHoverTerminal = next;
    });
  }

  void _handleConnectionRequested(TerminalId from, TerminalId to) {
    if (_blockStudentTpMutation()) return;
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
      _circuit,
      from,
      to,
    );
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

    final CircuitState nextCircuit = F9WiringPolicy.append(
      _circuit,
      connection,
    );
    final CircuitVisualLayout nextLayout = _routeWithG2A(nextCircuit, _layout);
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
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
    _announce(decision.message);
  }

  void _commitElementMoveIfSafe(
    String elementId,
    Offset position, {
    bool moving = false,
  }) {
    if (moving) {
      final CircuitVisualLayout base = _directDragBaseLayout ?? _layout;
      final CircuitVisualLayout preview = F18DragPreviewPolicy.previewMove(
        circuit: _circuit,
        baseLayout: base,
        elementId: elementId,
        position: position,
      );
      setState(() {
        _layout = preview;
      });
      return;
    }

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
      _status = 'Position graphique mise à jour : $elementId';
    });
  }

  void _finalizeDirectDrag(String elementId) {
    final CircuitVisualLayout? base = _directDragBaseLayout;
    if (base == null) {
      return;
    }

    final CircuitVisualLayout candidate = _routeWithG2A(_circuit, _layout);
    if (!F18WorkspaceWireSafety.isCrossingFree(
      circuit: _circuit,
      layout: candidate,
    )) {
      setState(() {
        _layout = base;
        _status =
            'Déplacement refusé : aucun routage final sans croisement de nets.';
      });
      return;
    }

    setState(() {
      _layout = candidate;
      _status = 'Position graphique mise à jour : $elementId';
    });
  }

  void _cancelCanvasInteraction() {
    final CircuitVisualLayout? dragBase = _directDragBaseLayout;
    setState(() {
      _canvasInteractionEpoch += 1;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      if (dragBase != null) {
        _layout = dragBase;
      }
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
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _replaceSelectedElement() async {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null) {
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(
      _circuit,
      selected,
    );
    if (details == null || details.kind != F9ElementKind.component) {
      _setStatus('Remplacement indisponible pour cet élément.');
      return;
    }
    final ComponentInstance original = _circuit.components.singleWhere(
      (ComponentInstance item) => item.id.value == selected,
    );
    final List<F9PaletteDefinition> candidates = f9PaletteCatalog
        .where(
          (F9PaletteDefinition item) =>
              item.kind == F9PaletteElementKind.component &&
              item.supportsMode(_circuit.mode) &&
              item.terminalCount == original.terminals.length,
        )
        .toList(growable: false);
    final F9PaletteDefinition? replacement =
        await showDialog<F9PaletteDefinition>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Remplacer le composant'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: ListView(
                children: candidates
                    .map(
                      (F9PaletteDefinition item) => ListTile(
                        key: Key('replace-${item.keyName}'),
                        leading: F18ComponentArchetypeGlyph(
                          modelType: item.modelType,
                        ),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle ?? item.category),
                        onTap: () => Navigator.of(dialogContext).pop(item),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        );
    if (!mounted || replacement == null) {
      return;
    }
    final List<Terminal> generatedTerminals = _buildPaletteTerminals(
      replacement,
      selected,
    );
    final List<Terminal> replacementTerminals = <Terminal>[
      for (var index = 0; index < original.terminals.length; index++)
        Terminal(
          id: original.terminals[index].id,
          name: generatedTerminals[index].name,
          role: generatedTerminals[index].role,
          phase: generatedTerminals[index].phase,
        ),
    ];
    final Map<String, Object?> replacementParameters = <String, Object?>{
      ...(replacement.defaultParameters.isNotEmpty
          ? replacement.defaultParameters
          : _defaultParametersFor(replacement.keyName)),
      if (replacement.visualModelType != null)
        '_visualModelType': replacement.visualModelType!,
      if (replacement.visualVariant != null)
        '_visualVariant': replacement.visualVariant!,
      if (replacement.displayLabel != null)
        '_displayLabel': replacement.displayLabel!,
    };
    final CircuitState next = F9ElementEditor.replaceComponent(
      _circuit,
      selected,
      modelType: replacement.modelType,
      parameters: replacementParameters,
      controlState: replacement.defaultControlState.isNotEmpty
          ? replacement.defaultControlState
          : _defaultControlStateFor(replacement.keyName),
      replacementTerminals: replacementTerminals,
    );
    setState(() {
      _circuit = next;
      final Map<String, Size> sizes = <String, Size>{..._layout.elementSizes};
      if (F18ReferenceComponentVisuals.supports(
        replacement.renderedModelType,
      )) {
        sizes[selected] = F18ReferenceComponentMetrics.boardSizeFor(
          replacement.renderedModelType,
        );
      } else {
        sizes.remove(selected);
      }
      _layout = _routeWithG2A(
        _circuit,
        CircuitVisualLayout(
          elementPositions: _layout.elementPositions,
          elementSizes: sizes,
          wireRoutes: _layout.wireRoutes,
          elementQuarterTurns: _layout.elementQuarterTurns,
          defaultElementSize: _layout.defaultElementSize,
        ),
      );
      _status = 'Remplacement : $selected → ${replacement.title}';
    });
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
    _announce(_status);
  }

  void _toggleSelectedPrimaryState() {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null) {
      return;
    }
    final CircuitState next = F9ElementEditor.togglePrimaryState(
      _circuit,
      selected,
    );
    if (identical(next, _circuit)) {
      _setStatus('Aucun état commutable pour $selected');
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(next, selected);
    setState(() {
      _circuit = next;
      _status =
          'État modifié : $selected — ${details?.stateLabel ?? 'mis à jour'}';
    });
    _simulation.updateCircuit(_circuit);
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
    if (_selectedIds.length > 1) {
      _deleteMultipleSelection();
      return;
    }
    final String? selected = _selected;
    if (selected == null) {
      _setStatus('Suppression impossible : aucune sélection.');
      return;
    }
    final F9ElementDetails? details = F9ElementEditor.describe(
      _circuit,
      selected,
    );
    if (details == null) {
      _setStatus('Suppression impossible : sélection introuvable.');
      return;
    }

    if (details.kind == F9ElementKind.connection) {
      final CircuitState next = F9ElementEditor.deleteConnection(
        _circuit,
        selected,
      );
      if (identical(next, _circuit)) {
        _setStatus('Suppression impossible : fil introuvable.');
        return;
      }
      final Map<String, List<Offset>> routes = <String, List<Offset>>{
        ..._layout.wireRoutes,
      }..remove(selected);
      setState(() {
        _circuit = next;
        _layout = _routeWithG2A(
          _circuit,
          CircuitVisualLayout(
            elementPositions: _layout.elementPositions,
            elementSizes: _layout.elementSizes,
            wireRoutes: routes,
            elementQuarterTurns: _layout.elementQuarterTurns,
            defaultElementSize: _layout.defaultElementSize,
          ),
        );
        _selected = null;
        _status = 'Suppression : fil — $selected';
      });
      _simulation.updateCircuit(_circuit);
      _syncStudentTpCircuit();
      _announce(_status);
      return;
    }
    final Set<TerminalId> removedTerminalIds = <TerminalId>{};
    for (final ComponentInstance component in _circuit.components) {
      if (component.id.value == selected) {
        removedTerminalIds.addAll(
          component.terminals.map((Terminal item) => item.id),
        );
      }
    }
    for (final SourceInstance source in _circuit.sources) {
      if (source.id.value == selected) {
        removedTerminalIds.addAll(
          source.terminals.map((Terminal item) => item.id),
        );
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
    final Map<String, Offset> positions = <String, Offset>{
      ..._layout.elementPositions,
    }..remove(selected);
    final Map<String, Size> sizes = <String, Size>{..._layout.elementSizes}
      ..remove(selected);
    final Map<String, int> rotations = <String, int>{
      ..._layout.elementQuarterTurns,
    }..remove(selected);
    final Map<String, List<Offset>> routes =
        <String, List<Offset>>{..._layout.wireRoutes}..removeWhere(
          (String key, List<Offset> value) =>
              removedConnectionIds.contains(key),
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
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
  }

  void _deleteMultipleSelection() {
    final Set<String> selectedIds = <String>{..._selectedIds};
    if (selectedIds.isEmpty) {
      _setStatus('Suppression impossible : aucune sélection.');
      return;
    }

    CircuitState next = _circuit;
    var removedCount = 0;
    for (final String id in selectedIds) {
      final F9ElementDetails? details =
          F9ElementEditor.describe(next, id) ??
          F9ElementEditor.describe(_circuit, id);
      if (details == null) continue;
      final CircuitState candidate = details.kind == F9ElementKind.connection
          ? F9ElementEditor.deleteConnection(next, id)
          : F9ElementEditor.deleteElement(next, id);
      if (!identical(candidate, next)) {
        next = candidate;
        removedCount += 1;
      }
    }

    if (removedCount == 0) {
      _setStatus('Suppression impossible : sélection introuvable.');
      return;
    }

    final Set<String> remainingElements = <String>{
      ...next.sources.map((SourceInstance item) => item.id.value),
      ...next.components.map((ComponentInstance item) => item.id.value),
    };
    final Set<String> remainingConnections = next.connections
        .map((Connection item) => item.id.value)
        .toSet();

    final Map<String, Offset> positions = <String, Offset>{
      for (final MapEntry<String, Offset> entry
          in _layout.elementPositions.entries)
        if (remainingElements.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, Size> sizes = <String, Size>{
      for (final MapEntry<String, Size> entry in _layout.elementSizes.entries)
        if (remainingElements.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, int> rotations = <String, int>{
      for (final MapEntry<String, int> entry
          in _layout.elementQuarterTurns.entries)
        if (remainingElements.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, List<Offset>> routes = <String, List<Offset>>{
      for (final MapEntry<String, List<Offset>> entry
          in _layout.wireRoutes.entries)
        if (remainingConnections.contains(entry.key)) entry.key: entry.value,
    };

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
      _status = 'Suppression multiple : $removedCount éléments sélectionnés';
    });
    _simulation.updateCircuit(_circuit);
    _syncStudentTpCircuit();
    _announce(_status);
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
    final Map<String, Offset> positions = <String, Offset>{};
    final Map<String, Size> sizes = <String, Size>{};
    final List<(String, String)> elements = <(String, String)>[
      ...circuit.sources.map(
        (SourceInstance item) => (
          item.id.value,
          (item.parameters['_visualModelType'] as String?) ?? item.modelType,
        ),
      ),
      ...circuit.components.map(
        (ComponentInstance item) => (
          item.id.value,
          (item.parameters['_visualModelType'] as String?) ?? item.modelType,
        ),
      ),
    ];
    for (var index = 0; index < elements.length; index++) {
      final int column = index % 3;
      final int row = index ~/ 3;
      final (String id, String modelType) = elements[index];
      positions[id] = Offset(144 + (column * 240.0), 192 + (row * 192.0));
      if (F18ReferenceComponentVisuals.supports(modelType)) {
        sizes[id] = F18ReferenceComponentMetrics.boardSizeFor(modelType);
      }
    }

    final CircuitVisualLayout base = CircuitVisualLayout(
      elementPositions: positions,
      elementSizes: sizes,
    );
    final CircuitVisualLayout arranged = _arrangeSimpleDcCircuit(circuit, base);
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
    final CircuitVisualLayout routed = _g2aWireLayoutEngine.routeAll(
      circuit: circuit,
      layout: layout,
    );
    if (!_isSimpleSeriesDc(circuit)) {
      return routed;
    }

    // The G2A router may deliberately leave a connection without waypoints.
    // With the larger reference-component envelopes that can expose a direct
    // diagonal segment. For the bounded simple-series DC arrangement only,
    // insert one Manhattan corner so the public wire contract stays strictly
    // orthogonal. The normal G2A route remains authoritative whenever it
    // produced an explicit route.
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      routed,
    );
    final Map<String, List<Offset>> routes = <String, List<Offset>>{
      ...routed.wireRoutes,
    };
    var changed = false;

    for (final Connection connection in circuit.connections) {
      final List<Offset> existing = routed.routeFor(connection.id.value);
      if (existing.isNotEmpty) continue;

      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null ||
          end == null ||
          start.dx == end.dx ||
          start.dy == end.dy) {
        continue;
      }

      routes[connection.id.value] = <Offset>[Offset(end.dx, start.dy)];
      changed = true;
    }

    if (!changed) {
      return routed;
    }
    return CircuitVisualLayout(
      elementPositions: routed.elementPositions,
      elementSizes: routed.elementSizes,
      wireRoutes: routes,
      elementQuarterTurns: routed.elementQuarterTurns,
      defaultElementSize: routed.defaultElementSize,
    );
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
    });
  }

  void _onSimulationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final Timer timer in _momentaryReleaseTimers.values) {
      timer.cancel();
    }
    _momentaryReleaseTimers.clear();
    _simulation.removeListener(_onSimulationChanged);
    _simulation.dispose();
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
    required this.onExitWorkspace,
    required this.onSave,
    required this.onOpen,
    required this.onRotateSelected,
    required this.onDeleteSelected,
    required this.onRecenter,
    required this.electricalMode,
    required this.onSelectElectricalMode,
    required this.simulationRunning,
    required this.simulatedTime,
    required this.onToggleSimulation,
    required this.onResetSimulation,
  });

  final String entryLabel;
  final String workspace;
  final bool sessionNavigation;
  final VoidCallback onHome;
  final VoidCallback? onDashboard;
  final VoidCallback? onManageSession;
  final VoidCallback? onExitWorkspace;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;
  final VoidCallback? onRotateSelected;
  final VoidCallback? onDeleteSelected;
  final VoidCallback onRecenter;
  final ElectricalMode electricalMode;
  final ValueChanged<ElectricalMode> onSelectElectricalMode;
  final bool simulationRunning;
  final Duration simulatedTime;
  final VoidCallback onToggleSimulation;
  final VoidCallback onResetSimulation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          return SizedBox(
            height: compact
                ? ElectroSimGeometry.compactTopBarHeight
                : ElectroSimGeometry.desktopTopBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ElectroSimSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    key: const Key('session-home-action'),
                    tooltip: 'Accueil',
                    onPressed: onHome,
                    icon: const Icon(Icons.home_outlined),
                  ),
                  if (onExitWorkspace != null)
                    IconButton(
                      key: const Key('workspace-exit-action'),
                      tooltip: 'Quitter l’atelier',
                      onPressed: onExitWorkspace,
                      icon: const Icon(Icons.arrow_back_outlined),
                    ),
                  const SizedBox(width: ElectroSimSpacing.xxs),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!compact)
                          Text(
                            workspace,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: ElectroSimColors.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<ElectricalMode>(
                    key: const Key('workspace-electrical-mode'),
                    tooltip: 'Domaine électrique',
                    initialValue: electricalMode,
                    onSelected: onSelectElectricalMode,
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<ElectricalMode>>[
                          const PopupMenuItem<ElectricalMode>(
                            key: Key('workspace-mode-dc'),
                            value: ElectricalMode.dc,
                            enabled: true,
                            child: Text('CC — courant continu'),
                          ),
                          const PopupMenuItem<ElectricalMode>(
                            key: Key('workspace-mode-ac1'),
                            value: ElectricalMode.ac1,
                            enabled: true,
                            child: Text('AC 1φ — monophasé'),
                          ),
                          const PopupMenuItem<ElectricalMode>(
                            key: Key('workspace-mode-ac3'),
                            value: ElectricalMode.ac3,
                            enabled: true,
                            child: Text('AC 3φ — triphasé'),
                          ),
                          const PopupMenuItem<ElectricalMode>(
                            key: Key('workspace-mode-pv'),
                            value: ElectricalMode.pv,
                            enabled: true,
                            child: Text('PV — photovoltaïque'),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ElectroSimSpacing.xs,
                        vertical: ElectroSimSpacing.xxs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.bolt_outlined, size: 18),
                          if (!compact) ...<Widget>[
                            const SizedBox(width: 4),
                            Text(switch (electricalMode) {
                              ElectricalMode.dc => 'CC',
                              ElectricalMode.ac1 => 'AC 1φ',
                              ElectricalMode.ac3 => 'AC 3φ',
                              ElectricalMode.pv => 'PV',
                            }, style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (sessionNavigation) ...<Widget>[
                    IconButton(
                      key: const Key('session-dashboard-action'),
                      tooltip: 'Tableau de bord',
                      onPressed: onDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                    ),
                    IconButton(
                      key: const Key('session-manage-action'),
                      tooltip: 'Gérer la session',
                      onPressed: onManageSession,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                  IconButton(
                    key: const Key('workspace-simulation-toggle'),
                    tooltip: simulationRunning
                        ? 'Mettre la simulation en pause'
                        : 'Démarrer la simulation',
                    onPressed: onToggleSimulation,
                    icon: Icon(
                      simulationRunning
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                  ),
                  IconButton(
                    key: const Key('workspace-rotate-action'),
                    tooltip: 'Rotation 90°',
                    onPressed: onRotateSelected,
                    icon: const Icon(Icons.rotate_right_outlined),
                  ),
                  IconButton(
                    key: const Key('workspace-delete-action'),
                    tooltip: 'Supprimer la sélection',
                    onPressed: onDeleteSelected,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  PopupMenuButton<_WorkspaceSecondaryAction>(
                    key: const Key('workspace-more-actions'),
                    tooltip: 'Plus d’actions',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (_WorkspaceSecondaryAction action) {
                      switch (action) {
                        case _WorkspaceSecondaryAction.save:
                          onSave?.call();
                        case _WorkspaceSecondaryAction.open:
                          onOpen?.call();
                        case _WorkspaceSecondaryAction.recenter:
                          onRecenter();
                        case _WorkspaceSecondaryAction.resetSimulation:
                          onResetSimulation();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<_WorkspaceSecondaryAction>>[
                          if (onSave != null)
                            const PopupMenuItem<_WorkspaceSecondaryAction>(
                              key: Key('workspace-save-action'),
                              value: _WorkspaceSecondaryAction.save,
                              child: ListTile(
                                leading: Icon(Icons.save_outlined),
                                title: Text('Sauvegarder'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (onOpen != null)
                            const PopupMenuItem<_WorkspaceSecondaryAction>(
                              key: Key('workspace-open-action'),
                              value: _WorkspaceSecondaryAction.open,
                              child: ListTile(
                                leading: Icon(Icons.restore_outlined),
                                title: Text('Reprendre'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          const PopupMenuItem<_WorkspaceSecondaryAction>(
                            key: Key('workspace-reset-simulation-action'),
                            value: _WorkspaceSecondaryAction.resetSimulation,
                            child: ListTile(
                              leading: Icon(Icons.restart_alt),
                              title: Text('Réinitialiser la simulation'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<_WorkspaceSecondaryAction>(
                            key: Key('workspace-recenter-action'),
                            value: _WorkspaceSecondaryAction.recenter,
                            child: ListTile(
                              leading: Icon(Icons.center_focus_strong),
                              title: Text('Recentrer la platine'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _WorkspaceSecondaryAction { save, open, recenter, resetSimulation }

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
  const _StatusBar({
    required this.circuit,
    required this.status,
    required this.simulationRunning,
    required this.simulatedTime,
  });

  final CircuitState circuit;
  final String status;
  final bool simulationRunning;
  final Duration simulatedTime;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          final int elementCount =
              circuit.components.length + circuit.sources.length;
          final String simulationLabel =
              '${simulationRunning ? '▶' : 'Ⅱ'} t=${(simulatedTime.inMilliseconds / 1000).toStringAsFixed(1)} s';
          final String countLabel = compact
              ? '$elementCount élém. · $simulationLabel'
              : '$elementCount élément${elementCount == 1 ? '' : 's'} · '
                    '${circuit.sources.length} source${circuit.sources.length == 1 ? '' : 's'} · '
                    '${circuit.mode.name.toUpperCase()} · $simulationLabel · Révision ${circuit.revision}';
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ElectroSimSpacing.sm,
            ),
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
        toTerminalId: switchIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-2'),
        fromTerminalId: switchOut.id,
        toTerminalId: lampIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-3'),
        fromTerminalId: lampOut.id,
        toTerminalId: sourceNegative.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
  );
}
