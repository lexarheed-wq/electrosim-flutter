import 'package:electrosim_domain/electrosim_domain.dart';

/// Historical UI regression fixture kept strictly inside the test tree.
///
/// Product workspaces start blank. This fixture exists only so visual and
/// interaction regression tests can exercise a deterministic non-empty board
/// without reintroducing obsolete product schemas.
CircuitState buildRegressionFixtureCircuit() {
  final Terminal sourcePositive = Terminal(
    id: TerminalId('source-pos'),
    name: '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = Terminal(
    id: TerminalId('source-neg'),
    name: '−',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal switchIn = Terminal(
    id: TerminalId('switch-in'),
    name: '1',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal switchOut = Terminal(
    id: TerminalId('switch-out'),
    name: '2',
    role: TerminalRole.output,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampIn = Terminal(
    id: TerminalId('lamp-in'),
    name: 'A',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampOut = Terminal(
    id: TerminalId('lamp-out'),
    name: 'B',
    role: TerminalRole.output,
    phase: PhaseTag.dcNegative,
  );

  return CircuitState(
    circuitId: CircuitId('regression-fixture'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-24v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('switch-1'),
        modelType: 'switch',
        terminals: <Terminal>[switchIn, switchOut],
        controlState: const <String, Object?>{'closed': true},
      ),
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'lamp',
        terminals: <Terminal>[lampIn, lampOut],
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
        id: ConnectionId('wire-1'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: switchIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-2'),
        fromTerminalId: switchOut.id,
        toTerminalId: lampIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-3'),
        fromTerminalId: lampOut.id,
        toTerminalId: sourceNegative.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
    metadata: const <String, Object?>{'scope': 'test-regression-only'},
  );
}
