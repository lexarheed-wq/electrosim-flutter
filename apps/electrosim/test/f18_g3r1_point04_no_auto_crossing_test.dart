import 'dart:io';

import 'package:electrosim/f18_workspace_wire_safety.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

Terminal _terminal(String id) =>
    Terminal(id: TerminalId(id), name: id, role: TerminalRole.input);

ComponentInstance _component(String id, Terminal terminal) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'test',
  terminals: <Terminal>[terminal],
);

String _workspaceSource() =>
    File('lib/f18_workspace_page.dart').readAsStringSync();

void main() {
  test('workspace no longer rejects valid wiring only because nets cross', () {
    final String source = _workspaceSource();
    expect(
      source,
      isNot(
        contains(
          'Connexion refusée : aucun routage automatique sans croisement',
        ),
      ),
    );
    expect(source, contains('F18WorkspaceWireSafety.isRenderable'));
  });

  test(
    'different-net orthogonal crossing remains renderable as non-junction',
    () {
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
        F18WorkspaceWireSafety.isRenderable(circuit: circuit, layout: layout),
        isTrue,
      );
      final WireSemantics semantics = const WireSemanticsAnalyzer().analyze(
        circuit: circuit,
        layout: layout,
      );
      expect(semantics.nonJunctionCrossings, isNotEmpty);
    },
  );
}
