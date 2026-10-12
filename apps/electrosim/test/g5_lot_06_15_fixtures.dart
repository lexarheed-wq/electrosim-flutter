import 'dart:ui';
import 'dart:convert';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'g5_lot_06_15_geometry_test.dart' as machines;

CircuitState lotFixture(NativeApplianceGeometry s) {
  final d = f9PaletteCatalog.singleWhere((d) => d.keyName == s.key);
  if (s.threePhase) {
    final j =
        jsonDecode(jsonEncode(machines.machineFixture(s).toJson()))
            as Map<String, dynamic>;
    final c = (j['components'] as List).single as Map<String, dynamic>;
    c['id'] = s.key;
    for (final wire in j['connections'] as List) {
      wire['phase'] = switch (wire['id']) {
        'a' => 'l1',
        'b' => 'l2',
        'c' => 'l3',
        'pe' => 'protectiveEarth',
        _ => 'none',
      };
    }
    c['parameters'] = {
      ...(c['parameters'] as Map<String, dynamic>),
      ...d.defaultParameters,
      '_displayLabel': d.displayLabel ?? d.title,
    };
    return CircuitState.fromJson(j);
  }
  final dc = s.key == 'external-solar-pump';
  final mobile = [
    'external-iron',
    'external-computer',
    'external-freezer',
  ].contains(s.key);
  Terminal t(String id) => Terminal(id: TerminalId(id), name: id);
  Connection w(String id, String a, String b) => Connection(
    id: ConnectionId(id),
    fromTerminalId: TerminalId(a),
    toTerminalId: TerminalId(b),
    phase: id == 'line'
        ? (dc ? PhaseTag.dcPositive : PhaseTag.l1)
        : id == 'neutral'
        ? (dc ? PhaseTag.dcNegative : PhaseTag.neutral)
        : PhaseTag.protectiveEarth,
  );
  var circuit = CircuitState(
    circuitId: CircuitId(s.key),
    revision: 0,
    mode: dc ? ElectricalMode.dc : ElectricalMode.ac1,
    sources: [
      SourceInstance(
        id: SourceId('grid'),
        modelType: dc ? 'dc_voltage_source' : 'ac_voltage_source',
        terminals: [t('L'), t('N')],
        parameters: dc ? {'voltageV': 24.0} : {'voltageRmsV': 230.0},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId(s.key),
        modelType: d.modelType,
        terminals: [
          Terminal(id: TerminalId('load-l'), name: dc ? '+' : 'L'),
          Terminal(id: TerminalId('load-n'), name: dc ? '−' : 'N'),
        ],
        parameters: {
          ...d.defaultParameters,
          '_displayLabel': d.displayLabel ?? d.title,
          '_visualModelType': s.visualType,
          '_visualVariant': s.variant,
        },
      ),
      if (mobile)
        ComponentInstance(
          id: ComponentId('socket'),
          modelType: 'power_socket_ac',
          terminals: [
            for (final id in ['li', 'ni', 'pei', 'lo', 'no', 'peo']) t(id),
          ],
        ),
    ],
    connections: mobile
        ? [
            w('line', 'L', 'li'),
            w('neutral', 'N', 'ni'),
            w('earth-bond', 'N', 'pei'),
          ]
        : [w('line', 'L', 'load-l'), w('neutral', 'N', 'load-n')],
    settings: {'frequencyHz': 50.0},
  );
  circuit = AppliancePowerConnection.addProtectiveEarth(circuit);
  if (mobile) {
    return AppliancePowerConnection.configure(
      circuit,
      s.key,
      'plug',
      socketId: 'socket',
    );
  }
  if (!dc) {
    final json = circuit.toJson();
    json['connections'] = [
      ...circuit.connections.map((w) => w.toJson()),
      w('pe', 'N', circuit.components.first.terminals.last.id.value).toJson(),
    ];
    circuit = CircuitState.fromJson(json);
  }
  return circuit;
}

CircuitVisualLayout lotLayout(NativeApplianceGeometry s) => CircuitVisualLayout(
  elementPositions: {
    'grid': const Offset(130, 140),
    'socket': const Offset(175, 400),
    s.key: const Offset(610, 390),
  },
  elementSizes: {
    'grid': const Size(140, 160),
    'socket': const Size(130, 120),
    s.key: s.boardSize,
  },
);
