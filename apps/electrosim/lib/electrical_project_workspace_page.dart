import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'f18_workspace_page.dart';
import 'mixed_board_projection.dart';
import 'mixed_board_runtime_view.dart';
import 'runtime/electrical_project_runtime_engine.dart';
import 'runtime/electrosim_layout_persistence.dart';

/// Shared visual board over independent electrical networks and one project clock.
final class ElectricalProjectWorkspacePage extends StatefulWidget {
  const ElectricalProjectWorkspacePage({
    super.key,
    required this.initialProject,
    required this.onProjectChanged,
  });
  final ElectricalProject initialProject;
  final ValueChanged<ElectricalProject> onProjectChanged;

  @override
  State<ElectricalProjectWorkspacePage> createState() => _ElectricalProjectWorkspacePageState();
}

final class _ElectricalProjectWorkspacePageState extends State<ElectricalProjectWorkspacePage> {
  late ElectricalProject _project = widget.initialProject;
  final ElectricalProjectRuntimeEngine _engine = const ElectricalProjectRuntimeEngine();
  final Map<String, CircuitVisualLayout> _layouts = <String, CircuitVisualLayout>{};
  String? _selectedNetworkId;
  ElectricalProjectRuntimeSnapshot? _runtime;
  Timer? _clock;
  bool _running = false;
  String _status = 'Projet prêt';
  int _boardGeneration = 0;
  static const String _sharedLayoutKey = '__mixed_board__';

  CircuitVisualLayout get _sharedLayout => _layouts[_sharedLayoutKey] ??
      MixedBoardProjection.combineLayouts(_project, _layouts);

  ElectricalNetwork? get _selected => _project.networks.where((ElectricalNetwork n) => n.id == _selectedNetworkId).firstOrNull ?? _project.networks.firstOrNull;
  bool get _isRunning => _running;

