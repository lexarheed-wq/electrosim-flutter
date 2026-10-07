import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  F9PaletteDefinition definition(String key) =>
      f9PaletteCatalog.firstWhere((F9PaletteDefinition item) => item.keyName == key);

  test('AC1 palette uses canonical breaker calibre and dedicated 230 V lamp', () {
    final F9PaletteDefinition breaker = definition('breaker-ac1');
    final F9PaletteDefinition lamp = definition('lamp-ac1-230v');

    expect(
      breaker.defaultParameters[ProtectionRating.ratedCurrentKey],
      10.0,
    );
    expect(breaker.defaultParameters.containsKey('ratedCurrentA'), isFalse);
    expect(lamp.supportsMode(ElectricalMode.ac1), isTrue);
    expect(definition('lamp').supportsMode(ElectricalMode.ac1), isFalse);
    expect(
      lamp.defaultParameters[ReceiverNominalRating.voltageKey],
      230.0,
    );
    expect(
      lamp.defaultParameters[ReceiverNominalRating.powerKey],
      100.0,
    );
  });

  test('AC1 source-breaker-lamp circuit resolves with physical values', () {
    final F9PaletteDefinition breaker = definition('breaker-ac1');
    final F9PaletteDefinition lamp = definition('lamp-ac1-230v');

    final Terminal sourceL = Terminal(
      id: TerminalId('source-l'),
      name: 'L',
      role: TerminalRole.line,
      phase: PhaseTag.l1,
    );
    final Terminal sourceN = Terminal(
      id: TerminalId('source-n'),
      name: 'N',
      role: TerminalRole.neutral,
      phase: PhaseTag.neutral,
    );
    final Terminal breakerL = Terminal(id: TerminalId('breaker-l'), name: 'L');
    final Terminal breakerT = Terminal(id: TerminalId('breaker-t'), name: 'T');
    final Terminal lampA = Terminal(id: TerminalId('lamp-a'), name: 'A');
    final Terminal lampB = Terminal(id: TerminalId('lamp-b'), name: 'B');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('ac1-palette-regression'),
      revision: 0,
      mode: ElectricalMode.ac1,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source'),
          modelType: 'ac_voltage_source',
          terminals: <Terminal>[sourceL, sourceN],
          parameters: const <String, Object?>{
            'voltageRmsV': 230.0,
            'phaseDeg': 0.0,
          },
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('breaker'),
          modelType: breaker.modelType,
          terminals: <Terminal>[breakerL, breakerT],
          parameters: breaker.defaultParameters,
          controlState: breaker.defaultControlState,
        ),
        ComponentInstance(
          id: ComponentId('lamp'),
          modelType: lamp.modelType,
          terminals: <Terminal>[lampA, lampB],
          parameters: lamp.defaultParameters,
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: sourceL.id,
          toTerminalId: breakerL.id,
          phase: PhaseTag.l1,
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: breakerT.id,
          toTerminalId: lampA.id,
          phase: PhaseTag.l1,
        ),
        Connection(
          id: ConnectionId('w3'),
          fromTerminalId: lampB.id,
          toTerminalId: sourceN.id,
          phase: PhaseTag.neutral,
        ),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac1);
    expect(snapshot.solved, isTrue);
    final ComponentOperatingState lampState =
        snapshot.componentOperatingState(ComponentId('lamp'))!;
    expect(lampState.voltageV, closeTo(230.0, 1e-6));
    expect(lampState.currentA, closeTo(230.0 / 529.0, 1e-6));
    expect(lampState.powerW, closeTo(100.0, 0.2));
  });
}
