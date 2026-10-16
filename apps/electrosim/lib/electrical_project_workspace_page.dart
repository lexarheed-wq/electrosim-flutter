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
import 'runtime/electrical_project_runtime_engine.dart';
import 'runtime/electrosim_layout_persistence.dart';

/// Two independent F18 editors governed by one project simulation clock.
final class ElectricalProjectWorkspacePage extends StatefulWidget {
  const ElectricalProjectWorkspacePage({
    super.key,
    required this.initialProject,
    required this.onProjectChanged,
  });
  final ElectricalProject initialProject;
  final ValueChanged<ElectricalProject> onProjectChanged;

  @override
  State<ElectricalProjectWorkspacePage> createState() =>
      _ElectricalProjectWorkspacePageState();
}

final class _ElectricalProjectWorkspacePageState
    extends State<ElectricalProjectWorkspacePage> {
  late ElectricalProject _project = widget.initialProject;
  final ElectricalProjectRuntimeEngine _engine =
      const ElectricalProjectRuntimeEngine();
  final Map<String, CircuitVisualLayout> _layouts =
      <String, CircuitVisualLayout>{};
  String? _selectedNetworkId;
  ElectricalProjectRuntimeSnapshot? _runtime;
  Timer? _clock;
  bool _running = false;
  String _status = 'Projet prêt';

  ElectricalNetwork? get _selected =>
      _project.networks
          .where((ElectricalNetwork n) => n.id == _selectedNetworkId)
          .firstOrNull ??
      _project.networks.firstOrNull;
  bool get _isRunning => _running;

  @override
  void initState() {
    super.initState();
    _selectedNetworkId =
        _project.networks
            .where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc)
            .firstOrNull
            ?.id ??
        _project.networks.firstOrNull?.id;
  }

  void _setProject(ElectricalProject next) {
    setState(() {
      _project = next;
      _status = 'Projet modifié';
    });
    widget.onProjectChanged(next);
  }

  void _onCircuitChanged(String networkId, CircuitState circuit) {
    final ElectricalNetwork? old = _project.networks
        .where((ElectricalNetwork n) => n.id == networkId)
        .firstOrNull;
    if (old == null || identical(old.circuit, circuit)) return;
    final List<ElectricalNetwork> networks = <ElectricalNetwork>[
      for (final ElectricalNetwork n in _project.networks)
        if (n.id == networkId)
          ElectricalNetwork(id: n.id, circuit: circuit)
        else
          n,
    ];
    bool hasComponent(String netId, String id) =>
        networks
            .where((ElectricalNetwork n) => n.id == netId)
            .firstOrNull
            ?.circuit
            .components
            .any((ComponentInstance c) => c.id.value == id) ??
        false;
    try {
      _setProject(
        ElectricalProject(
          networks: networks,
          relayLinks: _project.relayLinks
              .where(
                (CrossNetworkRelayLink l) =>
                    hasComponent(l.plcNetworkId, l.plcComponentId) &&
                    hasComponent(l.dcNetworkId, l.relayCoilId) &&
                    hasComponent(l.ac3NetworkId, l.ac3ContactId),
              )
              .toList(),
          signalLinks: _project.signalLinks
              .where(
                (CrossNetworkSignalLink l) =>
                    hasComponent(l.dcNetworkId, l.plcComponentId) &&
                    hasComponent(l.ac3NetworkId, l.auxiliaryContactId),
              )
              .toList(),
        ),
      );
    } on ElectricalProjectException catch (error) {
      setState(() => _status = 'Modification refusée : ${error.message}');
    }
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _clock = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _advance(const Duration(milliseconds: 250)),
    );
  }

  void _pause() {
    _clock?.cancel();
    _clock = null;
    if (mounted) setState(() => _running = false);
  }

  void _advance(Duration elapsed) {
    if (!mounted) return;
    try {
      final ElectricalProjectRuntimeSnapshot next = _engine.advance(
        _project,
        elapsed: elapsed,
        previous: _runtime,
      );
      setState(() {
        _runtime = next;
        _status = next.diagnostics.isEmpty
            ? 'Simulation résolue'
            : next.diagnostics.first;
      });
    } on Object catch (error) {
      _pause();
      setState(() => _status = 'Simulation arrêtée : $error');
    }
  }

  Future<void> _saveProject() async {
    final XFile? file =
        await getSaveLocation(
          suggestedName: 'ElectroSim_projet.electrosimproject.json',
        ).then(
          (FileSaveLocation? location) =>
              location == null ? null : XFile(location.path),
        );
    if (file == null) return;
    final DateTime now = DateTime.now().toUtc();
    final SavedElectricalProjectDocument document =
        SavedElectricalProjectDocument(
          saveId: _project.networks
              .map((ElectricalNetwork n) => n.id)
              .join('-'),
          title: 'Projet électrique mixte',
          createdAtUtc: now,
          updatedAtUtc: now,
          engineVersion: 'electrosim-project/1',
          project: _project,
          appState: <String, Object?>{
            'layouts': <String, Object?>{
              for (final MapEntry<String, CircuitVisualLayout> entry
                  in _layouts.entries)
                entry.key: ElectroSimLayoutPersistence.encode(entry.value),
            },
          },
        );
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(document.toJsonString())),
      mimeType: 'application/json',
    ).saveTo(file.path);
    if (mounted) setState(() => _status = 'Projet enregistré : ${file.path}');
  }

  Future<void> _openProject() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'Projet ElectroSim',
          extensions: <String>['json'],
        ),
      ],
    );
    if (file == null) return;
    try {
      final SavedElectricalProjectDocument document =
          SavedElectricalProjectDocument.fromJsonString(
            await file.readAsString(),
          );
      _pause();
      setState(() {
        _project = document.project;
        _selectedNetworkId =
            document.project.networks
                .where(
                  (ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc,
                )
                .firstOrNull
                ?.id ??
            document.project.networks.first.id;
        _runtime = null;
        final Object? rawLayouts = document.appState['layouts'];
        _layouts.clear();
        if (rawLayouts is Map<String, dynamic>) {
          for (final MapEntry<String, dynamic> entry in rawLayouts.entries) {
            final CircuitVisualLayout? layout =
                ElectroSimLayoutPersistence.decode(entry.value);
            if (layout != null) _layouts[entry.key] = layout;
          }
        }
        _status = 'Projet ouvert : ${document.title}';
      });
      widget.onProjectChanged(document.project);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'Impossible d’ouvrir le projet : $error');
      }
    }
  }

  Future<void> _manageLinks() async {
    final _ProjectLinkChoice? choice = await showDialog<_ProjectLinkChoice>(
      context: context,
      builder: (BuildContext context) => _ProjectLinkDialog(project: _project),
    );
    if (choice == null) return;
    final List<CrossNetworkRelayLink> relays = List<CrossNetworkRelayLink>.from(
      _project.relayLinks,
    );
    final List<CrossNetworkSignalLink> signals =
        List<CrossNetworkSignalLink>.from(_project.signalLinks);
    if (choice.removeId != null) {
      relays.removeWhere((CrossNetworkRelayLink l) => l.id == choice.removeId);
      signals.removeWhere(
        (CrossNetworkSignalLink l) => l.id == choice.removeId,
      );
    } else if (choice.relayCoilId != null && choice.contactId != null) {
      final ElectricalNetwork dc = _project.networks.firstWhere(
        (ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc,
      );
      final ComponentInstance plc = dc.circuit.components.firstWhere(
        (ComponentInstance c) => c.modelType == 'plc_dc',
      );
      final String? output = <String>['Q0', 'Q1', 'Q2', 'Q3']
          .where(
            (String a) => !relays.any(
              (CrossNetworkRelayLink l) =>
                  l.plcComponentId == plc.id.value && l.outputAddress == a,
            ),
          )
          .firstOrNull;
      if (output == null) {
        setState(() => _status = 'Les quatre sorties PLC sont déjà liées.');
        return;
      }
      final String id = _newLinkId(
        'bridge',
        relays.map((CrossNetworkRelayLink l) => l.id),
      );
      relays.add(
        CrossNetworkRelayLink(
          id: id,
          plcNetworkId: dc.id,
          plcComponentId: plc.id.value,
          outputAddress: output,
          dcNetworkId: dc.id,
          relayCoilId: choice.relayCoilId!,
          ac3NetworkId: _project.networks
              .firstWhere(
                (ElectricalNetwork n) => n.circuit.mode == ElectricalMode.ac3,
              )
              .id,
          ac3ContactId: choice.contactId!,
        ),
      );
    } else if (choice.plcInput != null && choice.contactId != null) {
      final ElectricalNetwork dc = _project.networks.firstWhere(
        (ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc,
      );
      final ComponentInstance plc = dc.circuit.components.firstWhere(
        (ComponentInstance c) => c.modelType == 'plc_dc',
      );
      final String? input = <String>['I0', 'I1', 'I2', 'I3']
          .where(
            (String a) => !signals.any(
              (CrossNetworkSignalLink l) =>
                  l.plcComponentId == plc.id.value && l.inputAddress == a,
            ),
          )
          .firstOrNull;
      if (input == null) {
        setState(() => _status = 'Les quatre entrées PLC sont déjà liées.');
        return;
      }
      final String id = _newLinkId(
        'feedback',
        signals.map((CrossNetworkSignalLink l) => l.id),
      );
      signals.add(
        CrossNetworkSignalLink(
          id: id,
          ac3NetworkId: _project.networks
              .firstWhere(
                (ElectricalNetwork n) => n.circuit.mode == ElectricalMode.ac3,
              )
              .id,
          auxiliaryContactId: choice.contactId!,
          dcNetworkId: dc.id,
          plcComponentId: plc.id.value,
          inputAddress: input,
        ),
      );
    }
    try {
      _setProject(
        ElectricalProject(
          networks: _project.networks,
          relayLinks: relays,
          signalLinks: signals,
        ),
      );
    } on Object catch (error) {
      setState(() => _status = 'Liaison refusée : $error');
    }
  }

  static String _newLinkId(String prefix, Iterable<String> existing) {
    final Set<String> ids = existing.toSet();
    for (int i = 1; i < 10000; i++) {
      final String id = '$prefix-$i';
      if (!ids.contains(id)) return id;
    }
    throw StateError('No free project link identifier.');
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ElectricalNetwork? selected = _selected;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final ElectricalNetwork network
                            in _project.networks)
                          ChoiceChip(
                            key: Key('project-network-${network.id}'),
                            label: Text(
                              network.circuit.mode == ElectricalMode.dc
                                  ? 'Commande 24 V CC'
                                  : 'Puissance AC3',
                            ),
                            selected: selected?.id == network.id,
                            onSelected: (_) =>
                                setState(() => _selectedNetworkId = network.id),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Ouvrir un projet',
                          onPressed: _openProject,
                          icon: const Icon(Icons.folder_open),
                        ),
                        IconButton(
                          tooltip: 'Enregistrer le projet',
                          onPressed: _saveProject,
                          icon: const Icon(Icons.save),
                        ),
                        IconButton(
                          tooltip: 'Liaisons PLC et relais',
                          onPressed: _project.networks.length == 2
                              ? _manageLinks
                              : null,
                          icon: const Icon(Icons.hub_outlined),
                        ),
                        FilledButton.icon(
                          key: const Key('project-simulation-toggle'),
                          onPressed: _isRunning ? _pause : _start,
                          icon: Icon(
                            _isRunning ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(_isRunning ? 'Pause' : 'Lancer'),
                        ),
                        IconButton(
                          tooltip: 'Un pas de 250 ms',
                          onPressed: () =>
                              _advance(const Duration(milliseconds: 250)),
                          icon: const Icon(Icons.skip_next),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_runtime != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      't = ${(_runtime!.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s',
                    ),
                    const SizedBox(width: 16),
                    for (final ElectricalNetwork n in _project.networks)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${n.circuit.mode == ElectricalMode.dc ? 'CC' : 'AC3'} : ${_runtime!.networks[n.id]?.solved == true ? 'résolu' : 'défaut'}',
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: selected == null
                  ? const Center(child: Text('Aucun réseau dans ce projet.'))
                  : F18WorkspacePage(
                      key: ValueKey<String>('network-${selected.id}'),
                      entryLabel: 'Projet électrique mixte',
                      initialCircuit: selected.circuit,
                      compositeNetworkMode: true,
                      externalRuntimeSnapshot: _runtime?.networks[selected.id],
                      initialVisualLayout: _layouts[selected.id],
                      onVisualLayoutChanged: (CircuitVisualLayout layout) =>
                          _layouts[selected.id] = layout,
                      onCircuitChanged: (CircuitState circuit) =>
                          _onCircuitChanged(selected.id, circuit),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProjectLinkChoice {
  const _ProjectLinkChoice({
    this.relayCoilId,
    this.contactId,
    this.plcInput,
    this.removeId,
  });
  final String? relayCoilId;
  final String? contactId;
  final bool? plcInput;
  final String? removeId;
}

final class _ProjectLinkDialog extends StatelessWidget {
  const _ProjectLinkDialog({required this.project});
  final ElectricalProject project;
  @override
  Widget build(BuildContext context) {
    final ElectricalNetwork? dc = project.networks
        .where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc)
        .firstOrNull;
    final ElectricalNetwork? ac = project.networks
        .where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.ac3)
        .firstOrNull;
    final List<ComponentInstance> coils =
        dc?.circuit.components
            .where((ComponentInstance c) => c.modelType == 'relay_coil')
            .toList() ??
        const <ComponentInstance>[];
    final List<ComponentInstance> contacts =
        ac?.circuit.components
            .where(
              (ComponentInstance c) =>
                  c.modelType == 'contactor_aux_no' ||
                  c.modelType == 'contactor_aux_nc',
            )
            .toList() ??
        const <ComponentInstance>[];
    final List<ComponentInstance> plcs =
        dc?.circuit.components
            .where((ComponentInstance c) => c.modelType == 'plc_dc')
            .toList() ??
        const <ComponentInstance>[];
    return AlertDialog(
      title: const Text('Liaisons inter-réseaux'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: ListView(
          children: <Widget>[
            const ListTile(
              title: Text('Sortie PLC → bobine relais CC → contact sec AC3'),
            ),
            for (final ComponentInstance coil in coils)
              for (final ComponentInstance contact in contacts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.electric_bolt),
                  title: Text('${coil.id.value} → ${contact.id.value}'),
                  subtitle: const Text('Créer un pont de relais isolé'),
                  onTap: () => Navigator.pop(
                    context,
                    _ProjectLinkChoice(
                      relayCoilId: coil.id.value,
                      contactId: contact.id.value,
                    ),
                  ),
                ),
            const Divider(),
            const ListTile(
              title: Text('Contact auxiliaire AC3 → entrée PLC CC'),
            ),
            for (final ComponentInstance plc in plcs)
              for (final ComponentInstance contact in contacts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.sync_alt),
                  title: Text('${contact.id.value} → ${plc.id.value}'),
                  subtitle: const Text('Créer un retour d’état isolé'),
                  onTap: () => Navigator.pop(
                    context,
                    _ProjectLinkChoice(
                      plcInput: true,
                      contactId: contact.id.value,
                    ),
                  ),
                ),
            const Divider(),
            for (final CrossNetworkRelayLink link in project.relayLinks)
              ListTile(
                dense: true,
                leading: const Icon(Icons.link_off),
                title: Text(
                  '${link.outputAddress} · ${link.relayCoilId} → ${link.ac3ContactId}',
                ),
                trailing: IconButton(
                  tooltip: 'Supprimer la liaison',
                  onPressed: () => Navigator.pop(
                    context,
                    _ProjectLinkChoice(removeId: link.id),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            for (final CrossNetworkSignalLink link in project.signalLinks)
              ListTile(
                dense: true,
                leading: const Icon(Icons.link_off),
                title: Text(
                  '${link.inputAddress} · ${link.auxiliaryContactId} → ${link.plcComponentId}',
                ),
                trailing: IconButton(
                  tooltip: 'Supprimer la liaison',
                  onPressed: () => Navigator.pop(
                    context,
                    _ProjectLinkChoice(removeId: link.id),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
