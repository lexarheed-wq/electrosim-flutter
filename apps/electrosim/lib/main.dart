import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f9_auto_placement.dart';
import 'f9_component_palette.dart';
import 'f9_wiring_policy.dart';
import 'f9_ui_context.dart';
import 'f9_context_panels.dart';
import 'f9_component_visuals.dart';
import 'f9_element_editor.dart';
import 'f9_canvas_interaction.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrosim_tp_session_controller.dart';

void main() {
  runApp(const ElectroSimApp());
}

class ElectroSimApp extends StatelessWidget {
  const ElectroSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroSim',
      theme: ElectroSimTheme.light(),
      home: const F9HomePage(),
    );
  }
}

class F9HomePage extends StatelessWidget {
  const F9HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final ElectroSimWindowClass windowClass = ElectroSimBreakpoints.classify(constraints.maxWidth);
            final double maxContentWidth = windowClass == ElectroSimWindowClass.expanded ? 1180 : 760;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.all(ElectroSimSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _BrandHeader(),
                      const SizedBox(height: ElectroSimSpacing.xl),
                      Text('Que voulez-vous faire ?', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: ElectroSimSpacing.xs),
                      Text(
                        'Accédez au simulateur, à la maintenance ou à la conception depuis une structure commune.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ElectroSimColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: ElectroSimSpacing.lg),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints bodyConstraints) {
                            final double cardWidth = _homeCardWidth(windowClass, bodyConstraints.maxWidth);
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: ElectroSimSpacing.md,
                                runSpacing: ElectroSimSpacing.md,
                                children: <Widget>[
                                  _HomeActionCard(
                                    key: const Key('home-create-session'),
                                    width: cardWidth,
                                    icon: Icons.add_circle_outline,
                                    title: 'Créer une nouvelle session',
                                    description: 'Préparer une activité et ouvrir un espace de travail.',
                                    onTap: () => _openWorkspace(
                                      context,
                                      'Session active',
                                      initialWorkspace: 'Câblage',
                                      sessionNavigation: true,
                                    ),
                                  ),
                                  _HomeActionCard(
                                    key: const Key('home-maintenance'),
                                    width: cardWidth,
                                    icon: Icons.build_circle_outlined,
                                    title: 'Centre de maintenance',
                                    description: 'Accéder aux parcours de recherche de dérangement.',
                                    onTap: () => _openWorkspace(
                                      context,
                                      'Centre de maintenance',
                                      initialWorkspace: 'Recherche de dérangement',
                                    ),
                                  ),
                                  _HomeActionCard(
                                    key: const Key('home-design'),
                                    width: cardWidth,
                                    icon: Icons.account_tree_outlined,
                                    title: 'Centre de conception',
                                    description: 'Câbler librement et préparer les futurs schémas sains.',
                                    onTap: () => _openWorkspace(
                                      context,
                                      'Centre de conception',
                                      initialWorkspace: 'Câblage',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
    );
  }

  static double _homeCardWidth(ElectroSimWindowClass windowClass, double availableWidth) {
    if (windowClass == ElectroSimWindowClass.compact) {
      return availableWidth;
    }
    if (windowClass == ElectroSimWindowClass.medium) {
      return (availableWidth - ElectroSimSpacing.md) / 2;
    }
    return (availableWidth - (ElectroSimSpacing.md * 2)) / 3;
  }

  static void _openWorkspace(
    BuildContext context,
    String entryLabel, {
    required String initialWorkspace,
    bool sessionNavigation = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => F9WorkspaceDemoPage(
          entryLabel: entryLabel,
          initialWorkspace: initialWorkspace,
          sessionNavigation: sessionNavigation,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ElectroSimColors.primary,
            borderRadius: BorderRadius.circular(ElectroSimRadii.card),
          ),
          child: const Icon(Icons.bolt, color: Colors.white),
        ),
        const SizedBox(width: ElectroSimSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('ElectroSim', style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Laboratoire électrique',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ElectroSimColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    super.key,
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: description,
      child: SizedBox(
        width: width,
        child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElectroSimRadii.panel),
          side: const BorderSide(color: ElectroSimColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ElectroSimRadii.panel),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ElectroSimSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 32, color: ElectroSimColors.primary),
                const SizedBox(height: ElectroSimSpacing.lg),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: ElectroSimSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ElectroSimColors.textSecondary),
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Ouvrir'),
                    SizedBox(width: ElectroSimSpacing.xs),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class F9WorkspaceDemoPage extends StatefulWidget {
  const F9WorkspaceDemoPage({
    super.key,
    this.entryLabel = 'Centre de conception',
    this.initialWorkspace = 'Câblage',
    this.sessionNavigation = false,
    this.initialSelectedElementId,
    this.role = F9UserRole.teacher,
    this.tpSessionController,
  });

  final String entryLabel;
  final String initialWorkspace;
  final bool sessionNavigation;
  final String? initialSelectedElementId;
  final F9UserRole role;
  final ElectroSimTpSessionController? tpSessionController;

  @override
  State<F9WorkspaceDemoPage> createState() => _F9WorkspaceDemoPageState();
}

class _F9WorkspaceDemoPageState extends State<F9WorkspaceDemoPage> {
  late CircuitState _circuit = _buildDemoCircuit();
  late CircuitVisualLayout _layout = CircuitVisualLayout(
    elementPositions: const <String, Offset>{
      'source-24v': Offset(150, 220),
      'switch-1': Offset(390, 220),
      'lamp-1': Offset(630, 220),
    },
    wireRoutes: const <String, List<Offset>>{
      'wire-1': <Offset>[Offset(270, 160), Offset(330, 160)],
      'wire-2': <Offset>[Offset(510, 280), Offset(570, 280)],
      'wire-3': <Offset>[Offset(630, 360), Offset(150, 360)],
    },
  );
  final ViewportController _viewport = ViewportController(scale: 1, translation: const Offset(40, 40));
  final GlobalKey _canvasDropKey = GlobalKey(debugLabel: 'f9-canvas-drop-target');
  late String? _selected;
  String _status = 'F9 final — interface responsive et Canvas F8 validé';
  late String _workspace;
  int _canvasInteractionEpoch = 0;
  final HitTestEngine _f9HitTest = const HitTestEngine();
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

  bool get _studentTpReadOnly =>
      widget.role == F9UserRole.student && _tpController.readOnly;

  @override
  void initState() {
    super.initState();
    _workspace = widget.initialWorkspace;
    _selected = widget.initialSelectedElementId;
    _ownsTpController = widget.tpSessionController == null;
    _tpController =
        widget.tpSessionController ?? ElectroSimTpSessionController();
    final TpSession? tp = _tpController.session;
    if (widget.role == F9UserRole.student &&
        tp != null &&
        tp.lifecycle != TpLifecycle.draft &&
        tp.lifecycle != TpLifecycle.published) {
      _circuit = tp.studentCircuit;
      _workspace = 'Recherche de dérangement';
      _layout = _layoutForCircuit(_circuit);
    } else {
      _layout = F9OrthogonalRouter.reroute(_circuit, _layout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ElectroSimRuntimeSnapshot runtimeSnapshot =
        const ElectroSimRuntimeEngine().evaluate(_circuit);
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
            onDashboard: widget.sessionNavigation ? _showDashboard : null,
            onManageSession: widget.sessionNavigation ? _showManageSession : null,
            onRecenter: () => _viewport.reset(translation: const Offset(40, 40)),
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
            onDeleteSelected: _selected == null ? null : _deleteSelectedElement,
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
          canvas: KeyedSubtree(
            key: const Key('f9-canvas-drop-region'),
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
                          setState(() {
                            _layout = F9OrthogonalRouter.reroute(_circuit, _layout.moveElement(id, position));
                            _status = 'Position graphique mise à jour : $id';
                          });
                        },
                        onConnectionRequested: _handleConnectionRequested,
                        onContextAction: (CanvasHitResult hit) {
                          setState(() {
                            _status = 'Action contextuelle : ${hit.kind.name}. Les mêmes actions sont disponibles dans Propriétés.';
                          });
                        },
                        enableInteraction: false,
                      ),
                      AnimatedBuilder(
                        animation: _viewport,
                        builder: (BuildContext context, Widget? child) => F9CanvasVisualOverlay(
                          circuit: _circuit,
                          layout: _layout,
                          viewport: _viewport,
                          pendingTerminalId: _wiringPendingTerminal,
                          hoverTerminalId: _wiringHoverTerminal,
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

  Future<void> _showManageSession() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => F17TpSessionDialog(
        controller: _tpController,
        role: widget.role,
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
      _layout = F9OrthogonalRouter.reroute(_circuit, _layout.moveElement(elementId, worldPosition));
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

  CanvasHitResult _f9CanvasHit(Offset localPosition) => _f9HitTest.hitTest(
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
      setState(() {
        _layout = F9OrthogonalRouter.reroute(
          _circuit,
          _layout.moveElement(draggingId, nextPosition),
        );
        _status = 'Déplacement : $draggingId';
      });
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
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(_circuit, from, to);
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
    setState(() {
      _circuit = F9WiringPolicy.append(_circuit, connection);
      _layout = F9OrthogonalRouter.reroute(_circuit, _layout);
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _status = decision.message;
    });
    _syncStudentTpCircuit();
    _announce(decision.message);
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
              leading: F9ComponentGlyph(modelType: item.modelType),
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
      _layout = F9OrthogonalRouter.reroute(_circuit, _layout);
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
    final Map<String, Size> sizes = <String, Size>{..._layout.elementSizes}..remove(selected);
    final Map<String, List<Offset>> routes = <String, List<Offset>>{..._layout.wireRoutes}
      ..removeWhere((String key, List<Offset> value) => removedConnectionIds.contains(key));
    setState(() {
      _circuit = next;
      _layout = F9OrthogonalRouter.reroute(
        _circuit,
        CircuitVisualLayout(
          elementPositions: positions,
          elementSizes: sizes,
          wireRoutes: routes,
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
    final Map<String, Offset> positions = <String, Offset>{};
    final List<String> ids = <String>[
      ...circuit.sources.map((SourceInstance item) => item.id.value),
      ...circuit.components.map((ComponentInstance item) => item.id.value),
    ];
    for (var index = 0; index < ids.length; index++) {
      final int column = index % 3;
      final int row = index ~/ 3;
      positions[ids[index]] = Offset(
        140 + (column * 240.0),
        180 + (row * 180.0),
      );
    }
    return F9OrthogonalRouter.reroute(
      circuit,
      CircuitVisualLayout(elementPositions: positions),
    );
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
    });
  }

  @override
  void dispose() {
    _viewport.dispose();
    if (_ownsTpController) {
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
    required this.onRecenter,
  });

  final String entryLabel;
  final String workspace;
  final bool sessionNavigation;
  final VoidCallback onHome;
  final VoidCallback? onDashboard;
  final VoidCallback? onManageSession;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: SizedBox(
        height: 64,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: ElectroSimSpacing.xs),
              child: Row(
                children: <Widget>[
                  if (sessionNavigation && !compact)
                    TextButton.icon(
                      key: const Key('session-home-action'),
                      onPressed: onHome,
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Accueil'),
                    )
                  else
                    IconButton(
                      key: const Key('session-home-action'),
                      tooltip: 'Accueil',
                      onPressed: onHome,
                      icon: const Icon(Icons.home_outlined),
                    ),
                  const SizedBox(width: ElectroSimSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          workspace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ElectroSimColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sessionNavigation) ...<Widget>[
                    if (compact)
                      IconButton(
                        key: const Key('session-dashboard-action'),
                        tooltip: 'Tableau de bord',
                        onPressed: onDashboard,
                        icon: const Icon(Icons.dashboard_outlined),
                      )
                    else
                      TextButton.icon(
                        key: const Key('session-dashboard-action'),
                        onPressed: onDashboard,
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('Tableau de bord'),
                      ),
                    if (compact)
                      IconButton(
                        key: const Key('session-manage-action'),
                        tooltip: 'Gérer la session',
                        onPressed: onManageSession,
                        icon: const Icon(Icons.settings_outlined),
                      )
                    else
                      TextButton.icon(
                        key: const Key('session-manage-action'),
                        onPressed: onManageSession,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Gérer la session'),
                      ),
                  ] else
                    ElectroSimStatusChip(
                      key: const Key('direct-entry-status'),
                      label: 'Accès direct',
                      icon: Icons.open_in_new_outlined,
                      emphasized: true,
                    ),
                  IconButton(
                    tooltip: 'Recentrer le Canvas',
                    onPressed: onRecenter,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            );
          },
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
    circuitId: CircuitId('f9-final-demo'),
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
