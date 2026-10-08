import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CORE-ISLAND01 PV workspace resolves standalone battery + 48 V lamp as DC', () {
    final Terminal bp = Terminal(
      id: TerminalId('bat-pos'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal bn = Terminal(
      id: TerminalId('bat-neg'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal la = Terminal(id: TerminalId('lamp-a'), name: 'A');
    final Terminal lb = Terminal(id: TerminalId('lamp-b'), name: 'B');

    final F9PaletteDefinition battery = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'pv-battery',
    );
    final F9PaletteDefinition lamp = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'lamp-dc-48v',
    );
    expect(battery.supportsMode(ElectricalMode.dc), isTrue);
    expect(battery.supportsMode(ElectricalMode.pv), isTrue);
    expect(lamp.supportsMode(ElectricalMode.pv), isTrue);

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('pv-workspace-autonomous-battery'),
      revision: 0,
      mode: ElectricalMode.pv,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('battery'),
          modelType: battery.modelType,
          terminals: <Terminal>[bp, bn],
          parameters: battery.defaultParameters,
        ),
        ComponentInstance(
          id: ComponentId('lamp'),
          modelType: lamp.modelType,
          terminals: <Terminal>[la, lb],
          parameters: lamp.defaultParameters,
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: bp.id,
          toTerminalId: la.id,
          phase: PhaseTag.dcPositive,
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: lb.id,
          toTerminalId: bn.id,
          phase: PhaseTag.dcNegative,
        ),
      ],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.dc);
    expect(snapshot.solved, isTrue);
    expect(snapshot.effectiveCircuit.mode, ElectricalMode.dc);
    final ComponentOperatingState state =
        snapshot.componentOperatingState(ComponentId('lamp'))!;
    expect(state.voltageV, closeTo(47.92, 0.05));
    expect(state.currentA, closeTo(0.998, 0.01));
  });
}
