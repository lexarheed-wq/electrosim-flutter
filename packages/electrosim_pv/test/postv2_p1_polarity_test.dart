import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverPV solver = SolverPV();
  const TopologyEngine topologyEngine = TopologyEngine();

  PvSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('Post-V2 P1.4 polarized PV equipment', () {
    test('P1-PV-INVERTER correct DC polarity solves', () {
      final PvSolveResult result = solve(_directPv(reverseDcInput: false));
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterOutputPowerW, greaterThan(0.0));
    });

    test('P1-PV-INVERTER reversed DC input is diagnosed, not silently solved', () {
      final PvSolveResult result = solve(_directPv(reverseDcInput: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.dcInputDisconnected),
      );
    });

    test('P1-PV-STORAGE correct controller/battery polarity solves', () {
      final PvSolveResult result = solve(_storagePv());
      expect(result.status, PvSolveStatus.solved);
      expect(result.controllerPresent, isTrue);
      expect(result.batteryPresent, isTrue);
    });

    test('P1-PV-CONTROLLER reversed PV input is explicit invalid topology', () {
      final PvSolveResult result = solve(_storagePv(reverseControllerInput: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.storageTopologyInvalid),
      );
    });

    test('P1-PV-CONTROLLER reversed DC output is explicit invalid topology', () {
      final PvSolveResult result = solve(_storagePv(reverseControllerOutput: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.storageTopologyInvalid),
      );
    });

    test('P1-PV-BATTERY reversed battery bus is explicit invalid topology', () {
      final PvSolveResult result = solve(_storagePv(reverseBattery: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.storageTopologyInvalid),
      );
    });
  });
}

CircuitState _directPv({required bool reverseDcInput}) {
  final SourceInstance array = _array('pv');
  final ComponentInstance inverter = _inverter('inv', dcMin: 300, dcMax: 500);
  final ComponentInstance load = _load('load');

  return CircuitState(
    circuitId: CircuitId('p1-pv-direct-$reverseDcInput'),
    revision: 0,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[array],
    components: <ComponentInstance>[inverter, load],
    connections: <Connection>[
      _w(
        'dc1',
        'pv-pos',
        reverseDcInput ? 'inv-dc-neg' : 'inv-dc-pos',
      ),
      _w(
        'dc2',
        'pv-neg',
        reverseDcInput ? 'inv-dc-pos' : 'inv-dc-neg',
      ),
      _w('ac1', 'inv-l', 'load-l'),
      _w('ac2', 'inv-n', 'load-n'),
    ],
    settings: const <String, Object?>{
      'irradianceWm2': 1000.0,
      'shadingPct': 0.0,
      'cellTemperatureC': 25.0,
    },
  );
}

