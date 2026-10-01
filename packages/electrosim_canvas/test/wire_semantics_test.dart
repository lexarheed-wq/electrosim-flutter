import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

Terminal _terminal(String id) => Terminal(
  id: TerminalId(id),
  name: id,
  role: TerminalRole.bidirectional,
);

ComponentInstance _node(String id, String terminalId) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'Node',
  terminals: <Terminal>[_terminal(terminalId)],
);

void main() {
  const WireSemanticsAnalyzer analyzer = WireSemanticsAnalyzer();

  test('detects a manual non-junction crossing', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('crossing'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _node('a', 'ta'),
        _node('b', 'tb'),
        _node('c', 'tc'),
        _node('d', 'td'),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('h'),
          fromTerminalId: TerminalId('ta'),
          toTerminalId: TerminalId('tb'),
        ),
        Connection(
          id: ConnectionId('v'),
          fromTerminalId: TerminalId('tc'),
          toTerminalId: TerminalId('td'),
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'a': Offset(48, 120),
        'b': Offset(300, 120),
        'c': Offset(174, 20),
        'd': Offset(174, 220),
      },
    );

    final WireSemantics semantics = analyzer.analyze(
      circuit: circuit,
      layout: layout,
    );

    expect(semantics.nonJunctionCrossings, hasLength(1));
    expect(
      semantics.nonJunctionCrossings.single.point,
      const Offset(226, 120),
    );
    expect(semantics.junctionTerminalIds, isEmpty);
  });

  test('shared terminal is an explicit electrical junction, not a crossing', () {
    final Terminal junction = _terminal('junction');
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('junction'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _node('a', 'ta'),
        ComponentInstance(
          id: ComponentId('j'),
          modelType: 'Junction',
          terminals: <Terminal>[junction],
        ),
        _node('b', 'tb'),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('a-j'),
          fromTerminalId: TerminalId('ta'),
          toTerminalId: junction.id,
        ),
        Connection(
          id: ConnectionId('b-j'),
          fromTerminalId: TerminalId('tb'),
          toTerminalId: junction.id,
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'a': Offset(48, 120),
        'j': Offset(200, 120),
        'b': Offset(352, 120),
      },
    );

    final WireSemantics semantics = analyzer.analyze(
      circuit: circuit,
      layout: layout,
    );

    expect(semantics.junctionTerminalIds, contains(junction.id));
    expect(semantics.nonJunctionCrossings, isEmpty);
  });
}
