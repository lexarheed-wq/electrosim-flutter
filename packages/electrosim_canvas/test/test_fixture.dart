import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

CircuitState buildTestCircuit() {
  final Terminal sourcePositive = Terminal(
    id: TerminalId('src-pos'),
    name: '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = Terminal(
    id: TerminalId('src-neg'),
    name: '-',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal resistorIn = Terminal(
    id: TerminalId('res-in'),
    name: 'A',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal resistorOut = Terminal(
    id: TerminalId('res-out'),
    name: 'B',
    role: TerminalRole.output,
    phase: PhaseTag.dcNegative,
  );
  return CircuitState(
    circuitId: CircuitId('canvas-test'),
    revision: 3,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source'),
        modelType: 'DC source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('resistor'),
        modelType: 'Resistor',
        terminals: <Terminal>[resistorIn, resistorOut],
        parameters: const <String, Object?>{'resistanceOhm': 12.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('wire-a'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: resistorIn.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-b'),
        fromTerminalId: resistorOut.id,
        toTerminalId: sourceNegative.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
  );
}

CircuitVisualLayout buildTestLayout() => CircuitVisualLayout(
  elementPositions: const <String, Offset>{
    'source': Offset(100, 120),
    'resistor': Offset(320, 120),
  },
  wireRoutes: const <String, List<Offset>>{
    'wire-a': <Offset>[Offset(210, 80)],
    'wire-b': <Offset>[Offset(210, 180)],
  },
);
