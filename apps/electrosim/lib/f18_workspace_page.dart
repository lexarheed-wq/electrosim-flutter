import 'runtime/energy_meter_runtime.dart';
import 'f18_native_appliance_assets.dart';
// Shared electrical workspace for desktop and browser frontends.
// The student browser must import this module, never the Mac application entrypoint.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'f17_tp_session_dialog.dart';
import 'f17_tp_supervision_panel.dart';
import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';
import 'f18_drag_preview.dart';
import 'f18_physical_instrument_readouts.dart';
import 'mixed_board_runtime_view.dart';
import 'f18_voltmeter_3d_assets.dart';
import 'f18_ammeter_3d_assets.dart';
import 'f18_ammeter_controls.dart';
import 'f18_frequency_3d_assets.dart';
import 'f18_phase_sequence_3d_assets.dart';
import 'f18_crusher_3d_assets.dart';
import 'f18_frequency_controls.dart';
import 'f18_voltmeter_controls.dart';
import 'f18_physical_layout_migration.dart';
import 'f18_selection_state.dart';
import 'f18_workspace_wire_safety.dart';
import 'industrial_workspace_representation.dart';
import 'industrial_marking_registry.dart';
import 'industrial_schematic_svg_export.dart';
import 'industrial_schematic_pdf_export.dart';
import 'industrial_cabinet_workspace.dart';
import 'f9_auto_placement.dart';
import 'f9_component_palette.dart';
import 'f9_wiring_policy.dart';
import 'reference_components/reference_widgets.dart';
import 'reference_components/disjoncteur_3d.dart';
import 'f9_ui_context.dart';
import 'f9_context_panels.dart';
import 'f9_component_visuals.dart';
import 'f9_element_editor.dart';
import 'f9_canvas_interaction.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_connection_router.dart';
import 'runtime/electrosim_instrument_projection.dart';
import 'runtime/f18_ammeter_fuse_safety.dart';
import 'runtime/f18_continuity_audio.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrosim_persistence_controller.dart';
import 'runtime/electrosim_simulation_controller.dart';
import 'runtime/electrosim_tp_session_controller.dart';
import 'runtime/workspace_layout_preferences.dart';

class F18WorkspacePage extends StatefulWidget {
  const F18WorkspacePage({
    super.key,
    this.entryLabel = 'Centre de conception',
    this.initialWorkspace = 'Câblage',
    this.sessionNavigation = false,
    this.initialSelectedElementId,
    this.initialCircuit,
    this.initialCabinetLayout,
    this.initialVisualLayout,
    this.onVisualLayoutChanged,
    this.onCircuitChanged,
    this.compositeNetworkMode = false,
    this.paletteModeOverride,
    this.onOpenMixedMode,
    this.externalRuntimeSnapshot,
    this.mixedRuntimeView,
    this.role = F9UserRole.teacher,
    this.tpSessionController,
    this.persistenceController,
    this.layoutPreferences,
    this.layoutPreferencesFuture,
    this.syncClient,
    this.onSessionDashboard,
    this.onSessionHome,
    this.onSessionManage,
    this.onSessionManageWithCircuit,
    this.onExitWorkspace,
  });

  final String entryLabel;
  final String initialWorkspace;
  final bool sessionNavigation;
  final String? initialSelectedElementId;
  final CircuitState? initialCircuit;
  final CabinetLayout? initialCabinetLayout;
  final CircuitVisualLayout? initialVisualLayout;
  final ValueChanged<CircuitVisualLayout>? onVisualLayoutChanged;
  final ValueChanged<CircuitState>? onCircuitChanged;
  final bool compositeNetworkMode;
  final ElectricalMode? paletteModeOverride;
  final ValueChanged<CircuitState>? onOpenMixedMode;
  final ElectroSimRuntimeSnapshot? externalRuntimeSnapshot;
  final MixedBoardRuntimeView? mixedRuntimeView;
  final F9UserRole role;
  final ElectroSimTpSessionController? tpSessionController;
  final ElectroSimPersistenceController? persistenceController;
  final WorkspaceLayoutPreferences? layoutPreferences;
  final Future<WorkspaceLayoutPreferences>? layoutPreferencesFuture;
  final ElectroSimLanSyncClient? syncClient;
  final VoidCallback? onSessionDashboard;
  final VoidCallback? onSessionHome;
  final VoidCallback? onSessionManage;
  final ValueChanged<CircuitState>? onSessionManageWithCircuit;
  final VoidCallback? onExitWorkspace;

  @override
  State<F18WorkspacePage> createState() => _F18WorkspacePageState();
}

final class _F18WorkspaceHistoryEntry {
  const _F18WorkspaceHistoryEntry(this.circuit, this.layout, this.selectedId);
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final String? selectedId;
}

class _F18WorkspacePageState extends State<F18WorkspacePage> {
  String? _studentTpIdValue;
  CircuitVisualLayout? _lastReportedVisualLayout;
  bool _visualLayoutReportScheduled = false;
  CircuitState? _lastReportedCircuit;
  bool _circuitReportScheduled = false;

