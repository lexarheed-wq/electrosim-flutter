import 'package:electrosim_domain/electrosim_domain.dart';


/// The fuse is persistent state on the physical ammeter, never an edited
/// ordinary wire. Its electrical open state is projected only for simulation.
/// A user must explicitly replace a blown fuse; power cycling never resets it.
abstract final class F18AmmeterFuseSafety {
  static Connection? wiredCut(
    CircuitState circuit,
    InstrumentInstance instrument,
  ) {
    if (instrument.kind != InstrumentKind.ammeter ||
        instrument.cutConnectionId == null) {
      return null;
    }
    final Connection? cut = circuit.connections
        .where((c) => c.id == instrument.cutConnectionId && c.enabled)
        .firstOrNull;
    if (cut == null) return null;
    final TerminalId? amp = circuit.probes
        .where((p) =>
            p.instrumentId == instrument.id && p.port == InstrumentPort.amp)
        .firstOrNull
        ?.terminalId;
    final TerminalId? common = circuit.probes
        .where((p) =>
            p.instrumentId == instrument.id && p.port == InstrumentPort.common)
        .firstOrNull
        ?.terminalId;
    final bool bridged =
        (amp == cut.fromTerminalId && common == cut.toTerminalId) ||
        (amp == cut.toTerminalId && common == cut.fromTerminalId);
    return bridged ? cut : null;
  }

  /// Trips only when the caller supplies a solver-verified overcurrent. An invalid wiring,
  /// disconnected meter, unsupported mode or arbitrary ERR cannot blow a fuse.
  static bool shouldTrip({
    required CircuitState circuit,
    required InstrumentInstance instrument,
    required bool solverDetectedOvercurrent,
  }) =>
      instrument.kind == InstrumentKind.ammeter &&
      !instrument.fuseBlown &&
      instrument.poweredOn &&
      solverDetectedOvercurrent &&
      wiredCut(circuit, instrument) != null;

  static CircuitState latch({
    required CircuitState circuit,
    required InstrumentId instrumentId,
  }) {
    bool changed = false;
    final instruments = <InstrumentInstance>[
      for (final meter in circuit.instruments)
        if (meter.id == instrumentId &&
            meter.kind == InstrumentKind.ammeter &&
            !meter.fuseBlown &&
            wiredCut(circuit, meter) != null)
          _markBlown(meter)
        else
          meter,
    ];
    for (var index = 0; index < circuit.instruments.length; index++) {
      if (!identical(instruments[index], circuit.instruments[index])) {
        changed = true;
        break;
      }
    }
    if (!changed) return circuit;
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision + 1,
      mode: circuit.mode,
      components: circuit.components,
      sources: circuit.sources,
      connections: circuit.connections,
      instruments: instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  static InstrumentInstance _markBlown(InstrumentInstance meter) =>
      InstrumentInstance(
        id: meter.id,
        kind: meter.kind,
        mode: meter.mode,
        inputImpedanceOhm: meter.inputImpedanceOhm,
        burdenResistanceOhm: meter.burdenResistanceOhm,
        maximumVoltageV: meter.maximumVoltageV,
        maximumCurrentA: meter.maximumCurrentA,
        fuseRatingA: meter.fuseRatingA,
        fuseBlown: true,
        poweredOn: meter.poweredOn,
        cutConnectionId: meter.cutConnectionId,
        settings: meter.settings,
      );

  /// Runtime-only open circuit. The design connections and their metadata
  /// survive untouched; the solver sees exactly the cut wire disabled.
  static CircuitState projectOpenFuses(CircuitState design) {
    final cutIds = <ConnectionId>{
      for (final meter in design.instruments)
        if (meter.fuseBlown)
          if (wiredCut(design, meter) case final Connection cut) cut.id,
    };
    if (cutIds.isEmpty) return design;
    return CircuitState(
      circuitId: design.circuitId,
      revision: design.revision,
      mode: design.mode,
      sources: design.sources,
      components: design.components,
      instruments: design.instruments,
      probes: design.probes,
      connections: [
        for (final connection in design.connections)
          if (cutIds.contains(connection.id))
            Connection(
              id: connection.id,
              fromTerminalId: connection.fromTerminalId,
              toTerminalId: connection.toTerminalId,
              conductorType: connection.conductorType,
              phase: connection.phase,
              enabled: false,
              metadata: connection.metadata,
            )
          else
            connection,
      ],
      settings: design.settings,
      metadata: design.metadata,
    );
  }
}
