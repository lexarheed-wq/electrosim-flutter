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

  /// A fuse can be physically replaced only after the instrument is OFF and
  /// EVERY electrical source/storage component has been removed from this
  /// simulation scene. A 0 V reading across the blown fuse is not isolation.
  /// This intentionally conservative policy cannot energize a repair scene.
  static bool canReplace(CircuitState circuit, InstrumentInstance meter) =>
      meter.kind == InstrumentKind.ammeter &&
      meter.fuseBlown &&
      !meter.poweredOn &&
      circuit.sources.isEmpty &&
      !circuit.components.any((component) {
        final type = component.modelType.toLowerCase();
        return type.contains('battery') ||
            type.contains('inverter') ||
            type.contains('generator') ||
            type.contains('alternator') ||
            type.contains('capacitor');
      });

  static CircuitState replaceSafely({
    required CircuitState circuit,
    required InstrumentId instrumentId,
  }) {
    final meter = circuit.instruments
        .where((item) => item.id == instrumentId)
        .firstOrNull;
    if (meter == null || !canReplace(circuit, meter)) return circuit;
    final replacement = InstrumentInstance(
      id: meter.id,
      kind: meter.kind,
      mode: meter.mode,
      inputImpedanceOhm: meter.inputImpedanceOhm,
      burdenResistanceOhm: meter.burdenResistanceOhm,
      maximumVoltageV: meter.maximumVoltageV,
      maximumCurrentA: meter.maximumCurrentA,
      fuseRatingA: meter.fuseRatingA,
      fuseBlown: false,
      poweredOn: meter.poweredOn,
      cutConnectionId: meter.cutConnectionId,
      settings: meter.settings,
    );
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision + 1,
      mode: circuit.mode,
      sources: circuit.sources,
      components: circuit.components,
      connections: circuit.connections,
      instruments: [
        for (final item in circuit.instruments)
          if (item.id == meter.id) replacement else item,
      ],
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

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