  @override
  void initState() {
    super.initState();
    _selectedNetworkId = _project.networks.where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc).firstOrNull?.id ?? _project.networks.firstOrNull?.id;
    _runtime = _engine.advance(_project, elapsed: Duration.zero);
  }

  void _setProject(ElectricalProject next) {
    final ElectricalProjectRuntimeSnapshot runtime = _engine.advance(
      next,
      elapsed: Duration.zero,
      previous: _runtime,
    );
    setState(() {
      _project = next;
      _runtime = runtime;
      _status = runtime.diagnostics.isEmpty
          ? 'Projet modifié · simulation résolue'
          : runtime.diagnostics.first;
    });
    widget.onProjectChanged(next);
  }

  void _onCircuitChanged(String networkId, CircuitState circuit) {
    final CircuitState currentBoard = MixedBoardProjection.fromProject(
      _project,
    ).circuit;
    if (circuit == currentBoard) return;
    final Map<String, Object?> normalized = circuit.toJson()
      ..['revision'] = currentBoard.revision;
    final bool unchangedTopology =
        CircuitState.fromJson(normalized) == currentBoard;
    if (unchangedTopology) return;
    try {
      final ElectricalProject next = MixedBoardProjection.applyBoardEdit(
        _project, circuit, networkId,
      );
      _setProject(next);
    } on Object catch (error) {
      setState(() {
        _status = 'Modification mixte refusée : $error';
        _boardGeneration++;
      });
    }
  }

  void _start() {
    if (_running) return;
    _advance(Duration.zero);
    setState(() => _running = true);
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => _advance(const Duration(milliseconds: 250)));
  }
  void _pause() {
    _clock?.cancel();
    _clock = null;
    if (mounted) setState(() => _running = false);
  }
  void _advance(Duration elapsed) {
    if (!mounted) return;
    try {
      final ElectricalProjectRuntimeSnapshot next = _engine.advance(_project, elapsed: elapsed, previous: _runtime);
      setState(() {
        _runtime = next;
        _status = next.diagnostics.isEmpty ? 'Simulation résolue' : next.diagnostics.first;
      });
    } on Object catch (error) {
      _pause();
      setState(() => _status = 'Simulation arrêtée : $error');
    }
  }

  Future<void> _saveProject() async {
    final XFile? file = await getSaveLocation(suggestedName: 'ElectroSim_projet.electrosimproject.json').then((FileSaveLocation? location) => location == null ? null : XFile(location.path));
    if (file == null) return;
    final DateTime now = DateTime.now().toUtc();
    final SavedElectricalProjectDocument document = SavedElectricalProjectDocument(
      saveId: _project.networks.map((ElectricalNetwork n) => n.id).join('-'),
      title: 'Projet électrique mixte', createdAtUtc: now, updatedAtUtc: now,
      engineVersion: 'electrosim-project/1', project: _project,
      appState: <String, Object?>{
        'layouts': <String, Object?>{
          for (final MapEntry<String, CircuitVisualLayout> entry in _layouts.entries)
            entry.key: ElectroSimLayoutPersistence.encode(entry.value),
        },
      },
    );
    await XFile.fromData(Uint8List.fromList(utf8.encode(document.toJsonString())), mimeType: 'application/json').saveTo(file.path);
    if (mounted) setState(() => _status = 'Projet enregistré : ${file.path}');
  }

  Future<void> _openProject() async {
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[
      const XTypeGroup(label: 'Projet ElectroSim', extensions: <String>['json']),
    ]);
    if (file == null) return;
    try {
      final SavedElectricalProjectDocument document = SavedElectricalProjectDocument.fromJsonString(await file.readAsString());
      _pause();
      final ElectricalProjectRuntimeSnapshot runtime = _engine.advance(
        document.project,
        elapsed: Duration.zero,
      );
      setState(() {
        _project = document.project;
        _boardGeneration++;
        _selectedNetworkId = document.project.networks.where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc).firstOrNull?.id ?? document.project.networks.first.id;
        _runtime = runtime;
        final Object? rawLayouts = document.appState['layouts'];
        _layouts.clear();
        if (rawLayouts is Map<String, dynamic>) {
          for (final MapEntry<String, dynamic> entry in rawLayouts.entries) {
            final CircuitVisualLayout? layout = ElectroSimLayoutPersistence.decode(entry.value);
            if (layout != null) _layouts[entry.key] = layout;
          }
        }
        _status = 'Projet ouvert : ${document.title}';
      });
      widget.onProjectChanged(document.project);
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Impossible d’ouvrir le projet : $error');
    }
  }

  Future<void> _manageLinks() async {
    final _ProjectLinkChoice? choice = await showDialog<_ProjectLinkChoice>(
      context: context,
      builder: (BuildContext context) => _ProjectLinkDialog(project: _project),
    );
    if (choice == null) return;
    final relays = List<CrossNetworkRelayLink>.from(_project.relayLinks);
    final signals = List<CrossNetworkSignalLink>.from(_project.signalLinks);
    final actuators = List<CrossNetworkActuatorLink>.from(_project.actuatorLinks);
    final converters = List<CrossNetworkConverterLink>.from(_project.converterLinks);
    if (choice.removeId != null) {
      relays.removeWhere((link) => link.id == choice.removeId);
      signals.removeWhere((link) => link.id == choice.removeId);
      actuators.removeWhere((link) => link.id == choice.removeId);
      converters.removeWhere((link) => link.id == choice.removeId);
    } else if (choice.contactorId != null && choice.targetNetworkId != null &&
        choice.plcComponentId != null) {
      final plcNetwork = _project.networks.firstWhere((network) =>
          network.circuit.components.any((component) => component.id.value == choice.plcComponentId));
      final availableOutput = <String>['Q0', 'Q1', 'Q2', 'Q3'].where((address) =>
          !relays.any((link) => link.plcNetworkId == plcNetwork.id && link.plcComponentId == choice.plcComponentId && link.outputAddress == address) &&
          !actuators.any((link) => link.plcNetworkId == plcNetwork.id && link.plcComponentId == choice.plcComponentId && link.outputAddress == address)).firstOrNull;
      if (availableOutput == null) {
        setState(() => _status = 'Les quatre sorties de cet automate sont déjà liées.');
        return;
      }
      final id = _newLinkId('plc', <String>[
        ...relays.map((link) => link.id), ...signals.map((link) => link.id),
        ...actuators.map((link) => link.id), ...converters.map((link) => link.id),
      ]);
      actuators.add(CrossNetworkActuatorLink(
        id: id, plcNetworkId: plcNetwork.id, plcComponentId: choice.plcComponentId!,
        outputAddress: availableOutput, targetNetworkId: choice.targetNetworkId!,
        contactorId: choice.contactorId!,
      ));
    } else if (choice.converterComponentId != null && choice.outputNetworkId != null &&
        choice.outputLineTerminalId != null && choice.outputNeutralTerminalId != null) {
      final pvNetwork = _project.networks.firstWhere((network) =>
          network.circuit.components.any((component) => component.id.value == choice.converterComponentId));
      final id = _newLinkId('pv-ac', <String>[
        ...relays.map((link) => link.id), ...signals.map((link) => link.id),
        ...actuators.map((link) => link.id), ...converters.map((link) => link.id),
      ]);
      converters.add(CrossNetworkConverterLink(
        id: id, inputNetworkId: pvNetwork.id,
        converterComponentId: choice.converterComponentId!,
        outputNetworkId: choice.outputNetworkId!,
        outputLineTerminalId: choice.outputLineTerminalId!,
        outputNeutralTerminalId: choice.outputNeutralTerminalId!,
      ));
    } else if (choice.relayCoilId != null && choice.contactId != null) {
      final ElectricalNetwork dc = _project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.dc);
      final ComponentInstance plc = dc.circuit.components.firstWhere((component) => component.modelType == 'plc_dc');
      final String? output = <String>['Q0', 'Q1', 'Q2', 'Q3'].where((address) =>
          !relays.any((link) => link.plcComponentId == plc.id.value && link.outputAddress == address) &&
          !actuators.any((link) => link.plcComponentId == plc.id.value && link.outputAddress == address)).firstOrNull;
      if (output == null) { setState(() => _status = 'Les quatre sorties PLC sont déjà liées.'); return; }
      final String id = _newLinkId('bridge', <String>[...relays.map((link) => link.id), ...signals.map((link) => link.id), ...actuators.map((link) => link.id), ...converters.map((link) => link.id)]);
      relays.add(CrossNetworkRelayLink(id: id, plcNetworkId: dc.id, plcComponentId: plc.id.value, outputAddress: output, dcNetworkId: dc.id, relayCoilId: choice.relayCoilId!, ac3NetworkId: _project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.ac3).id, ac3ContactId: choice.contactId!));
    } else if (choice.plcInput != null && choice.contactId != null) {
      final ElectricalNetwork dc = _project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.dc);
      final ComponentInstance plc = dc.circuit.components.firstWhere((component) => component.modelType == 'plc_dc');
      final String? input = <String>['I0', 'I1', 'I2', 'I3'].where((address) => !signals.any((link) => link.plcComponentId == plc.id.value && link.inputAddress == address)).firstOrNull;
      if (input == null) { setState(() => _status = 'Les quatre entrées PLC sont déjà liées.'); return; }
      final String id = _newLinkId('feedback', <String>[...relays.map((link) => link.id), ...signals.map((link) => link.id), ...actuators.map((link) => link.id), ...converters.map((link) => link.id)]);
      signals.add(CrossNetworkSignalLink(id: id, ac3NetworkId: _project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.ac3).id, auxiliaryContactId: choice.contactId!, dcNetworkId: dc.id, plcComponentId: plc.id.value, inputAddress: input));
    }
    try {
      _setProject(ElectricalProject(
        networks: _project.networks, relayLinks: relays, signalLinks: signals,
        actuatorLinks: actuators, converterLinks: converters,
      ));
    } on Object catch (error) { setState(() => _status = 'Liaison refusée : $error'); }
  }

  static String _newLinkId(String prefix, Iterable<String> existing) {
    final Set<String> ids = existing.toSet();
    for (int i = 1; i < 10000; i++) { final String id = '$prefix-$i'; if (!ids.contains(id)) return id; }
    throw StateError('No free project link identifier.');
  }

  @override
  void dispose() { _clock?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ElectricalNetwork? selected = _selected;
    final MixedBoardProjection board = MixedBoardProjection.fromProject(_project);
    final MixedBoardRuntimeView runtimeView = MixedBoardRuntimeView(
      projection: board,
      snapshot: _runtime,
      running: _running,
      defaultNetworkId: selected?.id,
    );
    return Scaffold(
      body: SafeArea(child: Column(children: <Widget>[
        Material(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: <Widget>[
            Wrap(spacing: 8, children: <Widget>[
              for (final ElectricalNetwork network in _project.networks)
                ChoiceChip(key: Key('project-network-${network.id}'), label: Text(_modeLabel(network.circuit.mode)), selected: selected?.id == network.id, onSelected: (_) => setState(() => _selectedNetworkId = network.id)),
            ]),
            Wrap(spacing: 6, children: <Widget>[
              IconButton(tooltip: 'Ouvrir un projet', onPressed: _openProject, icon: const Icon(Icons.folder_open)),
              IconButton(tooltip: 'Enregistrer le projet', onPressed: _saveProject, icon: const Icon(Icons.save)),
              IconButton(tooltip: 'Liaisons PLC et relais', onPressed: _project.networks.length > 1 ? _manageLinks : null, icon: const Icon(Icons.hub_outlined)),
              FilledButton.icon(key: const Key('project-simulation-toggle'), onPressed: _isRunning ? _pause : _start, icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow), label: Text(_isRunning ? 'Pause' : 'Lancer')),
              IconButton(tooltip: 'Un pas de 250 ms', onPressed: () => _advance(const Duration(milliseconds: 250)), icon: const Icon(Icons.skip_next)),
            ]),
          ]),
        )),
        if (_runtime != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: <Widget>[
          Text('t = ${(_runtime!.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s'),
          const SizedBox(width: 16),
          for (final ElectricalNetwork n in _project.networks)
            Padding(padding: const EdgeInsets.only(right: 12), child: Text('${_modeLabel(n.circuit.mode)} : ${_runtime!.networks[n.id]?.solved == true ? 'résolu' : 'défaut'}')),
        ])),
        Expanded(child: selected == null
            ? const Center(child: Text('Aucun réseau dans ce projet.'))
            : F18WorkspacePage(
                key: ValueKey<String>('mixed-board-$_boardGeneration'),
                entryLabel: 'Simulateur — mode Mixte',
                initialCircuit: board.circuit,
                compositeNetworkMode: true,
                mixedRuntimeView: runtimeView,
                paletteModeOverride: selected.circuit.mode,
                initialVisualLayout: _sharedLayout,
                onVisualLayoutChanged: (CircuitVisualLayout layout) {
                  _layouts[_sharedLayoutKey] = MixedBoardProjection.normalizeLayout(
                    _project, layout, selected.id,
                  );
                },
                onCircuitChanged: (CircuitState circuit) =>
                    _onCircuitChanged(selected.id, circuit),
              )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Align(alignment: Alignment.centerLeft, child: Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis))),
      ])),
    );
  }
}

