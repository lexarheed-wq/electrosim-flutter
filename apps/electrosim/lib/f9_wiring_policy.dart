import 'package:electrosim_domain/electrosim_domain.dart';

final class F9WiringDecision {
  const F9WiringDecision._({
    required this.accepted,
    required this.message,
    this.connection,
  });

  factory F9WiringDecision.accepted(Connection connection, String message) =>
      F9WiringDecision._(
        accepted: true,
        message: message,
        connection: connection,
      );

  factory F9WiringDecision.rejected(String message) =>
      F9WiringDecision._(accepted: false, message: message);

  final bool accepted;
  final String message;
  final Connection? connection;
}

abstract final class F9WiringPolicy {
  static F9WiringDecision evaluateAndBuild(
    CircuitState circuit,
    TerminalId from,
    TerminalId to,
  ) {
    if (from == to) {
      return F9WiringDecision.rejected(
        'Connexion refusée : une borne ne peut pas être reliée à elle-même.',
      );
    }

    final Terminal? fromTerminal = _findTerminal(circuit, from);
    final Terminal? toTerminal = _findTerminal(circuit, to);
    if (fromTerminal == null || toTerminal == null) {
      return F9WiringDecision.rejected(
        'Connexion refusée : borne inconnue dans le CircuitState.',
      );
    }

    for (final Connection connection in circuit.connections) {
      final bool sameDirection =
          connection.fromTerminalId == from && connection.toTerminalId == to;
      final bool reverseDirection =
          connection.fromTerminalId == to && connection.toTerminalId == from;
      if (sameDirection || reverseDirection) {
        return F9WiringDecision.rejected(
          'Connexion refusée : ces deux bornes sont déjà reliées.',
        );
      }
    }

    final PhaseTag fromPhase = fromTerminal.phase;
    final PhaseTag toPhase = toTerminal.phase;

    // Terminal phase/polarity tags describe the electrical terminals; they are
    // not a universal UI-level wiring prohibition. In particular, DC+ -> DC-
    // is required for valid series-source circuits and can also represent a
    // deliberate fault to be interpreted by TopologyEngine/SolverEngine.
    // Preserve an explicit wire phase only when both endpoints agree, or when
    // exactly one endpoint is untagged. Mixed explicit tags stay neutral.
    final PhaseTag phase = fromPhase == toPhase
        ? fromPhase
        : fromPhase == PhaseTag.none
        ? toPhase
        : toPhase == PhaseTag.none
        ? fromPhase
        : PhaseTag.none;
    final String id = _allocateConnectionId(circuit);
    final Connection connection = Connection(
      id: ConnectionId(id),
      fromTerminalId: from,
      toTerminalId: to,
      phase: phase,
      metadata: const <String, Object?>{'createdBy': 'F9WiringPolicy'},
    );
    return F9WiringDecision.accepted(
      connection,
      'Connexion créée : ${fromTerminal.name} → ${toTerminal.name} ($id).',
    );
  }

  static CircuitState append(CircuitState circuit, Connection connection) =>
      CircuitState(
        circuitId: circuit.circuitId,
        revision: circuit.revision + 1,
        mode: circuit.mode,
        components: circuit.components,
        connections: <Connection>[...circuit.connections, connection],
        sources: circuit.sources,
        settings: circuit.settings,
        metadata: circuit.metadata,
      );

  static Terminal? _findTerminal(CircuitState circuit, TerminalId id) {
    for (final ComponentInstance component in circuit.components) {
      for (final Terminal terminal in component.terminals) {
        if (terminal.id == id) {
          return terminal;
        }
      }
    }
    for (final SourceInstance source in circuit.sources) {
      for (final Terminal terminal in source.terminals) {
        if (terminal.id == id) {
          return terminal;
        }
      }
    }
    return null;
  }

  static String _allocateConnectionId(CircuitState circuit) {
    final Set<String> used = circuit.connections
        .map((Connection item) => item.id.value)
        .toSet();
    var serial = 1;
    while (used.contains('wire-$serial')) {
      serial += 1;
    }
    return 'wire-$serial';
  }
}
