import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pneumatic_device_glyph.dart';

/// Experimental two-view editor. The physical solver is NOT driven by widgets.
/// Both presentations edit exactly one canonical MultiphysicsProject.
class PneumaticWorkshopPage extends StatefulWidget {
  const PneumaticWorkshopPage({super.key, this.initialProject});
  final MultiphysicsProject? initialProject;

  @override
  State<PneumaticWorkshopPage> createState() => _PneumaticWorkshopPageState();
}

class _PneumaticWorkshopPageState extends State<PneumaticWorkshopPage> {
  late PneumaticWorkshopState _state;
  final List<PneumaticWorkshopState> _undo = <PneumaticWorkshopState>[];
  final List<PneumaticWorkshopState> _redo = <PneumaticWorkshopState>[];
  PneumaticPortId? _firstPort;
  int _deviceSerial = 0;
  int _pipeSerial = 0;

  static const List<PneumaticDeviceKind> _catalog = <PneumaticDeviceKind>[
    PneumaticDeviceKind.idealSource,
    PneumaticDeviceKind.valve32,
    PneumaticDeviceKind.valve52,
    PneumaticDeviceKind.singleActingCylinder,
    PneumaticDeviceKind.doubleActingCylinder,
    PneumaticDeviceKind.restrictor,
    PneumaticDeviceKind.checkValve,
    PneumaticDeviceKind.tee,
    PneumaticDeviceKind.manometer,
    PneumaticDeviceKind.silencer,
  ];

  @override
  void initState() {
    super.initState();
    _state = PneumaticWorkshopState(
      project: widget.initialProject ??
          MultiphysicsProject(
            electricalCircuit: CircuitState(
              circuitId: CircuitId('r4-air-workshop'),
              revision: 0,
              mode: ElectricalMode.dc,
            ),
          ),
    );
  }

