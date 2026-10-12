import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'g5_lot_06_15_fixtures.dart' as old;

const lastLotAndMeterKeys = [
  'external-refrigerator',
  'external-refrigerator-dc',
  'external-tv',
  'external-fan-ac1',
  'external-fan-3p',
  'pv-resistive-load',
  'source-ac3-grid',
  'source-ac3-alternator',
  'load-wye-3p',
  'load-delta-3p',
  'impedance',
  'energy-meter-ac1',
  'energy-meter-ac3',
  'energy-meter-pv',
];
Terminal port(String id, String name, PhaseTag phase) =>
    Terminal(id: TerminalId(id), name: name, phase: phase);
Connection link(String id, String a, String b, PhaseTag phase) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
  phase: phase,
);
List<Terminal> definitionPorts(F9PaletteDefinition d, String id) => [
  for (var i = 0; i < d.terminalCount; i++)
    Terminal(
      id: TerminalId('$id:$i'),
      name: d.terminalLabels.isNotEmpty
          ? d.terminalLabels[i]
          : d.terminals[i].label,
      role: d.terminals.isNotEmpty ? d.terminals[i].role : TerminalRole.generic,
      phase: d.terminals.isNotEmpty
          ? d.terminals[i].phase
          : i == 0
          ? (d.visualVariant == 'refrigerator-dc'
                ? PhaseTag.dcPositive
                : PhaseTag.l1)
          : (d.visualVariant == 'refrigerator-dc'
                ? PhaseTag.dcNegative
                : PhaseTag.neutral),
    ),
];
CircuitState lastLotFixture(
  NativeApplianceGeometry s, {
  bool reverseMeter = false,
}) {
  final d = f9PaletteCatalog.singleWhere((d) => d.keyName == s.key);
  if (s.threePhase) return old.lotFixture(s);
  final meter = s.key.startsWith('energy-meter-');
  final source = d.kind == F9PaletteElementKind.source;
  final pv = s.key == 'pv-resistive-load' || s.key == 'energy-meter-pv';
  final dc = s.key == 'external-refrigerator-dc';
  final ac3 =
      source ||
      s.key == 'load-wye-3p' ||
      s.key == 'load-delta-3p' ||
      s.key == 'energy-meter-ac3';
  final phases = ac3
      ? [PhaseTag.l1, PhaseTag.l2, PhaseTag.l3, PhaseTag.neutral]
      : dc
      ? [PhaseTag.dcPositive, PhaseTag.dcNegative]
      : [PhaseTag.l1, PhaseTag.neutral];
  final params = {
    ...d.defaultParameters,
    if (d.visualModelType != null) '_visualModelType': d.visualModelType,
    '_visualVariant': s.variant,
    '_displayLabel': d.displayLabel ?? d.title,
  };
  final target = ComponentInstance(
    id: ComponentId(s.key),
    modelType: d.modelType,
    terminals: definitionPorts(d, s.key),
    parameters: params,
  );
  final feedIds = pv
      ? ['inv-l', 'inv-n']
      : [for (var i = 0; i < phases.length; i++) 'grid:$i'];
  final load = ComponentInstance(
    id: ComponentId('proof-load'),
    modelType: pv
        ? 'pv_resistive_load'
        : ac3
        ? 'load_wye_3p'
        : 'impedance',
    terminals: [
      for (var i = 0; i < phases.length; i++)
        port('proof-load:$i', phases[i].name, phases[i]),
    ],
    parameters: {
      'resistanceOhm': pv ? 52.9 : 46.0,
      'reactanceOhm': 0.0,
      'inductanceH': 0.0,
      '_visualVariant': 'proof-load',
    },
  );
  var c = CircuitState(
    circuitId: CircuitId(s.key),
    revision: 0,
    mode: pv
        ? ElectricalMode.pv
        : dc
        ? ElectricalMode.dc
        : ac3
        ? ElectricalMode.ac3
        : ElectricalMode.ac1,
    sources: pv
        ? [
            SourceInstance(
              id: SourceId('grid'),
              modelType: 'pv_array',
              terminals: [
                port('pv-pos', '+', PhaseTag.dcPositive),
                port('pv-neg', '−', PhaseTag.dcNegative),
              ],
              parameters: {
                'mppVoltageV': 400.0,
                'mppCurrentA': 10.0,
                'powerTemperatureCoefficientPerC': 0.0,
                'voltageTemperatureCoefficientPerC': 0.0,
              },
            ),
          ]
        : [
            SourceInstance(
              id: SourceId(source ? s.key : 'grid'),
              modelType: source
                  ? d.modelType
                  : dc
                  ? 'dc_voltage_source'
                  : ac3
                  ? 'ac3_voltage_source'
                  : 'ac_voltage_source',
              terminals: source
                  ? definitionPorts(d, s.key)
                  : [
                      for (var i = 0; i < phases.length; i++)
                        port(feedIds[i], phases[i].name, phases[i]),
                    ],
              parameters: source
                  ? params
                  : dc
                  ? {'voltageV': 24.0}
                  : ac3
                  ? {'phaseVoltageRmsV': 230.0}
                  : {'voltageRmsV': 230.0},
            ),
          ],
    components: [
      if (!source) target,
      if (meter || source) load,
      if (pv)
        ComponentInstance(
          id: ComponentId('inverter'),
          modelType: 'pv_inverter',
          terminals: [
            port('inv-pos', 'DC+', PhaseTag.dcPositive),
            port('inv-neg', 'DC−', PhaseTag.dcNegative),
            port('inv-l', 'L', PhaseTag.l1),
            port('inv-n', 'N', PhaseTag.neutral),
          ],
          parameters: {
            'minDcVoltageV': 300.0,
            'maxDcVoltageV': 500.0,
            'nominalAcVoltageV': 230.0,
            'ratedAcPowerW': 3500.0,
            'efficiency': .95,
          },
        ),
    ],
    connections: [
      if (pv) ...[
        link('pv-pos', 'pv-pos', 'inv-pos', PhaseTag.dcPositive),
        link('pv-neg', 'pv-neg', 'inv-neg', PhaseTag.dcNegative),
      ],
      for (
        var i = 0;
        i <
            (meter
                ? phases.length
                : source
                ? 4
                : target.terminals.length);
        i++
      )
        if (meter) ...[
          link(
            'in-$i',
            feedIds[i],
            '${s.key}:${i + (reverseMeter ? phases.length : 0)}',
            phases[i],
          ),
          link(
            'out-$i',
            '${s.key}:${i + (reverseMeter ? 0 : phases.length)}',
            'proof-load:$i',
            phases[i],
          ),
        ] else
          link(
            'supply-$i',
            source ? '${s.key}:$i' : feedIds[i],
            source ? 'proof-load:$i' : '${s.key}:$i',
            phases[i],
          ),
    ],
    settings: {
      'frequencyHz': 50.0,
      if (pv) 'irradianceWm2': 1000.0,
      if (pv) 'cellTemperatureC': 25.0,
    },
  );
  c = AppliancePowerConnection.addProtectiveEarth(c);
  final targetList = c.components.where((x) => x.id.value == s.key);
  if (targetList.isNotEmpty &&
      targetList.single.terminals.last.role == TerminalRole.protectiveEarth) {
    final j = c.toJson();
    j['connections'] = [
      ...c.connections.map((w) => w.toJson()),
      link(
        'pe',
        feedIds.last,
        targetList.single.terminals.last.id.value,
        PhaseTag.protectiveEarth,
      ).toJson(),
    ];
    c = CircuitState.fromJson(j);
  }
  if (s.key == 'external-refrigerator' || s.key == 'external-tv') {
    final j = c.toJson();
    j['components'] = [
      ...c.components.map((x) => x.toJson()),
      ComponentInstance(
        id: ComponentId('socket'),
        modelType: 'power_socket_ac',
        terminals: [
          for (var i = 0; i < 6; i++)
            port(
              'socket:$i',
              'socket:$i',
              i % 3 == 0
                  ? PhaseTag.l1
                  : i % 3 == 1
                  ? PhaseTag.neutral
                  : PhaseTag.protectiveEarth,
            ),
        ],
      ).toJson(),
    ];
    j['connections'] = [
      link('line', feedIds[0], 'socket:0', PhaseTag.l1).toJson(),
      link('neutral', feedIds[1], 'socket:1', PhaseTag.neutral).toJson(),
      link('earth', feedIds[1], 'socket:2', PhaseTag.protectiveEarth).toJson(),
    ];
    c = AppliancePowerConnection.configure(
      CircuitState.fromJson(j),
      s.key,
      'plug',
      socketId: 'socket',
    );
  }
  return c;
}

CircuitVisualLayout lastLotLayout(NativeApplianceGeometry s) =>
    CircuitVisualLayout(
      elementPositions: {
        'grid': const Offset(140, 150),
        'inverter': const Offset(390, 150),
        'socket': const Offset(230, 400),
        'proof-load': const Offset(230, 400),
        s.key: const Offset(680, 400),
      },
      elementSizes: {
        'grid': const Size(140, 160),
        'inverter': const Size(170, 120),
        'socket': const Size(130, 120),
        'proof-load': const Size(155, 140),
        s.key: s.boardSize,
      },
    );
