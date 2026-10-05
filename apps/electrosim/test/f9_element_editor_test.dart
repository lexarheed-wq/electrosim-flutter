import 'package:electrosim/f9_element_editor.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('describes and toggles a switch without changing topology', () {
    final CircuitState circuit = _circuit();
    final F9ElementDetails? details = F9ElementEditor.describe(
      circuit,
      'switch-1',
    );
    expect(details, isNotNull);
    expect(details!.primaryToggleValue, isTrue);

    final CircuitState next = F9ElementEditor.togglePrimaryState(
      circuit,
      'switch-1',
    );
    expect(next.revision, circuit.revision + 1);
    expect(next.connections, circuit.connections);
    expect(
      F9ElementEditor.describe(next, 'switch-1')!.primaryToggleValue,
      isFalse,
    );
  });

  test('toggles a source enabled state explicitly', () {
    final CircuitState circuit = _circuit();
    final CircuitState next = F9ElementEditor.togglePrimaryState(
      circuit,
      'source-24v',
    );
    expect(next.sources.single.enabled, isFalse);
    expect(next.revision, circuit.revision + 1);
  });

  test(
    'replaces a component while preserving id, terminals and connections',
    () {
      final CircuitState circuit = _circuit();
      final CircuitState next = F9ElementEditor.replaceComponent(
        circuit,
        'switch-1',
        modelType: 'Résistance',
        parameters: const <String, Object?>{'resistanceOhm': 100.0},
      );
      expect(next.revision, circuit.revision + 1);
      final ComponentInstance replaced = next.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'switch-1',
      );
      expect(replaced.modelType, 'Résistance');
      expect(
        replaced.terminals.map((Terminal item) => item.id),
        circuit.components.first.terminals.map((Terminal item) => item.id),
      );
      expect(next.connections, circuit.connections);
    },
  );

  test('deleting an element also removes only its attached connections', () {
    final CircuitState circuit = _circuit();
    final CircuitState next = F9ElementEditor.deleteElement(circuit, 'lamp-1');
    expect(
      next.components.map((ComponentInstance item) => item.id.value),
      <String>['switch-1'],
    );
    expect(next.connections.map((Connection item) => item.id.value), <String>[
      'wire-1',
    ]);
    expect(next.sources.single.id.value, 'source-24v');
    expect(next.revision, circuit.revision + 1);
  });

  test('describes a wire as a first-class selectable connection', () {
    final CircuitState circuit = _circuit();
    final F9ElementDetails? details = F9ElementEditor.describe(
      circuit,
      'wire-2',
    );
    expect(details, isNotNull);
    expect(details!.kind, F9ElementKind.connection);
    expect(details.modelType, 'wire');
    expect(details.terminalLabels, <String>['switch-out', 'lamp-in']);
    expect(details.stateLabel, 'raccordé');
  });

  test('deleting a selected wire removes only that connection', () {
    final CircuitState circuit = _circuit();
    final CircuitState next = F9ElementEditor.deleteConnection(
      circuit,
      'wire-2',
    );
    expect(next.connections.map((Connection item) => item.id.value), <String>[
      'wire-1',
      'wire-3',
    ]);
    expect(next.components, circuit.components);
    expect(next.sources, circuit.sources);
    expect(next.revision, circuit.revision + 1);
  });

  test('unknown element is a no-op', () {
    final CircuitState circuit = _circuit();
    expect(F9ElementEditor.describe(circuit, 'missing'), isNull);
    expect(
      identical(F9ElementEditor.deleteElement(circuit, 'missing'), circuit),
      isTrue,
    );
    expect(
      identical(F9ElementEditor.deleteConnection(circuit, 'missing'), circuit),
      isTrue,
    );
    expect(
      identical(
        F9ElementEditor.togglePrimaryState(circuit, 'missing'),
        circuit,
      ),
      isTrue,
    );
  });
}

CircuitState _circuit() {
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
    circuitId: CircuitId('editor-test'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-24v'),
        modelType: 'DC 24 V',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('switch-1'),
        modelType: 'Interrupteur',
        terminals: <Terminal>[switchIn, switchOut],
        controlState: const <String, Object?>{'closed': true},
      ),
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'Lampe',
        terminals: <Terminal>[lampIn, lampOut],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
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
  );
}
