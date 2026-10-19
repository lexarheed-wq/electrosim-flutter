import 'dart:async';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:flutter/material.dart';

/// Guided, authored-project electro-pneumatic bench available from the
/// experimental workshop. The circuit and hose network are both solved.
class ElectropneumaticTrainingBenchPage extends StatefulWidget {
  const ElectropneumaticTrainingBenchPage({super.key});

  @override
  State<ElectropneumaticTrainingBenchPage> createState() =>
      _ElectropneumaticTrainingBenchPageState();
}

class _ElectropneumaticTrainingBenchPageState
    extends State<ElectropneumaticTrainingBenchPage> {
  late final AuthoredNetworkSelfHoldValve52Cycle _cycle;
  late AuthoredNetworkSelfHoldSnapshot _accepted;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MultiphysicsProject project = _buildProject();
    final ElectropneumaticLink y1 = project.links.firstWhere(
      (link) => link.role == ElectropneumaticLinkRole.solenoidCoil,
    );
    _cycle = AuthoredNetworkSelfHoldValve52Cycle(
      electrical: SelfHold24vElectricalCycle(
        project: project,
        binding: SelfHold24vBinding(
          startComponentId: 's1',
          holdContactComponentId: 'k1-contact',
          endStopComponentId: 'b1',
          relayWindingComponentId: 'k1-winding',
          valveSolenoidLink: y1,
        ),
      ),
      compiler: const WorkshopClosedAirCompiler(dischargeCoefficient: .8),
      valveDeviceId: 'valve',
      cylinderDeviceId: 'cylinder',
      endSensor: PositionEndContact(
        strokeM: .06,
        triggerPositionM: .059,
        releasePositionM: .055,
        normallyOpen: false,
      ),
      solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
      maxStepS: .0005,
      mechanicalStepS: .00005,
    );
    _accepted = _cycle.initial();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance(double seconds, {bool start = false}) {
    if (_error != null) return;
    try {
      final AuthoredNetworkSelfHoldSnapshot next = _cycle.advance(
        _accepted,
        durationS: seconds,
        startPressed: start,
      );
      setState(() => _accepted = next);
    } on Object catch (error) {
      _timer?.cancel();
      setState(() => _error = '$error');
    }
  }

  void _toggleRun() {
    if (_timer != null) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        _advance(.01);
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _accepted = _cycle.initial();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double stroke = .06;
    final double position = _accepted.air.positionM;
    final double fraction = (position / stroke).clamp(0.0, 1.0);
    final bool energized = _accepted.electrical?.relay.energized ?? false;
    final double voltage = _accepted.electrical?.valveReading.voltageV ?? 0;
    return Scaffold(
      key: const Key('electropneumatic-training-bench'),
      appBar: AppBar(title: const Text('Banc électropneumatique 24 V')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Montage guidé : S1 commande K1 avec auto-maintien, B1 ouvre '
            'la chaîne en fin de course, Y1 commute le distributeur 5/2 et '
            'le vérin double effet avance sur le réseau pneumatique raccordé.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: const Key('ep-start-s1'),
                onPressed: _error == null
                    ? () => _advance(0, start: true)
                    : null,
                child: const Text('Impulsion Marche S1'),
              ),
              OutlinedButton(
                key: const Key('ep-step'),
                onPressed: _error == null ? () => _advance(.005) : null,
                child: const Text('Avancer de 5 ms'),
              ),
              OutlinedButton(
                key: const Key('ep-run'),
                onPressed: _error == null ? _toggleRun : null,
                child: Text(_timer == null ? 'Exécuter' : 'Pause'),
              ),
              TextButton(
                key: const Key('ep-reset'),
                onPressed: _reset,
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          if (_error != null)
            Text('Erreur de calcul : $_error', key: const Key('ep-error')),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: <Widget>[
              _metric(
                'Temps simulé',
                '${_accepted.timeS.toStringAsFixed(3)} s',
              ),
              _metric('K1 / Y1', energized ? 'Excités' : 'Au repos'),
              _metric('Tension Y1', '${voltage.toStringAsFixed(2)} V'),
              _metric(
                'Fin de course B1',
                _accepted.endStopActuated ? 'Actionné' : 'Libre',
              ),
              _metric(
                'Position vérin',
                '${(position * 1000).toStringAsFixed(2)} mm',
              ),
              _metric(
                'Vitesse tige',
                '${_accepted.air.velocityMPerS.toStringAsFixed(3)} m/s',
              ),
              _metric(
                'Distributeur',
                _accepted.spool == ValveSpoolSide.coilSide
                    ? 'Côté bobine Y1'
                    : 'Côté ressort',
              ),
              _metric(
                'Résidu de masse',
                '${_cycle.massBalanceResidualKg(_accepted).toStringAsExponential(2)} kg',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Course physique acceptée'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const Key('ep-stroke'),
            value: fraction,
            minHeight: 10,
          ),
          const SizedBox(height: 20),
          const Text(
            'Le banc utilise un projet de démonstration calibré et le solveur '
            'électrique continu ainsi que le réseau d’air couplé. Il sert à '
            'explorer le cycle ; les composants et raccordements de l’atelier '
            'libre ne sont pas encore compilés automatiquement dans ce banc.',
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

MultiphysicsProject _buildProject() {
  Terminal terminal(String id) => Terminal(id: TerminalId(id), name: id);
  ComponentInstance contact(String id, String type, String a, String b) =>
      ComponentInstance(
        id: ComponentId(id),
        modelType: type,
        terminals: <Terminal>[terminal(a), terminal(b)],
        controlState: <String, Object?>{
          if (type == 'switch') 'closed': false,
          if (type != 'switch') 'actuated': false,
        },
      );
  ComponentInstance coil(String id, String a, String b, double ohms) =>
      ComponentInstance(
        id: ComponentId(id),
        modelType: 'resistor',
        terminals: <Terminal>[terminal(a), terminal(b)],
        parameters: <String, Object?>{'resistanceOhm': ohms},
      );
  Connection wire(String id, String a, String b) => Connection(
    id: ConnectionId(id),
    fromTerminalId: TerminalId(a),
    toTerminalId: TerminalId(b),
  );
  final CircuitState circuit = CircuitState(
    circuitId: CircuitId('electrosim-ep-training-24v'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      contact('s1', 'switch', 's1a', 's1b'),
      contact('k1-contact', 'relay_contact_no', 'k1a', 'k1b'),
      contact('b1', 'relay_contact_nc', 'b1a', 'b1b'),
      coil('k1-winding', 'k1c', 'k1d', 480),
      coil('y1', 'y1a', 'y1b', 240),
    ],
    connections: <Connection>[
      wire('w1', 'vp', 's1a'),
      wire('w2', 'vp', 'k1a'),
      wire('w3', 's1b', 'b1a'),
      wire('w4', 'k1b', 'b1a'),
      wire('w5', 'b1b', 'k1c'),
      wire('w6', 'b1b', 'y1a'),
      wire('w7', 'k1d', 'vn'),
      wire('w8', 'y1b', 'vn'),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('supply'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('vp'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('vn'),
            name: '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: <String, Object?>{'voltageV': 24},
      ),
    ],
  );
  PneumaticDevice boundary(
    String id,
    PneumaticDeviceKind kind,
    double pressure,
  ) => PneumaticDevice(
    id: id,
    kind: kind,
    ports: <PneumaticPort>[
      PneumaticPort(
        id: PneumaticPortId('$id.1'),
        deviceId: id,
        role: kind == PneumaticDeviceKind.idealSource
            ? PneumaticPortRole.supply
            : PneumaticPortRole.exhaust,
      ),
    ],
    parametersSi: <String, double>{'pressureAbsPa': pressure},
  );
  PneumaticDevice valve = PneumaticDevice(
    id: 'valve',
    kind: PneumaticDeviceKind.valve52,
    ports: <PneumaticPort>[
      for (final (String name, PneumaticPortRole role)
          in <(String, PneumaticPortRole)>[
            ('P', PneumaticPortRole.supply),
            ('A', PneumaticPortRole.work),
            ('B', PneumaticPortRole.work),
            ('R', PneumaticPortRole.exhaust),
            ('S', PneumaticPortRole.exhaust),
          ])
        PneumaticPort(
          id: PneumaticPortId('valve.$name'),
          deviceId: 'valve',
          role: role,
        ),
    ],
    parametersSi: <String, double>{
      'portDeadVolumeM3': .00001,
      'pressureAbsPa': 101325,
      'valveEffectiveAreaM2': .000004,
      'valveCd': .8,
      'energized': 0,
    },
  );
  PneumaticDevice cylinder = PneumaticDevice(
    id: 'cylinder',
    kind: PneumaticDeviceKind.doubleActingCylinder,
    ports: <PneumaticPort>[
      for (final String name in <String>['A', 'B'])
        PneumaticPort(
          id: PneumaticPortId('cylinder.$name'),
          deviceId: 'cylinder',
          role: PneumaticPortRole.work,
        ),
    ],
    parametersSi: <String, double>{
      'pistonDiameterM': .032,
      'rodDiameterM': .008,
      'strokeM': .06,
      'deadVolumeAM3': .00005,
      'deadVolumeBM3': .00005,
      'initialPositionM': .005,
      'initialPressureAAbsPa': 101325,
      'initialPressureBAbsPa': 101325,
      'movingMassKg': 1,
      'staticBreakawayFrictionN': 3,
      'coulombFrictionN': 2,
    },
  );
  PneumaticPipe pipe(String id, String a, String b) => PneumaticPipe(
    id: id,
    fromPortId: PneumaticPortId(a),
    toPortId: PneumaticPortId(b),
    lengthM: .2,
    innerDiameterM: .003,
    lossCoefficient: 1,
  );
  final ElectropneumaticLink y1 = ElectropneumaticLink(
    id: 'y1-to-valve',
    electricalComponentId: 'y1',
    pneumaticDeviceId: 'valve',
    role: ElectropneumaticLinkRole.solenoidCoil,
  );
  return MultiphysicsProject(
    electricalCircuit: circuit,
    pneumaticNetwork: PneumaticNetwork(
      devices: <PneumaticDevice>[
        boundary('air', PneumaticDeviceKind.idealSource, 701325),
        boundary('outR', PneumaticDeviceKind.silencer, 101325),
        boundary('outS', PneumaticDeviceKind.silencer, 101325),
        valve,
        cylinder,
      ],
      pipes: <PneumaticPipe>[
        pipe('P', 'air.1', 'valve.P'),
        pipe('A', 'valve.A', 'cylinder.A'),
        pipe('B', 'valve.B', 'cylinder.B'),
        pipe('R', 'valve.R', 'outR.1'),
        pipe('S', 'valve.S', 'outS.1'),
      ],
    ),
    devices: <PhysicalDeviceRecord>[
      PhysicalDeviceRecord(id: 'source', pneumaticDeviceId: 'air'),
      PhysicalDeviceRecord(
        id: 'valve',
        pneumaticDeviceId: 'valve',
        electricalComponentIds: <String>['y1'],
      ),
      PhysicalDeviceRecord(
        id: 'cylinder',
        pneumaticDeviceId: 'cylinder',
        electricalComponentIds: <String>['b1'],
      ),
      PhysicalDeviceRecord(id: 'exhaust-r', pneumaticDeviceId: 'outR'),
      PhysicalDeviceRecord(id: 'exhaust-s', pneumaticDeviceId: 'outS'),
    ],
    links: <ElectropneumaticLink>[
      y1,
      ElectropneumaticLink(
        id: 'b1-to-cylinder',
        electricalComponentId: 'b1',
        pneumaticDeviceId: 'cylinder',
        role: ElectropneumaticLinkRole.positionContact,
      ),
    ],
  );
}
