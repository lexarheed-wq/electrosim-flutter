import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/runtime/electrosim_runtime_engine.dart';

void main() {
  test('severe receiver stress becomes an electrical open in the same tick', () {
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
  });
}