  void _scheduleCircuitReport() {
    final ValueChanged<CircuitState>? callback = widget.onCircuitChanged;
    if (callback == null ||
        identical(_circuit, _lastReportedCircuit) ||
        _circuitReportScheduled) {
      return;
    }
    _circuitReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _circuitReportScheduled = false;
      if (!mounted || identical(_circuit, _lastReportedCircuit)) return;
      _lastReportedCircuit = _circuit;
      widget.onCircuitChanged?.call(_circuit);
    });
  }

  bool get _visualLayoutMatchesSession {
    if (widget.role != F9UserRole.student) return true;
    final session = _tpController.session;
    return session != null &&
        _studentTpIdValue == session.definition.id.value &&
        _circuit.circuitId == session.studentCircuit.circuitId &&
        _circuit.revision == session.studentCircuit.revision;
  }

  // Report committed geometry after the frame, including asynchronous routing.
  // Drag previews use their separate notifier and never enter this snapshot.
  void _scheduleVisualLayoutReport() {
    if (!_visualLayoutMatchesSession ||
        widget.onVisualLayoutChanged == null ||
        identical(_layout, _lastReportedVisualLayout) ||
        _visualLayoutReportScheduled) {
      return;
    }
    _visualLayoutReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visualLayoutReportScheduled = false;
      if (!mounted ||
          !_visualLayoutMatchesSession ||
          identical(_layout, _lastReportedVisualLayout)) {
        return;
      }
      _lastReportedVisualLayout = _layout;
      widget.onVisualLayoutChanged?.call(_layout);
    });
  }

  WorkspaceRepresentation _representation = WorkspaceRepresentation.plate;
  final Map<WorkspaceRepresentation, (double, Offset)> _viewports = {};
  CircuitVisualLayout? _schematicAuthorLayout;
  CircuitState? _schematicCircuit;
  CircuitVisualLayout? _schematicLayout;

  CircuitVisualLayout _displayLayout(CircuitVisualLayout author) {
    if (_representation == WorkspaceRepresentation.plate) return author;
    if (!identical(author, _schematicAuthorLayout) ||
        !identical(_circuit, _schematicCircuit)) {
      _schematicAuthorLayout = author;
      _schematicCircuit = _circuit;
      _schematicLayout = IndustrialSchematicProjection.derive(_circuit, author);
    }
    return _schematicLayout!;
  }

  void _selectRepresentation(WorkspaceRepresentation next) {
    if (_representation == next) return;
    _viewports[_representation] = (_viewport.scale, _viewport.translation);
    _prepareWorkspaceLayoutChange();
    setState(() {
      _representation = next;
      _selectedCabinetFixtureId = null;
      _status = next == WorkspaceRepresentation.plate
          ? 'Platine : implantation physique'
          : 'Schéma : symboles et connexions';
    });
    final saved = _viewports[next];
    if (saved == null) {
      _fitCircuitToViewport();
    } else {
      _viewport.reset(scale: saved.$1, translation: saved.$2);
    }
    _scheduleLayoutSave();
  }

  Future<void> _exportSchematic({required bool pdf}) async {
    // Native save locations are supported on macOS, Windows and Linux.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      _setStatus('Export schéma : sélectionner la version de bureau.');
      return;
    }
    final kind = pdf ? 'PDF' : 'SVG';
    final extension = pdf ? 'pdf' : 'svg';
    final circuit = _circuit;
    final layout = _layout;
    final fileId = circuit.circuitId.value.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final filename = 'ElectroSim_${fileId}_schema.$extension';
    try {
      final destination = await getSaveLocation(suggestedName: filename);
      if (destination == null) return;
      final Uint8List bytes = pdf
          ? await IndustrialSchematicPdfExport.render(circuit, layout)
          : Uint8List.fromList(
              utf8.encode(IndustrialSchematicSvgExport.render(circuit, layout)),
            );
      await XFile.fromData(
        bytes,
        mimeType: pdf ? 'application/pdf' : 'image/svg+xml',
        name: filename,
      ).saveTo(destination.path);
      if (!mounted) return;
      _setStatus('Schéma $kind exporté : ${destination.path}');
    } on Object catch (error) {
      if (!mounted) return;
      _setStatus('Échec de l’export $kind : $error');
    }
  }

  CircuitState _continueIndustrialMarking(CircuitState candidate) {
    if (widget.role != F9UserRole.teacher ||
        !_circuit.metadata.containsKey(IndustrialMarkingRegistry.metadataKey)) {
      return candidate;
    }
    return IndustrialMarkingRegistry.materialize(candidate);
  }

  CircuitVisualLayout _mergeBoardLayout(
    CircuitVisualLayout defaults,
    CircuitVisualLayout saved,
  ) => CircuitVisualLayout(
    elementPositions: <String, Offset>{
      ...defaults.elementPositions,
      ...saved.elementPositions,
    },
    elementSizes: <String, Size>{...defaults.elementSizes, ...saved.elementSizes},
    wireRoutes: <String, List<Offset>>{...defaults.wireRoutes, ...saved.wireRoutes},
    elementQuarterTurns: <String, int>{
      ...defaults.elementQuarterTurns,
      ...saved.elementQuarterTurns,
    },
    defaultElementSize: saved.defaultElementSize,
    cabinetLayout: saved.cabinetLayout,
    terminalAnchorOffsets: <String, Offset>{
      ...defaults.terminalAnchorOffsets,
      ...saved.terminalAnchorOffsets,
    },
  );

  void _generateIndustrialMarkings() {
    if (widget.role != F9UserRole.teacher) {
      _setStatus('Repérage réservé au professeur.');
      return;
    }
    final next = IndustrialMarkingRegistry.materialize(_circuit);
    final plan = IndustrialMarkingRegistry.inspect(next);
    final message =
        'Repérage : ${plan.devices.length} appareils, '
        '${plan.conductors.length} conducteurs, '
        '${plan.terminals.length} bornes. '
        '${plan.issues.length} anomalie(s).';
    if (identical(next, _circuit)) {
      _setStatus(message);
      return;
    }
    setState(() {
      _circuit = next;
      _status = message;
    });
    _updateSimulationCircuit(next);
  }

  Future<void> _editSelectedIndustrialMarking() async {
    if (widget.role != F9UserRole.teacher) {
      _setStatus('Modification des repères réservée au professeur.');
      return;
    }
    final selected = _selected;
    if (selected == null) {
      _setStatus('Sélectionner un appareil ou un fil à repérer.');
      return;
    }
    final plan = IndustrialMarkingRegistry.inspect(_circuit);
    final kind = plan.devices.containsKey(selected)
        ? IndustrialMarkingKind.device
        : plan.conductors.containsKey(selected)
        ? IndustrialMarkingKind.conductor
        : null;
    if (kind == null) {
      _setStatus('Sélectionner un appareil ou un conducteur.');
      return;
    }
    final availablePorts = <Terminal>[
      for (final source in _circuit.sources)
        if (source.id.value == selected) ...source.terminals,
      for (final component in _circuit.components)
        if (component.id.value == selected) ...component.terminals,
    ];
    var targetId = selected;
    var targetKind = kind;
    var editedReference = plan.referenceOf(targetKind, targetId);
    var locked = plan.locks['${targetKind.name}:$targetId'] ?? false;
    final answer =
        await showDialog<(IndustrialMarkingKind, String, String, bool)>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: const Text('Repérage industriel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (availablePorts.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: const Key('p4-marking-target'),
                      initialValue: targetId,
                      decoration: const InputDecoration(
                        labelText: 'Élément / borne',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: selected,
                          child: Text('Appareil : $selected'),
                        ),
                        for (final port in availablePorts)
                          DropdownMenuItem(
                            value: port.id.value,
                            child: Text('Borne : ${port.name}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          targetId = value;
                          targetKind = value == selected
                              ? IndustrialMarkingKind.device
                              : IndustrialMarkingKind.terminal;
                          editedReference = plan.referenceOf(
                            targetKind,
                            targetId,
                          );
                          locked =
                              plan.locks['${targetKind.name}:$targetId'] ??
                              false;
                        });
                      },
                    ),
                  KeyedSubtree(
                    key: ValueKey(targetId),
                    child: TextFormField(
                      key: const Key('p4-marking-text'),
                      initialValue: editedReference,
                      onChanged: (value) => editedReference = value,
                      decoration: const InputDecoration(labelText: 'Repère'),
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('p4-marking-locked'),
                    value: locked,
                    title: const Text('Verrouiller ce repère'),
                    onChanged: (value) => setDialogState(() => locked = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  key: const Key('p4-marking-apply'),
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop((targetKind, targetId, editedReference, locked)),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        );
    if (answer == null || !mounted) return;
    try {
      final next = IndustrialMarkingRegistry.setReference(
        _circuit,
        kind: answer.$1,
        id: answer.$2,
        reference: answer.$3,
        locked: answer.$4,
        teacherAuthorized: widget.role == F9UserRole.teacher,
      );
      final issues = IndustrialMarkingRegistry.inspect(next).issues;
      setState(() {
        _circuit = next;
        _status =
            'Repère enregistré : ${answer.$3}. '
            '${issues.length} anomalie(s) de repérage.';
      });
      _updateSimulationCircuit(next);
    } on Object catch (error) {
      _setStatus('Repérage refusé : $error');
    }
  }

  static const int _maxHistoryEntries = 64;
  final List<_F18WorkspaceHistoryEntry> _undoHistory =
      <_F18WorkspaceHistoryEntry>[];
  final List<_F18WorkspaceHistoryEntry> _redoHistory =
      <_F18WorkspaceHistoryEntry>[];
  bool _restoringHistory = false;

  bool _sameEditableGeometry(
    CircuitVisualLayout before,
    CircuitVisualLayout after,
  ) =>
      mapEquals(before.elementPositions, after.elementPositions) &&
      mapEquals(before.elementSizes, after.elementSizes) &&
      mapEquals(before.elementQuarterTurns, after.elementQuarterTurns) &&
      _sameCabinetGeometry(before.cabinetLayout, after.cabinetLayout);

  bool _sameCabinetGeometry(CabinetLayout a, CabinetLayout b) {
    if (a.fixtures.length != b.fixtures.length ||
        a.envelope != b.envelope ||
        !mapEquals(a.mounts, b.mounts)) {
      return false;
    }
    for (var index = 0; index < a.fixtures.length; index++) {
      final first = a.fixtures[index];
      final second = b.fixtures[index];
      if (first.id != second.id ||
          first.kind != second.kind ||
          first.bounds != second.bounds) {
        return false;
      }
    }
    return true;
  }

  @override
  void setState(VoidCallback fn) {
    final CircuitState beforeCircuit = _circuit;
    final CircuitVisualLayout beforeLayout = _layout;
    final String? beforeSelection = _selected;
    super.setState(fn);
    _scheduleVisualLayoutReport();
    if (_restoringHistory || _studentTpReadOnly) return;
    if (!identical(beforeCircuit, _circuit) ||
        !_sameEditableGeometry(beforeLayout, _layout)) {
      _undoHistory.add(
        _F18WorkspaceHistoryEntry(beforeCircuit, beforeLayout, beforeSelection),
      );
      if (_undoHistory.length > _maxHistoryEntries) {
        _undoHistory.removeAt(0);
      }
      _redoHistory.clear();
    }
  }

  // P2 cabinet fixtures belong to visual layout, never to electrical
  // CircuitState. Edits are undoable through the existing history.
  CabinetLayout _cabinetWithDefaultMounts() {
    var cabinet = _layout.cabinetLayout;
    void add(String id, String type) {
      if (!cabinet.mounts.containsKey(id)) {
        cabinet = cabinet.withMount(
          id,
          IndustrialEquipmentProfile.mounting(type, _layout.sizeOf(id)),
        );
      }
    }

    for (final c in _circuit.components) {
      add(
        c.id.value,
        (c.parameters['_visualModelType'] as String?) ?? c.modelType,
      );
    }
    for (final c in _circuit.sources) {
      add(
        c.id.value,
        (c.parameters['_visualModelType'] as String?) ?? c.modelType,
      );
    }
    return cabinet;
  }

  String? _cabinetConfigurationProblem(
    CabinetLayout cabinet, {
    CircuitVisualLayout? layout,
    CircuitState? circuit,
  }) {
    final e = cabinet.envelope;
    if (e == null) return null;
    for (final fixture in cabinet.fixtures) {
      if (!e.contains(fixture.bounds)) {
        return 'Le support ${fixture.id} dépasse la plaque utile.';
      }
    }
    final geometry = CircuitGeometryIndex.build(
      circuit ?? _circuit,
      layout ?? _layout,
    );
    for (final item in geometry.elementRects.entries) {
      final details = F9ElementEditor.describe(circuit ?? _circuit, item.key);
      if (details == null) continue;
      final mount =
          cabinet.mounts[item.key] ??
          IndustrialEquipmentProfile.mounting(
            (details.parameters['_visualModelType'] as String?) ??
                details.modelType,
            (layout ?? _layout).sizeOf(item.key),
          );
      if (!e.contains(item.value, surface: mount.surface)) {
        return '${item.key} dépasse sa surface de montage. Agrandissez l’armoire ou repositionnez cet équipement.';
      }
      if (mount.surface == CabinetSurface.interior &&
          mount.depthMm + 20 > e.depthMm) {
        return 'Profondeur insuffisante pour ${item.key}.';
      }
    }
    return null;
  }

  Future<void> _configureCabinet() async {
    if (_blockStudentTpMutation()) return;
    _prepareWorkspaceLayoutChange();
    final selected = F9ElementEditor.describe(_circuit, _selected);
    final cabinet = await showDialog<CabinetLayout>(
      context: context,
      builder: (context) => IndustrialCabinetInspector(
        cabinet: _cabinetWithDefaultMounts(),
        validate: _cabinetConfigurationProblem,
        selectedId: selected?.kind == F9ElementKind.connection
            ? null
            : selected?.id,
        selectedModelType: selected?.kind == F9ElementKind.connection
            ? null
            : (selected?.parameters['_visualModelType'] as String?) ??
                  selected?.modelType,
        selectedSize: selected == null ? null : _layout.sizeOf(selected.id),
        selectedFixture: _layout.cabinetLayout.fixture(
          _selectedCabinetFixtureId ?? '',
        ),
      ),
    );
    if (!mounted || cabinet == null) return;
    setState(() {
      _layout = _layout.withCabinetLayout(cabinet);
      _status = 'Armoire et surfaces de montage mises à jour';
    });
    _fitCircuitToViewport();
  }

  Future<void> _previewCabinet() async {
    _prepareWorkspaceLayoutChange();
    await showDialog<void>(
      context: context,
      builder: (context) =>
          IndustrialCabinetPreview(circuit: _circuit, layout: _layout),
    );
  }

  void _routeWiresViaCabinetDucts() {
    if (_blockStudentTpMutation()) return;
    if (!_layout.cabinetLayout.fixtures.any(
      (f) => f.kind == CabinetFixtureKind.wireDuct,
    )) {
      _setStatus('Ajoutez une goulotte avant de router les fils.');
      return;
    }
    final geometry = CircuitGeometryIndex.build(_circuit, _layout);
    final routes = <String, List<Offset>>{..._layout.wireRoutes};
    var changed = 0;
    for (final connection in _circuit.connections) {
      final a = geometry.terminalRoutingPositions[connection.fromTerminalId];
      final b = geometry.terminalRoutingPositions[connection.toTerminalId];
      final physicalA = geometry.terminalPositions[connection.fromTerminalId];
      final physicalB = geometry.terminalPositions[connection.toTerminalId];
      if (a == null || b == null || physicalA == null || physicalB == null) {
        continue;
      }
      final ownerA = geometry.terminalOwners[connection.fromTerminalId];
      final ownerB = geometry.terminalOwners[connection.toTerminalId];
      // Only the short physical-terminal escape may cross its own envelope.
      if (!CabinetDuctWirePlanner.isClear(
            [physicalA, a],
            obstacles: geometry.elementRects.entries
                .where((e) => e.key != ownerA)
                .map((e) => e.value),
          ) ||
          !CabinetDuctWirePlanner.isClear(
            [b, physicalB],
            obstacles: geometry.elementRects.entries
                .where((e) => e.key != ownerB)
                .map((e) => e.value),
          )) {
        continue;
      }
      final route = CabinetDuctWirePlanner.route(
        start: a,
        end: b,
        cabinet: _layout.cabinetLayout,
        obstacles: geometry.elementRects.values,
      );
      if (route == null) continue;
      routes[connection.id.value] = [a, ...route, b];
      changed++;
    }
    if (changed == 0) {
      _setStatus('Aucun fil admissible à router dans les goulottes.');
      return;
    }
    final candidate = CircuitVisualLayout(
      elementPositions: _layout.elementPositions,
      elementSizes: _layout.elementSizes,
      wireRoutes: routes,
      elementQuarterTurns: _layout.elementQuarterTurns,
      defaultElementSize: _layout.defaultElementSize,
      cabinetLayout: _layout.cabinetLayout,
    );
    if (!F18WorkspaceWireSafety.isRenderable(
      circuit: _circuit,
      layout: candidate,
    )) {
      _setStatus('Routage conservé : trajectoire non représentable.');
      return;
    }
    // Automatic route recomputation is excluded from geometry history. This
    // explicit author command must nevertheless restore the exact old routes.
    _undoHistory.add(_F18WorkspaceHistoryEntry(_circuit, _layout, _selected));
    if (_undoHistory.length > _maxHistoryEntries) {
      _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
    setState(() {
      _layout = candidate;
      _status = 'Câbles routés orthogonalement en goulottes : $changed';
    });
  }

  void _toggleCabinetSnap() {
    setState(() {
      _cabinetPlacementMode = _cabinetPlacementMode == CabinetPlacementMode.free
          ? CabinetPlacementMode.assistedDin
          : CabinetPlacementMode.free;
      _status = _cabinetPlacementMode == CabinetPlacementMode.assistedDin
          ? 'Placement assisté sur rail DIN activé'
          : 'Placement libre activé';
    });
  }

  void _addCabinetFixture(CabinetFixtureKind kind) {
    if (_blockStudentTpMutation()) return;
    final size = switch (kind) {
      CabinetFixtureKind.dinRail => const Size(460, 34),
      CabinetFixtureKind.wireDuct => const Size(460, 42),
      CabinetFixtureKind.terminalZone => const Size(260, 58),
    };
    final canvasSize = _canvasViewportSize();
    final center = _viewport.screenToWorld(
      Offset(canvasSize.width / 2, canvasSize.height / 2),
    );
    final dy = switch (kind) {
      CabinetFixtureKind.dinRail => -110.0,
      CabinetFixtureKind.wireDuct => 130.0,
      CabinetFixtureKind.terminalZone => 220.0,
    };
    final count = _layout.cabinetLayout.fixtures
        .where((fixture) => fixture.kind == kind)
        .length;
    final id = 'cabinet-${kind.name}-${count + 1}';
    var nextId = id;
    var ordinal = count + 1;
    while (_layout.cabinetLayout.fixture(nextId) != null) {
      nextId = 'cabinet-${kind.name}-${++ordinal}';
    }
    final position = center + Offset(0, dy + 58 * count);
    final fixture = CabinetFixture(
      id: nextId,
      kind: kind,
      bounds: Rect.fromCenter(
        center: position,
        width: size.width,
        height: size.height,
      ),
    );
    if (!_cabinetFixtureValid(fixture)) {
      _setStatus(
        'Emplacement occupé : déplacez les autres équipements '
        'avant d’ajouter cet élément d’armoire.',
      );
      return;
    }
    setState(() {
      _layout = _layout.withCabinetLayout(_layout.cabinetLayout.add(fixture));
      _status = switch (kind) {
        CabinetFixtureKind.dinRail => 'Rail DIN ajouté à la platine',
        CabinetFixtureKind.wireDuct => 'Goulotte de câblage ajoutée',
        CabinetFixtureKind.terminalZone => 'Zone de borniers ajoutée',
      };
    });
  }

  void _undoEdit() {
    if (_studentTpReadOnly || _undoHistory.isEmpty) return;
    final _F18WorkspaceHistoryEntry previous = _undoHistory.removeLast();
    _redoHistory.add(_F18WorkspaceHistoryEntry(_circuit, _layout, _selected));
    _restoreEdit(previous, 'Modification annulée');
  }

  void _redoEdit() {
    if (_studentTpReadOnly || _redoHistory.isEmpty) return;
    final _F18WorkspaceHistoryEntry next = _redoHistory.removeLast();
    _undoHistory.add(_F18WorkspaceHistoryEntry(_circuit, _layout, _selected));
    _restoreEdit(next, 'Modification rétablie');
  }

  void _restoreEdit(_F18WorkspaceHistoryEntry entry, String status) {
    _restoringHistory = true;
    try {
      setState(() {
        _circuit = entry.circuit;
        _layout = entry.layout;
        _selected = entry.selectedId;
        _status = status;
        _wiringPendingTerminal = null;
        _wiringHoverTerminal = null;
        _dragPreviewLayout.value = null;
        _selectedCabinetFixtureId = null;
      });
    } finally {
      _restoringHistory = false;
    }
    _updateSimulationCircuit(_circuit);
    _syncStudentTpCircuit();
  }

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

  final WorkspaceLayoutController _workspaceLayout =
      WorkspaceLayoutController();
  WorkspaceLayoutPreferences? _layoutPreferences;
  late final Future<WorkspaceLayoutPreferences> _layoutPreferencesReady;
  int _layoutEditOrder = 0;
  Timer? _layoutSaveTimer;
  bool _layoutEdited = false;
  bool _restoringLayout = false;
  Size? _lastWorkspaceCanvasSize;

  late CircuitState _circuit;
  late CircuitVisualLayout _layout;
  bool _soundEnabled = true;
  bool _showAllTerminals = false;
  final ElectroSimConnectionRouter _connectionRouter =
      ElectroSimConnectionRouter();
  final ViewportController _viewport = ViewportController(
    minScale: 0.05,
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
  bool _saveInProgress = false;
  CircuitState? _meterReadoutCacheCircuit;
  ElectroSimRuntimeSnapshot? _meterReadoutCacheSnapshot;
  int? _meterReadoutCacheSecond;
  Map<String, String> _meterReadoutCache = const <String, String>{};
  final F18ContinuityAudio _continuityAudio = F18ContinuityAudio();
  late String _workspace;
  int _canvasInteractionEpoch = 0;
  final HitTestEngine _hitTest = const HitTestEngine();
  HitTestSession? _hitTestSession;
  CircuitState? _hitTestSessionCircuit;
  CircuitVisualLayout? _hitTestSessionLayout;
  final ValueNotifier<Offset?> _wiringPointerWorld = ValueNotifier<Offset?>(
    null,
  );
  TerminalId? _wiringPendingTerminal;
  TerminalId? _wiringHoverTerminal;
  int? _activeCanvasPointer;
  String? _selectedCabinetFixtureId;
  String? _draggingCabinetFixtureId;
  Offset? _cabinetPointerStart;
  Rect? _cabinetDragInitialBounds;
  bool _cabinetResizeActive = false;
  CabinetPlacementMode _cabinetPlacementMode = CabinetPlacementMode.free;
  String? _directDragElementId;
  Offset? _directDragGrabDelta;
  CircuitVisualLayout? _directDragBaseLayout;
  F18DragSession? _directDragSession;
  final ValueNotifier<CircuitVisualLayout?> _dragPreviewLayout =
      ValueNotifier<CircuitVisualLayout?>(null);
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
  Duration? _lastDirectControlTapTime;
  String? _lastDirectControlTapElementId;
  Offset? _lastDirectControlTapLocal;
  final Map<String, Timer> _momentaryReleaseTimers = <String, Timer>{};
  late final ElectroSimTpSessionController _tpController;
  late final bool _ownsTpController;
  ElectroSimLanSyncHost? _lanHost;
  ElectroSimLanHostInfo? _lanHostInfo;
  late final ElectroSimSimulationController _simulation;

  void _updateSimulationCircuit(CircuitState next) {
    // A shared mixed board is only a render/edit projection. Project runtime
    // owns simulation and sends homogeneous networks to their specialist solvers.
    if (widget.compositeNetworkMode) return;
    _simulation.updateCircuit(next);
  }
  ElectroSimRuntimeSnapshot get _runtimeSnapshot =>
      (widget.mixedRuntimeView?.runtimeForElement(_selected ?? '') ??
          widget.mixedRuntimeView?.defaultRuntime) ??
      widget.externalRuntimeSnapshot ?? _simulation.snapshot;
  bool get _simulationRunning =>
      widget.mixedRuntimeView?.running ?? _simulation.running;
  Duration get _simulatedTime =>
      widget.mixedRuntimeView?.elapsed ?? _simulation.simulatedTime;

  CabinetFixture? _cabinetFixtureAt(Offset local) {
    if (_representation != WorkspaceRepresentation.plate) return null;
    final world = _viewport.screenToWorld(local);
    for (final fixture in _layout.cabinetLayout.fixtures.reversed) {
      if (fixture.bounds.inflate(8 / _viewport.scale).contains(world)) {
        return fixture;
      }
    }
    return null;
  }

  Map<String, Rect> _cabinetDeviceRects() =>
      CircuitGeometryIndex.build(_circuit, _layout).elementRects;

  bool _cabinetFixtureValid(CabinetFixture fixture) {
    final envelope = _layout.cabinetLayout.envelope;
    if (envelope != null && !envelope.contains(fixture.bounds)) return false;
    for (final other in _layout.cabinetLayout.fixtures) {
      if (other.id == fixture.id || !fixture.bounds.overlaps(other.bounds)) {
        continue;
      }
      // Cabinet furniture (rail/duct/terminal zone) cannot silently
      // overlap other furniture. A rail may, however, sit behind a device.
      return false;
    }
    if (fixture.kind != CabinetFixtureKind.dinRail) {
      for (final entry in _cabinetDeviceRects().entries) {
        final details = F9ElementEditor.describe(_circuit, entry.key);
        final surface =
            _layout.cabinetLayout.mounts[entry.key]?.surface ??
            (details == null
                ? CabinetSurface.interior
                : IndustrialEquipmentProfile.defaultSurface(
                    (details.parameters['_visualModelType'] as String?) ??
                        details.modelType,
                  ));
        if (surface == CabinetSurface.interior &&
            entry.value.overlaps(fixture.bounds)) {
          return false;
        }
      }
    }
    return true;
  }

  void _finishCabinetDrag() {
    final id = _draggingCabinetFixtureId;
    final preview = _dragPreviewLayout.value;
    if (id != null && preview != null) {
      final fixture = preview.cabinetLayout.fixture(id);
      if (fixture != null && _cabinetFixtureValid(fixture)) {
        setState(() {
          _layout = preview;
          _selectedCabinetFixtureId = id;
          _status = 'Élément d’armoire repositionné : $id';
        });
      } else {
        _setStatus('Collision d’armoire : déplacement refusé.');
      }
    }
    _dragPreviewLayout.value = null;
    _draggingCabinetFixtureId = null;
    _cabinetPointerStart = null;
    _cabinetDragInitialBounds = null;
    _cabinetResizeActive = false;
  }

  bool get _studentTpReadOnly =>
      widget.role == F9UserRole.student && _tpController.readOnly;

  Set<String> get _voltmeter3dIds => F18Voltmeter3dAssets.ready
      ? _circuit.instruments
            .where(F18Voltmeter3dAssets.uses3d)
            .map((InstrumentInstance instrument) => instrument.id.value)
            .toSet()
      : const <String>{};

  Set<String> get _ammeter3dIds => F18Ammeter3dAssets.ready
      ? _circuit.instruments
            .where(F18Ammeter3dAssets.uses3d)
            .map((i) => i.id.value)
            .toSet()
      : const <String>{};

  Set<String> get _frequency3dIds => F18Frequency3dAssets.ready
      ? _circuit.instruments
            .where(F18Frequency3dAssets.uses3d)
            .map((i) => i.id.value)
            .toSet()
      : const <String>{};

  Set<String> get _phaseSequence3dIds => F18PhaseSequence3dAssets.ready
      ? _circuit.instruments
            .where(F18PhaseSequence3dAssets.uses3d)
            .map((i) => i.id.value)
            .toSet()
      : const <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(
      F18NativeApplianceAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      F18Crusher3dAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      F18PhaseSequence3dAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      F18Frequency3dAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      F18Ammeter3dAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      F18Voltmeter3dAssets.preload().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _circuit = widget.initialCircuit ?? _buildBlankCircuit();
    _workspace = widget.initialWorkspace;
    _selected = widget.initialSelectedElementId;
    _ownsTpController = widget.tpSessionController == null;
    _tpController =
        widget.tpSessionController ?? ElectroSimTpSessionController();
    widget.syncClient?.addListener(_onLanSyncChanged);
    final TpSession? tp = _tpController.session;
    _studentTpIdValue = tp?.definition.id.value;
    if (widget.role == F9UserRole.student &&
        tp != null &&
        tp.lifecycle != TpLifecycle.draft &&
        tp.lifecycle != TpLifecycle.published) {
      _circuit = tp.studentCircuit;
      _workspace = tp.definition.mode == TpMode.wiring
          ? 'Câblage'
          : 'Recherche de dérangement';
    }
    if (tp == null && !widget.compositeNetworkMode) {
      _circuit = AppliancePowerConnection.addProtectiveEarth(_circuit);
    }
    _layout = widget.initialVisualLayout == null
        ? _layoutForCircuit(_circuit)
        : widget.compositeNetworkMode
        ? _mergeBoardLayout(_layoutForCircuit(_circuit), widget.initialVisualLayout!)
        : widget.initialVisualLayout!;
    _layout = migrateCrusherPhysicalLayout(
      _circuit,
      _layout,
      router: _g2aWireLayoutEngine,
    );
    _layout = migrateNativeApplianceLayout(
      _circuit,
      _layout,
      router: _g2aWireLayoutEngine,
    );
    if (widget.initialCabinetLayout != null) {
      _layout = _layout.withCabinetLayout(widget.initialCabinetLayout!);
    }
    _simulation = ElectroSimSimulationController(
      circuit: widget.compositeNetworkMode ? _buildBlankCircuit() : _circuit,
    );
    if (widget.role == F9UserRole.student) {
      _tpController.addListener(_onStudentTpChanged);
    }
    _workspaceLayout.addListener(_scheduleLayoutSave);
    _layoutPreferencesReady = widget.layoutPreferences != null
        ? Future.value(widget.layoutPreferences!)
        : widget.layoutPreferencesFuture ??
              WorkspaceLayoutPreferences.createDefault();
    unawaited(_restoreWorkspaceLayout());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitCircuitToViewport();
      }
    });
  }

  void _prepareWorkspaceLayoutChange() {
    if (_activeCanvasPointer == null &&
        _wiringPendingTerminal == null &&
        !_trackpadPanZoomActive) {
      return;
    }
    setState(() {
      _canvasInteractionEpoch += 1;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _wiringPointerWorld.value = null;
      _clearDirectPointerState();
      _trackpadPanZoomActive = false;
      _trackpadLastScale = 1;
      _status = 'Interaction annulée : disposition modifiée.';
    });
  }

  void _onWorkspaceCanvasSizeChanged(Size size) {
    if (!mounted ||
        size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    final previous = _lastWorkspaceCanvasSize;
    _lastWorkspaceCanvasSize = size;
    if (previous == null || previous == size) return;
    _prepareWorkspaceLayoutChange();
    _viewport.preserveWorldCenterOnResize(previous, size);
  }

  Future<void> _restoreWorkspaceLayout() async {
    try {
      final preferences = await _layoutPreferencesReady;
      if (!mounted) return;
      _layoutPreferences = preferences;
      final stored = await preferences.load();
      if (!mounted) return;
      if (!_layoutEdited && stored != null) {
        _restoringLayout = true;
        _workspaceLayout.restore(stored);
        setState(() {
          _representation = stored['representation'] == 'schematic'
              ? WorkspaceRepresentation.schematic
              : WorkspaceRepresentation.plate;
        });
        _restoringLayout = false;
      } else if (_layoutEdited) {
        _scheduleLayoutSave(recordEdit: false);
      }
    } on Object {
      // Optional UI preferences must not prevent entering a workshop when the
      // platform preference directory is unavailable.
    }
  }

  void _scheduleLayoutSave({bool recordEdit = true}) {
    if (_restoringLayout) return;
    _layoutEdited = true;
    if (recordEdit) {
      _layoutEditOrder = WorkspaceLayoutPreferences.reserveSaveOrder();
    }
    _layoutSaveTimer?.cancel();
    if (_layoutPreferences == null) return;
    _layoutSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        _persistWorkspaceLayout(
          _workspaceLayout.toJson(),
          order: _layoutEditOrder,
        ),
      );
    });
  }

  Future<void> _persistWorkspaceLayout(
    Map<String, Object?> state, {
    required int order,
  }) async {
    final snapshot = {...state, 'representation': _representation.name};
    try {
      final preferences = _layoutPreferences ?? await _layoutPreferencesReady;
      await preferences.save(snapshot, order: order);
    } on Object {
      if (mounted) {
        _setStatus('Disposition non enregistrée. L’atelier reste utilisable.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleVisualLayoutReport();
    _scheduleCircuitReport();
    final F9ElementDetails? selectedDetails = F9ElementEditor.describe(
      _circuit,
      _selected,
    );
    final bool canDeleteSelection =
        (_selectedIds.isNotEmpty || _selectedCabinetFixtureId != null) &&
        !_studentTpReadOnly;
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
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                _undoEdit,
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                _undoEdit,
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
              shift: true,
            ): _redoEdit,
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): _redoEdit,
            const SingleActivator(LogicalKeyboardKey.keyY, control: true):
                _redoEdit,
            const SingleActivator(LogicalKeyboardKey.equal, shift: true): () =>
                _viewport.zoomAt(const Offset(400, 300), 1.1),
            const SingleActivator(LogicalKeyboardKey.minus): () =>
                _viewport.zoomAt(const Offset(400, 300), 0.9),
          },
          child: Focus(
            autofocus: true,
            child: ElectroSimWorkspaceShell(
              workspaceLabel: _representation == WorkspaceRepresentation.plate
                  ? 'PLATINE'
                  : 'SCHÉMA',
              layoutController: _workspaceLayout,
              onBeforeLayoutChange: _prepareWorkspaceLayoutChange,
              onCanvasSizeChanged: _onWorkspaceCanvasSizeChanged,
              topBar: AnimatedBuilder(
                animation: _simulation,
                builder: (BuildContext context, Widget? child) =>
                    _WorkspaceTopBar(
                      entryLabel: widget.entryLabel,
                      workspace: _workspace,
                      sessionNavigation: widget.sessionNavigation,
                      onHome:
                          widget.onSessionHome ??
                          () => Navigator.of(context).popUntil(
                            (Route<dynamic> route) =>
                                route.isFirst ||
                                route.settings.name == 'session-home',
                          ),
                      onDashboard: widget.sessionNavigation
                          ? (widget.onSessionDashboard ?? _showDashboard)
                          : null,
                      onManageSession: widget.sessionNavigation
                          ? (widget.onSessionManageWithCircuit != null
                                ? () => widget.onSessionManageWithCircuit!(
                                    _circuit,
                                  )
                                : (widget.onSessionManage ??
                                      _showManageSession))
                          : null,
                      onExitWorkspace: widget.onExitWorkspace,
                      onGenerateIndustrialMarkings:
                          widget.role == F9UserRole.teacher
                          ? _generateIndustrialMarkings
                          : null,
                      onEditIndustrialMarking: widget.role == F9UserRole.teacher
                          ? _editSelectedIndustrialMarking
                          : null,
                      onExportSchematicSvg: () =>
                          unawaited(_exportSchematic(pdf: false)),
                      onExportSchematicPdf: () =>
                          unawaited(_exportSchematic(pdf: true)),
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
                      onConfigureCabinet: _studentTpReadOnly
                          ? null
                          : _configureCabinet,
                      onPreviewCabinet: _previewCabinet,
                      representation: _representation,
                      onSelectRepresentation: _selectRepresentation,
                      onAddDinRail: _studentTpReadOnly
                          ? null
                          : () =>
                                _addCabinetFixture(CabinetFixtureKind.dinRail),
                      onAddWireDuct: _studentTpReadOnly
                          ? null
                          : () =>
                                _addCabinetFixture(CabinetFixtureKind.wireDuct),
                      onAddTerminalZone: _studentTpReadOnly
                          ? null
                          : () => _addCabinetFixture(
                              CabinetFixtureKind.terminalZone,
                            ),
                      onToggleCabinetSnap: _studentTpReadOnly
                          ? null
                          : _toggleCabinetSnap,
                      onRouteCabinetWires: _studentTpReadOnly
                          ? null
                          : _routeWiresViaCabinetDucts,
                      cabinetSnapEnabled:
                          _cabinetPlacementMode ==
                          CabinetPlacementMode.assistedDin,
                      electricalMode: _circuit.mode,
                      onSelectElectricalMode: _requestElectricalModeChange,
                      soundEnabled: _soundEnabled,
                      showAllTerminals: _showAllTerminals,
                      onToggleTerminals: () => setState(
                        () => _showAllTerminals = !_showAllTerminals,
                      ),
                      onToggleSound: () =>
                          setState(() => _soundEnabled = !_soundEnabled),
                      simulationRunning: _simulationRunning,
                      simulatedTime: _simulatedTime,
                      onToggleSimulation: widget.mixedRuntimeView == null
                          ? _simulation.toggle
                          : null,
                      onResetSimulation: widget.mixedRuntimeView == null
                          ? _simulation.resetDynamics
                          : null,
                      simulationAdvancing: _simulation.fastForwarding,
                      onAdvanceSimulation: widget.mixedRuntimeView == null
                          ? (Duration elapsed) {
                              unawaited(_advanceSimulation(elapsed));
                            }
                          : (_) {},
                      onCancelAdvance: widget.mixedRuntimeView == null
                          ? _simulation.cancelAdvance
                          : null,
                      onUndo: _undoHistory.isEmpty || _studentTpReadOnly
                          ? null
                          : _undoEdit,
                      onRedo: _redoHistory.isEmpty || _studentTpReadOnly
                          ? null
                          : _redoEdit,
                      showSimulationControls: !widget.compositeNetworkMode,
                      showModeSelector: !widget.compositeNetworkMode,
                    ),
              ),
              palette: F9ComponentPalette(
                mode: widget.paletteModeOverride ?? _circuit.mode,
                onStatus: _setStatus,
                onQuickAdd: _quickAddFromPalette,
              ),
              contextPanel:
                  _workspace == 'Supervision' &&
                      widget.role == F9UserRole.teacher
                  ? F17TpSupervisionPanel(controller: _tpController)
                  : AnimatedBuilder(
                      animation: _simulation,
                      builder: (BuildContext context, Widget? child) =>
                          F9ContextPanels(
                            circuit: _circuit,
                            onPowerConnectionChanged: _studentTpReadOnly
                                ? null
                                : _configureSelectedPower,
                            onConfigurePlc: _studentTpReadOnly
                                ? null
                                : _editPlcLadder,
                            onLinkPlcOutput: _studentTpReadOnly
                                ? null
                                : _linkPlcOutput,
                            onConfigureTimer: _studentTpReadOnly
                                ? null
                                : _editStarDeltaTimer,
                            onConfigureMechanicalInterlock: _studentTpReadOnly
                                ? null
                                : _editMechanicalInterlock,
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
                            runtimeSnapshot: _runtimeSnapshot,
                            mixedRuntimeView: widget.mixedRuntimeView,
                            tpSessionController:
                                widget.sessionNavigation ||
                                    widget.tpSessionController != null
                                ? _tpController
                                : null,
                          ),
                    ),
              statusBar: AnimatedBuilder(
                animation: _simulation,
                builder: (BuildContext context, Widget? child) => _StatusBar(
                  circuit: _circuit,
                  status: _status,
                  simulationRunning: _simulationRunning,
                  simulatedTime: _simulatedTime,
                ),
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
                            child: MouseRegion(
                              onExit: (_) {
                                if (_wiringHoverTerminal != null && mounted) {
                                  setState(() => _wiringHoverTerminal = null);
                                }
                              },
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
                                child: ValueListenableBuilder<CircuitVisualLayout?>(
                                  valueListenable: _dragPreviewLayout,
                                  builder:
                                      (
                                        BuildContext context,
                                        CircuitVisualLayout? dragLayout,
                                        Widget? child,
                                      ) {
                                        final CircuitVisualLayout canvasLayout =
                                            _displayLayout(
                                              dragLayout ?? _layout,
                                            );
                                        return Stack(
                                          clipBehavior: Clip.hardEdge,
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            SimulatorCanvas(
                                              key: ValueKey<int>(
                                                _canvasInteractionEpoch,
                                              ),
                                              circuit: _circuit,
                                              layout: canvasLayout,
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
                                                      'Action contextuelle : ${hit.kind.name}. '
                                                      'Les mêmes actions sont disponibles dans Propriétés.';
                                                });
                                              },
                                              enableInteraction: false,
                                              industrialPlatePresentation:
                                                  _representation ==
                                                  WorkspaceRepresentation.plate,
                                              paintElementChrome: false,
                                              schematicPresentation:
                                                  _representation ==
                                                  WorkspaceRepresentation
                                                      .schematic,
                                              smartWireSemantics: true,
                                              wirePreviewPlanner:
                                                  _g2aWirePreviewPlanner,
                                              customInstrumentCaseIds: <String>{
                                                ..._voltmeter3dIds,
                                                ..._ammeter3dIds,
                                                ..._frequency3dIds,
                                                ..._phaseSequence3dIds,
                                              },
                                            ),
                                            if (_representation ==
                                                WorkspaceRepresentation.plate)
                                              AnimatedBuilder(
                                                animation: _simulation,
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      Widget? child,
                                                    ) => F9CanvasVisualOverlay(
                                                      showAllTerminals:
                                                          _showAllTerminals,
                                                      circuit: _circuit,
                                                      layout: canvasLayout,
                                                      viewport: _viewport,
                                                      selectedElementIds:
                                                          _selectedIds,
                                                      pendingTerminalId:
                                                          _wiringPendingTerminal,
                                                      hoverTerminalId:
                                                          _wiringHoverTerminal,
                                                      pointerWorldPositionListenable:
                                                          _wiringPointerWorld,
                                                      wirePreviewPlanner:
                                                          _g2aWirePreviewPlanner,
                                                      runtimeSnapshot:
                                                          _runtimeSnapshot,
                                                      mixedRuntimeView:
                                                          widget.mixedRuntimeView,
                                                      soundEnabled:
                                                          _soundEnabled,
                                                      simulationRunning:
                                                          _simulationRunning,
                                                    ),
                                              ),
                                            if (_representation ==
                                                WorkspaceRepresentation
                                                    .schematic)
                                              IndustrialSchematicOverlay(
                                                circuit: _circuit,
                                                layout: canvasLayout,
                                                viewport: _viewport,
                                                selectedIds: _selectedIds,
                                                pointer: _wiringPointerWorld,
                                                pendingTerminal:
                                                    _wiringPendingTerminal,
                                                hoverTerminal:
                                                    _wiringHoverTerminal,
                                              ),
                                            if (_representation ==
                                                WorkspaceRepresentation.plate)
                                              IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _CabinetSelectionPainter(
                                                    fixture: canvasLayout
                                                        .cabinetLayout
                                                        .fixture(
                                                          _selectedCabinetFixtureId ??
                                                              '',
                                                        ),
                                                    viewport: _viewport,
                                                  ),
                                                  size: Size.infinite,
                                                ),
                                              ),
                                            if (_representation ==
                                                    WorkspaceRepresentation
                                                        .plate &&
                                                _circuit.instruments.isNotEmpty)
                                              AnimatedBuilder(
                                                animation: _simulation,
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      Widget? child,
                                                    ) => IgnorePointer(
                                                      child: CustomPaint(
                                                        painter: F18PhysicalInstrumentReadouts(
                                                          layout: canvasLayout,
                                                          viewport: _viewport,
                                                          readouts:
                                                              _physicalMeterReadouts(),
                                                          circuit: _circuit,
                                                          voltmeter3dIds:
                                                              _voltmeter3dIds,
                                                          voltmeterFront:
                                                              F18Voltmeter3dAssets
                                                                  .front,
                                                          ammeter3dIds:
                                                              _ammeter3dIds,
                                                          ammeterFront:
                                                              F18Ammeter3dAssets
                                                                  .front,
                                                          frequency3dIds:
                                                              _frequency3dIds,
                                                          frequencyFront:
                                                              F18Frequency3dAssets
                                                                  .front,
                                                          phaseSequence3dIds:
                                                              _phaseSequence3dIds,
                                                          phaseSequenceFront:
                                                              F18PhaseSequence3dAssets
                                                                  .front,
                                                          selectedElementId:
                                                              _selected,
                                                        ),
                                                        size: Size.infinite,
                                                      ),
                                                    ),
                                              ),
                                          ],
                                        );
                                      },
                                ),
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
    if (persistence == null || _saveInProgress) return;
    _saveInProgress = true;
    try {
      final saved = await persistence.saveWorkspace(
        circuit: EnergyMeterRuntime.persist(
          _circuit,
          _runtimeSnapshot.energyMeters,
        ),
        workspace: _workspace,
        visualLayout: _layout,
        tpController: _tpController,
      );
      if (!mounted) return;
      _setStatus(
        'Sauvegarde locale : révision ${saved.circuit.revision} — ${saved.saveId}',
      );
    } catch (error) {
      if (!mounted) return;
      _setStatus('Échec de sauvegarde locale : $error');
    } finally {
      _saveInProgress = false;
    }
  }

  Future<void> _openLatestWorkspace() async {
    final ElectroSimPersistenceController? persistence =
        widget.persistenceController;
    if (persistence == null) return;
    if (_workspaceHasAuthoredContent()) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Remplacer le travail actuel ?'),
          content: const Text(
            'Reprendre la dernière sauvegarde remplacera le circuit et sa '
            'disposition ouverts. Enregistrez-les avant de continuer si vous '
            'souhaitez les conserver.',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('workspace-resume-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continuer le travail actuel'),
            ),
            FilledButton(
              key: const Key('workspace-resume-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reprendre la sauvegarde'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
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
        _circuit = AppliancePowerConnection.addProtectiveEarth(
          restored.circuit,
        );
        _workspace = restored.workspace;
        _selected = null;
        final savedLayout = restored.visualLayout;
        final migrated = savedLayout == null
            ? null
            : migrateIndustrialPhysicalLayout(_circuit, savedLayout);
        _layout = migrated == null
            ? _layoutForCircuit(_circuit)
            : identical(migrated, savedLayout)
            ? migrated
            : _routeWithG2A(_circuit, migrated);
        _status =
            'Session reprise : révision ${_circuit.revision} — ${restored.saveId}';
        _layout = migrateCrusherPhysicalLayout(
          _circuit,
          _layout,
          router: _g2aWireLayoutEngine,
        );
        _layout = migrateNativeApplianceLayout(
          _circuit,
          _layout,
          router: _g2aWireLayoutEngine,
        );
      });
      _updateSimulationCircuit(_circuit);
    } catch (error) {
      if (!mounted) return;
      _setStatus('Échec de reprise locale : $error');
    }
  }

  bool _workspaceHasAuthoredContent() =>
      _circuit.components.isNotEmpty ||
      _circuit.sources.isNotEmpty ||
      _circuit.connections.isNotEmpty ||
      _layout.elementPositions.isNotEmpty ||
      _layout.elementSizes.isNotEmpty ||
      _layout.wireRoutes.isNotEmpty ||
      _layout.cabinetLayout.fixtures.isNotEmpty;

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

  void _onStudentTpChanged() {
    if (!mounted) return;
    final session = _tpController.session;
    if (session != null &&
        session.lifecycle != TpLifecycle.draft &&
        session.lifecycle != TpLifecycle.published &&
        (_studentTpIdValue != session.definition.id.value ||
            session.studentCircuit.circuitId != _circuit.circuitId ||
            session.studentCircuit.revision != _circuit.revision)) {
      final sameTp = _studentTpIdValue == session.definition.id.value;
      final next = session.studentCircuit;
      final defaults = _layoutForCircuit(next);
      if (sameTp && next.circuitId == _circuit.circuitId) {
        final ids = defaults.elementPositions.keys.toSet();
        final connections = next.connections.map((c) => c.id.value).toSet();
        _layout = CircuitVisualLayout(
          elementPositions: {
            for (final id in ids)
              id: _layout.positionOf(id) ?? defaults.elementPositions[id]!,
          },
          elementSizes: {
            for (final id in ids)
              if (_layout.elementSizes[id] ?? defaults.elementSizes[id]
                  case final Size size)
                id: size,
          },
          elementQuarterTurns: {
            for (final entry in _layout.elementQuarterTurns.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
          },
          wireRoutes: {
            for (final id in connections)
              id: _layout.wireRoutes[id] ?? defaults.wireRoutes[id] ?? [],
          },
          terminalAnchorOffsets: _layout.terminalAnchorOffsets,
          defaultElementSize: _layout.defaultElementSize,
          cabinetLayout: _layout.cabinetLayout.retainMounts(ids),
        );
      } else {
        _layout = defaults;
      }
      _studentTpIdValue = session.definition.id.value;
      _workspace = session.definition.mode == TpMode.wiring
          ? 'Câblage'
          : 'Recherche de dérangement';
      _circuit = next;
      _updateSimulationCircuit(_circuit);
    }
    setState(() {});
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
      _workspace = session.definition.mode == TpMode.wiring
          ? 'Câblage'
          : 'Recherche de dérangement';
      _selected = null;
      circuitChanged = true;
    }

    if (circuitChanged) {
      _updateSimulationCircuit(_circuit);
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
            _workspace = session.definition.mode == TpMode.wiring
                ? 'Câblage'
                : 'Recherche de dérangement';
            _status = 'TP commencé — montage élève chargé.';
          });
          _updateSimulationCircuit(_circuit);
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
            mode == ElectricalMode.mixed
                ? 'Le circuit ${_electricalModeLabel(_circuit.mode)} actuel sera conservé sur la platine Mixte. '
                    'Les autres domaines seront ajoutés vides et les réseaux resteront électriquement séparés.'
                : 'Passer de ${_electricalModeLabel(_circuit.mode)} à '
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

    if (mode == ElectricalMode.mixed) {
      final ValueChanged<CircuitState>? openMixed = widget.onOpenMixedMode;
      if (openMixed == null) {
        _setStatus('Ouvrez le mode Mixte depuis le simulateur principal.');
      } else {
        _simulation.pause();
        openMixed(_circuit);
      }
      return;
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
      _wiringPointerWorld.value = null;
      _status = 'Nouvelle platine ${_electricalModeLabel(mode)} prête.';
    });
    _updateSimulationCircuit(next);
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
        ElectricalMode.mixed => const <String, Object?>{},
      };

  String _electricalModeLabel(ElectricalMode mode) => switch (mode) {
    ElectricalMode.dc => 'CC',
    ElectricalMode.ac1 => 'AC 1φ',
    ElectricalMode.ac3 => 'AC 3φ',
    ElectricalMode.pv => 'PV',
    ElectricalMode.mixed => 'Mixte',
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
    final Size elementSize = definition.kind == F9PaletteElementKind.instrument
        ? const Size(112, 152)
        : F18ReferenceComponentVisuals.supports(definition.renderedModelType)
        ? F18ReferenceComponentMetrics.boardSizeFor(
            definition.renderedModelType,
            variantKey: definition.visualVariant,
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
      ..._circuit.instruments.map((InstrumentInstance item) => item.id.value),
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
    if (definition.kind == F9PaletteElementKind.instrument) {
      _addPhysicalInstrument(definition, worldPosition);
      return;
    }
    if (definition.kind == F9PaletteElementKind.component) {
      final ComponentModelContract? contract = CoreComponentModelContracts
          .registry
          .resolve(definition.modelType);
      if (contract != null && !contract.supportsMode(widget.paletteModeOverride ?? _circuit.mode)) {
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
        ...definition.defaultParameters,
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
      if (const {
        'catalog_appliance_2t',
        'catalog_heater',
        'catalog_motor_driven_2t',
      }.contains(definition.visualModelType)) {
        parameters = {
          ...parameters,
          'powerConnectionMode':
              (definition.visualVariant == 'refrigerator-dc' ||
                  definition.modelType == 'motor_dc')
              ? 'dc'
              : const {
                  'computer',
                  'television',
                  'iron',
                  'freezer',
                  'refrigerator',
                }.contains(definition.visualVariant)
              ? 'plug'
              : 'fixed',
        };
      }
      components.add(
        ComponentInstance(
          id: ComponentId(elementId),
          modelType: definition.modelType,
          terminals: terminals,
          parameters: parameters,
          controlState: definition.defaultControlState,
        ),
      );
    }

    var nextCircuit = _continueIndustrialMarking(
      CircuitState(
        circuitId: _circuit.circuitId,
        revision: _circuit.revision + 1,
        mode: _circuit.mode,
        components: components,
        connections: _circuit.connections,
        sources: sources,
        instruments: _circuit.instruments,
        probes: _circuit.probes,
        settings: _circuit.settings,
        metadata: _circuit.metadata,
      ),
    );

    if (_tpController.session == null && !widget.compositeNetworkMode) {
      nextCircuit = AppliancePowerConnection.addProtectiveEarth(nextCircuit);
    }
    final CircuitVisualLayout moved = _layout.moveElement(
      elementId,
      worldPosition,
    );
    final Map<String, Size> sizes = <String, Size>{...moved.elementSizes};
    if (F18ReferenceComponentVisuals.supports(definition.renderedModelType)) {
      sizes[elementId] = F18ReferenceComponentMetrics.boardSizeFor(
        definition.renderedModelType,
        variantKey: definition.visualVariant,
      );
    }
    var proposed = CircuitVisualLayout(
      elementPositions: moved.elementPositions,
      elementSizes: sizes,
      wireRoutes: moved.wireRoutes,
      elementQuarterTurns: moved.elementQuarterTurns,
      defaultElementSize: moved.defaultElementSize,
      cabinetLayout: moved.cabinetLayout,
    );
    proposed = proposed.withCabinetLayout(
      proposed.cabinetLayout.withMount(
        elementId,
        IndustrialEquipmentProfile.mounting(
          definition.renderedModelType,
          proposed.sizeOf(elementId),
        ),
      ),
    );
    final problem = _cabinetConfigurationProblem(
      proposed.cabinetLayout,
      layout: proposed,
      circuit: nextCircuit,
    );
    if (problem != null) {
      _setStatus(problem);
      return;
    }
    setState(() {
      _circuit = nextCircuit;
      _layout = proposed;
      _selected = elementId;
      _status = 'Ajout : ${definition.title} — $elementId';
    });
    final CircuitVisualLayout afterInsertion = _layout;
    _updateSimulationCircuit(_circuit);
    _syncStudentTpCircuit();
    unawaited(_finishElementRoute(nextCircuit, afterInsertion, elementId));
  }

  final Set<InstrumentId> _pendingAmmeterFuseTrips = <InstrumentId>{};

  /// Never mutate a circuit from inside a CustomPainter/build. A solver-
  /// verified overcurrent queues one post-frame transition, which stays
  /// latched in InstrumentInstance until a fuse is explicitly replaced.
  void _scheduleAmmeterFuseTrip(InstrumentId id) {
    if (!_pendingAmmeterFuseTrips.add(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingAmmeterFuseTrips.remove(id);
      if (!mounted) return;
      final CircuitState before = _circuit;
      final CircuitState after = F18AmmeterFuseSafety.latch(
        circuit: before,
        instrumentId: id,
      );
      if (identical(before, after)) return;
      setState(() {
        _circuit = after;
        _meterReadoutCacheCircuit = null;
        _status =
            'Ampèremètre : fusible déclenché. '
            'Circuit de mesure ouvert. Remplacement requis.';
      });
      _updateSimulationCircuit(after);
      _syncStudentTpCircuit();
    });
  }

  Map<String, String> _physicalMeterReadouts() {
    if (_circuit.instruments.isEmpty) {
      unawaited(_continuityAudio.setActive(false));
      return const <String, String>{};
    }
    final int second = _simulatedTime.inMilliseconds ~/ 1000;
    final ElectroSimRuntimeSnapshot snapshot = _runtimeSnapshot;
    // The authored circuit identity invalidates cache on wiring edits.
    // Recalculate immediately if solve status changes (ERR -> valid) while
    // retaining one-second throttling during steady-state simulation; each
    // physical probe may require a separate expensive solver projection.
    if (widget.mixedRuntimeView == null &&
        identical(_meterReadoutCacheCircuit, _circuit) &&
        _meterReadoutCacheSecond == second &&
        (_meterReadoutCacheSnapshot?.solved == snapshot.solved)) {
      return _meterReadoutCache;
    }
    const ElectroSimInstrumentProjection projection =
        ElectroSimInstrumentProjection();
    final Map<String, String> results = <String, String>{};
    bool continuityActive = false;
    for (final InstrumentInstance item in _circuit.instruments) {
      final ElectroSimRuntimeSnapshot itemRuntime =
          widget.mixedRuntimeView?.runtimeForElement(item.id.value) ?? snapshot;
      final InstrumentInstance runtimeItem =
          widget.mixedRuntimeView?.runtimeInstrument(item) ?? item;
      final PhysicalInstrumentReading reading = projection.read(
        snapshot: itemRuntime,
        instrument: runtimeItem,
      );
      if (F18AmmeterFuseSafety.shouldTrip(
        circuit: _circuit,
        instrument: item,
        solverDetectedOvercurrent:
            reading.status == PhysicalInstrumentStatus.blownFuse ||
            (projection.seriesCurrent(itemRuntime, runtimeItem)?.abs() ?? 0) >
                item.fuseRatingA,
      )) {
        _scheduleAmmeterFuseTrip(item.id);
      }
      final double? value = reading.result?.reading?.value;
      final String? textValue = reading.result?.displayText;
      final bool valid = reading.status == PhysicalInstrumentStatus.valid;
      if (!continuityActive &&
          !F18VoltmeterControls.isHeld(item) &&
          F18VoltmeterControls.continuityDetected(
            meter: item,
            resistanceOhm: value,
            validReading: valid,
          )) {
        continuityActive = true;
      }
      final String raw;
      if (valid && textValue != null) {
        raw = textValue;
      } else if (valid && value != null) {
        final String unit = switch (item.mode) {
          InstrumentMode.currentDc || InstrumentMode.currentAcRms => 'A',
          InstrumentMode.frequency => 'Hz',
          InstrumentMode.resistance => 'Ω',
          _ => 'V',
        };
        raw = '${value.toStringAsFixed(2)} $unit';
      } else {
        raw = switch (reading.status) {
          PhysicalInstrumentStatus.off => 'OFF',
          PhysicalInstrumentStatus.blownFuse => 'FUSE',
          PhysicalInstrumentStatus.overRange => 'OL',
          PhysicalInstrumentStatus.unsupportedMode => 'N/A',
          PhysicalInstrumentStatus.unavailable => 'ERR',
          _ => '—',
        };
      }
      results[item.id.value] = item.kind == InstrumentKind.ammeter
          ? F18AmmeterControls.display(item, raw, value, valid)
          : item.kind == InstrumentKind.voltmeter
          ? F18VoltmeterControls.display(
              meter: item,
              computedText: raw,
              computedValue: value,
              validReading: valid,
            )
          : item.kind == InstrumentKind.frequencyMeter
          ? F18FrequencyControls.display(item, raw, valid)
          : raw;
    }
    _meterReadoutCacheCircuit = _circuit;
    _meterReadoutCacheSnapshot = snapshot;
    _meterReadoutCacheSecond = second;
    _meterReadoutCache = Map<String, String>.unmodifiable(results);
    unawaited(_continuityAudio.setActive(continuityActive));
    return _meterReadoutCache;
  }

  Future<void> _advanceSimulation(Duration elapsed) async {
    _setStatus('Avance du temps simulé en cours : ${elapsed.inMinutes} min.');
    try {
      await _simulation.advanceBy(elapsed);
      if (mounted) {
        _setStatus(
          'Simulation à t=${_simulation.simulatedTime.inSeconds} s. '
          'Résultats électriques recalculés.',
        );
      }
    } on Object catch (error) {
      if (mounted) _setStatus('Avance temporelle interrompue : $error');
    }
  }

  void _addPhysicalInstrument(
    F9PaletteDefinition definition,
    Offset worldPosition,
  ) {
    final bool current = definition.keyName == 'instrument-ammeter';
    final bool frequency = definition.keyName == 'instrument-frequency';
    final bool phaseSequence =
        definition.keyName == 'instrument-phase-sequence';
    final String elementId = _allocateElementId(definition.keyName);
    final ElectricalMode placementMode = widget.paletteModeOverride ?? _circuit.mode;
    final bool dc = placementMode == ElectricalMode.dc || placementMode == ElectricalMode.pv;
    final InstrumentInstance instrument = InstrumentInstance(
      id: InstrumentId(elementId),
      kind: current
          ? InstrumentKind.ammeter
          : frequency
          ? InstrumentKind.frequencyMeter
          : phaseSequence
          ? InstrumentKind.phaseSequenceTester
          : InstrumentKind.voltmeter,
      mode: current
          ? (dc ? InstrumentMode.currentDc : InstrumentMode.currentAcRms)
          : frequency
          ? InstrumentMode.frequency
          : phaseSequence
          ? InstrumentMode.phaseSequence
          : (dc ? InstrumentMode.voltageDc : InstrumentMode.voltageAcRms),
    );
    final CircuitState next = CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: _circuit.mode,
      components: _circuit.components,
      sources: _circuit.sources,
      connections: _circuit.connections,
      instruments: <InstrumentInstance>[..._circuit.instruments, instrument],
      probes: _circuit.probes,
      settings: _circuit.settings,
      metadata: _circuit.metadata,
    );
    setState(() {
      _circuit = next;
      final CircuitVisualLayout moved = _layout.moveElement(
        elementId,
        worldPosition,
      );
      _layout = CircuitVisualLayout(
        elementPositions: moved.elementPositions,
        elementSizes: <String, Size>{
          ...moved.elementSizes,
          elementId: const Size(112, 152),
        },
        wireRoutes: moved.wireRoutes,
        elementQuarterTurns: moved.elementQuarterTurns,
        defaultElementSize: moved.defaultElementSize,
        cabinetLayout: moved.cabinetLayout,
      );
      _selected = elementId;
      _status = current
          ? 'Ampèremètre physique ajouté : sélectionnez un fil pour l’insérer en série.'
          : frequency
          ? 'Fréquencemètre : choisissez deux bornes sous tension AC pour V/Ω et COM.'
          : phaseSequence
          ? 'Ordre des phases : sélectionnez trois bornes L1, L2 et L3 successivement.'
          : 'Voltmètre physique ajouté : sélectionnez V puis COM sur deux bornes.';
    });
    _updateSimulationCircuit(next);
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

  HitTestSession _preparedHitTestSession() {
    final display = _displayLayout(_dragPreviewLayout.value ?? _layout);
    if (_hitTestSession == null ||
        !identical(_hitTestSessionCircuit, _circuit) ||
        !identical(_hitTestSessionLayout, display)) {
      _hitTestSessionCircuit = _circuit;
      _hitTestSessionLayout = display;
      _hitTestSession = _hitTest.prepare(circuit: _circuit, layout: display);
    }
    return _hitTestSession!;
  }

  CanvasHitResult _f9CanvasHit(Offset localPosition) =>
      _hitTest.hitTestPrepared(
        worldPoint: _viewport.screenToWorld(localPosition),
        session: _preparedHitTestSession(),
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
    _directDragSession = null;
    _dragPreviewLayout.value = null;

    // Electrical targets always take priority over cabinet furniture.
    if (hit.kind == CanvasHitKind.background) {
      final fixture = _cabinetFixtureAt(event.localPosition);
      if (fixture != null) {
        final world = _viewport.screenToWorld(event.localPosition);
        final cornerDistance =
            (event.localPosition -
                    _viewport.worldToScreen(fixture.bounds.bottomRight))
                .distance;
        setState(() {
          _selected = null;
          _selectedCabinetFixtureId = fixture.id;
          _status = 'Armoire : ${fixture.id} sélectionné';
        });
        if (!_studentTpReadOnly) {
          _draggingCabinetFixtureId = fixture.id;
          _cabinetPointerStart = world;
          _cabinetDragInitialBounds = fixture.bounds;
          _cabinetResizeActive = cornerDistance <= 22;
        }
        return;
      }
    }
    _selectedCabinetFixtureId = null;

    if (hit.kind == CanvasHitKind.terminal && hit.terminalId != null) {
      if (_connectSelectedInstrumentProbe(hit.terminalId!)) {
        _clearDirectPointerState();
        return;
      }
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
          _wiringPointerWorld.value = _viewport.screenToWorld(
            event.localPosition,
          );
          _status =
              'Câblage : borne ${terminal.value} sélectionnée. Choisissez une cible.';
        } else {
          _wiringPendingTerminal = null;
          _wiringHoverTerminal = null;
          _wiringPointerWorld.value = null;
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
          _directDragSession = F18DragSession.begin(
            circuit: _circuit,
            baseLayout: _layout,
            elementId: id,
          );
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
      if (_insertSelectedAmmeterOnWire(hit.connectionId!)) {
        _clearDirectPointerState();
        return;
      }
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

  bool _connectSelectedInstrumentProbe(TerminalId target) {
    final String? selected = _selected;
    if (selected == null) return false;
    InstrumentInstance? meter;
    for (final InstrumentInstance instrument in _circuit.instruments) {
      if (instrument.id.value == selected) {
        meter = instrument;
        break;
      }
    }
    if (meter == null ||
        (meter.kind != InstrumentKind.voltmeter &&
            meter.kind != InstrumentKind.frequencyMeter &&
            meter.kind != InstrumentKind.phaseSequenceTester)) {
      return false;
    }
    if (_studentTpReadOnly) {
      _setStatus('TP remis : sondes en lecture seule.');
      return true;
    }
    final List<ProbeConnection> existing = _circuit.probes
        .where((item) => item.instrumentId == meter!.id)
        .toList(growable: false);
    final bool three = meter.mode == InstrumentMode.phaseSequence;
    final List<InstrumentPort> ports = three
        ? <InstrumentPort>[
            InstrumentPort.phase1,
            InstrumentPort.phase2,
            InstrumentPort.phase3,
          ]
        : <InstrumentPort>[InstrumentPort.voltOhm, InstrumentPort.common];
    final bool resetAll = ports.every(
      (port) => existing.any((probe) => probe.port == port),
    );
    final InstrumentPort port = resetAll
        ? ports.first
        : ports.firstWhere(
            (port) => !existing.any((probe) => probe.port == port),
          );
    final ProbeConnection added = ProbeConnection(
      id: ProbeId('${meter.id.value}-${port.name}'),
      instrumentId: meter.id,
      port: port,
      terminalId: target,
    );
    final CircuitState next = CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: _circuit.mode,
      components: _circuit.components,
      sources: _circuit.sources,
      connections: _circuit.connections,
      instruments: _circuit.instruments,
      probes: <ProbeConnection>[
        for (final ProbeConnection item in _circuit.probes)
          if (item.instrumentId != meter.id || (!resetAll && item.port != port))
            item,
        added,
      ],
      settings: _circuit.settings,
      metadata: _circuit.metadata,
    );
    setState(() {
      _circuit = next;
      _status = three
          ? 'Sonde ${port.name} : ${target.value}. '
                'Complétez L1, L2 et L3 pour obtenir l’ordre des phases.'
          : port == InstrumentPort.voltOhm
          ? 'Sonde V/Ω : ${target.value}. Sélectionner une borne pour COM.'
          : 'Sonde COM : ${target.value}. Mesure physique disponible.';
    });
    _updateSimulationCircuit(next);
    return true;
  }

  bool _insertSelectedAmmeterOnWire(ConnectionId target) {
    final String? selected = _selected;
    if (selected == null) return false;
    InstrumentInstance? meter;
    for (final InstrumentInstance item in _circuit.instruments) {
      if (item.id.value == selected) {
        meter = item;
        break;
      }
    }
    if (meter == null || meter.kind != InstrumentKind.ammeter) return false;
    if (_studentTpReadOnly) {
      _setStatus('TP remis : ampèremètre en lecture seule.');
      return true;
    }
    final Connection? wire = _circuit.connections
        .where((item) => item.id == target)
        .firstOrNull;
    if (wire == null || !wire.enabled) return false;
    final bool alreadyCut = _circuit.instruments.any(
      (item) => item.id != meter!.id && item.cutConnectionId == target,
    );
    if (alreadyCut) {
      _setStatus('Fil déjà instrumenté par un autre ampèremètre.');
      return true;
    }
    final InstrumentInstance replacement = InstrumentInstance(
      id: meter.id,
      kind: meter.kind,
      mode: meter.mode,
      inputImpedanceOhm: meter.inputImpedanceOhm,
      burdenResistanceOhm: meter.burdenResistanceOhm,
      maximumVoltageV: meter.maximumVoltageV,
      maximumCurrentA: meter.maximumCurrentA,
      fuseRatingA: meter.fuseRatingA,
      fuseBlown: meter.fuseBlown,
      poweredOn: meter.poweredOn,
      cutConnectionId: target,
      settings: meter.settings,
    );
    final CircuitState next = CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: _circuit.mode,
      components: _circuit.components,
      sources: _circuit.sources,
      connections: _circuit.connections,
      instruments: <InstrumentInstance>[
        for (final InstrumentInstance item in _circuit.instruments)
          if (item.id == meter.id) replacement else item,
      ],
      probes: <ProbeConnection>[
        for (final ProbeConnection item in _circuit.probes)
          if (item.instrumentId != meter.id) item,
        ProbeConnection(
          id: ProbeId('${meter.id.value}-amp'),
          instrumentId: meter.id,
          port: InstrumentPort.amp,
          terminalId: wire.fromTerminalId,
        ),
        ProbeConnection(
          id: ProbeId('${meter.id.value}-com'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: wire.toTerminalId,
        ),
      ],
      settings: _circuit.settings,
      metadata: _circuit.metadata,
    );
    setState(() {
      _circuit = next;
      _status =
          'Ampèremètre inséré virtuellement en série sur ${target.value}.';
    });
    _updateSimulationCircuit(next);
    return true;
  }

  void _onCanvasPointerMove(PointerMoveEvent event) {
    if (_activeCanvasPointer != event.pointer) {
      return;
    }
    final Offset? previous = _lastCanvasPointerLocal;
    _lastCanvasPointerLocal = event.localPosition;
    if (_wiringPendingTerminal != null) {
      _wiringPointerWorld.value = _viewport.screenToWorld(event.localPosition);
    }
    if (previous != null && (event.localPosition - previous).distance > 0.1) {
      _directPointerMoved = true;
    }

    final String? fixtureId = _draggingCabinetFixtureId;
    final Offset? initialPointer = _cabinetPointerStart;
    final Rect? initialBounds = _cabinetDragInitialBounds;
    if (fixtureId != null && initialPointer != null && initialBounds != null) {
      final world = _viewport.screenToWorld(event.localPosition);
      final delta = world - initialPointer;
      final candidate = _cabinetResizeActive
          ? Rect.fromLTWH(
              initialBounds.left,
              initialBounds.top,
              math.max(
                _layout.cabinetLayout.fixture(fixtureId)!.kind ==
                        CabinetFixtureKind.dinRail
                    ? 60
                    : 24,
                initialBounds.width + delta.dx,
              ),
              math.max(
                _layout.cabinetLayout.fixture(fixtureId)!.kind ==
                        CabinetFixtureKind.dinRail
                    ? 16
                    : 24,
                initialBounds.height + delta.dy,
              ),
            )
          : initialBounds.shift(delta);
      final updated = _layout.cabinetLayout.replace(
        _layout.cabinetLayout.fixture(fixtureId)!.withBounds(candidate),
      );
      _dragPreviewLayout.value = _layout.withCabinetLayout(updated);
      return;
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
    if (_draggingCabinetFixtureId != null) {
      _finishCabinetDrag();
      _clearDirectPointerState();
      return;
    }
    // The generic hit tester may classify an instrument as background.
    // Dispatch its physical controls BEFORE background deselection.
    if (!_directPointerMoved &&
        _wiringPendingTerminal == null &&
        !_selectionModifierAtPointerDown &&
        _handleVoltmeterControlTap(event.localPosition)) {
      _resetDirectControlTapTracking();
      _clearDirectPointerState();
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
      _handleDirectControlTap(event.localPosition, event.timeStamp);
    }
    _clearDirectPointerState();
  }

  /// Independent physical control hit testing. Image and probe sockets
  /// never alter circuit.connections, only the selected InstrumentInstance.
  bool _handleVoltmeterControlTap(Offset screenPosition) {
    if ((!F18Voltmeter3dAssets.ready &&
            !F18Ammeter3dAssets.ready &&
            !F18Frequency3dAssets.ready) ||
        _representation != WorkspaceRepresentation.plate) {
      return false;
    }
    final Offset world = _viewport.screenToWorld(screenPosition);
    for (final InstrumentInstance meter in _circuit.instruments) {
      if (meter.kind == InstrumentKind.voltmeter) {
        if (!F18Voltmeter3dAssets.ready) continue;
      } else if (meter.kind == InstrumentKind.ammeter) {
        if (!F18Ammeter3dAssets.ready) continue;
      } else if (meter.kind == InstrumentKind.frequencyMeter) {
        if (!F18Frequency3dAssets.ready) continue;
      } else {
        continue;
      }
      final Offset? center = _layout.positionOf(meter.id.value);
      if (center == null) continue;
      final Size size = _layout.sizeOf(meter.id.value);
      final Offset delta = world - center;
      final int turns = _layout.quarterTurnsOf(meter.id.value) % 4;
      final Offset unrotated = switch (turns) {
        0 => delta,
        1 => Offset(delta.dy, -delta.dx),
        2 => Offset(-delta.dx, -delta.dy),
        _ => Offset(-delta.dy, delta.dx),
      };
      final Offset local = Offset(
        size.width / 2 + unrotated.dx,
        size.height / 2 + unrotated.dy,
      );
      // The fuse hatch is not a mode button. A click on its actual
      // 3D front rectangle opens a separate, guarded replacement dialog.
      if (meter.kind == InstrumentKind.ammeter &&
          meter.fuseBlown &&
          size.width > 0 &&
          size.height > 0) {
        final double hx = local.dx * 112 / size.width;
        final double hy = local.dy * 152 / size.height;
        if (hx >= 39 && hx <= 67 && hy >= 109.75 && hy <= 118.25) {
          if (_blockStudentTpMutation()) return true;
          unawaited(_confirmAmmeterFuseReplacement(meter.id));
          return true;
        }
      }
      final F18VoltmeterAction? action = meter.kind == InstrumentKind.ammeter
          ? F18AmmeterControls.actionAt(local, size)
          : meter.kind == InstrumentKind.frequencyMeter
          ? F18FrequencyControls.actionAt(local, size)
          : F18VoltmeterControls.actionAt(local, size);
      if (action == null) continue;
      if (_blockStudentTpMutation()) return true;
      final PhysicalInstrumentReading reading =
          const ElectroSimInstrumentProjection().read(
            snapshot: _runtimeSnapshot,
            instrument: meter,
          );
      final double? value = reading.result?.reading?.value;
      final String unit = switch (meter.mode) {
        InstrumentMode.resistance => 'Ω',
        InstrumentMode.currentDc || InstrumentMode.currentAcRms => 'A',
        InstrumentMode.frequency => 'Hz',
        _ => 'V',
      };
      final String? text =
          reading.result?.displayText ??
          (value == null ? null : '${value.toStringAsFixed(2)} $unit');
      final bool valid = reading.status == PhysicalInstrumentStatus.valid;
      final InstrumentInstance next = meter.kind == InstrumentKind.ammeter
          ? F18AmmeterControls.apply(
              meter,
              action,
              text: text,
              value: value,
              valid: valid,
            )
          : meter.kind == InstrumentKind.frequencyMeter
          ? F18FrequencyControls.apply(
              meter,
              action,
              text: text,
              value: value,
              valid: valid,
            )
          : F18VoltmeterControls.apply(
              meter: meter,
              action: action,
              currentReading: text,
              currentValue: value,
              validReading: valid,
            );
      if (identical(next, meter)) {
        _setStatus('Commande ${action.name} indisponible dans ce mode.');
        return true;
      }
      final CircuitState candidate = CircuitState(
        circuitId: _circuit.circuitId,
        revision: _circuit.revision + 1,
        mode: _circuit.mode,
        sources: _circuit.sources,
        components: _circuit.components,
        connections: _circuit.connections,
        instruments: <InstrumentInstance>[
          for (final InstrumentInstance item in _circuit.instruments)
            if (item.id == meter.id) next else item,
        ],
        probes: _circuit.probes,
        settings: _circuit.settings,
        metadata: _circuit.metadata,
      );
      setState(() {
        _circuit = candidate;
        _selected = meter.id.value;
        _status =
            '${meter.kind == InstrumentKind.ammeter ? 'Ampèremètre' : 'Voltmètre'} : '
            '${action.name.toUpperCase()} — '
            '${next.poweredOn ? next.mode.name : 'OFF'}';
        _meterReadoutCacheCircuit = null;
      });
      _updateSimulationCircuit(candidate);
      _syncStudentTpCircuit();
      return true;
    }
    return false;
  }

  Future<void> _confirmAmmeterFuseReplacement(InstrumentId id) async {
    final InstrumentInstance? meter = _circuit.instruments
        .where((item) => item.id == id)
        .firstOrNull;
    if (meter == null || !F18AmmeterFuseSafety.canReplace(_circuit, meter)) {
      _setStatus(
        'Remplacement du fusible refusé : éteindre '
        'l’ampèremètre et retirer/isoler toutes les sources.',
      );
      return;
    }
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remplacer le fusible de l’ampèremètre'),
        content: Text(
          'Instrument hors tension et sources retirées. '
          'Remplacer le fusible ${meter.fuseRatingA} A ?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remplacer le fusible'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    final CircuitState old = _circuit;
    // Recheck AFTER dialog; the circuit may have changed while it was open.
    final CircuitState next = F18AmmeterFuseSafety.replaceSafely(
      circuit: old,
      instrumentId: id,
    );
    if (identical(next, old)) {
      _setStatus('Remplacement refusé : circuit modifié ou non isolé.');
      return;
    }
    setState(() {
      _circuit = next;
      _meterReadoutCacheCircuit = null;
      _status = 'Fusible remplacé. Ampèremètre encore hors tension.';
    });
    _updateSimulationCircuit(next);
    _syncStudentTpCircuit();
  }

  void _onCanvasPointerCancel(PointerCancelEvent event) {
    if (_activeCanvasPointer == event.pointer) {
      _dragPreviewLayout.value = null;
      _clearDirectPointerState();
    }
  }

  void _clearDirectPointerState() {
    _activeCanvasPointer = null;
    _draggingCabinetFixtureId = null;
    _cabinetPointerStart = null;
    _cabinetDragInitialBounds = null;
    _cabinetResizeActive = false;
    _directDragElementId = null;
    _directDragGrabDelta = null;
    _directDragBaseLayout = null;
    _directDragSession = null;
    _dragPreviewLayout.value = null;
    _lastCanvasPointerLocal = null;
    if (_wiringPendingTerminal == null) {
      _wiringPointerWorld.value = null;
    }
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

    if (modelType == 'rcd_2p_ac1') {
      if (Disjoncteur3D.hitsTestButton(baseSize, local)) {
        return (id: id, modelType: 'rcd_2p_ac1:test');
      }
      return Disjoncteur3D.hitsLever(baseSize, local)
          ? (id: id, modelType: modelType)
          : null;
    }

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

  void _handleDirectControlTap(Offset screenPosition, Duration eventTimeStamp) {
    final ({String id, String modelType})? target = _directControlAt(
      screenPosition,
    );
    if (target == null) {
      _resetDirectControlTapTracking();
      return;
    }

    final bool sameTarget = _lastDirectControlTapElementId == target.id;
    final Duration? previousTimeStamp = _lastDirectControlTapTime;
    final Duration? elapsed = previousTimeStamp == null
        ? null
        : eventTimeStamp - previousTimeStamp;
    final bool withinTime =
        elapsed != null &&
        elapsed >= Duration.zero &&
        elapsed <= _directControlDoubleTapWindow;
    final bool withinDistance =
        _lastDirectControlTapLocal != null &&
        (screenPosition - _lastDirectControlTapLocal!).distance <=
            _directControlDoubleTapDistance;

    if (sameTarget && withinTime && withinDistance) {
      _resetDirectControlTapTracking();
      _actuateDirectCanvasControl(target.id, target.modelType);
      return;
    }

    _lastDirectControlTapTime = eventTimeStamp;
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
        'proximity_sensor_24v' ||
        'limit_switch_no' ||
        'limit_switch_nc' ||
        'breaker_dc' ||
        'breaker_ac1' ||
        'rcd_2p_ac1' ||
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

    if (type == 'rcd_2p_ac1:test') {
      final bool tripped = _simulation.testResidualDevice(
        ComponentId(elementId),
      );
      setState(() {
        _selected = elementId;
        _status = tripped
            ? 'Test T : $elementId — déclenchement différentiel'
            : 'Test T indisponible : appareil ouvert, déclenché ou non alimenté';
      });
      return;
    }

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
        _updateSimulationCircuit(_circuit);
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
          _updateSimulationCircuit(_circuit);
          _syncStudentTpCircuit();
        },
      );
      return;
    }

    if (type == 'proximity_sensor_24v' ||
        type == 'limit_switch_no' ||
        type == 'limit_switch_nc') {
      final ComponentInstance? sensor = _circuit.components
          .where((ComponentInstance item) => item.id.value == elementId)
          .firstOrNull;
      if (sensor == null) return;
      final bool oldState = sensor.controlState['closed'] == true;
      final CircuitState next = F9ElementEditor.setComponentClosed(
        _circuit,
        elementId,
        closed: !oldState,
      );
      if (identical(next, _circuit)) return;
      setState(() {
        _circuit = next;
        _selected = elementId;
        _status = 'Capteur $elementId — ${!oldState ? 'actionné' : 'au repos'}';
      });
      _updateSimulationCircuit(next);
      _syncStudentTpCircuit();
      return;
    }

    final bool isProtectionReset =
        type == 'breaker_dc' ||
        type == 'breaker_ac1' ||
        type == 'rcd_2p_ac1' ||
        type == 'breaker' ||
        type == 'breaker_3p' ||
        type == 'breaker_4p' ||
        type == 'thermal_overload_3p';
    final String runtimeElementId =
        widget.mixedRuntimeView?.localIdForElement(elementId) ?? elementId;
    if (isProtectionReset &&
        _runtimeSnapshot.protectionTripped(ComponentId(runtimeElementId))) {
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
        _updateSimulationCircuit(_circuit);
      }
        if (widget.mixedRuntimeView == null) {
          _simulation.rearmProtection(ComponentId(runtimeElementId));
        }
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
    _updateSimulationCircuit(_circuit);
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
      layout: _displayLayout(_layout),
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
      _displayLayout(_layout),
    );
    final envelope = _representation == WorkspaceRepresentation.plate
        ? _layout.cabinetLayout.envelope
        : null;
    if (geometry.elementRects.isEmpty && envelope == null) {
      _viewport.reset(scale: 1, translation: const Offset(40, 40));
      return;
    }

    Rect bounds = envelope?.bounds ?? geometry.elementRects.values.first;
    for (final f in _displayLayout(_layout).cabinetLayout.fixtures) {
      bounds = bounds.expandToInclude(f.bounds);
    }
    for (final Rect rect in geometry.elementRects.values) {
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
        ..._displayLayout(_layout).routeFor(connection.id.value),
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
    final double scale = math
        .min(scaleX, scaleY)
        .clamp(_viewport.minScale, 1.50)
        .toDouble();
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
    final Offset worldPoint = _viewport.screenToWorld(localPosition);
    if (_wiringPendingTerminal != null) {
      _wiringPointerWorld.value = worldPoint;
    }
    final CanvasHitResult hit = _hitTest.hitTestTerminalPrepared(
      worldPoint: worldPoint,
      session: _preparedHitTestSession(),
      viewportScale: _viewport.scale,
    );
    final TerminalId? next = hit.kind == CanvasHitKind.terminal
        ? hit.terminalId
        : null;
    if (next == _wiringHoverTerminal) return;
    setState(() {
      _wiringHoverTerminal = next;
    });
  }

  void _handleConnectionRequested(TerminalId from, TerminalId to) {
    if (_circuit.components.any(
      (c) =>
          AppliancePowerConnection.isExternal(c) &&
          AppliancePowerConnection.mode(c) != 'fixed' &&
          c.terminals.any((t) => t.id == from || t.id == to),
    )) {
      _setStatus(
        'Raccorder la prise, puis brancher la fiche depuis les propriétés de l’appareil.',
      );
      return;
    }
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

    final CircuitState nextCircuit = _continueIndustrialMarking(
      F9WiringPolicy.append(_circuit, connection),
    );
    final bool backgroundRouting =
        nextCircuit.components.length + nextCircuit.sources.length >= 30;
    var nextLayout = backgroundRouting
        ? provisionalConnectionLayout(
            circuit: nextCircuit,
            layout: _layout,
            connection: connection,
          )
        : _g2aWireLayoutEngine.routeConnection(
            circuit: nextCircuit,
            layout: _layout,
            connectionId: connection.id,
          );
    if (!backgroundRouting) {
      nextLayout = migrateNativeApplianceLayout(
        nextCircuit,
        nextLayout,
        router: _g2aWireLayoutEngine,
      );
    }
    final bool routeRenderable = F18WorkspaceWireSafety.isRenderable(
      circuit: nextCircuit,
      layout: nextLayout,
    );

    setState(() {
      _circuit = nextCircuit;
      _layout = nextLayout;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _wiringPointerWorld.value = null;
      _status = backgroundRouting
          ? '${decision.message} Ajustement du trajet en cours…'
          : routeRenderable
          ? decision.message
          : '${decision.message} Routage graphique provisoire.';
    });
    _updateSimulationCircuit(_circuit);
    _syncStudentTpCircuit();
    _announce(_status);
    if (backgroundRouting) {
      unawaited(
        _finishConnectionRoute(
          nextCircuit,
          nextLayout,
          connection.id,
          decision.message,
        ),
      );
    }
  }

  Future<void> _finishConnectionRoute(
    CircuitState circuit,
    CircuitVisualLayout baseLayout,
    ConnectionId id,
    String message,
  ) async {
    try {
      final routed = await _connectionRouter.route(
        circuit: circuit,
        layout: baseLayout,
        connectionId: id,
      );
      // A newer connection, component move or restored workspace owns the
      // state now. Never overwrite it with an old background result.
      if (!mounted ||
          routed == null ||
          !identical(_circuit, circuit) ||
          !identical(_layout, baseLayout)) {
        return;
      }
      setState(() {
        _layout = routed;
        _status =
            F18WorkspaceWireSafety.isRenderable(
              circuit: circuit,
              layout: routed,
            )
            ? message
            : '$message Routage graphique provisoire.';
      });
    } catch (error) {
      if (!mounted ||
          !identical(_circuit, circuit) ||
          !identical(_layout, baseLayout)) {
        return;
      }
      _setStatus('$message Trajet provisoire conservé : $error');
    }
  }

  void _commitElementMoveIfSafe(
    String elementId,
    Offset position, {
    bool moving = false,
  }) {
    if (moving) {
      final F18DragSession session =
          _directDragSession ??
          F18DragSession.begin(
            circuit: _circuit,
            baseLayout: _directDragBaseLayout ?? _layout,
            elementId: elementId,
          );
      _directDragSession = session;
      _dragPreviewLayout.value = session.previewAt(position);
      return;
    }

    final CircuitState circuit = _circuit;
    final CircuitVisualLayout moved = _layout.moveElement(elementId, position);
    final problem = _cabinetConfigurationProblem(
      moved.cabinetLayout,
      layout: moved,
    );
    if (problem != null) {
      _setStatus(problem);
      return;
    }
    setState(() {
      _layout = moved;
      _status =
          'Position graphique mise à jour : $elementId — routage en cours.';
    });
    unawaited(_finishElementRoute(circuit, moved, elementId));
  }

  void _finalizeDirectDrag(String elementId) {
    final CircuitVisualLayout? base = _directDragBaseLayout;
    if (base == null) return;

    var preview = _dragPreviewLayout.value ?? _layout;
    final CircuitState circuit = _circuit;
    final details = F9ElementEditor.describe(circuit, elementId);
    final type =
        (details?.parameters['_visualModelType'] as String?) ??
        details?.modelType ??
        '';
    final mount =
        _layout.cabinetLayout.mounts[elementId] ??
        IndustrialEquipmentProfile.mounting(type, _layout.sizeOf(elementId));
    final anchor = IndustrialEquipmentProfile.rotateAnchor(
      mount.anchorOffset,
      _layout.quarterTurnsOf(elementId),
    );
    final position = preview.positionOf(elementId);
    if (position != null &&
        (_layout.cabinetLayout.fixtures.isNotEmpty ||
            _layout.cabinetLayout.envelope != null)) {
      final planned = CabinetPlacementPlanner.plan(
        cabinet: _layout.cabinetLayout,
        elementId: elementId,
        deviceSize: _layout.displaySizeOf(elementId),
        mountingAnchorOffset: anchor,
        surface: mount.surface,
        proposedCenter: position,
        existingDevices: {
          for (final entry in _cabinetDeviceRects().entries)
            if (entry.key != elementId) entry.key: entry.value,
        },
        mode:
            mount.surface == CabinetSurface.interior &&
                _layout.quarterTurnsOf(elementId).isEven
            ? _cabinetPlacementMode
            : CabinetPlacementMode.free,
        dinMountable: IndustrialEquipmentProfile.dinMountable(type),
      );
      if (!planned.isValid) {
        _setStatus(
          'Encombrement : ${planned.intersectingIds.join(", ")}. '
          'Déplacement du composant refusé.',
        );
        _dragPreviewLayout.value = null;
        return;
      }
      preview = preview
          .moveElement(elementId, planned.position)
          .withCabinetLayout(
            preview.cabinetLayout.withMount(
              elementId,
              CabinetMount(
                surface: mount.surface,
                railId: planned.railId,
                anchorOffset: mount.anchorOffset,
                depthMm: mount.depthMm,
              ),
            ),
          );
    }
    setState(() {
      _layout = preview;
      _status =
          'Position graphique mise à jour : $elementId — routage en cours.';
    });
    _dragPreviewLayout.value = null;
    unawaited(_finishElementRoute(circuit, preview, elementId));
  }

  Future<void> _finishElementRoute(
    CircuitState circuit,
    CircuitVisualLayout base,
    String elementId,
  ) async {
    try {
      final CircuitVisualLayout? routed = await _connectionRouter
          .routeChangedElement(
            circuit: circuit,
            layout: base,
            elementId: elementId,
          );
      if (!mounted ||
          routed == null ||
          !identical(_circuit, circuit) ||
          !identical(_layout, base)) {
        return;
      }
      if (identical(routed, base)) return;
      setState(() {
        _layout = routed;
        _status =
            F18WorkspaceWireSafety.isRenderable(
              circuit: circuit,
              layout: routed,
            )
            ? 'Routage ajusté : $elementId'
            : 'Position conservée ; trajet provisoire à vérifier.';
      });
    } catch (error) {
      if (mounted && identical(_circuit, circuit) && identical(_layout, base)) {
        _setStatus('Position conservée ; routage différé : $error');
      }
    }
  }

  void _cancelCanvasInteraction() {
    _dragPreviewLayout.value = null;
    setState(() {
      _canvasInteractionEpoch += 1;
      _wiringPendingTerminal = null;
      _wiringHoverTerminal = null;
      _wiringPointerWorld.value = null;
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
              item.supportsMode(widget.paletteModeOverride ?? _circuit.mode) &&
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
      ...replacement.defaultParameters,
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
      controlState: replacement.defaultControlState,
      replacementTerminals: replacementTerminals,
    );
    final Map<String, Size> sizes = <String, Size>{..._layout.elementSizes};
    if (F18ReferenceComponentVisuals.supports(replacement.renderedModelType)) {
      sizes[selected] = F18ReferenceComponentMetrics.boardSizeFor(
        replacement.renderedModelType,
        variantKey: replacement.visualVariant,
      );
    } else {
      sizes.remove(selected);
    }
    var proposed = CircuitVisualLayout(
      elementPositions: _layout.elementPositions,
      elementSizes: sizes,
      wireRoutes: _layout.wireRoutes,
      elementQuarterTurns: _layout.elementQuarterTurns,
      defaultElementSize: _layout.defaultElementSize,
      cabinetLayout: _layout.cabinetLayout,
    );
    final oldMount = _layout.cabinetLayout.mounts[selected];
    final profile = IndustrialEquipmentProfile.mounting(
      replacement.renderedModelType,
      proposed.sizeOf(selected),
    );
    final surface = oldMount?.surface ?? profile.surface;
    proposed = proposed.withCabinetLayout(
      proposed.cabinetLayout.withMount(
        selected,
        CabinetMount(
          surface: surface,
          anchorOffset: profile.anchorOffset,
          depthMm: profile.depthMm,
        ),
      ),
    );
    final problem = _cabinetConfigurationProblem(
      proposed.cabinetLayout,
      layout: proposed,
      circuit: next,
    );
    if (problem != null) {
      _setStatus(problem);
      return;
    }
    setState(() {
      _circuit = next;
      _layout = proposed;
      _status = 'Remplacement : $selected → ${replacement.title}';
    });
    _updateSimulationCircuit(_circuit);
    _syncStudentTpCircuit();
    _announce(_status);
    unawaited(_finishElementRoute(_circuit, _layout, selected));
  }

  void _toggleSelectedPrimaryState() {
    if (widget.compositeNetworkMode) {
      _setStatus('Utilisez les commandes du projet mixte pour piloter la simulation.');
      return;
    }
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
    _updateSimulationCircuit(_circuit);
    _syncStudentTpCircuit();
  }

  Future<void> _editPlcLadder(String componentId) async {
    final ComponentInstance plc = _circuit.components.firstWhere(
      (ComponentInstance c) => c.id.value == componentId,
    );
    final Object? rawProgram = plc.parameters['ladderProgram'];
    final List<Map<String, Object?>> savedRungs = rawProgram is List
        ? rawProgram.whereType<Map>().map((Map row) {
            final Object? rawSteps = row['steps'];
            return <String, Object?>{
              'steps': rawSteps is List
                  ? rawSteps
                        .whereType<Map>()
                        .map((Map step) => Map<String, Object?>.from(step))
                        .toList()
                  : <Map<String, Object?>>[],
            };
          }).toList()
        : <Map<String, Object?>>[];
    final List<Map<String, Object?>> rungs =
        rawProgram is List &&
            rawProgram.isNotEmpty &&
            rawProgram.whereType<Map>().every(
              (Map row) => row.containsKey('steps'),
            )
        ? savedRungs
        : <Map<String, Object?>>[
            <String, Object?>{
              'steps': rawProgram is List
                  ? rawProgram
                        .whereType<Map>()
                        .map((Map step) => Map<String, Object?>.from(step))
                        .toList()
                  : <Map<String, Object?>>[],
            },
          ];
    if (rungs.isEmpty) {
      rungs.add(<String, Object?>{'steps': <Map<String, Object?>>[]});
    }
    final List<String> addresses = <String>[
      'I0',
      'I1',
      'I2',
      'I3',
      'Q0',
      'Q1',
      'Q2',
      'Q3',
      for (int i = 0; i < 16; i++) 'M$i',
      for (int i = 0; i < 16; i++) 'T$i',
    ];
    final List<String> types = <String>[
      'contact_no',
      'contact_nc',
      'TON',
      'timer_done',
      'coil',
      'coil_set',
      'coil_reset',
    ];
    final List<String> typeLabels = <String>[
      'Contact NO',
      'Contact NC',
      'TON',
      'TON terminé',
      'Bobine Q/M',
      'SET',
      'RESET',
    ];
    final List<dynamic>? result = await showDialog<List<dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Programme Ladder'),
          content: SizedBox(
            width: 620,
            height: 430,
            child: Column(
              children: <Widget>[
                const Text(
                  'Les entrées I lisent les boutons/capteurs raccordés. Chaque rung est évalué de gauche à droite; TON temporise puis active son bit DN.',
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: rungs.length,
                    itemBuilder: (BuildContext context, int rungIndex) {
                      final List<Map<String, Object?>> steps =
                          rungs[rungIndex]['steps']!
                              as List<Map<String, Object?>>;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    'Rung ${rungIndex + 1}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Supprimer le rung',
                                    onPressed: rungs.length <= 1
                                        ? null
                                        : () => setDialogState(
                                            () => rungs.removeAt(rungIndex),
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              for (
                                int stepIndex = 0;
                                stepIndex < steps.length;
                                stepIndex++
                              )
                                _ladderStepEditor(
                                  context: context,
                                  step: steps[stepIndex],
                                  types: types,
                                  typeLabels: typeLabels,
                                  addresses: switch (steps[stepIndex]['type']) {
                                    'contact_no' || 'contact_nc' =>
                                      addresses
                                          .where(
                                            (String address) =>
                                                !address.startsWith('T'),
                                          )
                                          .toList(),
                                    'TON' || 'timer_done' =>
                                      addresses
                                          .where(
                                            (String address) =>
                                                address.startsWith('T'),
                                          )
                                          .toList(),
                                    _ =>
                                      addresses
                                          .where(
                                            (String address) =>
                                                address.startsWith('Q') ||
                                                address.startsWith('M'),
                                          )
                                          .toList(),
                                  },
                                  onChanged: () => setDialogState(() {}),
                                  onDelete: () => setDialogState(
                                    () => steps.removeAt(stepIndex),
                                  ),
                                  isLastStep: stepIndex == steps.length - 1,
                                ),
                              Wrap(
                                spacing: 6,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed:
                                        steps.any(
                                          (Map<String, Object?> step) =>
                                              <String>[
                                                'TON',
                                                'coil',
                                                'coil_set',
                                                'coil_reset',
                                              ].contains(step['type']),
                                        )
                                        ? null
                                        : () => setDialogState(
                                            () => steps.add(<String, Object?>{
                                              'type': 'contact_no',
                                              'address': 'I0',
                                            }),
                                          ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Contact'),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        steps.any(
                                          (Map<String, Object?> step) =>
                                              <String>[
                                                'TON',
                                                'coil',
                                                'coil_set',
                                                'coil_reset',
                                              ].contains(step['type']),
                                        )
                                        ? null
                                        : () => setDialogState(
                                            () => steps.add(<String, Object?>{
                                              'type': 'TON',
                                              'address': 'T0',
                                              'presetSeconds': 1.0,
                                            }),
                                          ),
                                    icon: const Icon(Icons.timer_outlined),
                                    label: const Text('TON'),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        steps.any(
                                          (Map<String, Object?> step) =>
                                              <String>[
                                                'TON',
                                                'coil',
                                                'coil_set',
                                                'coil_reset',
                                              ].contains(step['type']),
                                        )
                                        ? null
                                        : () => setDialogState(
                                            () => steps.add(<String, Object?>{
                                              'type': 'coil',
                                              'address': 'Q0',
                                            }),
                                          ),
                                    icon: const Icon(Icons.electrical_services),
                                    label: const Text('Bobine'),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        steps.any(
                                          (Map<String, Object?> step) =>
                                              <String>[
                                                'TON',
                                                'coil',
                                                'coil_set',
                                                'coil_reset',
                                              ].contains(step['type']),
                                        )
                                        ? null
                                        : () => setDialogState(
                                            () => steps.add(<String, Object?>{
                                              'type': 'contact_nc',
                                              'address': 'I1',
                                            }),
                                          ),
                                    icon: const Icon(Icons.sync_alt),
                                    label: const Text('Contact NC'),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        steps.any(
                                          (Map<String, Object?> step) =>
                                              <String>[
                                                'TON',
                                                'coil',
                                                'coil_set',
                                                'coil_reset',
                                              ].contains(step['type']),
                                        )
                                        ? null
                                        : () => setDialogState(
                                            () => steps.add(<String, Object?>{
                                              'type': 'timer_done',
                                              'address': 'T0',
                                            }),
                                          ),
                                    icon: const Icon(Icons.timer),
                                    label: const Text('TON terminé'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setDialogState(
                      () => rungs.add(<String, Object?>{
                        'steps': <Map<String, Object?>>[],
                      }),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un rung'),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, rungs),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final CircuitState next = _replaceComponentParameters(
      componentId,
      <String, Object?>{'ladderProgram': result},
    );
    setState(() {
      _circuit = next;
      _status = 'Programme Ladder enregistré';
    });
    _updateSimulationCircuit(next);
    _syncStudentTpCircuit();
  }

  Widget _ladderStepEditor({
    required BuildContext context,
    required Map<String, Object?> step,
    required List<String> types,
    required List<String> typeLabels,
    required List<String> addresses,
    required VoidCallback onChanged,
    required VoidCallback onDelete,
    required bool isLastStep,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: types.contains(step['type'])
                ? step['type'] as String
                : types.first,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Élément',
            ),
            items: <DropdownMenuItem<String>>[
              for (int index = 0; index < types.length; index++)
                if (isLastStep ||
                    types[index] == step['type'] ||
                    !<String>[
                      'TON',
                      'coil',
                      'coil_set',
                      'coil_reset',
                    ].contains(types[index]))
                  DropdownMenuItem(
                    value: types[index],
                    child: Text(typeLabels[index]),
                  ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                step['type'] = value;
                if (value == 'TON') {
                  step['address'] = 'T0';
                } else if (<String>[
                  'coil',
                  'coil_set',
                  'coil_reset',
                ].contains(value)) {
                  step['address'] = 'Q0';
                } else if ((step['address'] as String? ?? '').startsWith('T')) {
                  step['address'] = 'I0';
                }
                onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: addresses.contains(step['address'])
                ? step['address'] as String
                : addresses.first,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Adresse',
            ),
            items: addresses
                .map(
                  (String value) =>
                      DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged:
                (isLastStep &&
                        <String>[
                          'coil',
                          'coil_set',
                          'coil_reset',
                        ].contains(step['type'])) ||
                    step['type'] == 'TON'
                ? null
                : (String? value) {
                    if (value != null) {
                      step['address'] = value;
                      onChanged();
                    }
                  },
          ),
        ),
        if (step['type'] == 'TON')
          SizedBox(
            width: 88,
            child: TextFormField(
              initialValue: '${step['presetSeconds'] ?? 1}',
              decoration: const InputDecoration(isDense: true, labelText: 's'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (String value) {
                final double? parsed = double.tryParse(
                  value.replaceAll(',', '.'),
                );
                if (parsed != null &&
                    parsed.isFinite &&
                    parsed > 0 &&
                    parsed <= 3600) {
                  step['presetSeconds'] = parsed;
                }
              },
            ),
          ),
        IconButton(
          tooltip: 'Supprimer l’élément',
          onPressed: onDelete,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Future<void> _editStarDeltaTimer(String componentId) async {
    final ComponentInstance timer = _circuit.components.firstWhere(
      (ComponentInstance c) => c.id.value == componentId,
    );
    final TextEditingController delayController = TextEditingController(
      text: '${(timer.parameters['delaySeconds'] as num?)?.toDouble() ?? 5}',
    );
    final TextEditingController deadTimeController = TextEditingController(
      text:
          '${(timer.parameters['deadTimeSeconds'] as num?)?.toDouble() ?? 0.05}',
    );
    final (String, String)? value = await showDialog<(String, String)>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Retard étoile-triangle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: delayController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Retard étoile (secondes)',
                helperText: 'Valeur entre 0,1 s et 300 s',
              ),
            ),
            TextField(
              controller: deadTimeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Temps mort avant triangle',
                helperText: 'Valeur entre 0 et 5 s',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              delayController.text,
              deadTimeController.text,
            )),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    delayController.dispose();
    deadTimeController.dispose();
    if (!mounted || value == null) return;
    final double? delay = double.tryParse(value.$1.replaceAll(',', '.'));
    final double? deadTime = double.tryParse(value.$2.replaceAll(',', '.'));
    if (delay == null ||
        !delay.isFinite ||
        delay < 0.1 ||
        delay > 300 ||
        deadTime == null ||
        !deadTime.isFinite ||
        deadTime < 0 ||
        deadTime > 5) {
      _setStatus(
        'Réglages invalides : retard de 0,1 à 300 s et temps mort de 0 à 5 s.',
      );
      return;
    }
    final CircuitState next = _replaceComponentParameters(
      componentId,
      <String, Object?>{'delaySeconds': delay, 'deadTimeSeconds': deadTime},
    );
    setState(() {
      _circuit = next;
      _status = 'Temporisateur réglé à ${delay.toStringAsFixed(2)} s';
    });
    _updateSimulationCircuit(next);
  }

  Future<void> _editMechanicalInterlock(String componentId) async {
    final ComponentInstance accessory = _circuit.components.firstWhere(
      (ComponentInstance c) => c.id.value == componentId,
    );
    final List<ComponentInstance> contactors = _circuit.components
        .where((ComponentInstance c) => c.modelType == 'contactor_3p')
        .toList(growable: false);
    if (contactors.length < 2) {
      _setStatus(
        'Ajoutez au moins deux contacteurs triphasés pour configurer le verrouillage.',
      );
      return;
    }
    String selectedA =
        accessory.parameters['contactorAId'] as String? ??
        contactors[0].id.value;
    String selectedB =
        accessory.parameters['contactorBId'] as String? ??
        contactors[1].id.value;
    if (selectedA == selectedB ||
        !contactors.any((c) => c.id.value == selectedA)) {
      selectedA = contactors[0].id.value;
    }
    if (selectedA == selectedB ||
        !contactors.any((c) => c.id.value == selectedB)) {
      selectedB = contactors
          .firstWhere((c) => c.id.value != selectedA)
          .id
          .value;
    }
    final (String, String)? pair = await showDialog<(String, String)>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Verrouillage mécanique'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    key: const Key('mechanical-interlock-contactora'),
                    initialValue: selectedA,
                    decoration: const InputDecoration(
                      labelText: 'Contacteur A',
                    ),
                    items: [
                      for (final c in contactors)
                        DropdownMenuItem(
                          value: c.id.value,
                          child: Text(c.id.value),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedA = value;
                          if (selectedA == selectedB) {
                            selectedB = contactors
                                .firstWhere((c) => c.id.value != selectedA)
                                .id
                                .value;
                          }
                        });
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    key: const Key('mechanical-interlock-contactorb'),
                    initialValue: selectedB,
                    decoration: const InputDecoration(
                      labelText: 'Contacteur B',
                    ),
                    items: [
                      for (final c in contactors.where(
                        (c) => c.id.value != selectedA,
                      ))
                        DropdownMenuItem(
                          value: c.id.value,
                          child: Text(c.id.value),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() => selectedB = value);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, (selectedA, sele