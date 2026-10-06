import 'package:electrosim/f9_wiring_policy.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P1.2 UI accepts + to - across two distinct DC sources', () {
    final CircuitState circuit = _twoSourceCircuit();
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
      circuit,
      TerminalId('v1p'),
      TerminalId('v2n'),
    );

    expect(decision.accepted, isTrue);
    expect(decision.connection, isNotNull);
    expect(decision.connection!.phase, PhaseTag.none);
  });

  test('P1.2 UI does not silently forbid a direct DC source short', () {
    final CircuitState circuit = _twoSourceCircuit();
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
      circuit,
      TerminalId('v1p'),
      TerminalId('v1n'),
    );

    expect(decision.accepted, isTrue);
    expect(decision.connection, isNotNull);
    expect(decision.connection!.phase, PhaseTag.none);
  });

  test(
    'P1.2 UI rejects only structural invalidity, not electrical polarity',
    () {
      final CircuitState circuit = _twoSourceCircuit();

      expect(
        F9WiringPolicy.evaluateAndBuild(
          circuit,
          TerminalId('v1p'),
          TerminalId('v1p'),
        ).accepted,
        isFalse,
      );

      expect(
        F9WiringPolicy.evaluateAndBuild(
          circuit,
          TerminalId('missing'),
          TerminalId('v1p'),
        ).accepted,
        isFalse,
      );
    },
  );
}

CircuitState _twoSourceCircuit() => CircuitState(
  circuitId: CircuitId('p1-wiring-policy'),
  revision: 0,
  mode: ElectricalMode.dc,
  sources: <SourceInstance>[_source('v1'), _source('v2')],
);

SourceInstance _source(String id) => SourceInstance(
  id: SourceId(id),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    Terminal(
      id: TerminalId('${id}p'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    Terminal(
      id: TerminalId('${id}n'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
  ],
  parameters: const <String, Object?>{'voltageV': 12.0},
);
