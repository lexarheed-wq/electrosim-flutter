Warning: truncated output (original token count: 59045)
Total output lines: 6376

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
    elementSizes: <String, Size>{
      ...defaults.elementSizes,
      ...saved.elementSizes,
    },
    wireRoutes: <String, List<Offset>>{
      ...defaults.wireRoutes,
      ...saved.wireRoutes,
    },
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
      widget.externalRuntimeSnapshot ??
      _simulation.snapshot;
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
        ? _mergeBoardLayout(
            _layoutForCircuit(_circuit),
            widget.initialVisualLayout!,
          )
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
                          : () {},
                      onResetSimulation: widget.mixedRuntimeView == null
                          ? _simulation.resetDynamics
                          : () {},
                      simulationAdvancing: _simulation.fastForwarding,
                      onAdvanceSimulation: widget.mixedRuntimeView == null
                          ? (Duration elapsed) {
                              unawaited(_advanceSimulation(elapsed));
                            }
                          : (_) {},
                      onCancelAdvance: widget.mixedRuntimeView == null
                          ? _simulation.cancelAdvance
                          : () {},
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
                            onProximityTargetDistanceChanged: _studentTpReadOnly
                                ? null
                                : _setProximityTargetDistance,
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
                                                      mixedRuntimeView: widget
                                                          .mixedRuntimeView,
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
    final BuildContext…19045 tokens truncated…         return <String, Object?>{
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
                      Navigator.pop(context, (selectedA, selectedB)),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
      ),
    );
    if (!mounted || pair == null) return;
    final CircuitState next = _replaceComponentParameters(
      componentId,
      <String, Object?>{'contactorAId': pair.$1, 'contactorBId': pair.$2},
    );
    setState(() {
      _circuit = next;
      _status = 'Verrouillage mécanique configuré : ${pair.$1} / ${pair.$2}';
    });
    _updateSimulationCircuit(next);
  }

  CircuitState _replaceComponentParameters(
    String componentId,
    Map<String, Object?> updates,
  ) {
    return CircuitState(
      circuitId: _circuit.circuitId,
      revision: _circuit.revision + 1,
      mode: _circuit.mode,
      components: _circuit.components
          .map(
            (ComponentInstance c) => c.id.value != componentId
                ? c
                : ComponentInstance(
                    id: c.id,
                    modelType: c.modelType,
                    terminals: c.terminals,
                    parameters: <String, Object?>{...c.parameters, ...updates},
                    condition: c.condition,
                    controlState: c.controlState,
                  ),
          )
          .toList(growable: false),
      sources: _circuit.sources,
      connections: _circuit.connections,
      instruments: _circuit.instruments,
      probes: _circuit.probes,
      settings: _circuit.settings,
      metadata: _circuit.metadata,
    );
  }

  void _linkPlcOutput(String plcId, String output, String? targetId) {
    final ComponentInstance? plc = _circuit.components
        .where(
          (ComponentInstance c) =>
              c.id.value == plcId && c.modelType == 'plc_ac3',
        )
        .firstOrNull;
    if (plc == null) return;
    final Map<String, Object?> links = <String, Object?>{
      if (plc.parameters['outputLinks'] is Map)
        ...(plc.parameters['outputLinks'] as Map).cast<String, Object?>(),
    };
    if (targetId == null || targetId.isEmpty) {
      links.remove(output);
    } else {
      final bool validTarget = _circuit.components.any(
        (ComponentInstance c) =>
            c.id.value == targetId && c.modelType == 'contactor_3p',
      );
      if (!validTarget) {
        _setStatus(
          'La sortie PLC AC3 doit cibler un contacteur triphasé existant.',
        );
        return;
      }
      for (final MapEntry<String, Object?> entry in links.entries.toList()) {
        if (entry.key != output && entry.value == targetId) {
          _setStatus('Ce contacteur est déjà lié à ${entry.key}.');
          return;
        }
      }
      links[output] = targetId;
    }
    final CircuitState next = _replaceComponentParameters(
      plcId,
      <String, Object?>{'outputLinks': links},
    );
    setState(() {
      _circuit = next;
      _status = targetId == null || targetId.isEmpty
          ? '$output déliée'
          : '$output commande le contacteur $targetId';
    });
    _updateSimulationCircuit(next);
    _syncStudentTpCircuit();
  }

  void _configureSelectedPower(String mode, String? socketId) {
    if (_blockStudentTpMutation() || _selected == null) return;
    try {
      final next = mode == 'fault-on' || mode == 'fault-off'
          ? AppliancePowerConnection.setInsulationFault(
              _circuit,
              _selected!,
              mode == 'fault-on',
            )
          : AppliancePowerConnection.configure(
              _circuit,
              _selected!,
              mode,
              socketId: socketId,
            );
      var nextLayout = _layout;
      for (final wire in next.connections) {
        if (!mode.startsWith('fault-') &&
            wire.metadata[AppliancePowerConnection.cableTag] == _selected) {
          nextLayout = _g2aWireLayoutEngine.routeConnection(
            circuit: next,
            layout: nextLayout,
            connectionId: wire.id,
          );
        }
      }
      setState(() {
        _circuit = next;
        _layout = nextLayout;
        _status = mode.startsWith('fault-')
            ? (mode == 'fault-on'
                  ? 'Défaut d’isolement activé.'
                  : 'Défaut d’isolement supprimé.')
            : socketId == null
            ? 'Raccordement modifié — fiche débranchée si présente.'
            : 'Fiche branchée dans $socketId';
      });
      _updateSimulationCircuit(next);
      _syncStudentTpCircuit();
    } on ArgumentError catch (error) {
      _setStatus(error.message.toString());
    }
  }

  void _rotateSelectedElement() {
    if (_blockStudentTpMutation()) return;
    final String? selected = _selected;
    if (selected == null ||
        F9ElementEditor.describe(_circuit, selected) == null) {
      _setStatus('Rotation impossible : aucun élément sélectionné.');
      return;
    }

    final CircuitVisualLayout previous = _layout;
    var provisional = previous.rotateElement(selected);
    final mount = provisional.cabinetLayout.mounts[selected];
    if (mount?.railId != null) {
      provisional = provisional.withCabinetLayout(
        provisional.cabinetLayout.withMount(selected, mount!.withoutRail()),
      );
    }
    final problem = _cabinetConfigurationProblem(
      provisional.cabinetLayout,
      layout: provisional,
    );
    if (problem != null) {
      _setStatus(problem);
      return;
    }
    final CircuitState circuit = _circuit;
    setState(() {
      _layout = provisional;
      _status = 'Rotation 90° : $selected · routage en cours.';
    });
    unawaited(_finishRotationRoute(circuit, provisional, previous, selected));
  }

  Future<void> _finishRotationRoute(
    CircuitState circuit,
    CircuitVisualLayout provisional,
    CircuitVisualLayout previous,
    String elementId,
  ) async {
    try {
      final CircuitVisualLayout? routed = await _connectionRouter
          .routeChangedElement(
            circuit: circuit,
            layout: provisional,
            elementId: elementId,
          );
      if (!mounted ||
          routed == null ||
          !identical(_circuit, circuit) ||
          !identical(_layout, provisional)) {
        return;
      }
      if (!F18WorkspaceWireSafety.isRenderable(
        circuit: circuit,
        layout: routed,
      )) {
        setState(() {
          _layout = previous;
          _status = 'Rotation refusée : fils non routables.';
        });
        return;
      }
      setState(() {
        _layout = routed;
        _status = 'Rotation 90° : $elementId';
      });
    } on Object catch (error) {
      if (!mounted ||
          !identical(_circuit, circuit) ||
          !identical(_layout, provisional)) {
        return;
      }
      setState(() {
        _layout = previous;
        _status = 'Rotation annulée : $error';
      });
    }
  }

  void _deleteSelectedElement() {
    if (_blockStudentTpMutation()) return;
    if (_selectedCabinetFixtureId != null) {
      final id = _selectedCabinetFixtureId!;
      setState(() {
        _layout = _layout.withCabinetLayout(_layout.cabinetLayout.remove(id));
        _selectedCabinetFixtureId = null;
        _status = 'Élément d’armoire supprimé : $id';
      });
      return;
    }
    if (_selectedIds.length > 1) {
      _deleteMultipleSelection();
      return;
    }
    final String? selected = _selected;
    if (selected == null) {
      _setStatus('Suppression impossible : aucune sélection.');
      return;
    }
    if (_circuit.instruments.any((item) => item.id.value == selected)) {
      final CircuitState next = CircuitState(
        circuitId: _circuit.circuitId,
        revision: _circuit.revision + 1,
        mode: _circuit.mode,
        components: _circuit.components,
        sources: _circuit.sources,
        connections: _circuit.connections,
        instruments: <InstrumentInstance>[
          for (final InstrumentInstance item in _circuit.instruments)
            if (item.id.value != selected) item,
        ],
        probes: <ProbeConnection>[
          for (final ProbeConnection item in _circuit.probes)
            if (item.instrumentId.value != selected) item,
        ],
        settings: _circuit.settings,
        metadata: _circuit.metadata,
      );
      final CircuitVisualLayout old = _layout;
      setState(() {
        _circuit = next;
        _layout = CircuitVisualLayout(
          elementPositions: <String, Offset>{...old.elementPositions}
            ..remove(selected),
          elementSizes: <String, Size>{...old.elementSizes}..remove(selected),
          wireRoutes: old.wireRoutes,
          elementQuarterTurns: <String, int>{...old.elementQuarterTurns}
            ..remove(selected),
          defaultElementSize: old.defaultElementSize,
          cabinetLayout: old.cabinetLayout,
        );
        _selected = null;
        _status = 'Instrument physique supprimé : $selected';
      });
      _updateSimulationCircuit(next);
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
        _layout = CircuitVisualLayout(
          elementPositions: _layout.elementPositions,
          elementSizes: _layout.elementSizes,
          wireRoutes: routes,
          elementQuarterTurns: _layout.elementQuarterTurns,
          defaultElementSize: _layout.defaultElementSize,
          cabinetLayout: _layout.cabinetLayout,
        );
        _selected = null;
        _status = 'Suppression : fil — $selected';
      });
      _updateSimulationCircuit(_circuit);
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
      _layout = CircuitVisualLayout(
        elementPositions: positions,
        elementSizes: sizes,
        wireRoutes: routes,
        elementQuarterTurns: rotations,
        defaultElementSize: _layout.defaultElementSize,
        cabinetLayout: _layout.cabinetLayout.retainMounts({
          for (final c in next.components) c.id.value,
          for (final c in next.sources) c.id.value,
        }),
      );
      _selected = null;
      _status = 'Suppression : ${details.modelType} — $selected';
    });
    _updateSimulationCircuit(_circuit);
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
      if (details == null &&
          next.instruments.any((item) => item.id.value == id)) {
        next = CircuitState(
          circuitId: next.circuitId,
          revision: next.revision + 1,
          mode: next.mode,
          components: next.components,
          sources: next.sources,
          connections: next.connections,
          instruments: <InstrumentInstance>[
            for (final InstrumentInstance item in next.instruments)
              if (item.id.value != id) item,
          ],
          probes: <ProbeConnection>[
            for (final ProbeConnection item in next.probes)
              if (item.instrumentId.value != id) item,
          ],
          settings: next.settings,
          metadata: next.metadata,
        );
        removedCount += 1;
        continue;
      }
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
      ...next.instruments.map((InstrumentInstance item) => item.id.value),
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
      _layout = CircuitVisualLayout(
        elementPositions: positions,
        elementSizes: sizes,
        wireRoutes: routes,
        elementQuarterTurns: rotations,
        defaultElementSize: _layout.defaultElementSize,
        cabinetLayout: _layout.cabinetLayout.retainMounts(remainingElements),
      );
      _selected = null;
      _status = 'Suppression multiple : $removedCount éléments sélectionnés';
    });
    _updateSimulationCircuit(_circuit);
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
      ...circuit.instruments.map(
        (InstrumentInstance item) => (item.id.value, 'physical-instrument'),
      ),
    ];
    final variants = {
      for (final source in circuit.sources)
        source.id.value:
            NativeApplianceGeometry.forSource(source)?.variant ??
            source.parameters['_visualVariant'] as String?,
      for (final c in circuit.components)
        c.id.value:
            NativeApplianceGeometry.forComponent(c)?.variant ??
            c.parameters['_visualVariant'] as String?,
    };
    double rowTop = 96;
    for (var start = 0; start < elements.length; start += 3) {
      final row = elements.skip(start).take(3).toList();
      double left = 48;
      double rowHeight = 192;
      for (final (id, modelType) in row) {
        final size = modelType == 'physical-instrument'
            ? const Size(112, 152)
            : F18ReferenceComponentVisuals.supports(modelType)
            ? F18ReferenceComponentMetrics.boardSizeFor(
                modelType,
                variantKey: variants[id],
              )
            : const Size(104, 64);
        if (modelType == 'physical-instrument' ||
            F18ReferenceComponentVisuals.supports(modelType)) {
          sizes[id] = size;
        }
        positions[id] = Offset(
          left + math.max(96, size.width / 2),
          rowTop + math.max(96, size.height / 2),
        );
        left += math.max(240, size.width + 48);
        rowHeight = math.max(rowHeight, size.height + 48);
      }
      rowTop += rowHeight;
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
      cabinetLayout: base.cabinetLayout,
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
      cabinetLayout: routed.cabinetLayout,
    );
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
    });
  }

  @override
  void dispose() {
    if (_visualLayoutMatchesSession &&
        !identical(_layout, _lastReportedVisualLayout)) {
      widget.onVisualLayoutChanged?.call(_layout);
    }
    _layoutSaveTimer?.cancel();
    _workspaceLayout.removeListener(_scheduleLayoutSave);
    _tpController.removeListener(_onStudentTpChanged);
    if (_layoutEdited) {
      unawaited(
        _persistWorkspaceLayout(
          _workspaceLayout.toJson(),
          order: _layoutEditOrder,
        ),
      );
    }
    _workspaceLayout.dispose();
    _connectionRouter.dispose();
    for (final Timer timer in _momentaryReleaseTimers.values) {
      timer.cancel();
    }
    _momentaryReleaseTimers.clear();
    _simulation.dispose();
    unawaited(_continuityAudio.dispose());
    widget.syncClient?.removeListener(_onLanSyncChanged);
    final ElectroSimLanSyncHost? host = _lanHost;
    if (host != null) unawaited(host.close());
    final ElectroSimLanSyncClient? client = widget.syncClient;
    if (client != null) unawaited(client.close());
    _dragPreviewLayout.dispose();
    _wiringPointerWorld.dispose();
    _viewport.dispose();
    if (_ownsTpController || client != null) {
      _tpController.dispose();
    }
    super.dispose();
  }
}

