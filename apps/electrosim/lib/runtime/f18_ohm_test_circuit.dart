import 'package:electrosim_domain/electrosim_domain.dart';

/// Constructs a disposable DC test circuit, without editing the saved board.
abstract final class F18OhmTestCircuit {
  static const double referenceOhm = 1000;
  static const double testVoltageV = 1;
  static const supported = <String>{'resistor', 'lamp', 'switch', 'switch_spst'};

  static CircuitState? build(CircuitState circuit, TerminalId a, TerminalId b) {
    if (circuit.sources.isNotEmpty ||
        circuit.components.any((e) => !supported.contains(e.modelType.toLowerCase()))) {
      return null;
    }
    final terminals = <TerminalId>{
      for (final e in circuit.components)
        for (final t in e.terminals) t.id,
    };
    if (!terminals.contains(a) || !terminals.contains(b)) return null;
    final ids = <String>{
      ...circuit.components.map((e) => e.id.value),
      ...circuit.connections.map((e) => e.id.value),
      ...terminals.map((e) => e.value),
    };
    var serial = 0;
    String m;
    do {
      m = 'g5-ohm-${serial++}';
    } while (ids.any((id) => id.startsWith(m)));
    final sp = TerminalId('$m-plus');
    final sn = TerminalId('$m-minus');
    final rp = TerminalId('$m-ref-plus');
    final rn = TerminalId('$m-ref-minus');
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: ElectricalMode.dc,
      components: [
        ...circuit.components,
        ComponentInstance(
          id: ComponentId('$m-ref'),
          modelType: 'resistor',
          terminals: [Terminal(id: rp, name: 'A'), Terminal(id: rn, name: 'B')],
          parameters: const {'resistanceOhm': referenceOhm},
        ),
      ],
      sources: [
        SourceInstance(
          id: SourceId('$m-source'),
          modelType: 'dc_voltage_source',
          terminals: [
            Terminal(id: sp, name: '+', phase: PhaseTag.dcPositive),
            Terminal(id: sn, name: '-', phase: PhaseTag.dcNegative),
          ],
          parameters: const {'voltageV': testVoltageV},
        ),
      ],
      connections: [
        ...circuit.connections,
        Connection(id: ConnectionId('$m-wire-1'),
          fromTerminalId: sp, toTerminalId: rp),
        Connection(id: ConnectionId('$m-wire-2'),
          fromTerminalId: rn, toTerminalId: a),
        Connection(id: ConnectionId('$m-wire-3'),
          fromTerminalId: b, toTerminalId: sn),
      ],
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }
}