CircuitState _storagePv({
  bool reverseControllerInput = false,
  bool reverseControllerOutput = false,
  bool reverseBattery = false,
}) {
  final SourceInstance array = _array('pv');
  final ComponentInstance controller = ComponentInstance(
    id: ComponentId('controller'),
    modelType: 'pv_controller',
    terminals: <Terminal>[
      _t('controller-pv-pos', 'PV+', PhaseTag.dcPositive, TerminalRole.positive),
      _t('controller-pv-neg', 'PV-', PhaseTag.dcNegative, TerminalRole.negative),
      _t('controller-bus-pos', 'BAT+', PhaseTag.dcPositive, TerminalRole.positive),
      _t('controller-bus-neg', 'BAT-', PhaseTag.dcNegative, TerminalRole.negative),
    ],
    parameters: const <String, Object?>{
      'outputVoltageV': 48.0,
      'maxOutputCurrentA': 60.0,
      'efficiency': 0.97,
    },
  );
  final ComponentInstance battery = ComponentInstance(
    id: ComponentId('battery'),
    modelType: 'pv_battery',
    terminals: <Terminal>[
      _t('battery-pos', '+', PhaseTag.dcPositive, TerminalRole.positive),
      _t('battery-neg', '-', PhaseTag.dcNegative, TerminalRole.negative),
    ],
    parameters: const <String, Object?>{
      'nominalVoltageV': 48.0,
      'capacityAh': 100.0,
      'initialSoc': 0.6,
      'minSoc': 0.1,
      'maxSoc': 0.95,
      'maxChargeCurrentA': 30.0,
      'maxDischargeCurrentA': 60.0,
      'chargeEfficiency': 0.95,
      'dischargeEfficiency': 0.95,
    },
  );
  final ComponentInstance inverter = _inverter('inv', dcMin: 40, dcMax: 60);
  final ComponentInstance load = _load('load');

  return CircuitState(
    circuitId: CircuitId(
      'p1-pv-storage-$reverseControllerInput-$reverseControllerOutput-$reverseBattery',
    ),
    revision: 0,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[array],
    components: <ComponentInstance>[controller, battery, inverter, load],
    connections: <Connection>[
      _w(
        'pv1',
        'pv-pos',
        reverseControllerInput ? 'controller-pv-neg' : 'controller-pv-pos',
      ),
      _w(
        'pv2',
        'pv-neg',
        reverseControllerInput ? 'controller-pv-pos' : 'controller-pv-neg',
      ),
      _w(
        'bus1',
        'controller-bus-pos',
        reverseControllerOutput ? 'inv-dc-neg' : 'inv-dc-pos',
      ),
      _w(
        'bus2',
        'controller-bus-neg',
        reverseControllerOutput ? 'inv-dc-pos' : 'inv-dc-neg',
      ),
      _w(
        'bat1',
        'battery-pos',
        reverseBattery ? 'inv-dc-neg' : 'inv-dc-pos',
      ),
      _w(
        'bat2',
        'battery-neg',
        reverseBattery ? 'inv-dc-pos' : 'inv-dc-neg',
      ),
      _w('ac1', 'inv-l', 'load-l'),
      _w('ac2', 'inv-n', 'load-n'),
    ],
    settings: const <String, Object?>{
      'irradianceWm2': 1000.0,
      'shadingPct': 0.0,
      'cellTemperatureC': 25.0,
    },
  );
}

SourceInstance _array(String id) => SourceInstance(
  id: SourceId(id),
  modelType: 'pv_array',
  terminals: <Terminal>[
    _t('${id}-pos', '+', PhaseTag.dcPositive, TerminalRole.positive),
    _t('${id}-neg', '-', PhaseTag.dcNegative, TerminalRole.negative),
  ],
  parameters: const <String, Object?>{
    'mppVoltageV': 360.0,
    'mppCurrentA': 10.0,
    'powerTemperatureCoefficientPerC': 0.0,
    'voltageTemperatureCoefficientPerC': 0.0,
  },
);

ComponentInstance _inverter(
  String id, {
  required double dcMin,
  required double dcMax,
}) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'pv_inverter',
  terminals: <Terminal>[
    _t('${id}-dc-pos', 'DC+', PhaseTag.dcPositive, TerminalRole.positive),
    _t('${id}-dc-neg', 'DC-', PhaseTag.dcNegative, TerminalRole.negative),
    _t('${id}-l', 'L', PhaseTag.l1, TerminalRole.line),
    _t('${id}-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
  ],
  parameters: <String, Object?>{
    'minDcVoltageV': dcMin,
    'maxDcVoltageV': dcMax,
    'nominalAcVoltageV': 230.0,
    'ratedAcPowerW': 3000.0,
    'efficiency': 0.96,
  },
);

ComponentInstance _load(String id) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'pv_resistive_load',
  terminals: <Terminal>[
    _t('${id}-l', 'L', PhaseTag.l1, TerminalRole.line),
    _t('${id}-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
  ],
  parameters: const <String, Object?>{'resistanceOhm': 52.9},
);

Terminal _t(String id, String name, PhaseTag phase, TerminalRole role) =>
    Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
  phase: PhaseTag.none,
);