class _CabinetSelectionPainter extends CustomPainter {
  const _CabinetSelectionPainter({
    required this.fixture,
    required this.viewport,
  });
  final CabinetFixture? fixture;
  final ViewportController viewport;
  @override
  void paint(Canvas canvas, Size size) {
    paintCabinetSelection(
      canvas,
      fixture: fixture,
      worldToScreen: viewport.worldToScreen,
      scale: viewport.scale,
    );
  }

  @override
  bool shouldRepaint(_CabinetSelectionPainter old) =>
      old.fixture != fixture ||
      old.viewport != viewport ||
      old.viewport.scale != viewport.scale ||
      old.viewport.translation != viewport.translation;
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
    this.onGenerateIndustrialMarkings,
    this.onEditIndustrialMarking,
    this.onExportSchematicSvg,
    this.onExportSchematicPdf,
    required this.onRotateSelected,
    required this.onDeleteSelected,
    required this.onRecenter,
    this.onConfigureCabinet,
    this.onPreviewCabinet,
    this.representation = WorkspaceRepresentation.plate,
    this.onSelectRepresentation,
    this.onAddDinRail,
    this.onAddWireDuct,
    this.onAddTerminalZone,
    this.onToggleCabinetSnap,
    this.onRouteCabinetWires,
    this.cabinetSnapEnabled = false,
    required this.electricalMode,
    required this.onSelectElectricalMode,
    this.showAllTerminals = false,
    this.onToggleTerminals,
    this.soundEnabled = true,
    this.onToggleSound,
    required this.simulationRunning,
    required this.simulatedTime,
    required this.onToggleSimulation,
    required this.onResetSimulation,
    required this.simulationAdvancing,
    required this.onAdvanceSimulation,
    required this.onCancelAdvance,
    required this.onUndo,
    required this.onRedo,
    this.showSimulationControls = true,
    this.showModeSelector = true,
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
  final VoidCallback? onGenerateIndustrialMarkings;
  final VoidCallback? onEditIndustrialMarking;
  final VoidCallback? onExportSchematicSvg;
  final VoidCallback? onExportSchematicPdf;
  final VoidCallback? onRotateSelected;
  final VoidCallback? onDeleteSelected;
  final VoidCallback onRecenter;
  final VoidCallback? onConfigureCabinet, onPreviewCabinet;
  final WorkspaceRepresentation representation;
  final ValueChanged<WorkspaceRepresentation>? onSelectRepresentation;
  final VoidCallback? onAddDinRail;
  final VoidCallback? onAddWireDuct;
  final VoidCallback? onAddTerminalZone;
  final VoidCallback? onToggleCabinetSnap;
  final VoidCallback? onRouteCabinetWires;
  final bool cabinetSnapEnabled;
  final ElectricalMode electricalMode;
  final ValueChanged<ElectricalMode> onSelectElectricalMode;
  final bool showAllTerminals;
  final VoidCallback? onToggleTerminals;
  final bool soundEnabled;
  final VoidCallback? onToggleSound;
  final bool simulationRunning;
  final Duration simulatedTime;
  final VoidCallback onToggleSimulation;
  final VoidCallback onResetSimulation;
  final bool simulationAdvancing;
  final ValueChanged<Duration> onAdvanceSimulation;
  final VoidCallback onCancelAdvance;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool showSimulationControls;
  final bool showModeSelector;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final wrapTools =
            constraints.maxWidth < 1000 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final headerIcons = IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: ElectroSimColors.workspaceOnHeader,
            minimumSize: const Size.square(48),
          ),
        );
        final tools = <Widget>[
          for (final view in WorkspaceRepresentation.values)
            TextButton(
              key: Key('workspace-view-${view.name}'),
              onPressed: () => onSelectRepresentation?.call(view),
              style: TextButton.styleFrom(
                foregroundColor: representation == view
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF334155),
                backgroundColor: representation == view
                    ? const Color(0xFFE0ECFF)
                    : Colors.transparent,
                minimumSize: const Size(76, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                view == WorkspaceRepresentation.plate ? 'Platine' : 'Schéma',
              ),
            ),
          if (representation == WorkspaceRepresentation.plate)
            IconButton(
              key: const Key('workspace-toggle-terminals'),
              tooltip: showAllTerminals
                  ? 'Masquer les bornes'
                  : 'Afficher les bornes',
              isSelected: showAllTerminals,
              onPressed: onToggleTerminals,
              icon: const Icon(Icons.adjust_outlined),
              selectedIcon: const Icon(Icons.adjust, color: Color(0xFF2563EB)),
            ),
          if (showModeSelector) _modeMenu(compact),
          if (showSimulationControls && !compact)
            PopupMenuButton<Duration>(
              key: const Key('workspace-time-advance'),
              tooltip: 'Avancer le temps simulé',
              enabled: !simulationAdvancing,
              icon: const Icon(Icons.more_time_outlined),
              onSelected: onAdvanceSimulation,
              itemBuilder: (context) => const [
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-minute'),
                  value: Duration(minutes: 1),
                  child: Text('Avancer de +1 min'),
                ),
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-hour'),
                  value: Duration(hours: 1),
                  child: Text('Avancer de +1 h'),
                ),
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-day'),
                  value: Duration(hours: 24),
                  child: Text('Avancer de +24 h'),
                ),
              ],
            ),
          if (!compact && onSave != null)
            IconButton(
              key: const Key('workspace-save-direct-action'),
              tooltip: 'Sauvegarder',
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
            ),
          if (!compact && onOpen != null)
            IconButton(
              key: const Key('workspace-open-direct-action'),
              tooltip: 'Reprendre',
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open_outlined),
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
          if (showSimulationControls)
            Tooltip(
              message: simulationAdvancing
                  ? 'Annuler l’avance temporelle'
                  : simulationRunning
                  ? 'Mettre la simulation en pause'
                  : 'Démarrer la simulation',
              child: FilledButton.icon(
                key: const Key('workspace-simulation-toggle'),
                onPressed: simulationAdvancing
                    ? onCancelAdvance
                    : onToggleSimulation,
                style: FilledButton.styleFrom(
                  backgroundColor: simulationRunning
                      ? ElectroSimColors.primary
                      : ElectroSimColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                icon: Icon(
                  simulationAdvancing
                      ? Icons.stop_circle_outlined
                      : simulationRunning
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  simulationAdvancing
                      ? 'Stop'
                      : simulationRunning
                      ? 'Pause'
                      : 'Lancer',
                ),
              ),
            ),
          _moreMenu(),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: ElectroSimColors.workspaceHeader,
              child: Theme(
                data: Theme.of(context).copyWith(iconButtonTheme: headerIcons),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 56 : 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
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
                        if (!compact && !wrapTools) ...[
                          const Icon(
                            Icons.hub_outlined,
                            color: ElectroSimColors.workspaceAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ElectroSim',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: ElectroSimColors.workspaceAccent,
                                ),
                          ),
                          const SizedBox(width: 24),
                        ],
                        Expanded(
                          child: Tooltip(
                            message: entryLabel,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entryLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color:
                                            ElectroSimColors.workspaceOnHeader,
                                      ),
                                ),
                                Text(
                                  workspace,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFB9C7D9),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (sessionNavigation) ...[
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: ElectroSimColors.surface,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ElectroSimColors.workspaceDivider,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: wrapTools
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: tools,
                        ),
                      )
                    : Row(
                        children: [
                          Text(
                            'Outils de l’atelier',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: ElectroSimColors.textSecondary,
                                ),
                          ),
                          const Spacer(),
                          ...tools,
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _modeMenu(bool compact) => PopupMenuButton<ElectricalMode>(
    key: const Key('workspace-electrical-mode'),
    tooltip: 'Domaine électrique',
    initialValue: electricalMode,
    onSelected: onSelectElectricalMode,
    itemBuilder: (context) => const [
      PopupMenuItem(
        key: Key('workspace-mode-dc'),
        value: ElectricalMode.dc,
        child: Text('CC — courant continu'),
      ),
      PopupMenuItem(
        key: Key('workspace-mode-ac1'),
        value: ElectricalMode.ac1,
        child: Text('AC 1φ — monophasé'),
      ),
      PopupMenuItem(
        key: Key('workspace-mode-ac3'),
        value: ElectricalMode.ac3,
        child: Text('AC 3φ — triphasé'),
      ),
      PopupMenuItem(
        key: Key('workspace-mode-pv'),
        value: ElectricalMode.pv,
        child: Text('PV — photovoltaïque'),
      ),
      PopupMenuItem(
        key: Key('workspace-mode-mixed'),
        value: ElectricalMode.mixed,
        child: Text('Mixte — CC, AC, triphasé et PV'),
      ),
    ],
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_outlined, size: 20),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(switch (electricalMode) {
                ElectricalMode.dc => 'CC',
                ElectricalMode.ac1 => 'AC 1φ',
                ElectricalMode.ac3 => 'AC 3φ',
                ElectricalMode.pv => 'PV',
                ElectricalMode.mixed => 'Mixte',
              }),
            ],
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    ),
  );

  Widget _moreMenu() => PopupMenuButton<_WorkspaceSecondaryAction>(
    key: const Key('workspace-more-actions'),
    tooltip: 'Plus d’actions',
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) {
      switch (action) {
        case _WorkspaceSecondaryAction.toggleSound:
          onToggleSound?.call();
        case _WorkspaceSecondaryAction.undo:
          onUndo?.call();
        case _WorkspaceSecondaryAction.redo:
          onRedo?.call();
        case _WorkspaceSecondaryAction.advanceMinute:
          onAdvanceSimulation(const Duration(minutes: 1));
        case _WorkspaceSecondaryAction.advanceHour:
          onAdvanceSimulation(const Duration(hours: 1));
        case _WorkspaceSecondaryAction.advanceDay:
          onAdvanceSimulation(const Duration(hours: 24));
        case _WorkspaceSecondaryAction.save:
          onSave?.call();
        case _WorkspaceSecondaryAction.open:
          onOpen?.call();
        case _WorkspaceSecondaryAction.generateIndustrialMarkings:
          onGenerateIndustrialMarkings?.call();
        case _WorkspaceSecondaryAction.editIndustrialMarking:
          onEditIndustrialMarking?.call();
        case _WorkspaceSecondaryAction.exportSchematicSvg:
          onExportSchematicSvg?.call();
        case _WorkspaceSecondaryAction.exportSchematicPdf:
          onExportSchematicPdf?.call();
        case _WorkspaceSecondaryAction.recenter:
          onRecenter();
        case _WorkspaceSecondaryAction.addDinRail:
          onAddDinRail?.call();
        case _WorkspaceSecondaryAction.addWireDuct:
          onAddWireDuct?.call();
        case _WorkspaceSecondaryAction.addTerminalZone:
          onAddTerminalZone?.call();
        case _WorkspaceSecondaryAction.toggleDinSnap:
          onToggleCabinetSnap?.call();
        case _WorkspaceSecondaryAction.configureCabinet:
          onConfigureCabinet?.call();
        case _WorkspaceSecondaryAction.previewCabinet:
          onPreviewCabinet?.call();
        case _WorkspaceSecondaryAction.routeCabinetWires:
          onRouteCabinetWires?.call();
        case _WorkspaceSecondaryAction.resetSimulation:
          onResetSimulation();
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        key: Key('workspace-recenter-action'),
        value: _WorkspaceSecondaryAction.recenter,
        child: ListTile(
          leading: Icon(Icons.center_focus_strong),
          title: Text('Recentrer la platine'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        key: Key('workspace-reset-simulation-action'),
        value: _WorkspaceSecondaryAction.resetSimulation,
        child: ListTile(
          leading: Icon(Icons.restart_alt),
          title: Text('Réinitialiser la simulation'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (onToggleSound != null)
        PopupMenuItem(
          key: const Key('workspace-sound-action'),
          value: _WorkspaceSecondaryAction.toggleSound,
          child: Text(
            soundEnabled
                ? 'Couper les sons des composants'
                : 'Activer les sons des composants',
          ),
        ),
      PopupMenuItem(
        key: const Key('workspace-undo-action'),
        value: _WorkspaceSecondaryAction.undo,
        enabled: onUndo != null,
        child: const Text('Annuler · ⌘Z / Ctrl+Z'),
      ),
      PopupMenuItem(
        key: const Key('workspace-redo-action'),
        value: _WorkspaceSecondaryAction.redo,
        enabled: onRedo != null,
        child: const Text('Rétablir · ⌘⇧Z / Ctrl+Y'),
      ),
      if (MediaQuery.sizeOf(context).width < 720 &&
          !simulationAdvancing) ...const [
        PopupMenuItem(
          key: Key('workspace-time-plus-minute'),
          value: _WorkspaceSecondaryAction.advanceMinute,
          child: Text('Avancer de +1 min'),
        ),
        PopupMenuItem(
          key: Key('workspace-time-plus-hour'),
          value: _WorkspaceSecondaryAction.advanceHour,
          child: Text('Avancer de +1 h'),
        ),
        PopupMenuItem(
          key: Key('workspace-time-plus-day'),
          value: _WorkspaceSecondaryAction.advanceDay,
          child: Text('Avancer de +24 h'),
        ),
      ],
      if (onSave != null)
        const PopupMenuItem(
          key: Key('workspace-save-action'),
          value: _WorkspaceSecondaryAction.save,
          child: ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text('Sauvegarder'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onOpen != null)
        const PopupMenuItem(
          key: Key('workspace-open-action'),
          value: _WorkspaceSecondaryAction.open,
          child: ListTile(
            leading: Icon(Icons.restore_outlined),
            title: Text('Reprendre'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onGenerateIndustrialMarkings != null)
        const PopupMenuItem(
          key: Key('workspace-generate-industrial-markings'),
          value: _WorkspaceSecondaryAction.generateIndustrialMarkings,
          child: Text('Repérage : générer / actualiser'),
        ),
      if (onEditIndustrialMarking != null)
        const PopupMenuItem(
          key: Key('workspace-edit-industrial-marking'),
          value: _WorkspaceSecondaryAction.editIndustrialMarking,
          child: Text('Repérage : modifier / verrouiller'),
        ),
      if (onExportSchematicSvg != null)
        const PopupMenuItem(
          key: Key('workspace-export-schematic-svg'),
          value: _WorkspaceSecondaryAction.exportSchematicSvg,
          child: ListTile(
            leading: Icon(Icons.code_outlined),
            title: Text('Schéma : exporter en SVG'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onExportSchematicPdf != null)
        const PopupMenuItem(
          key: Key('workspace-export-schematic-pdf'),
          value: _WorkspaceSecondaryAction.exportSchematicPdf,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Schéma : exporter en PDF'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onAddDinRail != null)
        const PopupMenuItem(
          key: Key('workspace-add-din-rail'),
          value: _WorkspaceSecondaryAction.addDinRail,
          child: ListTile(
            leading: Icon(Icons.view_stream_outlined),
            title: Text('Armoire : ajouter un rail DIN'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onAddWireDuct != null)
        const PopupMenuItem(
          key: Key('workspace-add-wire-duct'),
          value: _WorkspaceSecondaryAction.addWireDuct,
          child: ListTile(
            leading: Icon(Icons.table_rows_outlined),
            title: Text('Armoire : ajouter une goulotte'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onAddTerminalZone != null)
        const PopupMenuItem(
          key: Key('workspace-add-terminal-zone'),
          value: _WorkspaceSecondaryAction.addTerminalZone,
          child: ListTile(
            leading: Icon(Icons.grid_on_outlined),
            title: Text('Armoire : zone de borniers'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onConfigureCabinet != null)
        const PopupMenuItem(
          key: Key('workspace-configure-cabinet'),
          value: _WorkspaceSecondaryAction.configureCabinet,
          child: Text('Armoire : dimensions et montages'),
        ),
      if (onPreviewCabinet != null)
        const PopupMenuItem(
          key: Key('workspace-preview-3d'),
          value: _WorkspaceSecondaryAction.previewCabinet,
          child: Text('Aperçu 3D de l’armoire'),
        ),
      if (onRouteCabinetWires != null)
        const PopupMenuItem(
          key: Key('workspace-route-wiring-duct'),
          value: _WorkspaceSecondaryAction.routeCabinetWires,
          child: ListTile(
            leading: Icon(Icons.cable_outlined),
            title: Text('Armoire : router les fils en goulottes'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onToggleCabinetSnap != null)
        PopupMenuItem(
          key: const Key('workspace-toggle-din-snap'),
          value: _WorkspaceSecondaryAction.toggleDinSnap,
          child: ListTile(
            leading: Icon(
              cabinetSnapEnabled
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            title: Text(
              cabinetSnapEnabled
                  ? 'Placement DIN assisté : activé'
                  : 'Placement DIN assisté : désactivé',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ],
  );
}

enum _WorkspaceSecondaryAction {
  toggleSound,
  undo,
  redo,
  save,
  open,
  generateIndustrialMarkings,
  editIndustrialMarking,
  exportSchematicSvg,
  exportSchematicPdf,
  recenter,
  addDinRail,
  addWireDuct,
  addTerminalZone,
  toggleDinSnap,
  routeCabinetWires,
  configureCabinet,
  previewCabinet,
  resetSimulation,
  advanceMinute,
  advanceHour,
  advanceDay,
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

CircuitState _buildBlankCircuit() => CircuitState(
  circuitId: CircuitId('workspace-blank'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[],
  connections: <Connection>[],
  sources: <SourceInstance>[],
  settings: <String, Object?>{},
  metadata: <String, Object?>{'origin': 'blank-workspace'},
);