String _modeLabel(ElectricalMode mode) => switch (mode) {
  ElectricalMode.dc => 'CC 24 V',
  ElectricalMode.ac1 => 'AC monophasé',
  ElectricalMode.ac3 => 'AC triphasé',
  ElectricalMode.pv => 'Photovoltaïque',
  ElectricalMode.mixed => 'Mixte',
};

final class _ProjectLinkChoice {
  const _ProjectLinkChoice({
    this.relayCoilId, this.contactId, this.plcInput, this.removeId,
    this.plcComponentId, this.targetNetworkId, this.contactorId,
    this.converterComponentId, this.outputNetworkId,
    this.outputLineTerminalId, this.outputNeutralTerminalId,
  });
  final String? relayCoilId;
  final String? contactId;
  final bool? plcInput;
  final String? removeId;
  final String? plcComponentId;
  final String? targetNetworkId;
  final String? contactorId;
  final String? converterComponentId;
  final String? outputNetworkId;
  final String? outputLineTerminalId;
  final String? outputNeutralTerminalId;
}

final class _ProjectLinkDialog extends StatelessWidget {
  const _ProjectLinkDialog({required this.project});
  final ElectricalProject project;

  @override
  Widget build(BuildContext context) {
    final dc = project.networks.where((network) => network.circuit.mode == ElectricalMode.dc).firstOrNull;
    final ac3 = project.networks.where((network) => network.circuit.mode == ElectricalMode.ac3).firstOrNull;
    final plcComponents = dc?.circuit.components.where((component) => component.modelType == 'plc_dc').toList() ?? const <ComponentInstance>[];
    final relayCoils = dc?.circuit.components.where((component) => component.modelType == 'relay_coil').toList() ?? const <ComponentInstance>[];
    final ac3Auxiliaries = ac3?.circuit.components.where((component) =>
        component.modelType == 'contactor_aux_no' || component.modelType == 'contactor_aux_nc').toList() ?? const <ComponentInstance>[];
    final powerContactors = <(ElectricalNetwork, ComponentInstance)>[
      for (final network in project.networks.where((network) =>
          network.circuit.mode == ElectricalMode.ac1 || network.circuit.mode == ElectricalMode.ac3))
        for (final component in network.circuit.components.where((component) =>
            (component.modelType == 'contactor_ac1' || component.modelType == 'contactor_3p') &&
            !project.actuatorLinks.any((link) => link.targetNetworkId == network.id && link.contactorId == component.id.value)))
          (network, component),
    ];
    final pvConverters = <(ElectricalNetwork, ComponentInstance)>[
      for (final network in project.networks.where((network) => network.circuit.mode == ElectricalMode.pv))
        for (final component in network.circuit.components.where((component) => component.modelType == 'pv_inverter' &&
            !project.converterLinks.any((link) => link.inputNetworkId == network.id && link.converterComponentId == component.id.value)))
          (network, component),
    ];
    return AlertDialog(
      title: const Text('Liaisons inter-réseaux'),
      content: SizedBox(width: 620, height: 520, child: ListView(children: <Widget>[
        const ListTile(title: Text('Commande directe — sortie PLC vers contacteur')),
        for (final plc in plcComponents) for (final (network, contactor) in powerContactors)
          ListTile(
            dense: true, leading: const Icon(Icons.electric_bolt),
            title: Text('${plc.id.value} → ${contactor.id.value}'),
            subtitle: Text('Sortie PLC isolée · ${_modeLabel(network.circuit.mode)}'),
            onTap: () => Navigator.pop(context, _ProjectLinkChoice(
              plcComponentId: plc.id.value, targetNetworkId: network.id,
              contactorId: contactor.id.value,
            )),
          ),
        const Divider(),
        const ListTile(title: Text('Conversion photovoltaïque → AC monophasé')),
        for (final (_, inverter) in pvConverters)
          for (final acNetwork in project.networks.where((network) => network.circuit.mode == ElectricalMode.ac1))
            for (final line in <Terminal>[
              ...acNetwork.circuit.components.expand((component) => component.terminals),
              ...acNetwork.circuit.sources.expand((source) => source.terminals),
            ].where((terminal) => terminal.role == TerminalRole.line))
              for (final neutral in <Terminal>[
                ...acNetwork.circuit.components.expand((component) => component.terminals),
                ...acNetwork.circuit.sources.expand((source) => source.terminals),
              ].where((terminal) => terminal.role == TerminalRole.neutral && terminal.id != line.id))
                ListTile(
                  dense: true, leading: const Icon(Icons.solar_power_outlined),
                  title: Text('${inverter.id.value} → ${acNetwork.id}'),
                  subtitle: Text('Sortie ${line.name}/${neutral.name}'),
                  onTap: () => Navigator.pop(context, _ProjectLinkChoice(
                    converterComponentId: inverter.id.value,
                    outputNetworkId: acNetwork.id,
                    outputLineTerminalId: line.id.value,
                    outputNeutralTerminalId: neutral.id.value,
                  )),
                ),
        const Divider(),
        const ListTile(title: Text('Pont de relais isolé — PLC → bobine CC → contact sec AC3')),
        for (final ComponentInstance coil in relayCoils)
          for (final ComponentInstance contact in ac3Auxiliaries)
            ListTile(
              dense: true, leading: const Icon(Icons.hub_outlined),
              title: Text('${coil.id.value} → ${contact.id.value}'),
              subtitle: const Text('Créer un pont de relais isolé'),
              onTap: () => Navigator.pop(context, _ProjectLinkChoice(
                relayCoilId: coil.id.value, contactId: contact.id.value,
              )),
            ),
        const Divider(),
        const ListTile(title: Text('Retour d’état — auxiliaire AC3 vers entrée PLC CC')),
        for (final ComponentInstance plc in plcComponents)
          for (final ComponentInstance contact in ac3Auxiliaries)
            ListTile(
              dense: true, leading: const Icon(Icons.sync_alt),
              title: Text('${contact.id.value} → ${plc.id.value}'),
              subtitle: const Text('Retour d’état isolé'),
              onTap: () => Navigator.pop(context, _ProjectLinkChoice(
                plcInput: true, contactId: contact.id.value,
              )),
            ),
        const Divider(),
        for (final CrossNetworkActuatorLink link in project.actuatorLinks)
          ListTile(
            dense: true, leading: const Icon(Icons.link_off),
            title: Text('${link.outputAddress} · ${link.plcComponentId} → ${link.contactorId}'),
            trailing: IconButton(tooltip: 'Supprimer la liaison', onPressed: () => Navigator.pop(context, _ProjectLinkChoice(removeId: link.id)), icon: const Icon(Icons.delete_outline)),
          ),
        for (final CrossNetworkConverterLink link in project.converterLinks)
          ListTile(
            dense: true, leading: const Icon(Icons.link_off),
            title: Text('${link.converterComponentId} → ${link.outputNetworkId}'),
            trailing: IconButton(tooltip: 'Supprimer la liaison', onPressed: () => Navigator.pop(context, _ProjectLinkChoice(removeId: link.id)), icon: const Icon(Icons.delete_outline)),
          )