  void _edit(PneumaticWorkshopState Function() operation) {
    try {
      final PneumaticWorkshopState updated = operation();
      setState(() {
        _undo.add(_state);
        _redo.clear();
        _state = updated;
        _firstPort = null;
      });
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Raccordement refusé : $error')),
      );
    }
  }

  void _history(bool undo) {
    final List<PneumaticWorkshopState> source = undo ? _undo : _redo;
    final List<PneumaticWorkshopState> other = undo ? _redo : _undo;
    if (source.isEmpty) return;
    setState(() {
      other.add(_state);
      _state = source.removeLast();
      _firstPort = null;
    });
  }

  void _place(PneumaticDeviceKind kind) {
    String id;
    do {
      id = 'air' + (++_deviceSerial).toString();
    } while (_state.project.pneumaticNetwork.devices.any((d) => d.id == id));
    final List<String> names = _ports(kind);
    final PneumaticDevice part = PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        for (final String name in names)
          PneumaticPort(
            id: PneumaticPortId('$id.$name'),
            deviceId: id,
            role: name == 'P'
                ? PneumaticPortRole.supply
                : name == 'R' || name == 'S'
                    ? PneumaticPortRole.exhaust
                    : PneumaticPortRole.work,
          ),
      ],
    );
    final int n = _state.project.pneumaticNetwork.devices.length;
    _edit(
      () => _state.place(
        device: part,
        physicalPose: PhysicalViewPose(
          x: 50 + (n % 5) * 210,
          y: 60 + (n ~/ 5) * 180,
        ),
        schematicPose: PhysicalViewPose(
          x: 50 + (n % 5) * 210,
          y: 60 + (n ~/ 5) * 180,
        ),
      ),
    );
  }

  void _portTap(PneumaticPortId port) {
    if (_firstPort == null) {
      setState(() => _firstPort = port);
      return;
    }
    final PneumaticPortId from = _firstPort!;
    if (from == port) {
      setState(() => _firstPort = null);
      return;
    }
    _edit(
      () => _state.connect(
        PneumaticPipe(
          id: 'hose' + (++_pipeSerial).toString(),
          fromPortId: from,
          toPortId: port,
          lengthM: 1,
          innerDiameterM: .006,
        ),
      ),
    );
  }

  Future<void> _importClipboard() async {
    try {
      final ClipboardData? clipboard = await Clipboard.getData('text/plain');
      if (!mounted) return;
      _edit(
        () => PneumaticWorkshopState(
          project: MultiphysicsProject.fromJsonString(clipboard?.text ?? ''),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Projet importé refusé : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool plate = _state.view == PneumaticWorkshopView.physical;
    final Map<String, PhysicalViewPose> poses =
        plate ? _state.project.physicalLayout : _state.project.schematicLayout;
    final PneumaticDevice? selected = _selected();
    return Scaffold(
      key: const Key('pneumatic-r4-workshop'),
      appBar: AppBar(
        title: const Text('Atelier pneumatique expérimental'),
        actions: <Widget>[
          IconButton(
            key: const Key('air-undo'),
            onPressed: _undo.isEmpty ? null : () => _history(true),
            icon: const Icon(Icons.undo),
            tooltip: 'Annuler',
          ),
          IconButton(
            key: const Key('air-redo'),
            onPressed: _redo.isEmpty ? null : () => _history(false),
            icon: const Icon(Icons.redo),
            tooltip: 'Rétablir',
          ),
          PopupMenuButton<String>(
            key: const Key('air-hoses'),
            tooltip: 'Supprimer un tuyau',
            enabled: _state.project.pneumaticNetwork.pipes.isNotEmpty,
            onSelected: (String id) =>
                _edit(() => _state.disconnect(id)),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final PneumaticPipe pipe
                  in _state.project.pneumaticNetwork.pipes)
                PopupMenuItem<String>(
                  value: pipe.id,
                  child: Text('Supprimer ' + pipe.id),
                ),
            ],
            icon: const Icon(Icons.alt_route),
          ),
          IconButton(
            key: const Key('air-import'),
            onPressed: _importClipboard,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Importer un projet multiphysique depuis le presse-papiers',
          ),
          IconButton(
            key: const Key('air-export'),
            onPressed: () => Clipboard.setData(
              ClipboardData(text: _state.project.toJsonString()),
            ),
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copier le projet multiphysique',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                SegmentedButton<PneumaticWorkshopView>(
                  segments: const <ButtonSegment<PneumaticWorkshopView>>[
                    ButtonSegment(
                      value: PneumaticWorkshopView.physical,
                      label: Text('Platine'),
                    ),
                    ButtonSegment(
                      value: PneumaticWorkshopView.schematic,
                      label: Text('Schéma'),
                    ),
                  ],
                  selected: <PneumaticWorkshopView>{_state.view},
                  onSelectionChanged: (selection) => setState(() {
                    _state = _state.switchView(selection.single);
                    _firstPort = null;
                  }),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Édition de réseau uniquement. Simulation pneumatique '
                    'non encore raccordée à cette interface.',
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final PneumaticDeviceKind kind in _catalog)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ActionChip(
                      key: Key('add-' + kind.name),
                      avatar: PneumaticDeviceGlyph(
                        kind: kind,
                        schematic: false,
                        width: 28,
                        height: 22,
                      ),
                      label: Text('+ ' + kind.name),
                      onPressed: () => _place(kind),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: InteractiveViewer(
                    minScale: .4,
                    maxScale: 2.5,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(150),
                    child: SizedBox(
                      width: 1200,
                      height: 760,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: ColoredBox(
                              color: plate
                                  ? const Color(0xffd7dcdf)
                                  : const Color(0xfffcfcff),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(1200, 760),
                            painter: _PipePainter(
                              project: _state.project,
                              poses: poses,
                              plate: plate,
                            ),
                          ),
                          for (final PneumaticDevice device
                              in _state.project.pneumaticNetwork.devices)
                            _tile(
                              device,
                              poses[device.id] ??
                                  PhysicalViewPose(x: 20, y: 20),
                              plate,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: selected == null
                          ? const Text(
                              'Sélectionnez un appareil. Pour un tuyau, '
                              'touchez deux bornes.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(selected.id),
                                Text(selected.kind.name),
                                const SizedBox(height: 10),
                                Text(
                                  selected.ports
                                      .map((p) => p.id.value)
                                      .join(' • '),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Pressions et débits : aucun résultat '
                                  'physique disponible dans cet éditeur.',
                                ),
                                const Spacer(),
                                FilledButton.tonalIcon(
                                  key: const Key('air-delete'),
                                  onPressed: () =>
                                      _edit(() => _state.remove(selected.id)),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Supprimer'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PneumaticDevice? _selected() {
    for (final PneumaticDevice d in _state.project.pneumaticNetwork.devices) {
      if (d.id == _state.selectedPhysicalId) return d;
    }
    return null;
  }

  Widget _tile(PneumaticDevice device, PhysicalViewPose pose, bool plate) =>
      Positioned(
        left: pose.x,
        top: pose.y,
        child: GestureDetector(
          onPanStart: (_) {
            _undo.add(_state);
            _redo.clear();
          },
          onPanUpdate: (details) => setState(() {
            _state = _state.move(
              physicalId: device.id,
              pose: PhysicalViewPose(
                x: pose.x + details.delta.dx,
                y: pose.y + details.delta.dy,
                rotationRad: pose.rotationRad,
              ),
            );
          }),
          child: InkWell(
            key: Key('device-' + device.id),
            onTap: () => setState(() => _state = _state.select(device.id)),
            child: Container(
              width: 170,
              height: 140,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: plate ? const Color(0xfff4f5f6) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _state.selectedPhysicalId == device.id
                      ? Colors.blue
                      : Colors.blueGrey,
                  width: _state.selectedPhysicalId == device.id ? 3 : 1,
                ),
              ),
              child: Column(
                children: <Widget>[
                  PneumaticDeviceGlyph(
                    kind: device.kind,
                    schematic: !plate,
                    width: 110,
                    height: 38,
                  ),
                  Text(
                    device.id + ' : ' + device.kind.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 27,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        for (final PneumaticPort port in device.ports)
                          InkWell(
                            key: Key('port-' + port.id.value),
                            onTap: () => _portTap(port.id),
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _firstPort == port.id
                                    ? Colors.amber.shade100
                                    : Colors.blueGrey.shade100,
                                border: Border.all(color: Colors.blueGrey),
                              ),
                              child: Text(
                                port.id.value.split('.').last,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PipePainter extends CustomPainter {
  const _PipePainter({
    required this.project,
    required this.poses,
    required this.plate,
  });
  final MultiphysicsProject project;
  final Map<String, PhysicalViewPose> poses;
  final bool plate;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pen = Paint()
      ..color = plate ? const Color(0xff216b87) : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Map<String, Offset> terminals = <String, Offset>{};
    for (final PneumaticDevice device in project.pneumaticNetwork.devices) {
      final PhysicalViewPose? pose = poses[device.id];
      if (pose == null) continue;
      final int count = device.ports.length;
      final double gap = (160 - count * 24) / (count + 1);
      for (int i = 0; i < count; i++) {
        terminals[device.ports[i].id.value] = Offset(
          pose.x + 5 + (i + 1) * gap + (i + .5) * 24,
          pose.y + 123,
        );
      }
    }
    for (final PneumaticPipe pipe in project.pneumaticNetwork.pipes) {
      final Offset? start = terminals[pipe.fromPortId.value];
      final Offset? end = terminals[pipe.toPortId.value];
      if (start == null || end == null) continue;
      final double middle = (start.dy + end.dy) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx, middle)
          ..lineTo(end.dx, middle)
          ..lineTo(end.dx, end.dy),
        pen,
      );
      canvas.drawCircle(start, 3, pen);
      canvas.drawCircle(end, 3, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _PipePainter previous) =>
      previous.project != project ||
      previous.poses != poses ||
      previous.plate != plate;
}

List<String> _ports(PneumaticDeviceKind kind) => switch (kind) {
  PneumaticDeviceKind.idealSource => <String>['P'],
  PneumaticDeviceKind.valve32 => <String>['P', 'A', 'R'],
  PneumaticDeviceKind.valve52 => <String>['P', 'A', 'B', 'R', 'S'],
  PneumaticDeviceKind.singleActingCylinder => <String>['A'],
  PneumaticDeviceKind.doubleActingCylinder => <String>['A', 'B'],
  PneumaticDeviceKind.tee => <String>['1', '2', '3'],
  PneumaticDeviceKind.silencer => <String>['R'],
  PneumaticDeviceKind.checkValve ||
  PneumaticDeviceKind.restrictor => <String>['A', 'B'],
  _ => <String>['P'],
};
