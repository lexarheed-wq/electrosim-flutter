import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/runtime/electrosim_runtime_engine.dart';

void main() {
  test(
    'severe receiver stress becomes an electrical open in the same tick',
    () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('core-unify-health'),
        revision: 0,
        mode: ElectricalMode.dc,
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('v1'),
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
                name: '−',
                role: TerminalRole.negative,
                phase: PhaseTag.dcNegative,
              ),
            ],
            parameters: const <String, Object?>{'voltageV': 216.0},
          ),
        ],
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('lamp-1'),
            modelType: 'lamp',
            terminals: <Terminal>[
              Terminal(id: TerminalId('la'), name: 'A'),
              Terminal(id: TerminalId('lb'), name: 'B'),
            ],
            parameters: const <String, Object?>{
              ComponentParameterKeys.resistanceOhm: 24.0,
              ReceiverNominalRating.voltageKey: 24.0,
              ReceiverNominalRating.currentKey: 1.0,
              ReceiverNominalRating.powerKey: 24.0,
              ComponentParameterKeys.thermalWithstandSeconds: 0.5,
            },
          ),
        ],
        connections: <Connection>[
          Connection(
            id: ConnectionId('p'),
            fromTerminalId: TerminalId('vp'),
            toTerminalId: TerminalId('la'),
          ),
          Connection(
            id: ConnectionId('n'),
            fromTerminalId: TerminalId('lb'),
            toTerminalId: TerminalId('vn'),
          ),
        ],
      );

      const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
      final ElectroSimRuntimeSnapshot snapshot = engine.advance(
        circuit,
        elapsed: const Duration(milliseconds: 100),
      );

      expect(
        snapshot.componentHealthState(ComponentId('lamp-1')).code,
        ComponentHealthCode.failedOpen,
      );
      expect(
        snapshot.effectiveCircuit.components.single.condition,
        ComponentCondition.openCircuit,
      );
      expect(
        snapshot.componentOperatingState(ComponentId('lamp-1'))?.code,
        ComponentOperatingCode.faulted,
      );
      expect(snapshot.dc.branch('component:lamp-1').currentA, 0.0);
    },
  );

  test('24 V direct LED is solved, overstressed and fails open', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('core-unify-led-health'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v-led'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('led-vp'),
              name: '+',
              role: TerminalRole.positive,
              phase: PhaseTag.dcPositive,
            ),
            Terminal(
              id: TerminalId('led-vn'),
              name: '−',
              role: TerminalRole.negative,
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('led-1'),
          modelType: 'diode',
          terminals: <Terminal>[
            Terminal(id: TerminalId('led-a'), name: 'A'),
            Terminal(id: TerminalId('led-k'), name: 'K'),
          ],
          parameters: const <String, Object?>{
            '_visualVariant': 'led-red',
            ComponentParameterKeys.forwardVoltageV: 2.0,
            ComponentParameterKeys.seriesResistanceOhm: 5.0,
            ComponentParameterKeys.reverseBreakdownVoltageV: 5.0,
            ComponentParameterKeys.maxVoltageV: 3.0,
            ComponentParameterKeys.maxCurrentA: 0.020,
            ComponentParameterKeys.maxPowerW: 0.060,
            ComponentParameterKeys.thermalWithstandSeconds: 0.050,
          },
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('led-p'),
          fromTerminalId: TerminalId('led-vp'),
          toTerminalId: TerminalId('led-a'),
        ),
        Connection(
          id: ConnectionId('led-n'),
          fromTerminalId: TerminalId('led-k'),
          toTerminalId: TerminalId('led-vn'),
        ),
      ],
    );

    const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot snapshot = engine.advance(
      circuit,
      elapsed: const Duration(milliseconds: 100),
    );

    expect(snapshot.solved, isTrue);
    expect(
      snapshot.componentHealthState(ComponentId('led-1')).code,
      ComponentHealthCode.failedOpen,
    );
    expect(
      snapshot.effectiveCircuit.components.single.condition,
      ComponentCondition.openCircuit,
    );
    expect(snapshot.dc.branch('component:led-1').currentA, 0.0);
  });
}
