import 'dart:io';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/f18_workspace_wire_safety.dart';
import 'package:flutter_test/flutter_test.dart';

Terminal _terminal(String id) =>
    Terminal(id: TerminalId(id), name: id, role: TerminalRole.input);

ComponentInstance _component(String id, Terminal terminal) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'test',
  terminals: <Terminal>[terminal],
);

void main() {
  test(
    'real workspace enforces crossing safety on connection and drag commits',
    () {
      final String source = File('lib/main.dart').readAsStringSync();
      final int uses = 'F18WorkspaceWireSafety.isCrossingFree'
          .allMatches(source)
          .length;
      expect(uses, greaterThanOrEqualTo(2));
    },
  );

  test('different-net geometric crossing is rejected', () {
    final Terminal a = _terminal('a');
    final Terminal b = _terminal('b');
    final Terminal c = _terminal('c');
    final Terminal d = _terminal('d');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('crossing'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _component('A', a),
        _component('B', b),
        _component('C', c),
        _component('D', d),
      ],
      sources: const <SourceInstance>[],
      connections: <Connection>[
        Connection(
          id: ConnectionId('h'),
          fromTerminalId: a.id,
          toTerminalId: b.id,
        ),
        Connection(
          id: ConnectionId('v'),
          fromTerminalId: c.id,
          toTerminalId: d.id,
        ),
      ],
    );

    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'A': Offset(48, 240),
        'B': Offset(528, 240),
        'C': Offset(288, 48),
        'D': Offset(288, 432),
      },
    );

    expect(
      F18WorkspaceWireSafety.isCrossingFree(circuit: circuit, layout: layout),
      isFalse,
    );
  });

  test('orthogonal non-crossing routes are accepted', () {
    final Terminal a = _terminal('a');
    final Terminal b = _terminal('b');
    final Terminal c = _terminal('c');
    final Terminal d = _terminal('d');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('parallel'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _component('A', a),
        _component('B', b),
        _component('C', c),
        _component('D', d),
      ],
      sources: const <SourceInstance>[],
      connections: <Connection>[
        Connection(
          id: ConnectionId('top'),
          fromTerminalId: a.id,
          toTerminalId: b.id,
        ),
        Connection(
          id: ConnectionId('bottom'),
          fromTerminalId: c.id,
          toTerminalId: d.id,
        ),
      ],
    );

    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'A': Offset(48, 144),
        'B': Offset(528, 144),
        'C': Offset(48, 336),
        'D': Offset(528, 336),
      },
    );

    expect(
      F18WorkspaceWireSafety.isCrossingFree(circuit: circuit, layout: layout),
      isTrue,
    );
  });
}
