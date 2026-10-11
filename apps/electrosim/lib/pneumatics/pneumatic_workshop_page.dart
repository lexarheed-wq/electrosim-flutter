import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pneumatic_device_glyph.dart';
import 'pneumatic_reference_cycle_page.dart';

/// Experimental two-view editor of one canonical MultiphysicsProject.
/// Runtime advances an opt-in, calibrated physical subset only; unsupported
/// devices fail visibly and no calculation is performed by the widgets.
class PneumaticWorkshopPage extends StatefulWidget {
  const PneumaticWorkshopPage({
    super.key,
    this.initialProject,
    this.initialView = PneumaticWorkshopView.physical,
  });
  final MultiphysicsProject? initialProject;
  final PneumaticWorkshopView initialView;

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
  IsothermalAirNetwork? _airSolver;
  IsothermalAirSnapshot? _airSnapshot;
  double? _dischargeCoefficient;

  void _invalidateAirRuntime() {
    _airSolver = null;
    _airSnapshot = null;
  }

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
      view: widget.initialView,
      project:
          widget.initialProject ??
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
        _invalidateAirRuntime();
      });
    } on Object catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Raccordement refusé : $error')));
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
      _invalidateAirRuntime();
    });
  }

  void _place(PneumaticDeviceKind kind) {
    String id;
    do {
      id = 'air${++_deviceSerial}';
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

  TextFormField _physicalInput(
    String label,
    double? initial,
    ValueChanged<double> save, {
    bool allowZero = false,
    double? maxValue,
  }) => TextFormField(
    initialValue: initial?.toString() ?? '',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (String? value) {
      final double? number = double.tryParse(
        (value ?? '').trim().replaceAll(',', '.'),
      );
      if (number == null ||
          !number.isFinite ||
          (allowZero ? number < 0 : number <= 0)) {
        return allowZero
            ? 'Saisir un nombre positif ou nul.'
            : 'Saisir un nombre strictement positif.';
      }
      if (maxValue != null && number > maxValue) {
        return 'La valeur doit être inférieure ou égale à $maxValue.';
      }
      return null;
    },
    onSaved: (String? value) =>
        save(double.parse((value ?? '').trim().replaceAll(',', '.'))),
  );

  Future<void> _portTap(PneumaticPortId port) async {
    if (_firstPort == null) {
      setState(() => _firstPort = port);
      return;
    }
    final PneumaticPortId from = _firstPort!;
    if (from == port) {
      setState(() => _firstPort = null);
      return;
    }
    final GlobalKey<FormState> key = GlobalKey<FormState>();
    double length = 0;
    double bore = 0;
    double loss = 0;
    final List<double>? calibrated = await showDialog<List<double>>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Caractéristiques réelles du tuyau'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _physicalInput('Longueur (m)', null, (double x) => length = x),
              _physicalInput(
                'Diamètre intérieur (m)',
                null,
                (double x) => bore = x,
              ),
              _physicalInput(
                'Coefficient de perte K',
                null,
                (double x) => loss = x,
                allowZero: true,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('air-hose-calibration-apply'),
            onPressed: () {
              if (!key.currentState!.validate()) return;
              key.currentState!.save();
              Navigator.of(dialog).pop(<double>[length, bore, loss]);
            },
            child: const Text('Raccorder'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _firstPort = null);
    if (calibrated == null) return;
    String id;
    do {
      id = 'hose${++_pipeSerial}';
    } while (_state.project.pneumaticNetwork.pipes.any(
      (PneumaticPipe p) => p.id == id,
    ));
    _edit(
      () => _state.connect(
        PneumaticPipe(
          id: id,
          fromPortId: from,
          toPortId: port,
          lengthM: calibrated[0],
          innerDiameterM: calibrated[1],
          lossCoefficient: calibrated[2],
        ),
      ),
    );
  }

  Future<void> _calibrateSelected(PneumaticDevice device) async {
    final bool fitting =
        device.kind == PneumaticDeviceKind.tee ||
        device.kind == PneumaticDeviceKind.manifold;
    final bool boundary =
        device.kind == PneumaticDeviceKind.idealSource ||
        device.kind == PneumaticDeviceKind.silencer;
    if (!fitting && !boundary) return;
    final GlobalKey<FormState> key = GlobalKey<FormState>();
    final Map<String, double> values = <String, double>{};
    final Map<String, double>? calibrated =
        await showDialog<Map<String, double>>(
          context: context,
          builder: (BuildContext dialog) => AlertDialog(
            title: Text('Calibrer ${device.id} — unités SI'),
            content: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _physicalInput(
                    'Pression absolue (Pa)',
                    device.parametersSi['pressureAbsPa'],
                    (double x) => values['pressureAbsPa'] = x,
                  ),
                  if (fitting)
                    _physicalInput(
                      'Volume gazeux (m³)',
                      device.parametersSi['volumeM3'],
                      (double x) => values['volumeM3'] = x,
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                key: const Key('air-calibration-apply'),
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  key.currentState!.save();
                  Navigator.of(dialog).pop(values);
                },
                child: const Text('Appliquer'),
              ),
            ],
          ),
        );
    if (!mounted || calibrated == null) return;
    _edit(
      () => _state.calibrate(physicalId: device.id, parametersSi: calibrated),
    );
  }

  Future<void> _advanceAir() async {
    double? cd = _dischargeCoefficient;
    if (cd == null) {
      final GlobalKey<FormState> key = GlobalKey<FormState>();
      double entered = 0;
      cd = await showDialog<double>(
        context: context,
        builder: (BuildContext dialog) => AlertDialog(
          title: const Text('Coefficient d’écoulement Cd'),
          content: Form(
            key: key,
            child: _physicalInput(
              'Cd (0 < Cd ≤ 1)',
              null,
              (double x) => entered = x,
              maxValue: 1,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const Key('air-cd-apply'),
              onPressed: () {
                if (!key.currentState!.validate()) return;
                key.currentState!.save();
                Navigator.of(dialog).pop(entered);
              },
              child: const Text('Calculer'),
            ),
          ],
        ),
      );
      if (!mounted || cd == null) return;
    }
    try {
      final IsothermalAirNetwork solver =
          _airSolver ??
          WorkshopClosedAirCompiler(
            dischargeCoefficient: cd,
          ).compileWithIdealBoundaries(_state.project.pneumaticNetwork);
      final IsothermalAirSnapshot next = solver.advance(
        _airSnapshot ?? solver.initialSnapshot,
        durationS: .02,
        maxStepS: .001,
      );
      setState(() {
        _dischargeCoefficient = cd;
        _airSolver = solver;
        _airSnapshot = next;
      });
    } on Object catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Simulation impossible : $error')));
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Projet importé refusé : $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool plate = _state.view == PneumaticWorkshopView.physical;
    final Map<String, PhysicalViewPose> poses = plate
        ? _state.project.physicalLayout
        : _state.project.schematicLayout;
    final PneumaticDevice? selected = _selected();
    return Scaffold(
      key: const Key('pneumatic-r4-workshop'),
      appBar: AppBar(
        title: const Text('Atelier pneumatique expérimental'),
        actions: <Widget>[
          IconButton(
            key: const Key('air-advance'),
            tooltip: 'Avancer de 20 ms le réseau physique calibré',
            onPressed: _advanceAir,
            icon: const Icon(Icons.speed),
          ),
          IconButton(
            key: const Key('air-reset-physics'),
            tooltip: 'Réinitialiser les mesures physiques',
            onPressed: _airSnapshot == null
                ? null
                : () => setState(_invalidateAirRuntime),
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            key: const Key('r6-open-reference'),
            tooltip: 'Ouvrir le cycle physique de référence 24 V / 5/2',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PneumaticReferenceCyclePage(),
              ),
            ),
            icon: const Icon(Icons.play_circle_outline),
          ),
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
            onSelected: (String id) => _edit(() => _state.disconnect(id)),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final PneumaticPipe pipe
                  in _state.project.pneumaticNetwork.pipes)
                PopupMenuItem<String>(
                  value: pipe.id,
                  child: Text('Supprimer ${pipe.id}'),
                ),
            ],
            icon: const Icon(Icons.alt_route),
          ),
          IconButton(
            key: const Key('air-import'),
            onPressed: _importClipboard,
            icon: const Icon(Icons.file_download_outlined),
            tooltip:
                'Importer un projet multiphysique depuis le presse-papiers',
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
                Expanded(
                  child: Text(
                    _airSnapshot == null
                        ? 'Réseau expérimental : calcul seulement pour '
                              'sources idéales, silencieux et collecteurs '
                              'physiquement calibrés. Autres modèles refusés.'
                        : 'Simulation réelle : t = '
                              '${_airSnapshot!.timeS.toStringAsFixed(3)} s ; '
                              'masse externe = '
                              '${_airSnapshot!.externalMassAddedKg.toStringAsExponential(3)} kg',
                    key: const Key('air-runtime-state'),
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
                      key: Key('add-${kind.name}'),
                      avatar: PneumaticDeviceGlyph(
                        kind: kind,
                        schematic: false,
                        width: 28,
                        height: 22,
                      ),
                      label: Text('+ ${kind.name}'),
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
                                if (selected.parametersSi.isNotEmpty)
                                  Text(
                                    selected.parametersSi.entries
                                        .map((e) => '${e.key}=${e.value}')
                                        .join('  '),
                                    style: const TextStyle(fontSize: 10),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (_airSnapshot?.chambers[selected.id] != null)
                                  Text(
                                    'P abs = '
                                    '${_airSnapshot!.chambers[selected.id]!.pressureAbsPa.toStringAsFixed(0)} Pa',
                                    key: const Key('air-measured-pressure'),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  selected.ports
                                      .map((p) => p.id.value)
                                      .join(' • '),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _airSnapshot == null
                                      ? 'Aucune mesure disponible avant '
                                          'simulation du réseau calibré.'
                                      : 'Débits calculés (kg/s) : '
                                          '${_airSnapshot!.passageMassFlowKgPerS.entries.map((e) => '${e.key}=${e.value.toStringAsExponential(2)}').join(' ; ')}',
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  key: const Key('air-measured-flows'),
                                ),
                                if (selected.kind == PneumaticDeviceKind.tee ||
                                    selected.kind == PneumaticDeviceKind.manifold ||
                                    selected.kind == PneumaticDeviceKind.idealSource ||
                                    selected.kind == PneumaticDeviceKind.silencer)
                                  FilledButton.tonal(
                                    key: const Key('air-calibrate-device'),
                                    onPressed: () => _calibrateSelected(selected),
                                    child: const Text('Calibrer'),
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
            key: Key('device-${device.id}'),
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
                    '${device.id} : ${device.kind.name}',
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
                            key: Key('port-${port.id.value}'),
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
                                _displayPortLabel(device.kind, port),
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

String _displayPortLabel(PneumaticDeviceKind kind, PneumaticPort port) {
  final String label = port.id.value.split('.').last;
  if (kind == PneumaticDeviceKind.valve52) {
    // ISO 1219 / industry-identification convention for 5/2 devices:
    // 1=P supply, 2=A, 4=B, 3=R exhaust, 5=S exhaust.
    return switch (label) {
      'P' => '1/P',
      'A' => '2/A',
      'B' => '4/B',
      'R' => '3/R',
      'S' => '5/S',
      _ => label,
    };
  }
  if (kind == PneumaticDeviceKind.valve32) {
    return switch (label) {
      'P' => '1/P',
      'A' => '2/A',
      'R' => '3/R',
      _ => label,
    };
  }
  return label;
}
